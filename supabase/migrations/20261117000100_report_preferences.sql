-- Reformulação de Relatórios (RL1, 17/11/2026): escolhas da central de
-- relatórios na conta, em coluna própria (o celular regrava `tools` inteiro).
--  * `reports.setup`: 'done' | 'skipped' — configuração guiada vista; ausente =
--    ainda não feita. Feita em qualquer aparelho, não volta (decisão 2).
--  * `reports.selected`: lista ordenada de "Meus relatórios". Ausente = lista
--    sugerida. Vale a última lista enviada (mesma exceção à RN033 das
--    Ferramentas, aprovada em 17/11/2026). Não é dado financeiro.
--  * `reports.options`: reservado (configurações individuais futuras); as RPCs
--    preservam o que houver.
-- IDs de relatório não são validados contra uma lista fixa (o registro vive no
-- app); só o formato.
BEGIN;

ALTER TABLE public.user_preferences
    ADD COLUMN reports JSONB NOT NULL DEFAULT '{}'::JSONB
    CHECK (pg_catalog.jsonb_typeof(reports) = 'object');

-- Lista escolhida em "Meus relatórios", na ordem do usuário (NULL = sugerida).
CREATE FUNCTION public.set_report_selection(
    p_operation_id UUID,
    p_report_ids TEXT[]
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
    v_previous public.user_preferences%ROWTYPE;
    v_preferences public.user_preferences%ROWTYPE;
    v_had_previous BOOLEAN;
    v_reports JSONB;
    v_response JSONB;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL THEN
        RAISE EXCEPTION 'operation id is required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_report_ids IS NOT NULL THEN
        IF pg_catalog.cardinality(p_report_ids) > 200 THEN
            RAISE EXCEPTION 'too many reports'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        IF EXISTS (
            SELECT 1 FROM pg_catalog.unnest(p_report_ids) AS t(id)
            WHERE t.id IS NULL OR t.id !~ '^[a-z][a-z0-9_]{0,63}$'
        ) THEN
            RAISE EXCEPTION 'invalid report id'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        IF (
            SELECT COUNT(DISTINCT t.id) FROM pg_catalog.unnest(p_report_ids) AS t(id)
        ) <> pg_catalog.cardinality(p_report_ids) THEN
            RAISE EXCEPTION 'duplicated report id'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    END IF;

    v_request := pg_catalog.jsonb_build_object(
        'selected', pg_catalog.to_jsonb(p_report_ids)
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

    SELECT preferences.*
    INTO v_previous
    FROM public.user_preferences AS preferences
    WHERE preferences.owner_id = v_owner_id
    FOR UPDATE;
    v_had_previous := FOUND;

    v_reports := COALESCE(v_previous.reports, '{}'::JSONB) - 'selected';
    IF p_report_ids IS NOT NULL THEN
        v_reports := v_reports || pg_catalog.jsonb_build_object(
            'selected', pg_catalog.to_jsonb(p_report_ids)
        );
    END IF;

    IF v_had_previous THEN
        UPDATE public.user_preferences AS preferences
        SET reports = v_reports,
            version = preferences.version + 1,
            updated_at = pg_catalog.clock_timestamp()
        WHERE preferences.owner_id = v_owner_id
        RETURNING preferences.* INTO v_preferences;
    ELSE
        INSERT INTO public.user_preferences (owner_id, reports)
        VALUES (v_owner_id, v_reports)
        RETURNING * INTO v_preferences;
    END IF;

    INSERT INTO public.audit_events (
        owner_id, id, entity_type, entity_id, operation, actor_id,
        previous_values, new_values, operation_id
    )
    VALUES (
        v_owner_id,
        pg_catalog.gen_random_uuid(),
        'user_preferences',
        v_owner_id,
        CASE WHEN v_had_previous THEN 'update' ELSE 'create' END,
        v_owner_id,
        CASE WHEN v_had_previous THEN pg_catalog.to_jsonb(v_previous) END,
        pg_catalog.to_jsonb(v_preferences),
        p_operation_id
    );

    v_response := pg_catalog.jsonb_build_object(
        'status', 'applied',
        'preferences', pg_catalog.to_jsonb(v_preferences)
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

-- Configuração guiada vista (feita ou pulada).
CREATE FUNCTION public.complete_report_setup(
    p_operation_id UUID,
    p_status TEXT
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
    v_previous public.user_preferences%ROWTYPE;
    v_preferences public.user_preferences%ROWTYPE;
    v_had_previous BOOLEAN;
    v_reports JSONB;
    v_response JSONB;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_status IS NULL THEN
        RAISE EXCEPTION 'operation and status are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_status NOT IN ('done', 'skipped') THEN
        RAISE EXCEPTION 'invalid setup status'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object('setup', p_status);
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

    SELECT preferences.*
    INTO v_previous
    FROM public.user_preferences AS preferences
    WHERE preferences.owner_id = v_owner_id
    FOR UPDATE;
    v_had_previous := FOUND;

    -- A configuração guiada feita em qualquer aparelho não volta: o primeiro
    -- status gravado fica (feito ou pulado).
    v_reports := COALESCE(v_previous.reports, '{}'::JSONB);
    IF NOT (v_reports ? 'setup') THEN
        v_reports := v_reports || pg_catalog.jsonb_build_object(
            'setup', p_status
        );
    END IF;

    IF v_had_previous THEN
        UPDATE public.user_preferences AS preferences
        SET reports = v_reports,
            version = preferences.version + 1,
            updated_at = pg_catalog.clock_timestamp()
        WHERE preferences.owner_id = v_owner_id
        RETURNING preferences.* INTO v_preferences;
    ELSE
        INSERT INTO public.user_preferences (owner_id, reports)
        VALUES (v_owner_id, v_reports)
        RETURNING * INTO v_preferences;
    END IF;

    INSERT INTO public.audit_events (
        owner_id, id, entity_type, entity_id, operation, actor_id,
        previous_values, new_values, operation_id
    )
    VALUES (
        v_owner_id,
        pg_catalog.gen_random_uuid(),
        'user_preferences',
        v_owner_id,
        CASE WHEN v_had_previous THEN 'update' ELSE 'create' END,
        v_owner_id,
        CASE WHEN v_had_previous THEN pg_catalog.to_jsonb(v_previous) END,
        pg_catalog.to_jsonb(v_preferences),
        p_operation_id
    );

    v_response := pg_catalog.jsonb_build_object(
        'status', 'applied',
        'preferences', pg_catalog.to_jsonb(v_preferences)
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

ALTER FUNCTION public.set_report_selection(UUID, TEXT[]) OWNER TO postgres;
ALTER FUNCTION public.complete_report_setup(UUID, TEXT) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.set_report_selection(UUID, TEXT[])
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_report_setup(UUID, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_report_selection(UUID, TEXT[])
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_report_setup(UUID, TEXT)
    TO authenticated;

COMMENT ON FUNCTION public.set_report_selection(UUID, TEXT[])
    IS 'Sets the ordered list of reports chosen by the authenticated user (NULL = suggested list; last write wins, decision of 17/11/2026), with idempotency and audit.';
COMMENT ON FUNCTION public.complete_report_setup(UUID, TEXT)
    IS 'Marks the guided report setup as done or skipped for the authenticated user (first status stays across devices), with idempotency and audit.';

COMMIT;
