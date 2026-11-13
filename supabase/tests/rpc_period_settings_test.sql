\set ON_ERROR_STOP on

-- Reestruturação P6: configuração única de período (set_period_settings),
-- conflito por versão e lançamentos sem nenhum período gravado.
-- Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('c0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config('request.jwt.claim.sub',
    'c0000000-0000-0000-0000-000000000001', TRUE);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    v_owner UUID := 'c0000000-0000-0000-0000-000000000001';
    r JSONB;
    replay JSONB;
    conflict_id UUID;
    n BIGINT;
BEGIN
    IF pg_catalog.has_function_privilege('anon',
        'public.set_period_settings(uuid,bigint,text,smallint)', 'EXECUTE')
       OR NOT pg_catalog.has_function_privilege('authenticated',
        'public.set_period_settings(uuid,bigint,text,smallint)', 'EXECUTE') THEN
        RAISE EXCEPTION 'set_period_settings grants are incorrect';
    END IF;

    -- Primeiro acesso: cria a configuração (versão 1, id = dono).
    r := public.set_period_settings('c1000000-0000-0000-0000-000000000001', 0,
        'calendar_month', NULL);
    IF r ->> 'status' <> 'applied' OR r #>> '{settings,version}' <> '1'
        OR (r #>> '{settings,id}')::UUID <> v_owner
        OR r #>> '{settings,mode}' <> 'calendar_month' THEN
        RAISE EXCEPTION 'create failed: %', r;
    END IF;
    replay := public.set_period_settings('c1000000-0000-0000-0000-000000000001', 0,
        'calendar_month', NULL);
    IF replay IS DISTINCT FROM r THEN
        RAISE EXCEPTION 'create replay was not idempotent';
    END IF;
    BEGIN
        PERFORM public.set_period_settings('c1000000-0000-0000-0000-000000000001', 0,
            'custom_cycle', 10::SMALLINT);
        RAISE EXCEPTION 'reused key with other content was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Segundo "primeiro acesso" (outro aparelho): conflito, nada muda.
    r := public.set_period_settings('c1000000-0000-0000-0000-000000000002', 0,
        'custom_cycle', 5::SMALLINT);
    IF r ->> 'status' <> 'conflict' OR r #>> '{remote_settings,mode}' <> 'calendar_month' THEN
        RAISE EXCEPTION 'second create must conflict: %', r;
    END IF;

    -- Troca a qualquer momento (RN002): ciclo dia 20, versão 2.
    r := public.set_period_settings('c1000000-0000-0000-0000-000000000003', 1,
        'custom_cycle', 20::SMALLINT);
    IF r ->> 'status' <> 'applied' OR r #>> '{settings,version}' <> '2'
        OR r #>> '{settings,custom_start_day}' <> '20' THEN
        RAISE EXCEPTION 'update failed: %', r;
    END IF;

    -- Versão antiga: conflito (nunca "última gravação vence").
    r := public.set_period_settings('c1000000-0000-0000-0000-000000000004', 1,
        'custom_cycle', 31::SMALLINT);
    IF r ->> 'status' <> 'conflict' OR r #>> '{remote_settings,version}' <> '2' THEN
        RAISE EXCEPTION 'stale update must conflict: %', r;
    END IF;
    conflict_id := (r ->> 'conflict_id')::UUID;
    IF (SELECT s.custom_start_day FROM public.period_settings s WHERE s.owner_id = v_owner) <> 20 THEN
        RAISE EXCEPTION 'conflict changed the settings';
    END IF;

    -- Manter a versão do aparelho: aplica o dia 31 sobre a versão atual.
    r := public.resolve_sync_conflict('c1000000-0000-0000-0000-000000000005',
        conflict_id, 'keep_local');
    IF r ->> 'status' <> 'resolved'
        OR (SELECT s.custom_start_day FROM public.period_settings s WHERE s.owner_id = v_owner) <> 31
        OR (SELECT s.version FROM public.period_settings s WHERE s.owner_id = v_owner) <> 3 THEN
        RAISE EXCEPTION 'keep_local failed: %', r;
    END IF;

    -- Editar no conflito: valor novo escolhido pelo usuário.
    r := public.set_period_settings('c1000000-0000-0000-0000-000000000006', 1,
        'calendar_month', NULL);
    conflict_id := (r ->> 'conflict_id')::UUID;
    r := public.resolve_sync_conflict('c1000000-0000-0000-0000-000000000007',
        conflict_id, 'edit', '{"action":"update","mode":"custom_cycle","custom_start_day":15}'::JSONB);
    IF r ->> 'status' <> 'resolved'
        OR (SELECT s.custom_start_day FROM public.period_settings s WHERE s.owner_id = v_owner) <> 15 THEN
        RAISE EXCEPTION 'edit resolution failed: %', r;
    END IF;

    -- Manter a do servidor: nada muda.
    r := public.set_period_settings('c1000000-0000-0000-0000-000000000008', 1,
        'calendar_month', NULL);
    conflict_id := (r ->> 'conflict_id')::UUID;
    PERFORM public.resolve_sync_conflict('c1000000-0000-0000-0000-000000000009',
        conflict_id, 'keep_remote');
    IF (SELECT s.custom_start_day FROM public.period_settings s WHERE s.owner_id = v_owner) <> 15 THEN
        RAISE EXCEPTION 'keep_remote changed the settings';
    END IF;

    -- Validação.
    BEGIN
        PERFORM public.set_period_settings('c1000000-0000-0000-0000-00000000000a', 4,
            'calendar_month', 3::SMALLINT);
        RAISE EXCEPTION 'calendar month with a day was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.set_period_settings('c1000000-0000-0000-0000-00000000000b', 4,
            'custom_cycle', 32::SMALLINT);
        RAISE EXCEPTION 'day 32 was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.set_period_settings('c1000000-0000-0000-0000-00000000000c', 4,
            'custom_cycle', NULL);
        RAISE EXCEPTION 'cycle without day was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.set_period_settings('c1000000-0000-0000-0000-00000000000d', 4,
            'weekly', NULL);
        RAISE EXCEPTION 'unknown mode was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Escrita direta proibida.
    BEGIN
        UPDATE public.period_settings SET custom_start_day = 1 WHERE owner_id = v_owner;
        RAISE EXCEPTION 'direct update was accepted';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    -- Auditoria: criação, troca e resoluções.
    SELECT pg_catalog.count(*) INTO n FROM public.audit_events a
    WHERE a.owner_id = v_owner AND a.entity_type = 'period_settings';
    IF n < 4 THEN
        RAISE EXCEPTION 'period settings changes were not audited (%)', n;
    END IF;

    -- Sem nenhum período gravado: lançamentos em qualquer data são aceitos.
    r := public.apply_income_entry_change('c2000000-0000-0000-0000-000000000001', 'create',
        'c3000000-0000-0000-0000-000000000001', 0,
        '{"amount_centavos":1000,"received_on":"1999-01-31"}'::JSONB);
    IF r ->> 'status' <> 'applied' OR r #>> '{entry,accounting_period_id}' IS NOT NULL THEN
        RAISE EXCEPTION 'income without period failed: %', r;
    END IF;
    r := public.apply_expense_entry_change('c2000000-0000-0000-0000-000000000002', 'create',
        'c3000000-0000-0000-0000-000000000002', 0,
        '{"amount_centavos":500,"competence_on":"2040-12-31","due_on":"2040-12-31"}'::JSONB);
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'expense without period failed: %', r;
    END IF;
    r := public.apply_investment_allocation_change('c2000000-0000-0000-0000-000000000003', 'create',
        'c3000000-0000-0000-0000-000000000003', 0, 700, '2030-06-15');
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'investment without period failed: %', r;
    END IF;
    -- Recorrência começando há anos: aceita e gera as atrasadas sem período.
    r := public.create_recurrence_from_entry('c2000000-0000-0000-0000-000000000004', 'expense',
        'c4000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000004', 0,
        '{"frequency":"monthly","starts_on":"2025-01-31","monthly_reference_day":31,"value_mode":"fixed","default_amount_centavos":100}'::JSONB,
        '{"date":"2025-01-31","amount_centavos":100}'::JSONB);
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'recurrence without period failed: %', r;
    END IF;
    r := public.generate_due_recurrence_occurrences('c2000000-0000-0000-0000-000000000005');
    IF (r ->> 'expense_created')::INT < 10 THEN
        RAISE EXCEPTION 'generation without periods did not catch up: %', r;
    END IF;
    -- Limites da navegação: do mais antigo ao mais distante.
    r := public.get_entry_date_span();
    IF r ->> 'oldest' <> '1999-01-31' OR r ->> 'newest' <> '2040-12-31' THEN
        RAISE EXCEPTION 'date span is wrong: %', r;
    END IF;
    -- E somam pelas datas.
    r := public.get_range_report(ARRAY['1999-01-01', '2025-02-01']::DATE[],
        ARRAY['1999-02-01', '2025-03-01']::DATE[]);
    IF r -> 'ranges' -> 0 ->> 'income' <> '1000' OR r -> 'ranges' -> 1 ->> 'expense' <> '100' THEN
        RAISE EXCEPTION 'range totals without periods are wrong: %', r;
    END IF;
END;
$test$;

-- Isolamento: o outro usuário não vê nem altera a configuração do primeiro.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
    'c0000000-0000-0000-0000-000000000002', TRUE);

DO $test$
BEGIN
    IF EXISTS (SELECT 1 FROM public.period_settings) THEN
        RAISE EXCEPTION 'second user can read other settings';
    END IF;
    IF public.get_entry_date_span() ->> 'oldest' IS NOT NULL THEN
        RAISE EXCEPTION 'second user sees other entry dates';
    END IF;
    BEGIN
        PERFORM public.set_period_settings('c1000000-0000-0000-0000-0000000000f1', 5,
            'calendar_month', NULL);
        RAISE EXCEPTION 'second user updated settings it does not have';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
END;
$test$;

\echo PASS: single period settings, version conflicts, resolution, audit, isolation and entries without stored periods.
ROLLBACK;
