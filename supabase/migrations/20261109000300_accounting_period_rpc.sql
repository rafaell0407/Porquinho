-- Creates one period and, when needed, its next-period configuration atomically.
-- A per-owner transaction advisory lock serializes all calls to this function.
BEGIN;

CREATE FUNCTION public.create_accounting_period(
    p_operation_id UUID,
    p_period_id UUID,
    p_configuration_id UUID,
    p_start_date DATE,
    p_mode TEXT,
    p_custom_start_day SMALLINT
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
    v_configuration public.period_configurations%ROWTYPE;
    v_existing_configuration public.period_configurations%ROWTYPE;
    v_period public.accounting_periods%ROWTYPE;
    v_existing_period public.accounting_periods%ROWTYPE;
    v_previous_period public.accounting_periods%ROWTYPE;
    v_next_period public.accounting_periods%ROWTYPE;
    v_selected_configuration_id UUID;
    v_conflict_id UUID;
    v_response JSONB;
    v_month_start DATE;
    v_next_month DATE;
    v_month_last_day INTEGER;
    v_next_month_last_day INTEGER;
    v_target_day INTEGER;
    v_expected_end_date DATE;
    v_configuration_created BOOLEAN := FALSE;
    v_has_previous BOOLEAN := FALSE;
    v_has_next BOOLEAN := FALSE;
    v_is_transition_period BOOLEAN := FALSE;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;

    IF p_operation_id IS NULL
        OR p_period_id IS NULL
        OR p_configuration_id IS NULL
        OR p_start_date IS NULL
        OR p_mode IS NULL
    THEN
        RAISE EXCEPTION 'operation, period, configuration, start date and mode are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_mode = 'calendar_month' THEN
        IF p_custom_start_day IS NOT NULL THEN
            RAISE EXCEPTION 'calendar month does not accept a custom start day'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSIF p_mode = 'custom_cycle' THEN
        IF p_custom_start_day IS NULL OR p_custom_start_day NOT BETWEEN 1 AND 31 THEN
            RAISE EXCEPTION 'custom cycle requires a start day from 1 through 31'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSE
        RAISE EXCEPTION 'unsupported accounting period mode'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object(
        'period_id', p_period_id,
        'configuration_id', p_configuration_id,
        'start_date', p_start_date,
        'mode', p_mode,
        'custom_start_day', p_custom_start_day
    );
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

    -- hashtextextended collisions only cause harmless extra serialization:
    -- every row access below still filters by the authenticated owner UUID.
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('porquinho.accounting_periods:' || v_owner_id::TEXT, 0)
    );

    SELECT period.*
    INTO v_existing_period
    FROM public.accounting_periods AS period
    WHERE period.owner_id = v_owner_id
      AND period.start_date = p_start_date
    FOR UPDATE;

    IF FOUND THEN
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
    INTO v_existing_period
    FROM public.accounting_periods AS period
    WHERE period.owner_id = v_owner_id
      AND period.id = p_period_id
    FOR UPDATE;

    IF FOUND THEN
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

    SELECT configuration.*
    INTO v_configuration
    FROM public.period_configurations AS configuration
    WHERE configuration.owner_id = v_owner_id
      AND configuration.id = p_configuration_id
    FOR UPDATE;

    IF FOUND THEN
        IF v_configuration.mode <> p_mode
            OR v_configuration.custom_start_day IS DISTINCT FROM p_custom_start_day
        THEN
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
                'period_configuration',
                p_configuration_id,
                0,
                v_configuration.version,
                v_request,
                pg_catalog.to_jsonb(v_configuration)
            )
            RETURNING id INTO v_conflict_id;

            v_response := pg_catalog.jsonb_build_object(
                'status', 'conflict',
                'conflict_id', v_conflict_id,
                'remote_configuration', pg_catalog.to_jsonb(v_configuration)
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
    ELSE
        SELECT configuration.*
        INTO v_existing_configuration
        FROM public.period_configurations AS configuration
        WHERE configuration.owner_id = v_owner_id
          AND configuration.effective_from = p_start_date
        FOR UPDATE;

        IF FOUND THEN
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
                'period_configuration',
                p_configuration_id,
                0,
                v_existing_configuration.version,
                v_request,
                pg_catalog.to_jsonb(v_existing_configuration)
            )
            RETURNING id INTO v_conflict_id;

            v_response := pg_catalog.jsonb_build_object(
                'status', 'conflict',
                'conflict_id', v_conflict_id,
                'remote_configuration', pg_catalog.to_jsonb(v_existing_configuration)
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

        INSERT INTO public.period_configurations (
            owner_id,
            id,
            mode,
            custom_start_day,
            effective_from
        )
        VALUES (
            v_owner_id,
            p_configuration_id,
            p_mode,
            p_custom_start_day,
            p_start_date
        )
        RETURNING * INTO v_configuration;
        v_configuration_created := TRUE;
    END IF;

    SELECT configuration.id
    INTO v_selected_configuration_id
    FROM public.period_configurations AS configuration
    WHERE configuration.owner_id = v_owner_id
      AND configuration.effective_from <= p_start_date
    ORDER BY configuration.effective_from DESC
    LIMIT 1;

    IF v_selected_configuration_id IS DISTINCT FROM p_configuration_id THEN
        RAISE EXCEPTION 'configuration is not effective for this period start'
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT period.*
    INTO v_previous_period
    FROM public.accounting_periods AS period
    WHERE period.owner_id = v_owner_id
      AND period.start_date < p_start_date
    ORDER BY period.start_date DESC
    LIMIT 1
    FOR UPDATE;
    v_has_previous := FOUND;

    SELECT period.*
    INTO v_next_period
    FROM public.accounting_periods AS period
    WHERE period.owner_id = v_owner_id
      AND period.start_date > p_start_date
    ORDER BY period.start_date
    LIMIT 1
    FOR UPDATE;
    v_has_next := FOUND;

    IF v_has_previous THEN
        IF v_previous_period.end_date <> p_start_date THEN
            RAISE EXCEPTION 'period start must equal the previous period end'
                USING ERRCODE = 'check_violation';
        END IF;

        v_is_transition_period := v_previous_period.configuration_id <> p_configuration_id;
        IF v_is_transition_period
            AND v_configuration.effective_from <> p_start_date
        THEN
            RAISE EXCEPTION 'a changed configuration must become effective at the next period start'
                USING ERRCODE = 'check_violation';
        END IF;
        IF NOT v_is_transition_period
            AND v_configuration.effective_from >= p_start_date
        THEN
            RAISE EXCEPTION 'an existing configuration cannot first apply after its effective date'
                USING ERRCODE = 'check_violation';
        END IF;
    ELSIF v_configuration.effective_from <> p_start_date THEN
        RAISE EXCEPTION 'the first period must start when its configuration becomes effective'
            USING ERRCODE = 'check_violation';
    END IF;

    v_month_start := pg_catalog.date_trunc('month', p_start_date)::DATE;
    v_next_month := (v_month_start + INTERVAL '1 month')::DATE;
    v_month_last_day := EXTRACT(
        DAY FROM ((v_month_start + INTERVAL '1 month') - INTERVAL '1 day')
    )::INTEGER;
    v_next_month_last_day := EXTRACT(
        DAY FROM ((v_next_month + INTERVAL '1 month') - INTERVAL '1 day')
    )::INTEGER;

    IF p_mode = 'calendar_month' THEN
        IF NOT v_is_transition_period AND p_start_date <> v_month_start THEN
            RAISE EXCEPTION 'calendar-month periods must start on the first day of a month'
                USING ERRCODE = 'check_violation';
        END IF;
        v_expected_end_date := v_next_month;
    ELSIF v_is_transition_period THEN
        v_target_day := LEAST(p_custom_start_day::INTEGER, v_month_last_day);
        v_expected_end_date := v_month_start + (v_target_day - 1);
        IF v_expected_end_date <= p_start_date THEN
            v_target_day := LEAST(p_custom_start_day::INTEGER, v_next_month_last_day);
            v_expected_end_date := v_next_month + (v_target_day - 1);
        END IF;
    ELSE
        v_target_day := LEAST(p_custom_start_day::INTEGER, v_month_last_day);
        IF p_start_date <> v_month_start + (v_target_day - 1) THEN
            RAISE EXCEPTION 'custom-cycle period does not match its configured start day'
                USING ERRCODE = 'check_violation';
        END IF;
        v_target_day := LEAST(p_custom_start_day::INTEGER, v_next_month_last_day);
        v_expected_end_date := v_next_month + (v_target_day - 1);
    END IF;

    IF v_has_next AND v_next_period.start_date <> v_expected_end_date THEN
        RAISE EXCEPTION 'period end must equal the next period start'
            USING ERRCODE = 'check_violation';
    END IF;

    INSERT INTO public.accounting_periods (
        owner_id,
        id,
        configuration_id,
        start_date,
        end_date
    )
    VALUES (
        v_owner_id,
        p_period_id,
        p_configuration_id,
        p_start_date,
        v_expected_end_date
    )
    RETURNING * INTO v_period;

    IF v_configuration_created THEN
        INSERT INTO public.audit_events (
            owner_id,
            id,
            entity_type,
            entity_id,
            operation,
            actor_id,
            new_values,
            operation_id
        )
        VALUES (
            v_owner_id,
            pg_catalog.gen_random_uuid(),
            'period_configuration',
            p_configuration_id,
            'create',
            v_owner_id,
            pg_catalog.to_jsonb(v_configuration),
            p_operation_id
        );
    END IF;

    INSERT INTO public.audit_events (
        owner_id,
        id,
        entity_type,
        entity_id,
        operation,
        actor_id,
        new_values,
        operation_id
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

ALTER FUNCTION public.create_accounting_period(UUID, UUID, UUID, DATE, TEXT, SMALLINT)
    OWNER TO postgres;

REVOKE ALL ON FUNCTION public.create_accounting_period(UUID, UUID, UUID, DATE, TEXT, SMALLINT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_accounting_period(UUID, UUID, UUID, DATE, TEXT, SMALLINT)
    TO authenticated;

COMMENT ON FUNCTION public.create_accounting_period(UUID, UUID, UUID, DATE, TEXT, SMALLINT)
    IS 'Creates an adjacent accounting period and its effective configuration atomically, with per-owner locking, idempotency and audit.';

COMMIT;
