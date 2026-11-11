-- Resolution of open sync conflicts (Entrega 21B).
-- keep_remote: no data change, conflict closed, audit event.
-- keep_local / edit: the chosen request is re-applied through the entity's own
-- RPC against the CURRENT remote version, creating a new consolidated version.
-- Both original versions stay preserved in sync_conflicts.
BEGIN;

CREATE FUNCTION public.resolve_sync_conflict(
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
            'income_entry', 'expense_entry', 'income_recurrence_template', 'expense_recurrence_template') THEN
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
                WHEN 'income_recurrence_template' THEN 'income_recurrence_templates'
                ELSE 'expense_recurrence_templates' END)
        INTO v_version, v_has_template USING v_owner, v_conflict.entity_id;
        IF v_version IS NULL THEN
            RAISE EXCEPTION 'record was not found for the authenticated user' USING ERRCODE = 'no_data_found';
        END IF;

        v_inner := CASE v_conflict.entity_type
            WHEN 'category' THEN public.apply_category_change(v_inner_operation, v_chosen ->> 'action',
                v_conflict.entity_id, v_version, v_chosen ->> 'kind', v_chosen ->> 'name')
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

ALTER FUNCTION public.resolve_sync_conflict(UUID, UUID, TEXT, JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.resolve_sync_conflict(UUID, UUID, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_sync_conflict(UUID, UUID, TEXT, JSONB) TO authenticated;

COMMENT ON FUNCTION public.resolve_sync_conflict(UUID, UUID, TEXT, JSONB)
    IS 'Resolves one open sync conflict (keep_local, keep_remote or edit) idempotently, creating a consolidated version and audit event.';

COMMIT;
