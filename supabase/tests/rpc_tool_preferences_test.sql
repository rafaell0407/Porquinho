\set ON_ERROR_STOP on

-- Aba Ferramentas: lista escolhida e "Não mostrar novamente". Identidades
-- sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('92000000-0000-0000-0000-000000000001'),
    ('92000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '92000000-0000-0000-0000-000000000001',
    TRUE
);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    r JSONB;
    replay JSONB;
    n BIGINT;
BEGIN
    IF pg_catalog.has_function_privilege(
        'anon', 'public.set_tool_selection(uuid,text[])', 'EXECUTE'
    ) OR pg_catalog.has_function_privilege(
        'anon', 'public.dismiss_tool_intro(uuid,text)', 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anonymous execution must be revoked';
    END IF;

    -- Primeira gravação cria a linha, guardando a ordem.
    r := public.set_tool_selection(
        '93000000-0000-0000-0000-000000000001', ARRAY['reports', 'other_tool']);
    IF r ->> 'status' <> 'applied'
        OR r #> '{preferences,tools,selected}' <> '["reports", "other_tool"]'::JSONB
        OR r #>> '{preferences,version}' <> '1'
    THEN
        RAISE EXCEPTION 'first selection incorrect: %', r;
    END IF;

    -- Reenvio da mesma operação: mesma resposta, versão não sobe.
    replay := public.set_tool_selection(
        '93000000-0000-0000-0000-000000000001', ARRAY['reports', 'other_tool']);
    IF replay IS DISTINCT FROM r THEN
        RAISE EXCEPTION 'replay must return the stored response';
    END IF;
    SELECT version INTO n FROM public.user_preferences;
    IF n <> 1 THEN
        RAISE EXCEPTION 'replay must not bump the version';
    END IF;

    -- Mesma chave, conteúdo diferente: recusa.
    BEGIN
        PERFORM public.set_tool_selection(
            '93000000-0000-0000-0000-000000000001', ARRAY['reports']);
        RAISE EXCEPTION 'must reject key reuse with different content';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Reordenar: a última lista enviada vale.
    r := public.set_tool_selection(
        '93000000-0000-0000-0000-000000000002', ARRAY['other_tool', 'reports']);
    IF r #> '{preferences,tools,selected}' <> '["other_tool", "reports"]'::JSONB THEN
        RAISE EXCEPTION 'reorder incorrect: %', r;
    END IF;

    -- Lista vazia é escolha válida (diferente de "padrão").
    r := public.set_tool_selection(
        '93000000-0000-0000-0000-000000000003', ARRAY[]::TEXT[]);
    IF r #> '{preferences,tools,selected}' <> '[]'::JSONB THEN
        RAISE EXCEPTION 'empty selection incorrect: %', r;
    END IF;

    -- "Não mostrar novamente" se soma e não apaga a lista.
    r := public.dismiss_tool_intro(
        '93000000-0000-0000-0000-000000000004', 'reports');
    r := public.dismiss_tool_intro(
        '93000000-0000-0000-0000-000000000005', 'other_tool');
    r := public.dismiss_tool_intro(
        '93000000-0000-0000-0000-000000000006', 'reports');
    IF r #> '{preferences,tools,dismissed_intros}'
            <> '["reports", "other_tool"]'::JSONB
        OR r #> '{preferences,tools,selected}' <> '[]'::JSONB
    THEN
        RAISE EXCEPTION 'dismissed intros must merge: %', r;
    END IF;

    -- Restaurar padrão (NULL) tira só a lista; dispensas ficam.
    r := public.set_tool_selection('93000000-0000-0000-0000-000000000007', NULL);
    IF r #> '{preferences,tools}' ? 'selected'
        OR r #> '{preferences,tools,dismissed_intros}'
            <> '["reports", "other_tool"]'::JSONB
    THEN
        RAISE EXCEPTION 'restore default incorrect: %', r;
    END IF;

    -- Tema e ferramentas não se apagam.
    r := public.set_user_theme('93000000-0000-0000-0000-000000000008', 'dark');
    IF r #> '{preferences,tools,dismissed_intros}' IS NULL THEN
        RAISE EXCEPTION 'theme write must keep tools: %', r;
    END IF;

    -- Recusas: ID inválido, repetido, ou nulo.
    BEGIN
        PERFORM public.set_tool_selection(
            '93000000-0000-0000-0000-000000000009', ARRAY['Relatórios']);
        RAISE EXCEPTION 'must reject invalid id';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.set_tool_selection(
            '93000000-0000-0000-0000-000000000010', ARRAY['reports', 'reports']);
        RAISE EXCEPTION 'must reject duplicated id';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.dismiss_tool_intro(
            '93000000-0000-0000-0000-000000000011', NULL);
        RAISE EXCEPTION 'must reject null tool';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Auditoria: uma por gravação aplicada (4 listas + 3 dispensas + tema = 8).
    SELECT COUNT(*) INTO n FROM public.audit_events
    WHERE entity_type = 'user_preferences';
    IF n <> 8 THEN
        RAISE EXCEPTION 'expected 8 audit events, got %', n;
    END IF;
END;
$test$;

-- Isolamento: outro usuário não vê nem altera as escolhas do primeiro.
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '92000000-0000-0000-0000-000000000002',
    TRUE
);

DO $test$
DECLARE
    n BIGINT;
    r JSONB;
BEGIN
    SELECT COUNT(*) INTO n FROM public.user_preferences;
    IF n <> 0 THEN
        RAISE EXCEPTION 'second user must not see other preferences';
    END IF;
    r := public.dismiss_tool_intro(
        '93000000-0000-0000-0000-000000000020', 'reports');
    IF r #>> '{preferences,version}' <> '1'
        OR r #> '{preferences,tools}' <> '{"dismissed_intros": ["reports"]}'::JSONB
    THEN
        RAISE EXCEPTION 'second user must get own row: %', r;
    END IF;
END;
$test$;

ROLLBACK;
