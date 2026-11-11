\set ON_ERROR_STOP on

-- Entregas 66 e 67: tema e progresso do assistente. Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('90000000-0000-0000-0000-000000000001'),
    ('90000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '90000000-0000-0000-0000-000000000001',
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
        'anon', 'public.set_user_theme(uuid,text)', 'EXECUTE'
    ) OR pg_catalog.has_function_privilege(
        'anon', 'public.set_onboarding_step(uuid,text,text)', 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anonymous execution must be revoked';
    END IF;

    -- Primeira gravação cria a linha (versão 1).
    r := public.set_user_theme('91000000-0000-0000-0000-000000000001', 'dark');
    IF r ->> 'status' <> 'applied'
        OR r #>> '{preferences,theme}' <> 'dark'
        OR r #>> '{preferences,version}' <> '1'
    THEN
        RAISE EXCEPTION 'first theme write incorrect: %', r;
    END IF;

    -- Reenvio da mesma operação: mesma resposta, versão não sobe.
    replay := public.set_user_theme('91000000-0000-0000-0000-000000000001', 'dark');
    IF replay IS DISTINCT FROM r THEN
        RAISE EXCEPTION 'replay must return the stored response';
    END IF;
    SELECT version INTO n FROM public.user_preferences;
    IF n <> 1 THEN
        RAISE EXCEPTION 'replay must not bump the version';
    END IF;

    -- Mesma chave, conteúdo diferente: recusa.
    BEGIN
        PERFORM public.set_user_theme('91000000-0000-0000-0000-000000000001', 'light');
        RAISE EXCEPTION 'must reject key reuse with different content';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Última gravação enviada vale (D5), sem conflito.
    r := public.set_user_theme('91000000-0000-0000-0000-000000000002', 'light');
    IF r ->> 'status' <> 'applied'
        OR r #>> '{preferences,theme}' <> 'light'
        OR r #>> '{preferences,version}' <> '2'
    THEN
        RAISE EXCEPTION 'second theme write incorrect: %', r;
    END IF;

    -- NULL = seguir o aparelho (D4).
    r := public.set_user_theme('91000000-0000-0000-0000-000000000003', NULL);
    IF r #>> '{preferences,theme}' IS NOT NULL THEN
        RAISE EXCEPTION 'theme must be reset to NULL: %', r;
    END IF;

    -- Tema inválido: recusa.
    BEGIN
        PERFORM public.set_user_theme('91000000-0000-0000-0000-000000000004', 'blue');
        RAISE EXCEPTION 'must reject unknown theme';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Onboarding: etapas de aparelhos diferentes se somam.
    r := public.set_onboarding_step(
        '91000000-0000-0000-0000-000000000010', 'categories', 'done');
    r := public.set_onboarding_step(
        '91000000-0000-0000-0000-000000000011', 'security', 'skipped');
    IF r #>> '{preferences,onboarding,categories}' <> 'done'
        OR r #>> '{preferences,onboarding,security}' <> 'skipped'
        OR r #>> '{preferences,version}' <> '5'
    THEN
        RAISE EXCEPTION 'onboarding steps must merge: %', r;
    END IF;
    -- O tema não é apagado pelo progresso (e vice-versa).
    r := public.set_user_theme('91000000-0000-0000-0000-000000000012', 'dark');
    IF r #>> '{preferences,onboarding,categories}' <> 'done' THEN
        RAISE EXCEPTION 'theme write must keep onboarding: %', r;
    END IF;

    BEGIN
        PERFORM public.set_onboarding_step(
            '91000000-0000-0000-0000-000000000013', 'inexistente', 'done');
        RAISE EXCEPTION 'must reject unknown step';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.set_onboarding_step(
            '91000000-0000-0000-0000-000000000014', 'theme', 'pending');
        RAISE EXCEPTION 'must reject unknown status';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Auditoria: uma por gravação aplicada (1 + 1 + 1 + 2 + 1 = 6).
    SELECT COUNT(*) INTO n FROM public.audit_events
    WHERE entity_type = 'user_preferences';
    IF n <> 6 THEN
        RAISE EXCEPTION 'expected 6 audit events, got %', n;
    END IF;
END;
$test$;

-- Isolamento: outro usuário não vê nem altera as preferências do primeiro.
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '90000000-0000-0000-0000-000000000002',
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
    r := public.set_user_theme('91000000-0000-0000-0000-000000000020', 'light');
    IF r #>> '{preferences,version}' <> '1'
        OR r #>> '{preferences,onboarding}' <> '{}'
    THEN
        RAISE EXCEPTION 'second user must get own row: %', r;
    END IF;
END;
$test$;

ROLLBACK;
