\set ON_ERROR_STOP on
BEGIN;
DO $fixtures$
DECLARE
    v_owner_id UUID := '92000000-0000-0000-0000-000000000001';
    zone_today DATE := pg_catalog.timezone('America/Sao_Paulo',pg_catalog.clock_timestamp())::DATE;
    current_month DATE := pg_catalog.date_trunc('month',pg_catalog.timezone('America/Sao_Paulo',pg_catalog.clock_timestamp()))::DATE;
    period_base DATE := (current_month - INTERVAL '3 months')::DATE;
    month_start DATE := (current_month - INTERVAL '2 months')::DATE;
    start_date DATE := (month_start + 9)::DATE;
    config_id UUID := '92000000-0000-0000-0000-000000000010';
BEGIN
    INSERT INTO auth.users(id) VALUES(v_owner_id),('92000000-0000-0000-0000-000000000002');
    INSERT INTO public.user_preferences(owner_id,time_zone_id) VALUES(v_owner_id,'America/Sao_Paulo');
    INSERT INTO public.period_configurations(owner_id,id,mode,custom_start_day,effective_from)
    VALUES(v_owner_id,config_id,'calendar_month',NULL,period_base);
    INSERT INTO public.accounting_periods(owner_id,id,configuration_id,start_date,end_date)
    SELECT v_owner_id,('92000000-0000-0000-0000-'||pg_catalog.lpad((100+n)::TEXT,12,'0'))::UUID,config_id,
        (period_base+(n||' months')::INTERVAL)::DATE,
        (period_base+((n+1)||' months')::INTERVAL)::DATE
    FROM pg_catalog.generate_series(0,3) AS gs(n);

    INSERT INTO public.income_recurrence_templates(owner_id,id,description,frequency,starts_on,monthly_reference_day,
        value_mode,default_amount_centavos)
    VALUES
        (v_owner_id,'92000000-0000-0000-0000-000000000101','Monthly fixed','monthly',start_date,31,'fixed',5000),
        (v_owner_id,'92000000-0000-0000-0000-000000000102','By-period variable','by_period',(period_base+2*INTERVAL '1 month'+INTERVAL '14 days')::DATE,NULL,'variable',NULL),
        (v_owner_id,'92000000-0000-0000-0000-000000000103','Month end clamp','monthly','2026-01-01',31,'fixed',2500),
        (v_owner_id,'92000000-0000-0000-0000-000000000104','Inactive','monthly',start_date,31,'fixed',1000);
    UPDATE public.income_recurrence_templates AS t SET is_active=FALSE
    WHERE t.owner_id=v_owner_id AND t.id='92000000-0000-0000-0000-000000000104';

    INSERT INTO public.expense_recurrence_templates(owner_id,id,description,frequency,starts_on,monthly_reference_day,
        value_mode,default_amount_centavos)
    VALUES
        (v_owner_id,'92000000-0000-0000-0000-000000000201','Monthly fixed expense','monthly',start_date,31,'fixed',12000),
        (v_owner_id,'92000000-0000-0000-0000-000000000202','By-period variable expense','by_period',(period_base+2*INTERVAL '1 month'+INTERVAL '14 days')::DATE,NULL,'variable',NULL);
END;
$fixtures$;

SELECT pg_catalog.set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',TRUE);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE
    v_owner_id UUID := auth.uid();
    today DATE := pg_catalog.timezone('America/Sao_Paulo',pg_catalog.clock_timestamp())::DATE;
    current_month DATE := pg_catalog.date_trunc('month',pg_catalog.timezone('America/Sao_Paulo',pg_catalog.clock_timestamp()))::DATE;
    period_base DATE := (current_month-INTERVAL '3 months')::DATE;
    month_start DATE := (current_month-INTERVAL '2 months')::DATE;
    start_date DATE := (month_start+9)::DATE;
    first_candidate DATE;
    next_candidate DATE;
    income_occurrence public.income_entries%ROWTYPE;
    expense_occurrence public.expense_entries%ROWTYPE;
    result JSONB;
    replay JSONB;
    conflict_result JSONB;
    version_before BIGINT;
    audit_count BIGINT;
    current_period UUID;
