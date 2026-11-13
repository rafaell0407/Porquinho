\set ON_ERROR_STOP on
-- Fase 6, Entrega 55: recorrência de investimento (D7–D9) e regressão da geração
-- de receitas e despesas. Também exercita a RPC avulsa (Entrega 7A, ver E52).
BEGIN;
DO $fixtures$
DECLARE
    v_owner_id UUID := '95000000-0000-0000-0000-000000000001';
    current_month DATE := pg_catalog.date_trunc('month',pg_catalog.timezone('America/Sao_Paulo',pg_catalog.clock_timestamp()))::DATE;
    period_base DATE := (current_month - INTERVAL '3 months')::DATE;
    config_id UUID := '95000000-0000-0000-0000-000000000010';
BEGIN
    INSERT INTO auth.users(id) VALUES(v_owner_id),('95000000-0000-0000-0000-000000000002');
    INSERT INTO public.user_preferences(owner_id,time_zone_id) VALUES(v_owner_id,'America/Sao_Paulo');
END;
$fixtures$;

SELECT pg_catalog.set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000001',TRUE);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE
    v_owner_id UUID := auth.uid();
    current_month DATE := pg_catalog.date_trunc('month',pg_catalog.timezone('America/Sao_Paulo',pg_catalog.clock_timestamp()))::DATE;
    period_base DATE := (current_month - INTERVAL '3 months')::DATE;
    result JSONB;
    replay JSONB;
    tpl UUID := '95200000-0000-0000-0000-000000000001';
    n_before BIGINT;
    n_after BIGINT;
    v_alloc public.investment_allocations%ROWTYPE;
    v_other public.investment_allocations%ROWTYPE;
    v_template public.investment_recurrence_templates%ROWTYPE;
    last_scheduled DATE;
    expected_floor DATE;
    conflict_id UUID;
