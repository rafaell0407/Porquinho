-- Transactional category operations for the approved MVP category lifecycle.
-- Ownership is always derived from Supabase Auth; clients never send owner_id.
BEGIN;

CREATE FUNCTION public.apply_category_change(
    p_operation_id UUID,
    p_action TEXT,
    p_category_id UUID,
    p_expected_version BIGINT,
    p_kind TEXT,
    p_name TEXT
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

    IF p_action NOT IN ('create', 'rename', 'deactivate') THEN
        RAISE EXCEPTION 'unsupported category action'
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
    ELSE
        IF p_expected_version < 1 OR p_kind IS NOT NULL OR p_name IS NOT NULL THEN
            RAISE EXCEPTION 'deactivate requires a positive version and no kind or name'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    END IF;

    v_request := pg_catalog.jsonb_build_object(
        'action', p_action,
        'category_id', p_category_id,
        'expected_version', p_expected_version,
        'kind', p_kind,
        'name', p_name
    );

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
        INSERT INTO public.categories (owner_id, id, kind, name)
        VALUES (v_owner_id, p_category_id, p_kind, p_name)
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

ALTER FUNCTION public.apply_category_change(UUID, TEXT, UUID, BIGINT, TEXT, TEXT)
    OWNER TO postgres;

REVOKE ALL ON FUNCTION public.apply_category_change(UUID, TEXT, UUID, BIGINT, TEXT, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_category_change(UUID, TEXT, UUID, BIGINT, TEXT, TEXT)
    TO authenticated;

COMMENT ON FUNCTION public.apply_category_change(UUID, TEXT, UUID, BIGINT, TEXT, TEXT)
    IS 'Applies one authenticated category create, rename or deactivate operation with optimistic versioning, idempotency and audit in one transaction.';

COMMIT;
