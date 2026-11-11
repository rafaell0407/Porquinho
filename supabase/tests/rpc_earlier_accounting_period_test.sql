\set ON_ERROR_STOP on

-- Entrega 34B: períodos anteriores ao primeiro. Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('60000000-0000-0000-0000-000000000001'),
    ('60000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '60000000-0000-0000-0000-000000000001',
    TRUE
);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    r JSONB;
    replay JSONB;
    n BIGINT;
    caught BOOLEAN;
BEGIN
    IF pg_catalog.has_function_privilege(
        'anon', 'public.create_earlier_accounting_period(uuid,uuid,date)', 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anonymous execution must be revoked';
    END IF;

    -- Sem nenhum período: recusa.
    BEGIN
        PERFORM public.create_earlier_accounting_period(
            '61000000-0000-0000-0000-000000000099',
            '62000000-0000-0000-0000-000000000099', '2026-10-01');
        RAISE EXCEPTION 'must reject when there is no period';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Ciclo dia 31 a partir de 28/02/2026 (fevereiro curto).
    PERFORM public.create_accounting_period(
        '61000000-0000-0000-0000-000000000001',
        '62000000-0000-0000-0000-000000000001',
        '63000000-0000-0000-0000-000000000001',
        '2026-02-28', 'custom_cycle', 31::SMALLINT);

    r := public.create_earlier_accounting_period(
        '61000000-0000-0000-0000-000000000002',
        '62000000-0000-0000-0000-000000000002', '2026-01-31');
    IF r ->> 'status' <> 'applied'
        OR r #>> '{period,end_date}' <> '2026-02-28'
        OR r #>> '{period,configuration_id}' <> '63000000-0000-0000-0000-000000000001'
    THEN
        RAISE EXCEPTION 'earlier period incorrect: %', r;
    END IF;

    -- Reenvio da mesma operação: mesma resposta, sem segundo período.
    replay := public.create_earlier_accounting_period(
        '61000000-0000-0000-0000-000000000002',
        '62000000-0000-0000-0000-000000000002', '2026-01-31');
    IF replay IS DISTINCT FROM r THEN
        RAISE EXCEPTION 'replay must return the stored response';
    END IF;

    -- Continua para trás: 31/12/2025 → 31/01/2026.
    r := public.create_earlier_accounting_period(
        '61000000-0000-0000-0000-000000000003',
        '62000000-0000-0000-0000-000000000003', '2025-12-31');
    IF r #>> '{period,end_date}' <> '2026-01-31' THEN
        RAISE EXCEPTION 'second earlier period incorrect: %', r;
    END IF;

    -- Início que não fecha com o primeiro período: recusa.
    caught := FALSE;
    BEGIN
        PERFORM public.create_earlier_accounting_period(
            '61000000-0000-0000-0000-000000000004',
            '62000000-0000-0000-0000-000000000004', '2025-10-31');
    EXCEPTION WHEN check_violation THEN caught := TRUE;
    END;
    IF NOT caught THEN
        RAISE EXCEPTION 'a gap before the earliest period must be rejected';
    END IF;

    -- Início que não é o dia configurado: recusa.
    caught := FALSE;
    BEGIN
        PERFORM public.create_earlier_accounting_period(
            '61000000-0000-0000-0000-000000000005',
            '62000000-0000-0000-0000-000000000005', '2025-12-15');
    EXCEPTION WHEN check_violation THEN caught := TRUE;
    END;
    IF NOT caught THEN
        RAISE EXCEPTION 'a start that is not the configured day must be rejected';
    END IF;

    -- Data já coberta (início igual a existente): conflito, sem duplicar.
    r := public.create_earlier_accounting_period(
        '61000000-0000-0000-0000-000000000006',
        '62000000-0000-0000-0000-000000000006', '2026-01-31');
    IF r ->> 'status' <> 'conflict' THEN
        RAISE EXCEPTION 'existing start must conflict: %', r;
    END IF;

    -- Chave reutilizada com conteúdo diferente: recusa.
    caught := FALSE;
    BEGIN
        PERFORM public.create_earlier_accounting_period(
            '61000000-0000-0000-0000-000000000002',
            '62000000-0000-0000-0000-000000000002', '2025-11-30');
    EXCEPTION WHEN invalid_parameter_value THEN caught := TRUE;
    END;
    IF NOT caught THEN
        RAISE EXCEPTION 'idempotency key reuse with other content must fail';
    END IF;

    -- Sem lacuna nem sobreposição: cada fim = início do seguinte.
    SELECT COUNT(*) INTO n
    FROM public.accounting_periods AS a
    JOIN public.accounting_periods AS b
      ON b.owner_id = a.owner_id AND b.start_date = a.end_date;
    IF n <> 2 THEN
        RAISE EXCEPTION 'expected 2 contiguous joins, got %', n;
    END IF;

    SELECT COUNT(*) INTO n FROM public.accounting_periods;
    IF n <> 3 THEN
        RAISE EXCEPTION 'expected 3 periods, got %', n;
    END IF;

    -- A configuração não foi alterada.
    SELECT COUNT(*) INTO n FROM public.period_configurations
    WHERE effective_from = '2026-02-28' AND version = 1;
    IF n <> 1 THEN
        RAISE EXCEPTION 'configuration must stay untouched';
    END IF;

    -- Auditoria dos dois períodos criados para trás.
    SELECT COUNT(*) INTO n FROM public.audit_events
    WHERE entity_type = 'accounting_period' AND operation = 'create';
    IF n <> 3 THEN
        RAISE EXCEPTION 'expected 3 period audit events, got %', n;
    END IF;
END;
$test$;

-- Isolamento: outro usuário não vê nem altera os períodos do primeiro.
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '60000000-0000-0000-0000-000000000002',
    TRUE
);

DO $test$
DECLARE
    n BIGINT;
BEGIN
    SELECT COUNT(*) INTO n FROM public.accounting_periods;
    IF n <> 0 THEN
        RAISE EXCEPTION 'second user must not see other periods';
    END IF;
    BEGIN
        PERFORM public.create_earlier_accounting_period(
            '61000000-0000-0000-0000-000000000010',
            '62000000-0000-0000-0000-000000000010', '2025-11-30');
        RAISE EXCEPTION 'second user has no period; must reject';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END;
$test$;

ROLLBACK;
