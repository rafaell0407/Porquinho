\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users(id) VALUES
    ('71000000-0000-0000-0000-000000000001'),
    ('71000000-0000-0000-0000-000000000002');
SELECT pg_catalog.set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',TRUE);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE
    income JSONB;
    expense JSONB;
    replay JSONB;
    conflict_response JSONB;
    audit_count BIGINT;
BEGIN
    IF NOT pg_catalog.has_function_privilege('authenticated','public.apply_income_entry_change(uuid,text,uuid,bigint,jsonb)','EXECUTE')
        OR NOT pg_catalog.has_function_privilege('authenticated','public.apply_expense_entry_change(uuid,text,uuid,bigint,jsonb)','EXECUTE')
        OR pg_catalog.has_function_privilege('anon','public.apply_income_entry_change(uuid,text,uuid,bigint,jsonb)','EXECUTE')
        OR pg_catalog.has_function_privilege('anon','public.apply_expense_entry_change(uuid,text,uuid,bigint,jsonb)','EXECUTE') THEN
        RAISE EXCEPTION 'cash-entry RPC grants are incorrect';
    END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_proc f WHERE f.oid IN (
        'public.apply_income_entry_change(uuid,text,uuid,bigint,jsonb)'::REGPROCEDURE,
        'public.apply_expense_entry_change(uuid,text,uuid,bigint,jsonb)'::REGPROCEDURE)
        AND f.prosecdef AND f.proowner='postgres'::REGROLE AND f.proconfig @> ARRAY['search_path=""']) <> 2 THEN
        RAISE EXCEPTION 'cash-entry functions must use reviewed SECURITY DEFINER settings';
    END IF;

    PERFORM public.apply_category_change('75000000-0000-0000-0000-000000000001','create',
        '76000000-0000-0000-0000-000000000001',0,'income','Renda');
    PERFORM public.apply_category_change('75000000-0000-0000-0000-000000000002','create',
        '76000000-0000-0000-0000-000000000002',0,'expense','Moradia');

    income:=public.apply_income_entry_change('77000000-0000-0000-0000-000000000001','create',
        '78000000-0000-0000-0000-000000000001',0,
        '{"amount_centavos":12345,"received_on":"2026-11-30","category_id":"76000000-0000-0000-0000-000000000001"}'::JSONB);
    IF income->>'status'<>'applied' OR income#>>'{entry,status}'<>'received'
        OR income#>>'{entry,accounting_period_id}' IS NOT NULL THEN
        RAISE EXCEPTION 'income creation or period assignment failed: %',income;
    END IF;
    replay:=public.apply_income_entry_change('77000000-0000-0000-0000-000000000001','create',
        '78000000-0000-0000-0000-000000000001',0,
        '{"amount_centavos":12345,"received_on":"2026-11-30","category_id":"76000000-0000-0000-0000-000000000001"}'::JSONB);
    IF replay IS DISTINCT FROM income THEN RAISE EXCEPTION 'income create replay was not idempotent'; END IF;

    income:=public.apply_income_entry_change('77000000-0000-0000-0000-000000000002','update',
        '78000000-0000-0000-0000-000000000001',1,'{"received_on":"2026-12-01"}'::JSONB);
    IF income#>>'{entry,accounting_period_id}' IS NOT NULL
        OR income#>>'{entry,version}'<>'2' THEN RAISE EXCEPTION 'income date edit did not move period: %',income; END IF;
    conflict_response:=public.apply_income_entry_change('77000000-0000-0000-0000-000000000003','update',
        '78000000-0000-0000-0000-000000000001',1,'{"amount_centavos":999}'::JSONB);
    IF conflict_response->>'status'<>'conflict' THEN RAISE EXCEPTION 'stale income edit did not conflict'; END IF;
    PERFORM public.apply_income_entry_change('77000000-0000-0000-0000-000000000004','cancel',
        '78000000-0000-0000-0000-000000000001',2,NULL);

    expense:=public.apply_expense_entry_change('79000000-0000-0000-0000-000000000001','create',
        '7a000000-0000-0000-0000-000000000001',0,
        '{"amount_centavos":5000,"competence_on":"2026-11-30","due_on":"2026-12-03","category_id":"76000000-0000-0000-0000-000000000002"}'::JSONB);
    IF expense#>>'{entry,status}'<>'pending'
        OR expense#>>'{entry,accounting_period_id}' IS NOT NULL THEN
        RAISE EXCEPTION 'expense creation or competence assignment failed: %',expense;
    END IF;
    expense:=public.apply_expense_entry_change('79000000-0000-0000-0000-000000000002','pay',
        '7a000000-0000-0000-0000-000000000001',1,'{"paid_on":"2026-12-03"}'::JSONB);
    IF expense#>>'{entry,status}'<>'paid' OR expense#>>'{entry,paid_on}'<>'2026-12-03'
        OR expense#>>'{entry,accounting_period_id}' IS NOT NULL THEN
        RAISE EXCEPTION 'expense payment changed status/date or accounting period incorrectly: %',expense;
    END IF;
    expense:=public.apply_expense_entry_change('79000000-0000-0000-0000-000000000003','update',
        '7a000000-0000-0000-0000-000000000001',2,'{"amount_centavos":0}'::JSONB);
    IF expense#>>'{entry,status}'<>'paid' OR expense#>>'{entry,amount_centavos}'<>'0' THEN
        RAISE EXCEPTION 'editing paid expense should preserve paid status and allow zero: %',expense;
    END IF;
    expense:=public.apply_expense_entry_change('79000000-0000-0000-0000-000000000004','cancel',
        '7a000000-0000-0000-0000-000000000001',3,NULL);
    IF expense#>>'{entry,status}'<>'cancelled' THEN RAISE EXCEPTION 'expense cancel failed'; END IF;

    SELECT pg_catalog.count(*) INTO audit_count FROM public.audit_events e WHERE e.owner_id=auth.uid()
        AND e.entity_id IN ('78000000-0000-0000-0000-000000000001','7a000000-0000-0000-0000-000000000001');
    IF audit_count<>7 THEN RAISE EXCEPTION 'expected seven audit events, got %',audit_count; END IF;

    PERFORM pg_catalog.set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',TRUE);
    BEGIN
        PERFORM public.apply_expense_entry_change('79000000-0000-0000-0000-000000000005','update',
            '7a000000-0000-0000-0000-000000000001',4,'{"amount_centavos":12}'::JSONB);
        RAISE EXCEPTION 'other user changed an expense';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
END;
$test$;
\echo PASS: one-time income and expense RPCs, period assignment, payment, audit and isolation.
ROLLBACK;
