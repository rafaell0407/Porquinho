-- Visual das categorias (Renovação visual V2): chave de ícone e de cor.
-- As chaves apontam para um conjunto fixo no app; ícone é livre em formato
-- (para acrescentar ícones sem migration) e a cor é uma de 8 chaves.
-- Categorias já existentes ficam com o padrão ('category', 'gray').
-- Subcategorias herdam o visual da categoria (sem colunas próprias).
BEGIN;

ALTER TABLE public.categories
    ADD COLUMN icon_key TEXT NOT NULL DEFAULT 'category'
        CHECK (icon_key ~ '^[a-z0-9_]{1,40}$'),
    ADD COLUMN color_key TEXT NOT NULL DEFAULT 'gray'
        CHECK (color_key IN ('yellow', 'blue', 'sand', 'cyan', 'pink', 'orange', 'lime', 'gray'));

-- A assinatura muda (dois parâmetros opcionais no fim); chamadas antigas com
-- seis argumentos continuam válidas.
DROP FUNCTION public.apply_category_change(UUID, TEXT, UUID, BIGINT, TEXT, TEXT);

CREATE FUNCTION public.apply_category_change(
    p_operation_id UUID,
    p_action TEXT,
    p_category_id UUID,
    p_expected_version BIGINT,
    p_kind TEXT,
    p_name TEXT,
    p_icon_key TEXT DEFAULT NULL,
    p_color_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner_id UUID;
    v_request JSONB;
    v_content_hash BYTEA;
    v_claimed_key UUID;
    v_stored_hash BYTEA;
    v_stored_result JSONB;
    v_category public.categories%ROWTYPE;
    v_conflict_id UUID;
    v_response JSONB;
    v_audit_operation TEXT;
    v_previous_values JSONB;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;

    IF p_operation_id IS NULL
        OR p_category_id IS NULL
        OR p_expected_version IS NULL
        OR p_action IS NULL
    THEN
        RAISE EXCEPTION 'operation id, action, category id and expected version are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_action NOT IN ('create', 'rename', 'restyle', 'deactivate') THEN
        RAISE EXCEPTION 'unsupported category action'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_icon_key IS NOT NULL AND p_icon_key !~ '^[a-z0-9_]{1,40}$' THEN
        RAISE EXCEPTION 'invalid category icon'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_color_key IS NOT NULL
        AND p_color_key NOT IN ('yellow', 'blue', 'sand', 'cyan', 'pink', 'orange', 'lime', 'gray')
    THEN
        RAISE EXCEPTION 'invalid category color'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_action = 'create' THEN
        IF p_expected_version <> 0
            OR p_kind IS NULL
            OR p_kind NOT IN ('income', 'expense')
            OR p_name IS NULL
        THEN
            RAISE EXCEPTION 'create requires version 0, a valid kind and a name'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSIF p_action = 'rename' THEN
        IF p_expected_version < 1 OR p_kind IS NOT NULL OR p_name IS NULL THEN
            RAISE EXCEPTION 'rename requires a positive version and a name only'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSIF p_action = 'restyle' THEN
        IF p_expected_version < 1
            OR p_kind IS NOT NULL
            OR p_name IS NOT NULL
            OR (p_icon_key IS NULL AND p_color_key IS NULL)
        THEN
            RAISE EXCEPTION 'restyle requires a positive version, an icon or a color, and no kind or name'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSE
        IF p_expected_version < 1
            OR p_kind IS NOT NULL
            OR p_name IS NOT NULL
            OR p_icon_key IS NOT NULL
            OR p_color_key IS NOT NULL
        THEN
            RAISE EXCEPTION 'deactivate requires a positive version and no kind, name, icon or color'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    END IF;

    -- Icon and color enter the fingerprint only when sent, so retries of
    -- operations queued before this migration keep their original content.
    v_request := pg_catalog.jsonb_build_object(
        'action', p_action,
        'category_id', p_category_id,
        'expected_version', p_expected_version,
        'kind', p_kind,
        'name', p_name
    );
    IF p_icon_key IS NOT NULL OR p_color_key IS NOT NULL THEN
        v_request := v_request || pg_catalog.jsonb_build_object(
            'icon_key', p_icon_key,
            'color_key', p_color_key
        );
    END IF;

    -- MD5 is only a fast fingerprint. Exact JSONB equality below also checks
    -- the request, so a fingerprint collision cannot authorize a changed retry.
    v_content_hash := pg_catalog.decode(
        pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT, 'UTF8')),
        'hex'
    );

    INSERT INTO public.applied_sync_operations (
        owner_id,
        idempotency_key,
        content_hash,
        result_payload
    )
    VALUES (
        v_owner_id,
        p_operation_id,
        v_content_hash,
        pg_catalog.jsonb_build_object('request', v_request, 'response', NULL)
    )
    ON CONFLICT (owner_id, idempotency_key) DO NOTHING
    RETURNING idempotency_key INTO v_claimed_key;

    IF NOT FOUND THEN
        SELECT operation.content_hash, operation.result_payload
        INTO v_stored_hash, v_stored_result
        FROM public.applied_sync_operations AS operation
        WHERE operation.owner_id = v_owner_id
          AND operation.idempotency_key = p_operation_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'idempotency result disappeared during the operation'
                USING ERRCODE = 'serialization_failure';
        END IF;

        IF v_stored_hash IS DISTINCT FROM v_content_hash
            OR v_stored_result -> 'request' IS DISTINCT FROM v_request
        THEN
            RAISE EXCEPTION 'idempotency key was already used with different content'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;

        RETURN v_stored_result -> 'response';
    END IF;

    IF p_action = 'create' THEN
        INSERT INTO public.categories (owner_id, id, kind, name, icon_key, color_key)
        VALUES (
            v_owner_id,
            p_category_id,
            p_kind,
            p_name,
            COALESCE(p_icon_key, 'category'),
            COALESCE(p_color_key, 'gray')
        )
        RETURNING * INTO v_category;

        v_audit_operation := 'create';
        v_previous_values := NULL;
    ELSE
        SELECT category.*
        INTO v_category
        FROM public.categories AS category
        WHERE category.owner_id = v_owner_id
          AND category.id = p_category_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'category was not found for the authenticated user'
                USING ERRCODE = 'no_data_found';
        END IF;

        IF v_category.version <> p_expected_version THEN
            INSERT INTO public.sync_conflicts (
                owner_id,
                id,
                entity_type,
                entity_id,
                base_version,
                remote_version,
                local_snapshot,
                remote_snapshot
            )
            VALUES (
                v_owner_id,
                pg_catalog.gen_random_uuid(),
                'category',
                p_category_id,
                p_expected_version,
                v_category.version,
                v_request,
                pg_catalog.to_jsonb(v_category)
            )
            RETURNING id INTO v_conflict_id;

            v_response := pg_catalog.jsonb_build_object(
                'status', 'conflict',
                'conflict_id', v_conflict_id,
                'remote_category', pg_catalog.to_jsonb(v_category)
            );
        ELSE
            v_previous_values := pg_catalog.to_jsonb(v_category);

            UPDATE public.categories AS category
            SET name = CASE WHEN p_action = 'rename' THEN p_name ELSE category.name END,
                icon_key = CASE WHEN p_action IN ('rename', 'restyle')
                    THEN COALESCE(p_icon_key, category.icon_key) ELSE category.icon_key END,
                color_key = CASE WHEN p_action IN ('rename', 'restyle')
                    THEN COALESCE(p_color_key, category.color_key) ELSE category.color_key END,
                is_active = CASE WHEN p_action = 'deactivate' THEN FALSE ELSE category.is_active END,
                version = category.version + 1,
                updated_at = pg_catalog.clock_timestamp()
            WHERE category.owner_id = v_owner_id
              AND category.id = p_category_id
            RETURNING category.* INTO v_category;

            v_audit_operation := p_action;
        END IF;
    END IF;

    IF v_audit_operation IS NOT NULL THEN
        INSERT INTO public.audit_events (
            owner_id,
            id,
            entity_type,
            entity_id,
            operation,
            actor_id,
            previous_values,
            new_values,
            operation_id
        )
        VALUES (
            v_owner_id,
            pg_catalog.gen_random_uuid(),
            'category',
            p_category_id,
            v_audit_operation,
            v_owner_id,
            v_previous_values,
            pg_catalog.to_jsonb(v_category),
            p_operation_id
        );

        v_response := pg_catalog.jsonb_build_object(
            'status', 'applied',
            'category', pg_catalog.to_jsonb(v_category)
        );
    END IF;

    UPDATE public.applied_sync_operations AS operation
    SET result_payload = pg_catalog.jsonb_build_object(
            'request', v_request,
            'response', v_response
        ),
        applied_at = pg_catalog.clock_timestamp()
    WHERE operation.owner_id = v_owner_id
      AND operation.idempotency_key = p_operation_id;

    RETURN v_response;
