-- Entregas 66 e 67 (Fase 7): gravação das preferências do usuário.
--  * Tema claro/escuro (RF026). Decisão D5 de 11/11/2026: vale a última
--    gravação enviada, sem tela de conflito (exceção só para o tema).
--  * Progresso do assistente de configuração inicial (RF024, decisão D7):
--    salvo na conta; cada etapa vira 'done' ou 'skipped' e as chamadas de
--    aparelhos diferentes se somam (uma etapa nunca apaga a outra).
-- O dono sempre vem do Supabase Auth; a linha nasce na primeira gravação.
BEGIN;

ALTER TABLE public.user_preferences
    ADD COLUMN onboarding JSONB NOT NULL DEFAULT '{}'::JSONB
    CHECK (pg_catalog.jsonb_typeof(onboarding) = 'object');

CREATE FUNCTION public.set_user_theme(
    p_operation_id UUID,
    p_theme TEXT
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
    -- NULL = seguir o aparelho/navegador (D4).
    IF p_theme IS NOT NULL AND p_theme NOT IN ('light', 'dark') THEN
        RAISE EXCEPTION 'unsupported theme'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object('theme', p_theme);
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

    IF v_had_previous THEN
        UPDATE public.user_preferences AS preferences
        SET theme = p_theme,
            version = preferences.version + 1,
            updated_at = pg_catalog.clock_timestamp()
        WHERE preferences.owner_id = v_owner_id
        RETURNING preferences.* INTO v_preferences;
    ELSE
        INSERT INTO public.user_preferences (owner_id, theme)
        VALUES (v_owner_id, p_theme)
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

CREATE FUNCTION public.set_onboarding_step(
    p_operation_id UUID,
    p_step TEXT,
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
    v_response JSONB;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_step IS NULL OR p_status IS NULL THEN
        RAISE EXCEPTION 'operation, step and status are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_step NOT IN ('intro', 'categories', 'theme', 'security', 'recurrences') THEN
        RAISE EXCEPTION 'unsupported onboarding step'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_status NOT IN ('done', 'skipped') THEN
        RAISE EXCEPTION 'unsupported onboarding status'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object('step', p_step, 'status', p_status);
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

    IF v_had_previous THEN
        UPDATE public.user_preferences AS preferences
        SET onboarding = preferences.onboarding
                || pg_catalog.jsonb_build_object(p_step, p_status),
            version = preferences.version + 1,
            updated_at = pg_catalog.clock_timestamp()
        WHERE preferences.owner_id = v_owner_id
        RETURNING preferences.* INTO v_preferences;
    ELSE
        INSERT INTO public.user_preferences (owner_id, onboarding)
        VALUES (v_owner_id, pg_catalog.jsonb_build_object(p_step, p_status))
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

ALTER FUNCTION public.set_user_theme(UUID, TEXT) OWNER TO postgres;
ALTER FUNCTION public.set_onboarding_step(UUID, TEXT, TEXT) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.set_user_theme(UUID, TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_onboarding_step(UUID, TEXT, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_theme(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_onboarding_step(UUID, TEXT, TEXT)
    TO authenticated;

COMMENT ON FUNCTION public.set_user_theme(UUID, TEXT)
    IS 'Sets the theme of the authenticated user (last write wins, decision D5), creating the preferences row if needed, with idempotency and audit.';
COMMENT ON FUNCTION public.set_onboarding_step(UUID, TEXT, TEXT)
    IS 'Records an onboarding step as done or skipped for the authenticated user, merging with other devices, with idempotency and audit.';

COMMIT;
