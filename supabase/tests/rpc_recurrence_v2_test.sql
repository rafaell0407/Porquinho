\set ON_ERROR_STOP on
BEGIN;
DO $fixtures$
DECLARE
    v_owner_id UUID := '94000000-0000-0000-0000-000000000001';
    current_month DATE := pg_catalog.date_trunc('month',pg_catalog.timezone('America/Sao_Paulo',pg_catalog.clock_timestamp()))::DATE;
    period_base DATE := (current_month - INTERVAL '3 months')::DATE;
    config_id UUID := '94000000-0000-0000-0000-000000000010';
BEGIN
    INSERT INTO auth.users(id) VALUES(v_owner_id),('94000000-0000-0000-0000-000000000002');
    INSERT INTO public.user_preferences(owner_id,time_zone_id) VALUES(v_owner_id,'America/Sao_Paulo');
END;
$fixtures$;

SELECT pg_catalog.set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',TRUE);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE
    v_owner_id UUID := auth.uid();
    today DATE := pg_catalog.timezone('America/Sao_Paulo',pg_catalog.clock_timestamp())::DATE;
    current_month DATE := pg_catalog.date_trunc('month',pg_catalog.timezone('America/Sao_Paulo',pg_catalog.clock_timestamp()))::DATE;
    period_base DATE := (current_month - INTERVAL '3 months')::DATE;
    result JSONB;
    replay JSONB;
    last_scheduled DATE;
    expected_floor DATE;
    occurrence_count BIGINT;
    after_count BIGINT;
    entry_row public.expense_entries%ROWTYPE;
    income_row public.income_entries%ROWTYPE;
    template_row public.expense_recurrence_templates%ROWTYPE;
