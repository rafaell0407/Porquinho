\set ON_ERROR_STOP on

-- Synthetic identities only. The test runs inside an isolated PostgreSQL cluster.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('10000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000001',
    TRUE
);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    category_id CONSTANT UUID := '10000000-0000-0000-0000-000000001001';
    create_operation CONSTANT UUID := '20000000-0000-0000-0000-000000000001';
    rename_operation CONSTANT UUID := '20000000-0000-0000-0000-000000000002';
    conflict_operation CONSTANT UUID := '20000000-0000-0000-0000-000000000003';
    deactivate_operation CONSTANT UUID := '20000000-0000-0000-0000-000000000004';
    response JSONB;
    replay JSONB;
    category_row public.categories%ROWTYPE;
    conflict_row public.sync_conflicts%ROWTYPE;
    audit_count BIGINT;
BEGIN
    IF NOT pg_catalog.has_function_privilege(
        'authenticated',
        'public.apply_category_change(uuid,text,uuid,bigint,text,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'authenticated must be able to execute the category RPC';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS function
        WHERE function.oid = 'public.apply_category_change(uuid,text,uuid,bigint,text,text)'::REGPROCEDURE
          AND function.prosecdef
          AND function.proowner = 'postgres'::REGROLE
    ) THEN
        RAISE EXCEPTION 'category RPC must use the reviewed SECURITY DEFINER owner';
    END IF;

    IF pg_catalog.has_function_privilege(
        'anon',
        'public.apply_category_change(uuid,text,uuid,bigint,text,text)',
        'EXECUTE'
    ) OR EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS function
        CROSS JOIN LATERAL pg_catalog.aclexplode(
            COALESCE(
                function.proacl,
                pg_catalog.acldefault('f', function.proowner)
            )
        ) AS privilege
        WHERE function.oid = 'public.apply_category_change(uuid,text,uuid,bigint,text,text)'::REGPROCEDURE
          AND privilege.grantee = 0
          AND privilege.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anonymous or PUBLIC execution must be revoked';
    END IF;

    response := public.apply_category_change(
        create_operation, 'create', category_id, 0, 'income', 'Salário'
    );
    IF response ->> 'status' <> 'applied'
        OR response #>> '{category,version}' <> '1'
        OR response #>> '{category,is_active}' <> 'true'
    THEN
        RAISE EXCEPTION 'category create returned an unexpected response: %', response;
    END IF;

    replay := public.apply_category_change(
        create_operation, 'create', category_id, 0, 'income', 'Salário'
    );
    IF replay IS DISTINCT FROM response THEN
        RAISE EXCEPTION 'replaying a successful operation must return its original response';
    END IF;

    SELECT pg_catalog.count(*) INTO audit_count
    FROM public.audit_events AS event
    WHERE event.owner_id = auth.uid()
      AND event.entity_id = category_id;
    IF audit_count <> 1 THEN
        RAISE EXCEPTION 'an idempotent replay created duplicate audit events';
    END IF;

    BEGIN
        PERFORM public.apply_category_change(
            create_operation, 'create', category_id, 0, 'income', 'Outra descrição'
        );
        RAISE EXCEPTION 'reusing an idempotency key with changed content must fail'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;

    response := public.apply_category_change(
        rename_operation, 'rename', category_id, 1, NULL, 'Salário principal'
    );
    IF response ->> 'status' <> 'applied'
        OR response #>> '{category,name}' <> 'Salário principal'
        OR response #>> '{category,version}' <> '2'
    THEN
        RAISE EXCEPTION 'category rename did not advance its version: %', response;
    END IF;

    SELECT category.* INTO category_row
    FROM public.categories AS category
    WHERE category.owner_id = auth.uid()
      AND category.id = category_id;
    IF category_row.name <> 'Salário principal' OR category_row.version <> 2 THEN
        RAISE EXCEPTION 'renamed category was not persisted';
    END IF;

    SELECT pg_catalog.count(*) INTO audit_count
    FROM public.audit_events AS event
    WHERE event.owner_id = auth.uid()
      AND event.entity_id = category_id;
    IF audit_count <> 2 THEN
        RAISE EXCEPTION 'category create and rename must each have one audit event';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.audit_events AS event
        WHERE event.owner_id = auth.uid()
          AND event.entity_id = category_id
          AND event.operation = 'rename'
          AND event.previous_values ->> 'name' = 'Salário'
          AND event.new_values ->> 'name' = 'Salário principal'
    ) THEN
        RAISE EXCEPTION 'rename audit must preserve previous and new values';
    END IF;

    response := public.apply_category_change(
        conflict_operation, 'rename', category_id, 1, NULL, 'Nome desatualizado'
    );
    IF response ->> 'status' <> 'conflict'
        OR response #>> '{remote_category,version}' <> '2'
    THEN
        RAISE EXCEPTION 'stale version must return the current version as a conflict';
    END IF;

    replay := public.apply_category_change(
        conflict_operation, 'rename', category_id, 1, NULL, 'Nome desatualizado'
    );
    IF replay IS DISTINCT FROM response THEN
        RAISE EXCEPTION 'replaying a conflict must return the original conflict';
    END IF;

    SELECT conflict.* INTO conflict_row
    FROM public.sync_conflicts AS conflict
    WHERE conflict.owner_id = auth.uid()
      AND conflict.id = (response ->> 'conflict_id')::UUID;
    IF NOT FOUND
        OR conflict_row.entity_type <> 'category'
        OR conflict_row.entity_id <> category_id
        OR conflict_row.base_version <> 1
        OR conflict_row.remote_version <> 2
        OR conflict_row.local_snapshot ->> 'name' <> 'Nome desatualizado'
        OR conflict_row.remote_snapshot ->> 'name' <> 'Salário principal'
        OR conflict_row.status <> 'open'
    THEN
        RAISE EXCEPTION 'stale version snapshots were not preserved';
    END IF;

    SELECT pg_catalog.count(*) INTO audit_count
    FROM public.audit_events AS event
    WHERE event.owner_id = auth.uid()
      AND event.entity_id = category_id;
    IF audit_count <> 2 THEN
        RAISE EXCEPTION 'a rejected stale version must not modify category or add a success audit';
    END IF;

    response := public.apply_category_change(
        deactivate_operation, 'deactivate', category_id, 2, NULL, NULL
    );
    IF response ->> 'status' <> 'applied'
        OR response #>> '{category,is_active}' <> 'false'
        OR response #>> '{category,version}' <> '3'
    THEN
        RAISE EXCEPTION 'category deactivation was not versioned: %', response;
    END IF;

    SELECT pg_catalog.count(*) INTO audit_count
    FROM public.audit_events AS event
    WHERE event.owner_id = auth.uid()
      AND event.entity_id = category_id;
    IF audit_count <> 3 THEN
        RAISE EXCEPTION 'category deactivation must append an audit event';
    END IF;

    PERFORM pg_catalog.set_config(
        'request.jwt.claim.sub',
        '10000000-0000-0000-0000-000000000002',
        TRUE
    );
    BEGIN
        PERFORM public.apply_category_change(
            '30000000-0000-0000-0000-000000000001',
            'rename', category_id, 3, NULL, 'Acesso cruzado'
        );
        RAISE EXCEPTION 'one user must not mutate another user category'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN no_data_found THEN
        NULL;
    END;

    IF EXISTS (
        SELECT 1 FROM public.categories AS category
        WHERE category.id = category_id
    ) THEN
        RAISE EXCEPTION 'RLS must hide another user category';
    END IF;

    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '', TRUE);
    BEGIN
        PERFORM public.apply_category_change(
            '30000000-0000-0000-0000-000000000002',
            'create', '30000000-0000-0000-0000-000000000003', 0, 'expense', 'Sem sessão'
        );
        RAISE EXCEPTION 'unauthenticated category operations must fail'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_authorization_specification THEN
        NULL;
    END;

    PERFORM pg_catalog.set_config(
        'request.jwt.claim.sub',
        '10000000-0000-0000-0000-000000000001',
        TRUE
    );
    BEGIN
        INSERT INTO public.categories (owner_id, id, kind, name)
        VALUES (auth.uid(), '30000000-0000-0000-0000-000000000004', 'expense', 'DML direto');
        RAISE EXCEPTION 'direct category writes must fail'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END;
$test$;

ROLLBACK;

\echo PASS: category RPC authentication, idempotency, version conflicts and audit.
