-- Creates one accounting period immediately BEFORE the earliest existing one
-- (Entrega 34B; RN002 "períodos anteriores", approved 10/11/2026).
-- The new period reuses the configuration of the earliest period, so the
-- sequence stays contiguous without gaps or overlaps. The configuration row is
-- not changed. A per-owner advisory lock serializes it with the other period
-- RPCs (same lock key as create_accounting_period).
BEGIN;

CREATE FUNCTION public.create_earlier_accounting_period(
    p_operation_id UUID,
    p_period_id UUID,
    p_start_date DATE
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
    v_first_period public.accounting_periods%ROWTYPE;
    v_configuration public.period_configurations%ROWTYPE;
    v_existing_period public.accounting_periods%ROWTYPE;
    v_period public.accounting_periods%ROWTYPE;
    v_conflict_id UUID;
    v_response JSONB;
    v_month_start DATE;
    v_next_month DATE;
    v_month_last_day INTEGER;
    v_next_month_last_day INTEGER;
    v_target_day INTEGER;
    v_expected_end_date DATE;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;

    IF p_operation_id IS NULL OR p_period_id IS NULL OR p_start_date IS NULL THEN
        RAISE EXCEPTION 'operation, period and start date are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object(
        'period_id', p_period_id,
        'start_date', p_start_date,
        'direction', 'earlier'
    );
    v_content_hash := pg_catalog.decode(
        pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT, 'UTF8')),
        'hex'
    );

    INSERT INTO public.applied_sync_operations (
        owner_id, idempotency_key, content_hash, result_payload
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

    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('porquinho.accounting_periods:' || v_owner_id::TEXT, 0)
    );

    -- Same start date or same id already present: record a conflict.
    SELECT period.*
    INTO v_existing_period
    FROM public.accounting_periods AS period
    WHERE period.owner_id = v_owner_id
      AND (period.start_date = p_start_date OR period.id = p_period_id)
    ORDER BY period.start_date
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        INSERT INTO public.sync_conflicts (
            owner_id, id, entity_type, entity_id, base_version,
            remote_version, local_snapshot, remote_snapshot
        )
        VALUES (
            v_owner_id,
            pg_catalog.gen_random_uuid(),
            'accounting_period',
            p_period_id,
            0,
            v_existing_period.version,
            v_request,
            pg_catalog.to_jsonb(v_existing_period)
        )
        RETURNING id INTO v_conflict_id;

        v_response := pg_catalog.jsonb_build_object(
            'status', 'conflict',
            'conflict_id', v_conflict_id,
            'remote_period', pg_catalog.to_jsonb(v_existing_period)
        );
        UPDATE public.applied_sync_operations AS operation
        SET result_payload = pg_catalog.jsonb_build_object(
                'request', v_request,
                'response', v_response
            ),
            applied_at = pg_catalog.clock_timestamp()
        WHERE operation.owner_id = v_owner_id
          AND operation.idempotency_key = p_operation_id;
        RETURN v_response;
    END IF;

    SELECT period.*
    INTO v_first_period
    FROM public.accounting_periods AS period
    WHERE period.owner_id = v_owner_id
    ORDER BY period.start_date
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'there is no period yet; create the first period instead'
            USING ERRCODE = 'check_violation';
    END IF;

    IF p_start_date >= v_first_period.start_date THEN
        RAISE EXCEPTION 'the new period must start before the earliest existing period'
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT configuration.*
    INTO v_configuration
    FROM public.period_configurations AS configuration
    WHERE configuration.owner_id = v_owner_id
      AND configuration.id = v_first_period.configuration_id;

    v_month_start := pg_catalog.date_trunc('month', p_start_date)::DATE;
    v_next_month := (v_month_start + INTERVAL '1 month')::DATE;
    v_month_last_day := EXTRACT(
        DAY FROM ((v_month_start + INTERVAL '1 month') - INTERVAL '1 day')
    )::INTEGER;
    v_next_month_last_day := EXTRACT(
        DAY FROM ((v_next_month + INTERVAL '1 month') - INTERVAL '1 day')
    )::INTEGER;

    IF v_configuration.mode = 'calendar_month' THEN
        IF p_start_date <> v_month_start THEN
            RAISE EXCEPTION 'calendar-month periods must start on the first day of a month'
                USING ERRCODE = 'check_violation';
        END IF;
        v_expected_end_date := v_next_month;
    ELSE
        v_target_day := LEAST(v_configuration.custom_start_day::INTEGER, v_month_last_day);
        IF p_start_date <> v_month_start + (v_target_day - 1) THEN
            RAISE EXCEPTION 'custom-cycle period does not match its configured start day'
                USING ERRCODE = 'check_violation';
        END IF;
        v_target_day := LEAST(v_configuration.custom_start_day::INTEGER, v_next_month_last_day);
        v_expected_end_date := v_next_month + (v_target_day - 1);
    END IF;

    IF v_expected_end_date <> v_first_period.start_date THEN
        RAISE EXCEPTION 'period end must equal the earliest existing period start'
            USING ERRCODE = 'check_violation';
    END IF;

    INSERT INTO public.accounting_periods (
        owner_id, id, configuration_id, start_date, end_date
    )
    VALUES (
        v_owner_id,
        p_period_id,
        v_configuration.id,
        p_start_date,
        v_expected_end_date
    )
    RETURNING * INTO v_period;

    INSERT INTO public.audit_events (
        owner_id, id, entity_type, entity_id, operation,
        actor_id, new_values, operation_id
    )
    VALUES (
        v_owner_id,
        pg_catalog.gen_random_uuid(),
        'accounting_period',
        p_period_id,
        'create',
        v_owner_id,
        pg_catalog.to_jsonb(v_period),
        p_operation_id
    );

    v_response := pg_catalog.jsonb_build_object(
        'status', 'applied',
        'configuration', pg_catalog.to_jsonb(v_configuration),
        'period', pg_catalog.to_jsonb(v_period)
    );

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

ALTER FUNCTION public.create_earlier_accounting_period(UUID, UUID, DATE)
    OWNER TO postgres;

REVOKE ALL ON FUNCTION public.create_earlier_accounting_period(UUID, UUID, DATE)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_earlier_accounting_period(UUID, UUID, DATE)
    TO authenticated;

COMMENT ON FUNCTION public.create_earlier_accounting_period(UUID, UUID, DATE)
    IS 'Creates the period immediately before the earliest one, reusing its configuration, with per-owner locking, idempotency and audit.';

COMMIT;
