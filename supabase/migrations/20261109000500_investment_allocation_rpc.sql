-- Authenticated, versioned investment allocation writes with audit and idempotency.
BEGIN;

CREATE FUNCTION public.apply_investment_allocation_change(
    p_operation_id UUID,
    p_action TEXT,
    p_allocation_id UUID,
    p_expected_version BIGINT,
    p_amount_centavos BIGINT,
    p_allocated_on DATE
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
    v_stored_hash BYTEA;
    v_stored JSONB;
    v_row public.investment_allocations%ROWTYPE;
    v_period public.accounting_periods%ROWTYPE;
    v_existing public.investment_allocations%ROWTYPE;
    v_conflict UUID;
    v_response JSONB;
    v_previous JSONB;
    v_audit_operation TEXT;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_allocation_id IS NULL
        OR p_expected_version IS NULL OR p_action IS NULL THEN
        RAISE EXCEPTION 'operation, allocation, action and expected version are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_action NOT IN ('create', 'update', 'cancel') THEN
        RAISE EXCEPTION 'unsupported investment allocation action'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF (p_action = 'create' AND p_expected_version <> 0)
        OR (p_action <> 'create' AND p_expected_version < 1) THEN
        RAISE EXCEPTION 'expected version does not match action'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_action = 'create' OR p_action = 'update' THEN
        IF p_amount_centavos IS NULL OR p_amount_centavos < 0 OR p_allocated_on IS NULL THEN
            RAISE EXCEPTION 'amount must be nonnegative and allocation date is required'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSIF p_amount_centavos IS NOT NULL OR p_allocated_on IS NOT NULL THEN
        RAISE EXCEPTION 'cancel does not accept allocation values'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object(
        'action', p_action, 'allocation_id', p_allocation_id,
        'expected_version', p_expected_version,
        'amount_centavos', p_amount_centavos, 'allocated_on', p_allocated_on
    );
    v_hash := pg_catalog.decode(
        pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT, 'UTF8')), 'hex'
    );
    INSERT INTO public.applied_sync_operations(owner_id, idempotency_key, content_hash, result_payload)
    VALUES (v_owner, p_operation_id, v_hash,
        pg_catalog.jsonb_build_object('request', v_request, 'response', NULL))
    ON CONFLICT (owner_id, idempotency_key) DO NOTHING
    RETURNING idempotency_key INTO v_claimed;
    IF NOT FOUND THEN
        SELECT op.content_hash, op.result_payload INTO v_stored_hash, v_stored
        FROM public.applied_sync_operations AS op
        WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id FOR UPDATE;
        IF v_stored_hash IS DISTINCT FROM v_hash
            OR v_stored -> 'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key was already used with different content'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        RETURN v_stored -> 'response';
    END IF;

    IF p_action = 'create' THEN
        SELECT allocation.* INTO v_existing
        FROM public.investment_allocations AS allocation
        WHERE allocation.owner_id = v_owner AND allocation.id = p_allocation_id
        FOR UPDATE;
        IF FOUND THEN
            INSERT INTO public.sync_conflicts(owner_id, id, entity_type, entity_id,
                base_version, remote_version, local_snapshot, remote_snapshot)
            VALUES (v_owner, pg_catalog.gen_random_uuid(), 'investment_allocation',
                p_allocation_id, 0, v_existing.version, v_request,
                pg_catalog.to_jsonb(v_existing)) RETURNING id INTO v_conflict;
            v_response := pg_catalog.jsonb_build_object('status', 'conflict',
                'conflict_id', v_conflict, 'remote_allocation', pg_catalog.to_jsonb(v_existing));
        ELSE
            SELECT period.* INTO v_period
            FROM public.accounting_periods AS period
            WHERE period.owner_id = v_owner
              AND period.start_date <= p_allocated_on AND p_allocated_on < period.end_date;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'no accounting period covers the allocation date'
                    USING ERRCODE = 'foreign_key_violation';
            END IF;
            INSERT INTO public.investment_allocations(owner_id, id, amount_centavos,
                allocated_on, accounting_period_id)
            VALUES (v_owner, p_allocation_id, p_amount_centavos, p_allocated_on, v_period.id)
            RETURNING * INTO v_row;
            v_audit_operation := 'create';
        END IF;
    ELSE
        SELECT allocation.* INTO v_row
        FROM public.investment_allocations AS allocation
        WHERE allocation.owner_id = v_owner AND allocation.id = p_allocation_id
        FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'investment allocation was not found for the authenticated user'
                USING ERRCODE = 'no_data_found';
        END IF;
        IF v_row.version <> p_expected_version THEN
            INSERT INTO public.sync_conflicts(owner_id, id, entity_type, entity_id,
                base_version, remote_version, local_snapshot, remote_snapshot)
            VALUES (v_owner, pg_catalog.gen_random_uuid(), 'investment_allocation',
                p_allocation_id, p_expected_version, v_row.version, v_request,
                pg_catalog.to_jsonb(v_row)) RETURNING id INTO v_conflict;
            v_response := pg_catalog.jsonb_build_object('status', 'conflict',
                'conflict_id', v_conflict, 'remote_allocation', pg_catalog.to_jsonb(v_row));
        ELSE
            v_previous := pg_catalog.to_jsonb(v_row);
            IF p_action = 'update' THEN
                SELECT period.* INTO v_period
                FROM public.accounting_periods AS period
                WHERE period.owner_id = v_owner
                  AND period.start_date <= p_allocated_on AND p_allocated_on < period.end_date;
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'no accounting period covers the allocation date'
                        USING ERRCODE = 'foreign_key_violation';
                END IF;
                UPDATE public.investment_allocations AS allocation
                SET amount_centavos = p_amount_centavos,
                    allocated_on = p_allocated_on,
                    accounting_period_id = v_period.id,
                    version = allocation.version + 1,
                    updated_at = pg_catalog.clock_timestamp()
                WHERE allocation.owner_id = v_owner AND allocation.id = p_allocation_id
                RETURNING allocation.* INTO v_row;
                v_audit_operation := 'update';
            ELSE
                UPDATE public.investment_allocations AS allocation
                SET cancelled_at = COALESCE(allocation.cancelled_at, pg_catalog.clock_timestamp()),
                    version = allocation.version + 1,
                    updated_at = pg_catalog.clock_timestamp()
                WHERE allocation.owner_id = v_owner AND allocation.id = p_allocation_id
                RETURNING allocation.* INTO v_row;
                v_audit_operation := 'cancel';
            END IF;
        END IF;
    END IF;

    IF v_audit_operation IS NOT NULL THEN
        INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id,
            operation, actor_id, previous_values, new_values, operation_id)
        VALUES (v_owner, pg_catalog.gen_random_uuid(), 'investment_allocation',
            p_allocation_id, v_audit_operation, v_owner, v_previous,
            pg_catalog.to_jsonb(v_row), p_operation_id);
        v_response := pg_catalog.jsonb_build_object('status', 'applied',
            'allocation', pg_catalog.to_jsonb(v_row));
    END IF;
    UPDATE public.applied_sync_operations AS op
    SET result_payload = pg_catalog.jsonb_build_object('request', v_request, 'response', v_response),
        applied_at = pg_catalog.clock_timestamp()
    WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id;
    RETURN v_response;
END;
$function$;

ALTER FUNCTION public.apply_investment_allocation_change(UUID, TEXT, UUID, BIGINT, BIGINT, DATE)
    OWNER TO postgres;
REVOKE ALL ON FUNCTION public.apply_investment_allocation_change(UUID, TEXT, UUID, BIGINT, BIGINT, DATE)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_investment_allocation_change(UUID, TEXT, UUID, BIGINT, BIGINT, DATE)
    TO authenticated;
COMMENT ON FUNCTION public.apply_investment_allocation_change(UUID, TEXT, UUID, BIGINT, BIGINT, DATE)
    IS 'Applies authenticated investment allocation create, update or cancellation with period assignment, optimistic versioning, idempotency and audit.';
COMMIT;