BEGIN
    IF NOT pg_catalog.has_function_privilege('authenticated','public.generate_due_recurrence_occurrences(uuid)','EXECUTE')
        OR pg_catalog.has_function_privilege('anon','public.generate_due_recurrence_occurrences(uuid)','EXECUTE')
        OR NOT pg_catalog.has_function_privilege('authenticated','public.apply_income_recurrence_occurrence_change(uuid,text,uuid,bigint,jsonb)','EXECUTE')
        OR pg_catalog.has_function_privilege('anon','public.apply_income_recurrence_occurrence_change(uuid,text,uuid,bigint,jsonb)','EXECUTE')
        OR NOT pg_catalog.has_function_privilege('authenticated','public.apply_expense_recurrence_occurrence_change(uuid,text,uuid,bigint,jsonb)','EXECUTE')
        OR pg_catalog.has_function_privilege('anon','public.apply_expense_recurrence_occurrence_change(uuid,text,uuid,bigint,jsonb)','EXECUTE') THEN
        RAISE EXCEPTION 'recurrence occurrence RPC grants are incorrect';
    END IF;
    IF (SELECT pg_catalog.count(*) FROM pg_catalog.pg_proc f WHERE f.oid IN (
        'public.generate_due_recurrence_occurrences(uuid)'::REGPROCEDURE,
        'public.apply_income_recurrence_occurrence_change(uuid,text,uuid,bigint,jsonb)'::REGPROCEDURE,
        'public.apply_expense_recurrence_occurrence_change(uuid,text,uuid,bigint,jsonb)'::REGPROCEDURE)
        AND f.prosecdef AND f.proowner='postgres'::REGROLE AND f.proconfig@>ARRAY['search_path=""'])<>3 THEN
        RAISE EXCEPTION 'occurrence RPCs must use reviewed SECURITY DEFINER settings';
    END IF;

    SELECT (month_start+LEAST(31,EXTRACT(day FROM (month_start+INTERVAL '1 month'-INTERVAL '1 day'))::INTEGER)-1)::DATE
    INTO first_candidate;
    IF first_candidate<start_date THEN
        month_start:=(month_start+INTERVAL '1 month')::DATE;
        first_candidate:=(month_start+LEAST(31,EXTRACT(day FROM (month_start+INTERVAL '1 month'-INTERVAL '1 day'))::INTEGER)-1)::DATE;
    END IF;
    next_candidate:=(pg_catalog.date_trunc('month',first_candidate)+INTERVAL '1 month')::DATE;
    next_candidate:=(next_candidate+LEAST(31,EXTRACT(day FROM (next_candidate+INTERVAL '1 month'-INTERVAL '1 day'))::INTEGER)-1)::DATE;

    result:=public.generate_due_recurrence_occurrences('93000000-0000-0000-0000-000000000001');
    IF result->>'status'<>'applied' OR (result->>'income_created')::INTEGER<3 OR (result->>'expense_created')::INTEGER<2 THEN
        RAISE EXCEPTION 'generation did not catch up due monthly and per-period occurrences: %',result;
    END IF;
    IF NOT EXISTS(SELECT 1 FROM public.income_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='92000000-0000-0000-0000-000000000101' AND e.scheduled_for_date=first_candidate
        AND e.amount_centavos=5000 AND e.status='pending' AND e.accounting_period_id IS NULL) THEN
        RAISE EXCEPTION 'monthly occurrence did not start on the reference day at or after its start date';
    END IF;
    IF first_candidate<=today AND NOT EXISTS(SELECT 1 FROM public.expense_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='92000000-0000-0000-0000-000000000201' AND e.scheduled_for_date=first_candidate
        AND e.competence_on=first_candidate AND e.amount_centavos=12000 AND e.status='pending') THEN
        RAISE EXCEPTION 'monthly expense was not assigned to its scheduled competence';
    END IF;
    IF today>='2026-02-28' AND NOT EXISTS(SELECT 1 FROM public.income_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='92000000-0000-0000-0000-000000000103' AND e.scheduled_for_date='2026-02-28') THEN
        RAISE EXCEPTION 'monthly recurrence did not clamp day 31 to February end';
    END IF;
    IF today>='2026-03-31' AND NOT EXISTS(SELECT 1 FROM public.income_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='92000000-0000-0000-0000-000000000103' AND e.scheduled_for_date='2026-03-31') THEN
        RAISE EXCEPTION 'monthly recurrence did not restore day 31 after February';
    END IF;
    IF EXISTS(SELECT 1 FROM public.income_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='92000000-0000-0000-0000-000000000104') THEN
        RAISE EXCEPTION 'inactive recurrence generated a new occurrence';
    END IF;

    SELECT * INTO income_occurrence FROM public.income_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='92000000-0000-0000-0000-000000000102'
        AND e.scheduled_for_date=(SELECT p.start_date FROM public.accounting_periods p WHERE p.owner_id=v_owner_id
            AND p.end_date>(period_base+2*INTERVAL '1 month'+INTERVAL '14 days')::DATE ORDER BY p.start_date LIMIT 1)
        ORDER BY e.scheduled_for_date LIMIT 1;
    IF NOT FOUND OR income_occurrence.scheduled_for_date>=(period_base+2*INTERVAL '1 month'+INTERVAL '14 days')::DATE
        OR income_occurrence.scheduled_period_id IS NULL OR income_occurrence.amount_centavos IS NOT NULL THEN
        RAISE EXCEPTION 'by-period occurrence did not start in the period containing its configured start';
    END IF;
    SELECT * INTO expense_occurrence FROM public.expense_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='92000000-0000-0000-0000-000000000202'
        ORDER BY e.scheduled_for_date LIMIT 1;
    IF NOT FOUND OR expense_occurrence.scheduled_for_date>=(period_base+2*INTERVAL '1 month'+INTERVAL '14 days')::DATE
        OR expense_occurrence.scheduled_period_id IS NULL OR expense_occurrence.amount_centavos IS NOT NULL THEN
        RAISE EXCEPTION 'variable by-period expense occurrence was not created unpriced at its period start';
    END IF;

    replay:=public.generate_due_recurrence_occurrences('93000000-0000-0000-0000-000000000001');
    IF replay IS DISTINCT FROM result THEN RAISE EXCEPTION 'generation operation replay changed its result'; END IF;
    replay:=public.generate_due_recurrence_occurrences('93000000-0000-0000-0000-000000000002');
    IF (replay->>'income_created')::INTEGER<>0 OR (replay->>'expense_created')::INTEGER<>0 THEN
        RAISE EXCEPTION 'a second generation call duplicated scheduled occurrences: %',replay;
    END IF;

    SELECT * INTO income_occurrence FROM public.income_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id='92000000-0000-0000-0000-000000000101' AND e.scheduled_for_date=first_candidate;
    result:=public.apply_income_recurrence_occurrence_change('93000000-0000-0000-0000-000000000003','update',income_occurrence.id,
        income_occurrence.version,'{"amount_centavos":6000}'::JSONB);
    IF result->>'status'<>'applied' OR result#>>'{entry,version}'<>'2'
        OR (SELECT t.default_amount_centavos FROM public.income_recurrence_templates t WHERE t.owner_id=v_owner_id AND t.id=income_occurrence.recurrence_template_id)<>5000 THEN
        RAISE EXCEPTION 'individual income occurrence edit changed its model or failed versioning';
    END IF;
    current_period:=NULL;
    SELECT p.id INTO current_period FROM public.accounting_periods p WHERE p.owner_id=v_owner_id
        AND p.start_date<=today AND today<p.end_date;
    result:=public.apply_income_recurrence_occurrence_change('93000000-0000-0000-0000-000000000004','receive',income_occurrence.id,2,
        pg_catalog.jsonb_build_object('received_on',today,'amount_centavos',6000));
    IF result->>'status'<>'applied' OR result#>>'{entry,status}'<>'received'
        OR (result#>>'{entry,accounting_period_id}')::UUID IS DISTINCT FROM current_period THEN
        RAISE EXCEPTION 'income receipt did not assign the period from its effective receipt date';
    END IF;
    replay:=public.apply_income_recurrence_occurrence_change('93000000-0000-0000-0000-000000000004','receive',income_occurrence.id,2,
        pg_catalog.jsonb_build_object('received_on',today,'amount_centavos',6000));
    IF replay IS DISTINCT FROM result THEN RAISE EXCEPTION 'income receipt replay was not idempotent'; END IF;
    conflict_result:=public.apply_income_recurrence_occurrence_change('93000000-0000-0000-0000-000000000005','update',income_occurrence.id,1,
        '{"amount_centavos":7000}'::JSONB);
    IF conflict_result->>'status'<>'conflict' THEN RAISE EXCEPTION 'stale income occurrence edit did not create a conflict'; END IF;

    result:=public.apply_expense_recurrence_occurrence_change('93000000-0000-0000-0000-000000000006','update',expense_occurrence.id,
        expense_occurrence.version,'{"description":"Variable, still unpriced"}'::JSONB);
    IF result->>'status'<>'applied' OR result#>>'{entry,amount_centavos}' IS NOT NULL OR result#>>'{entry,version}'<>'2' THEN
        RAISE EXCEPTION 'variable pending expense could not be edited before its value was known';
    END IF;
    result:=public.apply_expense_recurrence_occurrence_change('93000000-0000-0000-0000-000000000007','update',expense_occurrence.id,
        2,'{"amount_centavos":3500}'::JSONB);
    IF result->>'status'<>'applied' OR result#>>'{entry,amount_centavos}'<>'3500'
        OR (result#>>'{entry,accounting_period_id}')::UUID IS DISTINCT FROM expense_occurrence.accounting_period_id THEN
        RAISE EXCEPTION 'variable expense value edit did not preserve its accounting period';
    END IF;
    result:=public.apply_expense_recurrence_occurrence_change('93000000-0000-0000-0000-000000000008','pay',expense_occurrence.id,3,
        pg_catalog.jsonb_build_object('paid_on',today));
    IF result->>'status'<>'applied' OR result#>>'{entry,status}'<>'paid'
        OR (result#>>'{entry,accounting_period_id}')::UUID IS DISTINCT FROM expense_occurrence.accounting_period_id THEN
        RAISE EXCEPTION 'expense payment changed competence or failed';
    END IF;
    result:=public.apply_expense_recurrence_occurrence_change('93000000-0000-0000-0000-00000000000A','cancel',expense_occurrence.id,4,NULL);
    IF result#>>'{entry,status}'<>'cancelled' OR (SELECT pg_catalog.count(*) FROM public.expense_entries e WHERE e.owner_id=v_owner_id
        AND e.recurrence_template_id=expense_occurrence.recurrence_template_id AND e.scheduled_for_date=expense_occurrence.scheduled_for_date)<>1 THEN
        RAISE EXCEPTION 'cancelling an occurrence removed or duplicated its historical row';
    END IF;

    SELECT pg_catalog.count(*) INTO audit_count FROM public.audit_events a WHERE a.owner_id=v_owner_id
        AND a.operation_id IN ('93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000003',
            '93000000-0000-0000-0000-000000000004','93000000-0000-0000-0000-000000000006',
            '93000000-0000-0000-0000-000000000007','93000000-0000-0000-0000-000000000008',
            '93000000-0000-0000-0000-00000000000A');
    IF audit_count < 8 THEN RAISE EXCEPTION 'occurrence generation and changes were not fully audited'; END IF;

    PERFORM pg_catalog.set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',TRUE);
    BEGIN
        PERFORM public.apply_income_recurrence_occurrence_change('93000000-0000-0000-0000-00000000000B','update',income_occurrence.id,3,
            '{"amount_centavos":8000}'::JSONB);
        RAISE EXCEPTION 'another user changed this recurring occurrence';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
END;
$test$;
\echo PASS: recurrence generation, monthly calendar, backfill, occurrence lifecycle, audit, idempotency and isolation.
ROLLBACK;
