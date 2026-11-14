-- Aba Ferramentas (13/11/2026): escolhas do usuário no catálogo de ferramentas.
--  * `tools.selected`: lista ordenada de IDs escolhidos em "Suas ferramentas".
--    Ausente = configuração padrão do app (nunca personalizou ou restaurou).
--    Decisão do responsável (13/11/2026): vale a última lista enviada, sem tela
--    de conflito (mesma exceção do tema, D5). Não é dado financeiro.
--  * `tools.dismissed_intros`: ferramentas cuja explicação inicial o usuário
--    dispensou ("Não mostrar novamente"); aparelhos diferentes se somam.
-- IDs de ferramenta não são validados contra uma lista fixa (o catálogo vive no
-- app e cresce sem migration); só o formato.
BEGIN;

ALTER TABLE public.user_preferences
    ADD COLUMN tools JSONB NOT NULL DEFAULT '{}'::JSONB
    CHECK (pg_catalog.jsonb_typeof(tools) = 'object');

-- Lista escolhida, na ordem do usuário (NULL = padrão do app).
CREATE FUNCTION public.set_tool_selection(
    p_operation_id UUID,
    p_tool_ids TEXT[]
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
    v_tools JSONB;
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
    IF p_tool_ids IS NOT NULL THEN
        IF pg_catalog.cardinality(p_tool_ids) > 200 THEN
            RAISE EXCEPTION 'too many tools'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        IF EXISTS (
            SELECT 1 FROM pg_catalog.unnest(p_tool_ids) AS t(id)
            WHERE t.id IS NULL OR t.id !~ '^[a-z][a-z0-9_]{0,63}$'
        ) THEN
            RAISE EXCEPTION 'invalid tool id'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        IF (
            SELECT COUNT(DISTINCT t.id) FROM pg_catalog.unnest(p_tool_ids) AS t(id)
        ) <> pg_catalog.cardinality(p_tool_ids) THEN
            RAISE EXCEPTION 'duplicated tool id'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    END IF;

    v_request := pg_catalog.jsonb_build_object(
        'selected', pg_catalog.to_jsonb(p_tool_ids)
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

    v_tools := COALESCE(v_previous.tools, '{}'::JSONB) - 'selected';
    IF p_tool_ids IS NOT NULL THEN
        v_tools := v_tools || pg_catalog.jsonb_build_object(
            'selected', pg_catalog.to_jsonb(p_tool_ids)
        );
    END IF;

    IF v_had_previous THEN
        UPDATE public.user_preferences AS preferences
        SET tools = v_tools,
            version = preferences.version + 1,
            updated_at = pg_catalog.clock_timestamp()
        WHERE preferences.owner_id = v_owner_id
        RETURNING preferences.* INTO v_preferences;
    ELSE
        INSERT INTO public.user_preferences (owner_id, tools)
        VALUES (v_owner_id, v_tools)
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

-- "Não mostrar novamente" da explicação inicial de uma ferramenta.
CREATE FUNCTION public.dismiss_tool_intro(
    p_operation_id UUID,
    p_tool_id TEXT
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
    v_dismissed JSONB;
    v_tools JSONB;
    v_response JSONB;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_tool_id IS NULL THEN
        RAISE EXCEPTION 'operation and tool are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_tool_id !~ '^[a-z][a-z0-9_]{0,63}$' THEN
        RAISE EXCEPTION 'invalid tool id'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object('dismiss_intro', p_tool_id);
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

    v_tools := COALESCE(v_previous.tools, '{}'::JSONB);
    v_dismissed := CASE
        WHEN pg_catalog.jsonb_typeof(v_tools -> 'dismissed_intros') = 'array'
        THEN v_tools -> 'dismissed_intros'
        ELSE '[]'::JSONB
    END;
    IF NOT v_dismissed @> pg_catalog.jsonb_build_array(p_tool_id) THEN
        v_dismissed := v_dismissed || pg_catalog.jsonb_build_array(p_tool_id);
    END IF;
    v_tools := v_tools || pg_catalog.jsonb_build_object(
        'dismissed_intros', v_dismissed
    );

    IF v_had_previous THEN
        UPDATE public.user_preferences AS preferences
        SET tools = v_tools,
            version = preferences.version + 1,
            updated_at = pg_catalog.clock_timestamp()
        WHERE preferences.owner_id = v_owner_id
        RETURNING preferences.* INTO v_preferences;
    ELSE
        INSERT INTO public.user_preferences (owner_id, tools)
        VALUES (v_owner_id, v_tools)
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

ALTER FUNCTION public.set_tool_selection(UUID, TEXT[]) OWNER TO postgres;
ALTER FUNCTION public.dismiss_tool_intro(UUID, TEXT) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.set_tool_selection(UUID, TEXT[])
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dismiss_tool_intro(UUID, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_tool_selection(UUID, TEXT[])
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.dismiss_tool_intro(UUID, TEXT)
    TO authenticated;

COMMENT ON FUNCTION public.set_tool_selection(UUID, TEXT[])
    IS 'Sets the ordered list of tools chosen by the authenticated user (NULL = app default; last write wins, decision of 13/11/2026), with idempotency and audit.';
COMMENT ON FUNCTION public.dismiss_tool_intro(UUID, TEXT)
    IS 'Marks the first-use explanation of a tool as dismissed for the authenticated user, merging with other devices, with idempotency and audit.';

COMMIT;