BEGIN
    -- D1: o identificador é uma função pura de modelo + data (mesmo valor do Dart).
    IF public.recurrence_occurrence_id('3f2a9d1e-1111-4c22-8d33-aaaaaaaaaaaa','2026-11-05')<>'d07bc585-9b84-523c-8598-d815da7b604e'::UUID THEN
        RAISE EXCEPTION 'occurrence id differs from the app algorithm: %',
            public.recurrence_occurrence_id('3f2a9d1e-1111-4c22-8d33-aaaaaaaaaaaa','2026-11-05');
    END IF;

    -- Modelo mensal de despesa criado pelo RPC existente.
    result:=public.apply_expense_recurrence_template_change('94100000-0000-0000-0000-000000000001','create',
        '94200000-0000-0000-0000-000000000001',0,
        pg_catalog.jsonb_build_object('description','Academia','frequency','monthly','starts_on',period_base,
            'monthly_reference_day',5,'value_mode','fixed','default_amount_centavos',9000));
    IF result->>'status'<>'applied' THEN RAISE EXCEPTION 'template create failed: %',result; END IF;

    result:=public.generate_due_recurrence_occurrences('94100000-0000-0000-0000-000000000002');
    IF (result->>'expense_created')::INTEGER<3 THEN RAISE EXCEPTION 'generation did not catch up: %',result; END IF;
    FOR entry_row IN SELECT * FROM public.expense_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='94200000-0000-0000-0000-000000000001' LOOP
        IF entry_row.id<>public.recurrence_occurrence_id(entry_row.recurrence_template_id,entry_row.scheduled_for_date) THEN
            RAISE EXCEPTION 'generated occurrence did not use the deterministic id';
        END IF;
        IF entry_row.due_on IS DISTINCT FROM entry_row.scheduled_for_date OR entry_row.competence_on<>entry_row.scheduled_for_date THEN
            RAISE EXCEPTION 'due date and competence must equal the scheduled date';
        END IF;
    END LOOP;

    -- Gerar de novo não duplica.
    SELECT pg_catalog.count(*) INTO occurrence_count FROM public.expense_entries e
    WHERE e.owner_id=v_owner_id AND e.recurrence_template_id='94200000-0000-0000-0000-000000000001';
    replay:=public.generate_due_recurrence_occurrences('94100000-0000-0000-0000-000000000003');
    SELECT pg_catalog.count(*) INTO after_count FROM public.expense_entries e
    WHERE e.owner_id=v_owner_id AND e.recurrence_template_id='94200000-0000-0000-0000-000000000001';
    IF (replay->>'expense_created')::INTEGER<>0 OR after_count<>occurrence_count THEN
        RAISE EXCEPTION 'repeated generation duplicated occurrences';
    END IF;

    -- Ocorrência cancelada não renasce.
    SELECT * INTO entry_row FROM public.expense_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='94200000-0000-0000-0000-000000000001' ORDER BY e.scheduled_for_date LIMIT 1;
    PERFORM public.apply_expense_recurrence_occurrence_change('94100000-0000-0000-0000-000000000004','cancel',entry_row.id,entry_row.version,NULL);
    PERFORM public.generate_due_recurrence_occurrences('94100000-0000-0000-0000-000000000005');
    SELECT pg_catalog.count(*) INTO after_count FROM public.expense_entries e
    WHERE e.owner_id=v_owner_id AND e.recurrence_template_id='94200000-0000-0000-0000-000000000001';
    IF after_count<>occurrence_count THEN RAISE EXCEPTION 'cancelled occurrence was recreated'; END IF;

    -- D2: mudar o dia só vale para ocorrências ainda não geradas.
    SELECT pg_catalog.max(e.scheduled_for_date) INTO last_scheduled FROM public.expense_entries e
    WHERE e.owner_id=v_owner_id AND e.recurrence_template_id='94200000-0000-0000-0000-000000000001';
    expected_floor:=(pg_catalog.date_trunc('month',last_scheduled)+INTERVAL '1 month')::DATE;
    result:=public.apply_expense_recurrence_template_change('94100000-0000-0000-0000-000000000006','update',
        '94200000-0000-0000-0000-000000000001',1,'{"monthly_reference_day":20}'::JSONB);
    IF (result#>>'{template,starts_on}')::DATE<>expected_floor THEN
        RAISE EXCEPTION 'schedule change must start after the last generated month: % vs %',result#>>'{template,starts_on}',expected_floor;
    END IF;
    PERFORM public.generate_due_recurrence_occurrences('94100000-0000-0000-0000-000000000007');
    SELECT pg_catalog.count(*) INTO after_count FROM public.expense_entries e
    WHERE e.owner_id=v_owner_id AND e.recurrence_template_id='94200000-0000-0000-0000-000000000001';
    IF after_count<>occurrence_count THEN RAISE EXCEPTION 'schedule change created past or duplicate occurrences'; END IF;

    -- D4 superada (P6): períodos são calculados; início em qualquer data é aceito.
    result:=public.apply_income_recurrence_template_change('94100000-0000-0000-0000-000000000008','create',
        '94200000-0000-0000-0000-000000000002',0,
        pg_catalog.jsonb_build_object('frequency','monthly','starts_on',(period_base-INTERVAL '2 months')::DATE,
            'monthly_reference_day',10,'value_mode','fixed','default_amount_centavos',100));
    IF result->>'status'<>'applied' THEN RAISE EXCEPTION 'template before the old first period was refused: %',result; END IF;
    PERFORM public.apply_income_recurrence_template_change('94100000-0000-0000-0000-000000000030','deactivate',
        '94200000-0000-0000-0000-000000000002',1,NULL);

    -- D8: lançamento novo vira a primeira ocorrência (despesa mensal).
    result:=public.create_recurrence_from_entry('94100000-0000-0000-0000-000000000009','expense',
        '94200000-0000-0000-0000-000000000003','94300000-0000-0000-0000-000000000001',0,
        pg_catalog.jsonb_build_object('description','Internet','frequency','monthly','starts_on',current_month+2,
            'monthly_reference_day',3,'value_mode','fixed','default_amount_centavos',12000),
        pg_catalog.jsonb_build_object('date',current_month+2,'amount_centavos',12000,'description','Internet'));
    IF result->>'status'<>'applied' OR result#>>'{entry,status}'<>'pending'
        OR (result#>>'{entry,scheduled_for_date}')::DATE<>current_month+2
        OR (result#>>'{entry,due_on}')::DATE<>current_month+2 THEN
        RAISE EXCEPTION 'new entry did not become the first expense occurrence: %',result;
    END IF;
    replay:=public.create_recurrence_from_entry('94100000-0000-0000-0000-000000000009','expense',
        '94200000-0000-0000-0000-000000000003','94300000-0000-0000-0000-000000000001',0,
        pg_catalog.jsonb_build_object('description','Internet','frequency','monthly','starts_on',current_month+2,
            'monthly_reference_day',3,'value_mode','fixed','default_amount_centavos',12000),
        pg_catalog.jsonb_build_object('date',current_month+2,'amount_centavos',12000,'description','Internet'));
    IF replay IS DISTINCT FROM result THEN RAISE EXCEPTION 'conversion replay was not idempotent'; END IF;
    PERFORM public.generate_due_recurrence_occurrences('94100000-0000-0000-0000-00000000000A');
    IF (SELECT pg_catalog.count(*) FROM public.expense_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='94200000-0000-0000-0000-000000000003' AND e.scheduled_for_date=current_month+2)<>1 THEN
        RAISE EXCEPTION 'generation duplicated the first occurrence';
    END IF;

    -- D8: lançamento avulso existente vira a primeira ocorrência (mensal, na própria data).
    result:=public.apply_expense_entry_change('94100000-0000-0000-0000-00000000000B','create','94300000-0000-0000-0000-000000000002',0,
        pg_catalog.jsonb_build_object('amount_centavos',5000,'competence_on',current_month+9,'description','Condomínio'));
    IF result->>'status'<>'applied' THEN RAISE EXCEPTION 'standalone expense create failed: %',result; END IF;
    result:=public.create_recurrence_from_entry('94100000-0000-0000-0000-00000000000C','expense',
        '94200000-0000-0000-0000-000000000004','94300000-0000-0000-0000-000000000002',1,
        pg_catalog.jsonb_build_object('description','Condomínio','frequency','monthly','monthly_reference_day',10,
            'starts_on',current_month+9,'value_mode','fixed','default_amount_centavos',5000),NULL);
    IF result->>'status'<>'applied' OR (result#>>'{entry,scheduled_for_date}')::DATE<>current_month+9
        OR (result#>>'{entry,competence_on}')::DATE<>current_month+9 OR result#>>'{entry,version}'<>'2'
        OR (result#>>'{entry,scheduled_period_id}') IS NOT NULL THEN
        RAISE EXCEPTION 'standalone expense did not become the first monthly occurrence: %',result;
    END IF;
    PERFORM public.generate_due_recurrence_occurrences('94100000-0000-0000-0000-00000000000D');
    IF (SELECT pg_catalog.count(*) FROM public.expense_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='94200000-0000-0000-0000-000000000004'
        AND e.scheduled_for_date>=current_month AND e.scheduled_for_date<(current_month+INTERVAL '1 month')::DATE)<>1 THEN
        RAISE EXCEPTION 'generation duplicated the converted occurrence';
    END IF;

    -- Versão antiga gera conflito, sem criar o modelo.
    result:=public.create_recurrence_from_entry('94100000-0000-0000-0000-00000000000E','expense',
        '94200000-0000-0000-0000-000000000005','94300000-0000-0000-0000-000000000002',1,
        pg_catalog.jsonb_build_object('frequency','monthly','monthly_reference_day',10,'starts_on',current_month+9,'value_mode','variable'),NULL);
    IF result->>'status'<>'conflict' OR EXISTS(SELECT 1 FROM public.expense_recurrence_templates t
        WHERE t.owner_id=v_owner_id AND t.id='94200000-0000-0000-0000-000000000005') THEN
        RAISE EXCEPTION 'stale conversion must conflict without creating a template: %',result;
    END IF;

    -- P5: "por período" é recusado também na conversão.
    BEGIN
        PERFORM public.create_recurrence_from_entry('94100000-0000-0000-0000-000000000020','expense',
            '94200000-0000-0000-0000-000000000009','94300000-0000-0000-0000-000000000009',0,
            pg_catalog.jsonb_build_object('frequency','by_period','starts_on',current_month+9,'value_mode','variable'),
            pg_catalog.jsonb_build_object('date',current_month+9));
        RAISE EXCEPTION 'by-period conversion was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Receita nova mensal: nasce pendente e sem período.
    result:=public.create_recurrence_from_entry('94100000-0000-0000-0000-00000000000F','income',
        '94200000-0000-0000-0000-000000000006','94300000-0000-0000-0000-000000000003',0,
        pg_catalog.jsonb_build_object('description','Salário','frequency','monthly','starts_on',current_month+4,
            'monthly_reference_day',5,'value_mode','variable'),
        pg_catalog.jsonb_build_object('date',current_month+4,'description','Salário'));
    IF result->>'status'<>'applied' OR result#>>'{entry,status}'<>'pending' OR result#>>'{entry,accounting_period_id}' IS NOT NULL
        OR result#>>'{entry,amount_centavos}' IS NOT NULL THEN
        RAISE EXCEPTION 'new income did not become a pending first occurrence: %',result;
    END IF;

    -- Dia diferente do dia do lançamento é recusado.
    BEGIN
        PERFORM public.create_recurrence_from_entry('94100000-0000-0000-0000-000000000010','income',
            '94200000-0000-0000-0000-000000000007','94300000-0000-0000-0000-000000000004',0,
            pg_catalog.jsonb_build_object('frequency','monthly','starts_on',current_month+4,
                'monthly_reference_day',9,'value_mode','variable'),
            pg_catalog.jsonb_build_object('date',current_month+4));
        RAISE EXCEPTION 'reference day different from the entry day was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Isolamento.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000002',TRUE);
    BEGIN
        PERFORM public.create_recurrence_from_entry('94100000-0000-0000-0000-000000000011','expense',
            '94200000-0000-0000-0000-000000000008','94300000-0000-0000-0000-000000000002',1,
            pg_catalog.jsonb_build_object('frequency','monthly','monthly_reference_day',10,'starts_on',current_month+9,'value_mode','variable'),NULL);
        RAISE EXCEPTION 'another user converted this entry';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
END;
$test$;
\echo PASS: recurrence v2 deterministic ids, generation, schedule changes, first period guard and entry conversion.
ROLLBACK;
