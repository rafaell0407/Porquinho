\set ON_ERROR_STOP on

-- Entrega 59: agendamento da configuração do próximo período. Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('70000000-0000-0000-0000-000000000001'),
    ('70000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '70000000-0000-0000-0000-000000000001',
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
        'anon',
        'public.schedule_period_configuration(uuid,text,uuid,bigint,date,text,smallint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anonymous execution must be revoked';
    END IF;

    -- Sem período: recusa.
    BEGIN
        PERFORM public.schedule_period_configuration(
            '71000000-0000-0000-0000-000000000099', 'create',
            '73000000-0000-0000-0000-000000000099', 0, '2026-12-01',
            'custom_cycle', 20::SMALLINT);
        RAISE EXCEPTION 'must reject when there is no period';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Mês-calendário com período de novembro/2026.
    PERFORM public.create_accounting_period(
        '71000000-0000-0000-0000-000000000001',
        '72000000-0000-0000-0000-000000000001',
        '73000000-0000-0000-0000-000000000001',
        '2026-11-01', 'calendar_month', NULL);

    -- Data diferente do fim do último período: recusa.
    BEGIN
        PERFORM public.schedule_period_configuration(
            '71000000-0000-0000-0000-000000000098', 'create',
            '73000000-0000-0000-0000-000000000098', 0, '2026-12-15',
            'custom_cycle', 20::SMALLINT);
        RAISE EXCEPTION 'must reject a date that is not the last period end';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Agenda ciclo dia 20 a partir de 01/12/2026.
    r := public.schedule_period_configuration(
        '71000000-0000-0000-0000-000000000002', 'create',
        '73000000-0000-0000-0000-000000000002', 0, '2026-12-01',
        'custom_cycle', 20::SMALLINT);
    IF r ->> 'status' <> 'applied'
        OR r #>> '{configuration,effective_from}' <> '2026-12-01'
        OR r #>> '{configuration,custom_start_day}' <> '20'
    THEN
        RAISE EXCEPTION 'schedule incorrect: %', r;
    END IF;

    -- Reenvio da mesma operação: mesma resposta, sem duplicar.
    replay := public.schedule_period_configuration(
        '71000000-0000-0000-0000-000000000002', 'create',
        '73000000-0000-0000-0000-000000000002', 0, '2026-12-01',
        'custom_cycle', 20::SMALLINT);
    IF replay IS DISTINCT FROM r THEN
        RAISE EXCEPTION 'replay must return the stored response';
    END IF;
    SELECT COUNT(*) INTO n FROM public.period_configurations;
    IF n <> 2 THEN
        RAISE EXCEPTION 'expected 2 configurations, got %', n;
    END IF;

    -- Mesma chave com conteúdo diferente: recusa.
    BEGIN
        PERFORM public.schedule_period_configuration(
            '71000000-0000-0000-0000-000000000002', 'create',
            '73000000-0000-0000-0000-000000000002', 0, '2026-12-01',
            'custom_cycle', 25::SMALLINT);
        RAISE EXCEPTION 'must reject key reuse with different content';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- D3: troca enquanto nenhum período a usa (versão sobe para 2).
    r := public.schedule_period_configuration(
        '71000000-0000-0000-0000-000000000003', 'update',
        '73000000-0000-0000-0000-000000000002', 1, '2026-12-01',
        'custom_cycle', 25::SMALLINT);
    IF r ->> 'status' <> 'applied'
        OR r #>> '{configuration,version}' <> '2'
        OR r #>> '{configuration,custom_start_day}' <> '25'
    THEN
        RAISE EXCEPTION 'update incorrect: %', r;
    END IF;

    -- Versão desatualizada: conflito preservado, nada muda.
    r := public.schedule_period_configuration(
        '71000000-0000-0000-0000-000000000004', 'update',
        '73000000-0000-0000-0000-000000000002', 1, '2026-12-01',
        'calendar_month', NULL);
    IF r ->> 'status' <> 'conflict' THEN
        RAISE EXCEPTION 'stale version must conflict: %', r;
    END IF;
    SELECT COUNT(*) INTO n FROM public.sync_conflicts
    WHERE entity_type = 'period_configuration';
    IF n <> 1 THEN
        RAISE EXCEPTION 'conflict must be stored';
    END IF;

    -- Segundo agendamento com id diferente na mesma data: conflito.
    r := public.schedule_period_configuration(
        '71000000-0000-0000-0000-000000000005', 'create',
        '73000000-0000-0000-0000-000000000005', 0, '2026-12-01',
        'calendar_month', NULL);
    IF r ->> 'status' <> 'conflict' THEN
        RAISE EXCEPTION 'second schedule on same date must conflict: %', r;
    END IF;

    -- O próximo período usa a configuração agendada (transição: 01/12 a 25/12).
    r := public.create_accounting_period(
        '71000000-0000-0000-0000-000000000006',
        '72000000-0000-0000-0000-000000000006',
        '73000000-0000-0000-0000-000000000002',
        '2026-12-01', 'custom_cycle', 25::SMALLINT);
    IF r ->> 'status' <> 'applied'
        OR r #>> '{period,end_date}' <> '2026-12-25'
    THEN
        RAISE EXCEPTION 'transition period incorrect: %', r;
    END IF;

    -- Já usada por um período: não pode mais ser trocada.
    BEGIN
        PERFORM public.schedule_period_configuration(
            '71000000-0000-0000-0000-000000000007', 'update',
            '73000000-0000-0000-0000-000000000002', 2, '2026-12-01',
            'calendar_month', NULL);
        RAISE EXCEPTION 'must reject changing a configuration already in use';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Período antigo inalterado.
    SELECT COUNT(*) INTO n FROM public.accounting_periods
    WHERE start_date = '2026-11-01' AND end_date = '2026-12-01' AND version = 1;
    IF n <> 1 THEN
        RAISE EXCEPTION 'existing period must stay untouched';
    END IF;

    -- Auditoria: criação + atualização da configuração agendada.
    SELECT COUNT(*) INTO n FROM public.audit_events
    WHERE entity_type = 'period_configuration'
      AND entity_id = '73000000-0000-0000-0000-000000000002';
    IF n <> 2 THEN
        RAISE EXCEPTION 'expected 2 audit events, got %', n;
    END IF;
END;
$test$;

-- Isolamento: outro usuário não vê nem altera as configurações do primeiro.
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '70000000-0000-0000-0000-000000000002',
    TRUE
);

DO $test$
DECLARE
    n BIGINT;
BEGIN
    SELECT COUNT(*) INTO n FROM public.period_configurations;
    IF n <> 0 THEN
        RAISE EXCEPTION 'second user must not see other configurations';
    END IF;
    BEGIN
        PERFORM public.schedule_period_configuration(
            '71000000-0000-0000-0000-000000000010', 'update',
            '73000000-0000-0000-0000-000000000002', 1, '2026-12-25',
            'calendar_month', NULL);
        RAISE EXCEPTION 'second user has no period; must reject';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END;
$test$;

ROLLBACK;
