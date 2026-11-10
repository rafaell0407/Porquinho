\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users(id) VALUES
    ('81000000-0000-0000-0000-000000000001'),
    ('81000000-0000-0000-0000-000000000002');
SELECT pg_catalog.set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000001',TRUE);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE
    income JSONB;
    expense JSONB;
    replay JSONB;
    conflict_response JSONB;
    audit_count BIGINT;
BEGIN
    IF NOT pg_catalog.has_function_privilege('authenticated','public.apply_income_recurrence_template_change(uuid,text,uuid,bigint,jsonb)','EXECUTE')
        OR NOT pg_catalog.has_function_privilege('authenticated','public.apply_expense_recurrence_template_change(uuid,text,uuid,bigint,jsonb)','EXECUTE')
        OR pg_catalog.has_function_privilege('anon','public.apply_income_recurrence_template_change(uuid,text,uuid,bigint,jsonb)','EXECUTE')
        OR pg_catalog.has_function_privilege('anon','public.apply_expense_recurrence_template_change(uuid,text,uuid,bigint,jsonb)','EXECUTE') THEN
        RAISE EXCEPTION 'recurrence-template RPC grants are incorrect';
    END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_proc f WHERE f.oid IN (
        'public.apply_income_recurrence_template_change(uuid,text,uuid,bigint,jsonb)'::REGPROCEDURE,
        'public.apply_expense_recurrence_template_change(uuid,text,uuid,bigint,jsonb)'::REGPROCEDURE)
        AND f.prosecdef AND f.proowner='postgres'::REGROLE AND f.proconfig @> ARRAY['search_path=""']) <> 2 THEN
        RAISE EXCEPTION 'recurrence-template functions must use reviewed SECURITY DEFINER settings';
    END IF;
    PERFORM public.apply_category_change('82000000-0000-0000-0000-000000000001','create',
        '83000000-0000-0000-0000-000000000001',0,'income','Salário');
    PERFORM public.apply_category_change('82000000-0000-0000-0000-000000000002','create',
        '83000000-0000-0000-0000-000000000002',0,'expense','Moradia');

    income:=public.apply_income_recurrence_template_change('84000000-0000-0000-0000-000000000001','create',
        '85000000-0000-0000-0000-000000000001',0,
        '{"description":"Salário","frequency":"monthly","starts_on":"2026-11-30","monthly_reference_day":31,"value_mode":"fixed","default_amount_centavos":500000,"category_id":"83000000-0000-0000-0000-000000000001"}'::JSONB);
    IF income->>'status'<>'applied' OR income#>>'{template,monthly_reference_day}'<>'31'
        OR income#>>'{template,is_active}'<>'true' THEN RAISE EXCEPTION 'income recurrence template create failed: %',income; END IF;
    replay:=public.apply_income_recurrence_template_change('84000000-0000-0000-0000-000000000001','create',
        '85000000-0000-0000-0000-000000000001',0,
        '{"description":"Salário","frequency":"monthly","starts_on":"2026-11-30","monthly_reference_day":31,"value_mode":"fixed","default_amount_centavos":500000,"category_id":"83000000-0000-0000-0000-000000000001"}'::JSONB);
    IF replay IS DISTINCT FROM income THEN RAISE EXCEPTION 'income-template replay was not idempotent'; END IF;
    income:=public.apply_income_recurrence_template_change('84000000-0000-0000-0000-000000000002','update',
        '85000000-0000-0000-0000-000000000001',1,
        '{"frequency":"by_period","monthly_reference_day":null,"value_mode":"variable","default_amount_centavos":null}'::JSONB);
    IF income#>>'{template,frequency}'<>'by_period' OR income#>>'{template,monthly_reference_day}' IS NOT NULL
        OR income#>>'{template,default_amount_centavos}' IS NOT NULL OR income#>>'{template,version}'<>'2' THEN
        RAISE EXCEPTION 'income recurrence template update failed: %',income;
    END IF;
    conflict_response:=public.apply_income_recurrence_template_change('84000000-0000-0000-0000-000000000003','update',
        '85000000-0000-0000-0000-000000000001',1,'{"description":"stale"}'::JSONB);
    IF conflict_response->>'status'<>'conflict' THEN RAISE EXCEPTION 'stale income-template update did not conflict'; END IF;
    income:=public.apply_income_recurrence_template_change('84000000-0000-0000-0000-000000000004','deactivate',
        '85000000-0000-0000-0000-000000000001',2,NULL);
    IF income#>>'{template,is_active}'<>'false' THEN RAISE EXCEPTION 'income recurrence deactivation failed'; END IF;

    expense:=public.apply_expense_recurrence_template_change('86000000-0000-0000-0000-000000000001','create',
        '87000000-0000-0000-0000-000000000001',0,
        '{"description":"Condomínio","frequency":"by_period","starts_on":"2026-11-01","value_mode":"variable","category_id":"83000000-0000-0000-0000-000000000002"}'::JSONB);
    IF expense->>'status'<>'applied' OR expense#>>'{template,default_amount_centavos}' IS NOT NULL
        OR expense#>>'{template,frequency}'<>'by_period' THEN RAISE EXCEPTION 'expense recurrence template create failed: %',expense; END IF;
    BEGIN
        PERFORM public.apply_expense_recurrence_template_change('86000000-0000-0000-0000-000000000002','update',
            '87000000-0000-0000-0000-000000000001',1,'{"value_mode":"fixed"}'::JSONB);
        RAISE EXCEPTION 'fixed-value template accepted a missing default amount';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    expense:=public.apply_expense_recurrence_template_change('86000000-0000-0000-0000-000000000003','deactivate',
        '87000000-0000-0000-0000-000000000001',1,NULL);
    IF expense#>>'{template,is_active}'<>'false' THEN RAISE EXCEPTION 'expense recurrence deactivation failed'; END IF;

    SELECT pg_catalog.count(*) INTO audit_count FROM public.audit_events e WHERE e.owner_id=auth.uid()
        AND e.entity_id IN ('85000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-000000000001');
    IF audit_count<>5 THEN RAISE EXCEPTION 'expected five template audit events, got %',audit_count; END IF;
    PERFORM pg_catalog.set_config('request.jwt.claim.sub','81000000-0000-0000-0000-000000000002',TRUE);
    BEGIN
        PERFORM public.apply_income_recurrence_template_change('84000000-0000-0000-0000-000000000005','update',
            '85000000-0000-0000-0000-000000000001',3,'{"description":"other owner"}'::JSONB);
        RAISE EXCEPTION 'other user changed an income recurrence template';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
END;
$test$;
\echo PASS: recurrence-template RPCs validate schedules, values, lifecycle, audit and isolation.
ROLLBACK;
