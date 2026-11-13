\set ON_ERROR_STOP on

-- Synthetic identities only. The test runs inside an isolated PostgreSQL cluster.
BEGIN;

INSERT INTO auth.users (id) VALUES ('10000000-0000-0000-0000-000000000011');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000011',
    TRUE
);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    plain_id CONSTANT UUID := '40000000-0000-0000-0000-000000001001';
    styled_id CONSTANT UUID := '40000000-0000-0000-0000-000000001002';
    response JSONB;
    replay JSONB;
    category_row public.categories%ROWTYPE;
    audit_row public.audit_events%ROWTYPE;
BEGIN
    -- Create without appearance keeps the neutral defaults.
    response := public.apply_category_change(
        '50000000-0000-0000-0000-000000000001',
        'create', plain_id, 0, 'expense', 'Sem visual'
    );
    SELECT * INTO category_row FROM public.categories WHERE id = plain_id;
    IF category_row.icon_key <> 'category' OR category_row.color_key <> 'gray' THEN
        RAISE EXCEPTION 'default appearance expected, got % / %', category_row.icon_key, category_row.color_key;
    END IF;

    -- Create with icon and color.
    response := public.apply_category_change(
        '50000000-0000-0000-0000-000000000002',
        'create', styled_id, 0, 'expense', 'Com visual', 'home', 'blue'
    );
    SELECT * INTO category_row FROM public.categories WHERE id = styled_id;
    IF category_row.icon_key <> 'home' OR category_row.color_key <> 'blue' OR category_row.version <> 1 THEN
        RAISE EXCEPTION 'created appearance expected, got % / % v%',
            category_row.icon_key, category_row.color_key, category_row.version;
    END IF;

    -- Restyle changes only icon and color and bumps the version with audit.
    response := public.apply_category_change(
        '50000000-0000-0000-0000-000000000003',
        'restyle', styled_id, 1, NULL, NULL, 'car', NULL
    );
    IF response ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'restyle must apply: %', response;
    END IF;
    SELECT * INTO category_row FROM public.categories WHERE id = styled_id;
    IF category_row.icon_key <> 'car'
        OR category_row.color_key <> 'blue'
        OR category_row.name <> 'Com visual'
        OR category_row.version <> 2
    THEN
        RAISE EXCEPTION 'restyle must change only the icon and bump the version';
    END IF;
    SELECT * INTO audit_row FROM public.audit_events
    WHERE operation_id = '50000000-0000-0000-0000-000000000003';
    IF audit_row.operation <> 'restyle'
        OR audit_row.previous_values ->> 'icon_key' <> 'home'
        OR audit_row.new_values ->> 'icon_key' <> 'car'
    THEN
        RAISE EXCEPTION 'restyle audit must keep old and new icon';
    END IF;

    -- Idempotent replay returns the stored response without a second change.
    replay := public.apply_category_change(
        '50000000-0000-0000-0000-000000000003',
        'restyle', styled_id, 1, NULL, NULL, 'car', NULL
    );
    IF replay IS DISTINCT FROM response THEN
        RAISE EXCEPTION 'replay must return the same response';
    END IF;
    SELECT * INTO category_row FROM public.categories WHERE id = styled_id;
    IF category_row.version <> 2 THEN
        RAISE EXCEPTION 'replay must not change the version again';
    END IF;

    -- Same key with different content is refused.
    BEGIN
        PERFORM public.apply_category_change(
            '50000000-0000-0000-0000-000000000003',
            'restyle', styled_id, 1, NULL, NULL, 'heart', NULL
        );
        RAISE EXCEPTION 'changed retry must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;

    -- Rename may carry a new appearance in the same operation.
    response := public.apply_category_change(
        '50000000-0000-0000-0000-000000000004',
        'rename', styled_id, 2, NULL, 'Com visual novo', NULL, 'pink'
    );
    SELECT * INTO category_row FROM public.categories WHERE id = styled_id;
    IF category_row.name <> 'Com visual novo'
        OR category_row.icon_key <> 'car'
        OR category_row.color_key <> 'pink'
        OR category_row.version <> 3
    THEN
        RAISE EXCEPTION 'rename with color must keep the icon and change the color';
    END IF;

    -- Version conflict opens a conflict and changes nothing.
    response := public.apply_category_change(
        '50000000-0000-0000-0000-000000000005',
        'restyle', styled_id, 1, NULL, NULL, 'book', NULL
    );
    IF response ->> 'status' <> 'conflict' THEN
        RAISE EXCEPTION 'stale restyle must conflict: %', response;
    END IF;

    -- Invalid values are refused.
    BEGIN
        PERFORM public.apply_category_change(
            '50000000-0000-0000-0000-000000000006',
            'restyle', styled_id, 3, NULL, NULL, NULL, 'purple'
        );
        RAISE EXCEPTION 'unknown color must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;
    BEGIN
        PERFORM public.apply_category_change(
            '50000000-0000-0000-0000-000000000007',
            'restyle', styled_id, 3, NULL, NULL, 'Bad Icon!', NULL
        );
        RAISE EXCEPTION 'malformed icon must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;
    BEGIN
        PERFORM public.apply_category_change(
            '50000000-0000-0000-0000-000000000008',
            'restyle', styled_id, 3, NULL, NULL, NULL, NULL
        );
        RAISE EXCEPTION 'restyle without icon or color must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;
    BEGIN
        PERFORM public.apply_category_change(
            '50000000-0000-0000-0000-000000000009',
            'deactivate', styled_id, 3, NULL, NULL, 'home', NULL
        );
        RAISE EXCEPTION 'deactivate with icon must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;
END;
$test$;

ROLLBACK;

\echo PASS: category appearance (icon and color) create, restyle, rename, idempotency, conflict and validation.
