-- Entrega 59 (Fase 7): agenda a nova configuração de período para o próximo
-- período (RN002, decisões D2 e D3 de 11/11/2026).
-- A configuração agendada só vale a partir do fim do último período existente
-- e pode ser trocada enquanto nenhum período a usar. Nenhum período existente
-- é alterado. O dono sempre vem do Supabase Auth.
BEGIN;

CREATE FUNCTION public.schedule_period_configuration(
    p_operation_id UUID,
    p_action TEXT,
    p_configuration_id UUID,
    p_expected_version BIGINT,
    p_effective_from DATE,
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
    v_last_period public.accounting_periods%ROWTYPE;
    v_configuration public.period_configurations%ROWTYPE;
    v_other public.period_configurations%ROWTYPE;
    v_previous_values JSONB;
    v_conflict_id UUID;
    v_response JSONB;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;

    IF p_operation_id IS NULL
        OR p_action IS NULL
        OR p_configuration_id IS NULL
        OR p_expected_version IS NULL
        OR p_effective_from IS NULL
        OR p_mode IS NULL
    THEN
        RAISE EXCEPTION 'operation, action, configuration, version, date and mode are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_action NOT IN ('create', 'update') THEN
        RAISE EXCEPTION 'unsupported schedule action'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF (p_action = 'create' AND p_expected_version <> 0)
        OR (p_action = 'update' AND p_expected_version < 1)
    THEN
        RAISE EXCEPTION 'expected version does not match the action'
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
        'action', p_action,
        'configuration_id', p_configuration_id,
        'expected_version', p_expected_version,
        'effective_from', p_effective_from,
        'mode', p_mode,
        'custom_start_day', p_custom_start_day
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

    -- Mesma trava dos períodos: agendar e criar períodos não se misturam.
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('porquinho.accounting_periods:' || v_owner_id::TEXT, 0)
    );

    SELECT period.*
    INTO v_last_period
    FROM public.accounting_periods AS period
    WHERE period.owner_id = v_owner_id
    ORDER BY period.start_date DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'there is no accounting period to schedule a change after'
            USING ERRCODE = 'check_violation';
    END IF;

    -- D2: a nova configuração começa onde o último período existente termina.
    IF p_effective_from <> v_last_period.end_date THEN
        RAISE EXCEPTION 'a scheduled configuration must start when the last period ends'
            USING ERRCODE = 'check_violation';
    END IF;

    IF p_action = 'create' THEN
        SELECT configuration.*
        INTO v_other
        FROM public.period_configurations AS configuration
        WHERE configuration.owner_id = v_owner_id
          AND (configuration.id = p_configuration_id
               OR configuration.effective_from = p_effective_from)
        FOR UPDATE;

        IF FOUND THEN
            INSERT INTO public.sync_conflicts (
                owner_id, id, entity_type, entity_id, base_version,
                remote_version, local_snapshot, remote_snapshot
            )
            VALUES (
                v_owner_id,
                pg_catalog.gen_random_uuid(),
                'period_configuration',
                p_configuration_id,
                0,
                v_other.version,
                v_request,
                pg_catalog.to_jsonb(v_other)
            )
            RETURNING id INTO v_conflict_id;

            v_response := pg_catalog.jsonb_build_object(
                'status', 'conflict',
                'conflict_id', v_conflict_id,
                'remote_configuration', pg_catalog.to_jsonb(v_other)
            );
        ELSE
            INSERT INTO public.period_configurations (
                owner_id, id, mode, custom_start_day, effective_from
            )
            VALUES (
                v_owner_id, p_configuration_id, p_mode,
                p_custom_start_day, p_effective_from
            )
            RETURNING * INTO v_configuration;

            INSERT INTO public.audit_events (
                owner_id, id, entity_type, entity_id, operation, actor_id,
                new_values, operation_id
            )
            VALUES (
                v_owner_id, pg_catalog.gen_random_uuid(),
                'period_configuration', p_configuration_id, 'create',
                v_owner_id, pg_catalog.to_jsonb(v_configuration), p_operation_id
            );
            v_response := pg_catalog.jsonb_build_object(
                'status', 'applied',
                'configuration', pg_catalog.to_jsonb(v_configuration)
            );
        END IF;
    ELSE
        SELECT configuration.*
        INTO v_configuration
        FROM public.period_configurations AS configuration
        WHERE configuration.owner_id = v_owner_id
          AND configuration.id = p_configuration_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'configuration was not found for the authenticated user'
                USING ERRCODE = 'no_data_found';
        END IF;

        -- D3: só pode ser trocada enquanto nenhum período a usar.
        IF v_configuration.effective_from <> p_effective_from
            OR EXISTS (
                SELECT 1
                FROM public.accounting_periods AS period
                WHERE period.owner_id = v_owner_id
                  AND period.configuration_id = p_configuration_id
            )
        THEN
            RAISE EXCEPTION 'only a configuration not used by any period can be changed'
                USING ERRCODE = 'check_violation';
        END IF;

        IF v_configuration.version <> p_expected_version THEN
            INSERT INTO public.sync_conflicts (
                owner_id, id, entity_type, entity_id, base_version,
                remote_version, local_snapshot, remote_snapshot
            )
            VALUES (
                v_owner_id,
                pg_catalog.gen_random_uuid(),
                'period_configuration',
                p_configuration_id,
                p_expected_version,
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
        ELSE
            v_previous_values := pg_catalog.to_jsonb(v_configuration);
            UPDATE public.period_configurations AS configuration
            SET mode = p_mode,
                custom_start_day = p_custom_start_day,
                version = configuration.version + 1,
                updated_at = pg_catalog.clock_timestamp()
            WHERE configuration.owner_id = v_owner_id
              AND configuration.id = p_configuration_id
            RETURNING configuration.* INTO v_configuration;

            INSERT INTO public.audit_events (
                owner_id, id, entity_type, entity_id, operation, actor_id,
                previous_values, new_values, operation_id
            )
            VALUES (
                v_owner_id, pg_catalog.gen_random_uuid(),
                'period_configuration', p_configuration_id, 'update',
                v_owner_id, v_previous_values,
                pg_catalog.to_jsonb(v_configuration), p_operation_id
            );
            v_response := pg_catalog.jsonb_build_object(
                'status', 'applied',
                'configuration', pg_catalog.to_jsonb(v_configuration)
            );
        END IF;
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

ALTER FUNCTION public.schedule_period_configuration(
    UUID, TEXT, UUID, BIGINT, DATE, TEXT, SMALLINT)
    OWNER TO postgres;

REVOKE ALL ON FUNCTION public.schedule_period_configuration(
    UUID, TEXT, UUID, BIGINT, DATE, TEXT, SMALLINT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_period_configuration(
    UUID, TEXT, UUID, BIGINT, DATE, TEXT, SMALLINT)
    TO authenticated;

COMMENT ON FUNCTION public.schedule_period_configuration(
    UUID, TEXT, UUID, BIGINT, DATE, TEXT, SMALLINT)
    IS 'Schedules or replaces the configuration for the next period (starts when the last period ends), with locking, idempotency, versioning and audit.';

COMMIT;