END;
$function$;

ALTER FUNCTION public.apply_category_change(UUID, TEXT, UUID, BIGINT, TEXT, TEXT, TEXT, TEXT)
    OWNER TO postgres;

REVOKE ALL ON FUNCTION public.apply_category_change(UUID, TEXT, UUID, BIGINT, TEXT, TEXT, TEXT, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_category_change(UUID, TEXT, UUID, BIGINT, TEXT, TEXT, TEXT, TEXT)
    TO authenticated;

COMMENT ON FUNCTION public.apply_category_change(UUID, TEXT, UUID, BIGINT, TEXT, TEXT, TEXT, TEXT)
    IS 'Applies one authenticated category create, rename, restyle (icon and color) or deactivate operation with optimistic versioning, idempotency and audit in one transaction.';

-- Resolução de conflito: 'manter o meu' em categoria leva ícone e cor.
CREATE OR REPLACE FUNCTION public.resolve_sync_conflict(
    p_operation_id UUID,
    p_conflict_id UUID,
    p_resolution TEXT,
    p_request JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB;
    v_hash BYTEA;
    v_claimed UUID;
    v_saved_hash BYTEA;
    v_saved JSONB;
    v_conflict public.sync_conflicts%ROWTYPE;
    v_chosen JSONB;
    v_inner_operation UUID;
    v_version BIGINT;
    v_has_template BOOLEAN;
    v_inner JSONB;
    v_remote JSONB;
    v_response JSONB;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_conflict_id IS NULL OR p_resolution IS NULL
        OR p_resolution NOT IN ('keep_local', 'keep_remote', 'edit') THEN
        RAISE EXCEPTION 'operation, conflict and a valid resolution are required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF (p_resolution = 'edit') <> (p_request IS NOT NULL)
        OR (p_request IS NOT NULL AND pg_catalog.jsonb_typeof(p_request) <> 'object') THEN
        RAISE EXCEPTION 'edit requires a request object and the other resolutions must not send one'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object('conflict_id', p_conflict_id,
        'resolution', p_resolution, 'request', p_request);
    v_hash := pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT, 'UTF8')), 'hex');
    INSERT INTO public.applied_sync_operations(owner_id, idempotency_key, content_hash, result_payload)
    VALUES (v_owner, p_operation_id, v_hash, pg_catalog.jsonb_build_object('request', v_request, 'response', NULL))
    ON CONFLICT (owner_id, idempotency_key) DO NOTHING RETURNING idempotency_key INTO v_claimed;
    IF NOT FOUND THEN
        SELECT op.content_hash, op.result_payload INTO v_saved_hash, v_saved
        FROM public.applied_sync_operations op
        WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved -> 'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        RETURN v_saved -> 'response';
    END IF;

    SELECT c.* INTO v_conflict FROM public.sync_conflicts c
    WHERE c.owner_id = v_owner AND c.id = p_conflict_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'conflict was not found for the authenticated user' USING ERRCODE = 'no_data_found';
    END IF;
    IF v_conflict.status <> 'open' THEN
        RAISE EXCEPTION 'conflict is already resolved' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_resolution = 'keep_remote' THEN
        v_remote := v_conflict.remote_snapshot;
        v_response := pg_catalog.jsonb_build_object('status', 'resolved', 'resolution', p_resolution,
            'conflict_id', p_conflict_id, 'record', v_remote);
    ELSE
        IF v_conflict.entity_type NOT IN ('category', 'subcategory', 'investment_allocation',
            'income_entry', 'expense_entry', 'income_recurrence_template', 'expense_recurrence_template',
            'investment_recurrence_template') THEN
            RAISE EXCEPTION 'this conflict type only supports keep_remote' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        v_chosen := CASE p_resolution WHEN 'keep_local' THEN v_conflict.local_snapshot ELSE p_request END;
        IF v_chosen ->> 'action' IS NULL OR v_chosen ->> 'action' = 'create' THEN
            RAISE EXCEPTION 'only updates can be re-applied; use keep_remote for a create conflict'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        v_inner_operation := pg_catalog.md5(p_operation_id::TEXT || ':apply')::UUID;

        -- Current remote version, read under lock so the inner call cannot conflict again.
        EXECUTE pg_catalog.format(
            'SELECT t.version, %s FROM public.%I t WHERE t.owner_id = $1 AND t.id = $2 FOR UPDATE',
            CASE WHEN v_conflict.entity_type IN ('income_entry', 'expense_entry')
                 THEN 't.recurrence_template_id IS NOT NULL' ELSE 'false' END,
            CASE v_conflict.entity_type
                WHEN 'category' THEN 'categories'
                WHEN 'subcategory' THEN 'subcategories'
                WHEN 'investment_allocation' THEN 'investment_allocations'
                WHEN 'income_entry' THEN 'income_entries'
                WHEN 'expense_entry' THEN 'expense_entries'
                WHEN 'investment_recurrence_template' THEN 'investment_recurrence_templates'
                WHEN 'income_recurrence_template' THEN 'income_recurrence_templates'
                ELSE 'expense_recurrence_templates' END)
        INTO v_version, v_has_template USING v_owner, v_conflict.entity_id;
        IF v_version IS NULL THEN
            RAISE EXCEPTION 'record was not found for the authenticated user' USING ERRCODE = 'no_data_found';
        END IF;

        v_inner := CASE v_conflict.entity_type
            WHEN 'category' THEN public.apply_category_change(v_inner_operation, v_chosen ->> 'action',
                v_conflict.entity_id, v_version, v_chosen ->> 'kind', v_chosen ->> 'name',
                v_chosen ->> 'icon_key', v_chosen ->> 'color_key')
            WHEN 'subcategory' THEN public.apply_subcategory_change(v_inner_operation, v_chosen ->> 'action',
                v_conflict.entity_id, (v_chosen ->> 'category_id')::UUID, v_version, v_chosen ->> 'name')
            WHEN 'investment_allocation' THEN public.apply_investment_allocation_change(v_inner_operation,
                v_chosen ->> 'action', v_conflict.entity_id, v_version,
                (v_chosen ->> 'amount_centavos')::BIGINT, (v_chosen ->> 'allocated_on')::DATE)
            WHEN 'income_entry' THEN CASE WHEN v_has_template
                THEN public.apply_income_recurrence_occurrence_change(v_inner_operation, v_chosen ->> 'action',
                    v_conflict.entity_id, v_version, v_chosen -> 'payload')
                ELSE public.apply_income_entry_change(v_inner_operation, v_chosen ->> 'action',
                    v_conflict.entity_id, v_version, v_chosen -> 'payload') END
            WHEN 'expense_entry' THEN CASE WHEN v_has_template
                THEN public.apply_expense_recurrence_occurrence_change(v_inner_operation, v_chosen ->> 'action',
                    v_conflict.entity_id, v_version, v_chosen -> 'payload')
                ELSE public.apply_expense_entry_change(v_inner_operation, v_chosen ->> 'action',
                    v_conflict.entity_id, v_version, v_chosen -> 'payload') END
            WHEN 'investment_recurrence_template' THEN public.apply_investment_recurrence_template_change(
                v_inner_operation, v_chosen ->> 'action', v_conflict.entity_id, v_version, v_chosen -> 'payload')
            WHEN 'income_recurrence_template' THEN public.apply_income_recurrence_template_change(
                v_inner_operation, v_chosen ->> 'action', v_conflict.entity_id, v_version, v_chosen -> 'payload')
            ELSE public.apply_expense_recurrence_template_change(
                v_inner_operation, v_chosen ->> 'action', v_conflict.entity_id, v_version, v_chosen -> 'payload')
        END;
        IF v_inner ->> 'status' IS DISTINCT FROM 'applied' THEN
            RAISE EXCEPTION 'consolidated version could not be applied: %', v_inner
                USING ERRCODE = 'serialization_failure';
        END IF;
        v_response := pg_catalog.jsonb_build_object('status', 'resolved', 'resolution', p_resolution,
            'conflict_id', p_conflict_id, 'result', v_inner);
    END IF;

    UPDATE public.sync_conflicts c
    SET status = 'resolved',
        resolution_payload = pg_catalog.jsonb_build_object('resolution', p_resolution,
            'operation_id', p_operation_id, 'request', p_request, 'response', v_response),
        resolved_at = pg_catalog.clock_timestamp(),
        version = c.version + 1,
        updated_at = pg_catalog.clock_timestamp()
    WHERE c.owner_id = v_owner AND c.id = p_conflict_id;

    INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id, operation, actor_id,
        previous_values, new_values, operation_id)
    VALUES (v_owner, pg_catalog.gen_random_uuid(), 'sync_conflict', p_conflict_id, 'conflict_resolved', v_owner,
        pg_catalog.jsonb_build_object('status', 'open', 'local', v_conflict.local_snapshot,
            'remote', v_conflict.remote_snapshot),
        pg_catalog.jsonb_build_object('status', 'resolved', 'resolution', p_resolution, 'response', v_response),
        p_operation_id);

    UPDATE public.applied_sync_operations op
    SET result_payload = pg_catalog.jsonb_build_object('request', v_request, 'response', v_response),
        applied_at = pg_catalog.clock_timestamp()
    WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id;

    RETURN v_response;
END;
$function$;

COMMIT;