BEGIN
    -- Identificador determinístico igual ao do aplicativo.
    IF public.recurrence_occurrence_id('3f2a9d1e-1111-4c22-8d33-aaaaaaaaaaaa','2026-11-05')<>'d07bc585-9b84-523c-8598-d815da7b604e'::UUID THEN
        RAISE EXCEPTION 'occurrence id differs from the app algorithm';
    END IF;

    -- Modelo mensal fixo (dia 5, desde o primeiro período).
    result:=public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-000000000001','create',tpl,0,
        pg_catalog.jsonb_build_object('frequency','monthly','starts_on',period_base,'monthly_reference_day',5,
            'default_amount_centavos',5000));
    IF result->>'status'<>'applied' THEN RAISE EXCEPTION 'template create failed: %',result; END IF;

    -- Também uma despesa recorrente: a geração de investimento não pode afetá-la.
    result:=public.apply_expense_recurrence_template_change('95100000-0000-0000-0000-000000000002','create',
        '95200000-0000-0000-0000-000000000002',0,
        pg_catalog.jsonb_build_object('description','Academia','frequency','monthly','starts_on',period_base,
            'monthly_reference_day',6,'value_mode','fixed','default_amount_centavos',9000));
    IF result->>'status'<>'applied' THEN RAISE EXCEPTION 'expense template create failed: %',result; END IF;

    result:=public.generate_due_recurrence_occurrences('95100000-0000-0000-0000-000000000003');
    IF (result->>'investment_created')::INTEGER<3 OR (result->>'expense_created')::INTEGER<3 THEN
        RAISE EXCEPTION 'generation did not catch up investments and expenses: %',result;
    END IF;
    FOR v_alloc IN SELECT * FROM public.investment_allocations a
        WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl LOOP
        IF v_alloc.id<>public.recurrence_occurrence_id(tpl,v_alloc.scheduled_for_date) THEN
            RAISE EXCEPTION 'generated investment did not use the deterministic id';
        END IF;
        IF v_alloc.allocated_on<>v_alloc.scheduled_for_date OR v_alloc.amount_centavos<>5000 OR v_alloc.cancelled_at IS NOT NULL THEN
            RAISE EXCEPTION 'generated investment has wrong date, amount or status';
        END IF;
        IF pg_catalog.to_jsonb(v_alloc)->>'accounting_period_id' IS NOT NULL THEN
            RAISE EXCEPTION 'generated investment must not be linked to a stored period (P6)';
        END IF;
    END LOOP;

    -- Gerar de novo não duplica (mesma operação e operação nova).
    SELECT pg_catalog.count(*) INTO n_before FROM public.investment_allocations a
    WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl;
    replay:=public.generate_due_recurrence_occurrences('95100000-0000-0000-0000-000000000004');
    SELECT pg_catalog.count(*) INTO n_after FROM public.investment_allocations a
    WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl;
    IF (replay->>'investment_created')::INTEGER<>0 OR n_after<>n_before THEN
        RAISE EXCEPTION 'repeated generation duplicated investments';
    END IF;
    replay:=public.generate_due_recurrence_occurrences('95100000-0000-0000-0000-000000000003');
    IF replay IS DISTINCT FROM (SELECT op.result_payload->'response' FROM public.applied_sync_operations op
        WHERE op.owner_id=v_owner_id AND op.idempotency_key='95100000-0000-0000-0000-000000000003') THEN
        RAISE EXCEPTION 'same operation id must return the stored response';
    END IF;

    -- Unicidade garantida pelo banco.
    SELECT * INTO v_alloc FROM public.investment_allocations a
    WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl ORDER BY a.scheduled_for_date LIMIT 1;
    SELECT * INTO v_other FROM public.investment_allocations a
    WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl AND a.id<>v_alloc.id ORDER BY a.scheduled_for_date LIMIT 1;

    -- Editar o valor de uma ocorrência não muda o modelo nem as outras (D8).
    result:=public.apply_investment_allocation_change('95100000-0000-0000-0000-000000000005','update',v_alloc.id,v_alloc.version,
        7777,v_alloc.allocated_on);
    IF result->>'status'<>'applied' OR (result#>>'{allocation,amount_centavos}')::BIGINT<>7777
        OR (result#>>'{allocation,version}')::BIGINT<>v_alloc.version+1
        OR (result#>>'{allocation,recurrence_template_id}')::UUID<>tpl THEN
        RAISE EXCEPTION 'occurrence value edit failed: %',result;
    END IF;
    IF (SELECT a.amount_centavos FROM public.investment_allocations a WHERE a.owner_id=v_owner_id AND a.id=v_other.id)<>5000 THEN
        RAISE EXCEPTION 'editing one occurrence changed another';
    END IF;
    SELECT * INTO v_template FROM public.investment_recurrence_templates t WHERE t.owner_id=v_owner_id AND t.id=tpl;
    IF v_template.default_amount_centavos<>5000 OR v_template.version<>1 THEN
        RAISE EXCEPTION 'editing an occurrence changed the template';
    END IF;

    -- Gerar de novo não desfaz a edição.
    PERFORM public.generate_due_recurrence_occurrences('95100000-0000-0000-0000-000000000006');
    IF (SELECT a.amount_centavos FROM public.investment_allocations a WHERE a.owner_id=v_owner_id AND a.id=v_alloc.id)<>7777 THEN
        RAISE EXCEPTION 'generation overwrote an edited occurrence';
    END IF;

    -- Ocorrência cancelada não renasce e sai da soma ativa.
    SELECT * INTO v_other FROM public.investment_allocations a WHERE a.owner_id=v_owner_id AND a.id=v_other.id;
    result:=public.apply_investment_allocation_change('95100000-0000-0000-0000-000000000007','cancel',v_other.id,v_other.version,NULL,NULL);
    IF result->>'status'<>'applied' THEN RAISE EXCEPTION 'occurrence cancel failed: %',result; END IF;
    PERFORM public.generate_due_recurrence_occurrences('95100000-0000-0000-0000-000000000008');
    SELECT pg_catalog.count(*) INTO n_after FROM public.investment_allocations a
    WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl;
    IF n_after<>n_before THEN RAISE EXCEPTION 'cancelled occurrence was recreated'; END IF;

    -- Mudar agenda e valor padrão vale só para as próximas ocorrências.
    SELECT pg_catalog.max(a.scheduled_for_date) INTO last_scheduled FROM public.investment_allocations a
    WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl;
    expected_floor:=(pg_catalog.date_trunc('month',last_scheduled)+INTERVAL '1 month')::DATE;
    result:=public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-000000000009','update',tpl,1,
        '{"monthly_reference_day":20,"default_amount_centavos":6000}'::JSONB);
    IF (result#>>'{template,starts_on}')::DATE<>expected_floor THEN
        RAISE EXCEPTION 'schedule change must start after the last generated month: %',result#>>'{template,starts_on}';
    END IF;
    PERFORM public.generate_due_recurrence_occurrences('95100000-0000-0000-0000-00000000000A');
    SELECT pg_catalog.count(*) INTO n_after FROM public.investment_allocations a
    WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl;
    IF n_after<>n_before THEN RAISE EXCEPTION 'schedule change created past or duplicate occurrences'; END IF;
    IF EXISTS(SELECT 1 FROM public.investment_allocations a WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl
        AND a.id<>v_alloc.id AND a.id<>v_other.id AND a.amount_centavos<>5000) THEN
        RAISE EXCEPTION 'template change rewrote existing occurrences';
    END IF;

    -- Parar de repetir: mantém as geradas e não gera mais.
    result:=public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-00000000000B','deactivate',tpl,2,NULL);
    IF result->>'status'<>'applied' OR (result#>>'{template,is_active}')::BOOLEAN THEN
        RAISE EXCEPTION 'deactivate failed: %',result;
    END IF;
    PERFORM public.generate_due_recurrence_occurrences('95100000-0000-0000-0000-00000000000C');
    SELECT pg_catalog.count(*) INTO n_after FROM public.investment_allocations a
    WHERE a.owner_id=v_owner_id AND a.recurrence_template_id=tpl;
    IF n_after<>n_before THEN RAISE EXCEPTION 'stopped recurrence changed the generated occurrences'; END IF;

    -- Valor sempre obrigatório (D8); valor variável e negativo recusados; início antes do 1º período recusado.
    BEGIN
        PERFORM public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-00000000000D','create',
            '95200000-0000-0000-0000-000000000003',0,
            pg_catalog.jsonb_build_object('frequency','monthly','monthly_reference_day',1,'starts_on',period_base));
        RAISE EXCEPTION 'template without amount was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-00000000000E','create',
            '95200000-0000-0000-0000-000000000003',0,
            pg_catalog.jsonb_build_object('frequency','monthly','monthly_reference_day',1,'starts_on',period_base,'value_mode','variable'));
        RAISE EXCEPTION 'variable value was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-00000000000F','create',
            '95200000-0000-0000-0000-000000000003',0,
            pg_catalog.jsonb_build_object('frequency','monthly','monthly_reference_day',1,'starts_on',period_base,'default_amount_centavos',-1));
        RAISE EXCEPTION 'negative amount was accepted';
    EXCEPTION WHEN invalid_parameter_value OR check_violation THEN NULL;
    END;
    -- P6: períodos são calculados; início em qualquer data é aceito.
    result:=public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-000000000010','create',
        '95200000-0000-0000-0000-000000000003',0,
        pg_catalog.jsonb_build_object('frequency','monthly','monthly_reference_day',1,'starts_on',(period_base-INTERVAL '2 months')::DATE,
            'default_amount_centavos',100));
    IF result->>'status'<>'applied' THEN RAISE EXCEPTION 'template before the old first period was refused: %',result; END IF;
    PERFORM public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-000000000031','deactivate',
        '95200000-0000-0000-0000-000000000003',1,NULL);
    -- P5: "por período" não existe mais.
    BEGIN
        PERFORM public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-000000000030','create',
            '95200000-0000-0000-0000-000000000009',0,
            pg_catalog.jsonb_build_object('frequency','by_period','starts_on',period_base,'default_amount_centavos',100));
        RAISE EXCEPTION 'by-period template was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Investimento novo vira a primeira ocorrência (mensal); reenvio idempotente.
    result:=public.create_investment_recurrence_from_entry('95100000-0000-0000-0000-000000000011',
        '95200000-0000-0000-0000-000000000004','95300000-0000-0000-0000-000000000001',0,
        pg_catalog.jsonb_build_object('frequency','monthly','starts_on',current_month+2,'monthly_reference_day',3,
            'default_amount_centavos',12000),
        pg_catalog.jsonb_build_object('date',current_month+2,'amount_centavos',12000));
    IF result->>'status'<>'applied' OR (result#>>'{allocation,amount_centavos}')::BIGINT<>12000
        OR (result#>>'{allocation,scheduled_for_date}')::DATE<>current_month+2
        OR (result#>>'{allocation,allocated_on}')::DATE<>current_month+2 THEN
        RAISE EXCEPTION 'new investment did not become the first occurrence: %',result;
    END IF;
    replay:=public.create_investment_recurrence_from_entry('95100000-0000-0000-0000-000000000011',
        '95200000-0000-0000-0000-000000000004','95300000-0000-0000-0000-000000000001',0,
        pg_catalog.jsonb_build_object('frequency','monthly','starts_on',current_month+2,'monthly_reference_day',3,
            'default_amount_centavos',12000),
        pg_catalog.jsonb_build_object('date',current_month+2,'amount_centavos',12000));
    IF replay IS DISTINCT FROM result THEN RAISE EXCEPTION 'conversion replay was not idempotent'; END IF;
    PERFORM public.generate_due_recurrence_occurrences('95100000-0000-0000-0000-000000000012');
    IF (SELECT pg_catalog.count(*) FROM public.investment_allocations a WHERE a.owner_id=v_owner_id
        AND a.recurrence_template_id='95200000-0000-0000-0000-000000000004' AND a.scheduled_for_date=current_month+2)<>1 THEN
        RAISE EXCEPTION 'generation duplicated the first occurrence';
    END IF;

    -- Investimento avulso vira a primeira ocorrência (mensal, na própria data).
    result:=public.apply_investment_allocation_change('95100000-0000-0000-0000-000000000013','create','95300000-0000-0000-0000-000000000002',0,
        4000,current_month+9);
    IF result->>'status'<>'applied' THEN RAISE EXCEPTION 'standalone create failed: %',result; END IF;
    result:=public.create_investment_recurrence_from_entry('95100000-0000-0000-0000-000000000014',
        '95200000-0000-0000-0000-000000000005','95300000-0000-0000-0000-000000000002',1,
        pg_catalog.jsonb_build_object('frequency','monthly','monthly_reference_day',10,'starts_on',current_month+9,
            'default_amount_centavos',4000),NULL);
    IF result->>'status'<>'applied' OR (result#>>'{allocation,scheduled_for_date}')::DATE<>current_month+9
        OR (result#>>'{allocation,allocated_on}')::DATE<>current_month+9 OR result#>>'{allocation,version}'<>'2'
        OR (result#>>'{allocation,scheduled_period_id}') IS NOT NULL THEN
        RAISE EXCEPTION 'standalone did not become the first monthly occurrence: %',result;
    END IF;
    PERFORM public.generate_due_recurrence_occurrences('95100000-0000-0000-0000-000000000015');
    IF (SELECT pg_catalog.count(*) FROM public.investment_allocations a WHERE a.owner_id=v_owner_id
        AND a.recurrence_template_id='95200000-0000-0000-0000-000000000005'
        AND a.scheduled_for_date>=current_month AND a.scheduled_for_date<(current_month+INTERVAL '1 month')::DATE)<>1 THEN
        RAISE EXCEPTION 'generation duplicated the converted occurrence';
    END IF;

    -- Versão antiga gera conflito, sem criar o modelo.
    result:=public.create_investment_recurrence_from_entry('95100000-0000-0000-0000-000000000016',
        '95200000-0000-0000-0000-000000000006','95300000-0000-0000-0000-000000000002',1,
        pg_catalog.jsonb_build_object('frequency','monthly','monthly_reference_day',10,'starts_on',current_month+9,'default_amount_centavos',1),NULL);
    IF result->>'status'<>'conflict' OR EXISTS(SELECT 1 FROM public.investment_recurrence_templates t
        WHERE t.owner_id=v_owner_id AND t.id='95200000-0000-0000-0000-000000000006') THEN
        RAISE EXCEPTION 'stale conversion must conflict without creating a template: %',result;
    END IF;

    -- Dia diferente do dia do investimento é recusado.
    BEGIN
        PERFORM public.create_investment_recurrence_from_entry('95100000-0000-0000-0000-000000000017',
            '95200000-0000-0000-0000-000000000007','95300000-0000-0000-0000-000000000003',0,
            pg_catalog.jsonb_build_object('frequency','monthly','starts_on',current_month+4,'monthly_reference_day',9,
                'default_amount_centavos',100),
            pg_catalog.jsonb_build_object('date',current_month+4,'amount_centavos',100));
        RAISE EXCEPTION 'reference day different from the entry day was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Conflito de edição de ocorrência resolvido com "editar" (valor e data).
    SELECT * INTO v_alloc FROM public.investment_allocations a WHERE a.owner_id=v_owner_id AND a.id='95300000-0000-0000-0000-000000000002';
    PERFORM public.apply_investment_allocation_change('95100000-0000-0000-0000-000000000018','update',v_alloc.id,v_alloc.version,4100,v_alloc.allocated_on);
    result:=public.apply_investment_allocation_change('95100000-0000-0000-0000-000000000019','update',v_alloc.id,v_alloc.version,4200,v_alloc.allocated_on);
    IF result->>'status'<>'conflict' THEN RAISE EXCEPTION 'stale occurrence edit must conflict: %',result; END IF;
    conflict_id:=(result->>'conflict_id')::UUID;
    result:=public.resolve_sync_conflict('95100000-0000-0000-0000-00000000001A',conflict_id,'edit',
        pg_catalog.jsonb_build_object('action','update','amount_centavos',4300,'allocated_on',v_alloc.allocated_on));
    IF result->>'status'<>'resolved' OR (result#>>'{result,allocation,amount_centavos}')::BIGINT<>4300 THEN
        RAISE EXCEPTION 'investment conflict was not resolved: %',result;
    END IF;

    -- Conflito do modelo resolvido pelo servidor (keep_remote) e pelo aparelho (edit).
    SELECT * INTO v_template FROM public.investment_recurrence_templates t WHERE t.owner_id=v_owner_id AND t.id='95200000-0000-0000-0000-000000000005';
    PERFORM public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-00000000001B','update',v_template.id,v_template.version,
        '{"default_amount_centavos":4500}'::JSONB);
    result:=public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-00000000001C','update',v_template.id,v_template.version,
        '{"default_amount_centavos":4600}'::JSONB);
    IF result->>'status'<>'conflict' THEN RAISE EXCEPTION 'stale template edit must conflict: %',result; END IF;
    conflict_id:=(result->>'conflict_id')::UUID;
    result:=public.resolve_sync_conflict('95100000-0000-0000-0000-00000000001D',conflict_id,'edit',
        pg_catalog.jsonb_build_object('action','update','payload','{"default_amount_centavos":4700}'::JSONB));
    IF result->>'status'<>'resolved'
        OR (SELECT t.default_amount_centavos FROM public.investment_recurrence_templates t
            WHERE t.owner_id=v_owner_id AND t.id=v_template.id)<>4700 THEN
        RAISE EXCEPTION 'template conflict was not resolved: %',result;
    END IF;

    -- Auditoria de criação das ocorrências geradas.
    IF NOT EXISTS(SELECT 1 FROM public.audit_events e WHERE e.owner_id=v_owner_id AND e.entity_type='investment_allocation'
        AND e.entity_id=v_alloc.id) THEN
        RAISE EXCEPTION 'investment audit missing';
    END IF;

    -- Isolamento: outro usuário não vê nem converte.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000002',TRUE);
    IF (SELECT pg_catalog.count(*) FROM public.investment_recurrence_templates)<>0
        OR (SELECT pg_catalog.count(*) FROM public.investment_allocations)<>0 THEN
        RAISE EXCEPTION 'another user can read investment recurrence data';
    END IF;
    BEGIN
        PERFORM public.create_investment_recurrence_from_entry('95100000-0000-0000-0000-00000000001E',
            '95200000-0000-0000-0000-000000000008','95300000-0000-0000-0000-000000000002',1,
            pg_catalog.jsonb_build_object('frequency','monthly','monthly_reference_day',10,'starts_on',current_month+9,'default_amount_centavos',1),NULL);
        RAISE EXCEPTION 'another user converted this investment';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
    BEGIN
        PERFORM public.apply_investment_recurrence_template_change('95100000-0000-0000-0000-00000000001F','deactivate',
            '95200000-0000-0000-0000-000000000005',1,NULL);
        RAISE EXCEPTION 'another user changed this template';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
END;
$test$;
\echo PASS: investment recurrence templates, deterministic generation, edits per occurrence, conversion, conflicts and isolation.
ROLLBACK;
