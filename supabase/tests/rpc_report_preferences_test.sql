\set ON_ERROR_STOP on

-- Reformulação de Relatórios (RL1): lista de "Meus relatórios" e configuração
-- guiada. Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('94000000-0000-0000-0000-000000000001'),
    ('94000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '94000000-0000-0000-0000-000000000001',
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
        'anon', 'public.set_report_selection(uuid,text[])', 'EXECUTE'
    ) OR pg_catalog.has_function_privilege(
        'anon', 'public.complete_report_setup(uuid,text)', 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anonymous execution must be revoked';
    END IF;

    -- Linha nova: a coluna nasce como objeto vazio.
    r := public.set_user_theme('95000000-0000-0000-0000-000000000001', 'dark');
    IF r #> '{preferences,reports}' <> '{}'::JSONB THEN
        RAISE EXCEPTION 'reports must default to empty object: %', r;
    END IF;

    -- Configuração guiada concluída.
    r := public.complete_report_setup(
        '95000000-0000-0000-0000-000000000002', 'done');
    IF r ->> 'status' <> 'applied'
        OR r #>> '{preferences,reports,setup}' <> 'done'
        OR r #>> '{preferences,version}' <> '2'
    THEN
        RAISE EXCEPTION 'setup incorrect: %', r;
    END IF;

    -- Reenvio da mesma operação: mesma resposta, versão não sobe.
    replay := public.complete_report_setup(
        '95000000-0000-0000-0000-000000000002', 'done');
    IF replay IS DISTINCT FROM r THEN
        RAISE EXCEPTION 'replay must return the stored response';
    END IF;
    SELECT version INTO n FROM public.user_preferences;
    IF n <> 2 THEN
        RAISE EXCEPTION 'replay must not bump the version';
    END IF;

    -- Mesma chave, conteúdo diferente: recusa.
    BEGIN
        PERFORM public.complete_report_setup(
            '95000000-0000-0000-0000-000000000002', 'skipped');
        RAISE EXCEPTION 'must reject key reuse with different content';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Feita não volta: "pulada" vinda de outro aparelho não troca o status.
    r := public.complete_report_setup(
        '95000000-0000-0000-0000-000000000003', 'skipped');
    IF r #>> '{preferences,reports,setup}' <> 'done' THEN
        RAISE EXCEPTION 'setup must stay once set: %', r;
    END IF;

    -- Lista com ordem; mantém o status da configuração.
    r := public.set_report_selection(
        '95000000-0000-0000-0000-000000000004',
        ARRAY['period_comparison', 'income_by_category']);
    IF r #> '{preferences,reports,selected}'
            <> '["period_comparison", "income_by_category"]'::JSONB
        OR r #>> '{preferences,reports,setup}' <> 'done'
    THEN
        RAISE EXCEPTION 'selection incorrect: %', r;
    END IF;

    -- Reordenar: a última lista enviada vale.
    r := public.set_report_selection(
        '95000000-0000-0000-0000-000000000005',
        ARRAY['income_by_category', 'period_comparison']);
    IF r #> '{preferences,reports,selected}'
            <> '["income_by_category", "period_comparison"]'::JSONB
    THEN
        RAISE EXCEPTION 'reorder incorrect: %', r;
    END IF;

    -- Lista vazia é escolha válida (diferente de "sugerida").
    r := public.set_report_selection(
        '95000000-0000-0000-0000-000000000006', ARRAY[]::TEXT[]);
    IF r #> '{preferences,reports,selected}' <> '[]'::JSONB THEN
        RAISE EXCEPTION 'empty selection incorrect: %', r;
    END IF;

    -- `options` reservado é preservado pelas gravações.
    RESET ROLE;
    UPDATE public.user_preferences
    SET reports = reports || '{"options": {"x": {"periods": 6}}}'::JSONB;
    SET LOCAL ROLE authenticated;

    -- Restaurar (NULL) tira só a lista; status e opções ficam.
    r := public.set_report_selection('95000000-0000-0000-0000-000000000007', NULL);
    IF r #> '{preferences,reports}' ? 'selected'
        OR r #>> '{preferences,reports,setup}' <> 'done'
        OR r #> '{preferences,reports,options}' <> '{"x": {"periods": 6}}'::JSONB
    THEN
        RAISE EXCEPTION 'restore incorrect: %', r;
    END IF;

    -- Gravar ferramentas e tema não apaga relatórios, e vice-versa.
    r := public.set_tool_selection(
        '95000000-0000-0000-0000-000000000008', ARRAY['reports']);
    IF r #>> '{preferences,reports,setup}' <> 'done' THEN
        RAISE EXCEPTION 'tool write must keep reports: %', r;
    END IF;
    r := public.set_report_selection(
        '95000000-0000-0000-0000-000000000009', ARRAY['investments_total']);
    IF r #> '{preferences,tools,selected}' <> '["reports"]'::JSONB
        OR r #>> '{preferences,theme}' <> 'dark'
    THEN
        RAISE EXCEPTION 'report write must keep tools and theme: %', r;
    END IF;

    -- Recusas: ID inválido, repetido, status inválido ou nulo.
    BEGIN
        PERFORM public.set_report_selection(
            '95000000-0000-0000-0000-000000000010', ARRAY['Receitas']);
        RAISE EXCEPTION 'must reject invalid id';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.set_report_selection(
            '95000000-0000-0000-0000-000000000011',
            ARRAY['investments_total', 'investments_total']);
        RAISE EXCEPTION 'must reject duplicated id';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.complete_report_setup(
            '95000000-0000-0000-0000-000000000012', 'maybe');
        RAISE EXCEPTION 'must reject invalid status';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.complete_report_setup(
            '95000000-0000-0000-0000-000000000013', NULL);
        RAISE EXCEPTION 'must reject null status';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Auditoria: uma por gravação aplicada
    -- (tema + 2 setups + 4 listas + ferramentas + 1 lista = 9).
    SELECT COUNT(*) INTO n FROM public.audit_events
    WHERE entity_type = 'user_preferences';
    IF n <> 9 THEN
        RAISE EXCEPTION 'expected 9 audit events, got %', n;
    END IF;
END;
$test$;

-- Isolamento: outro usuário não vê nem altera as escolhas do primeiro.
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '94000000-0000-0000-0000-000000000002',
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
    r := public.complete_report_setup(
        '95000000-0000-0000-0000-000000000020', 'skipped');
    IF r #>> '{preferences,version}' <> '1'
        OR r #> '{preferences,reports}' <> '{"setup": "skipped"}'::JSONB
    THEN
        RAISE EXCEPTION 'second user must get own row: %', r;
    END IF;
END;
$test$;

ROLLBACK;
