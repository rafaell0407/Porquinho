\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users(id) VALUES
    ('61000000-0000-0000-0000-000000000001'),
    ('61000000-0000-0000-0000-000000000002');
SELECT pg_catalog.set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000001', TRUE);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE
    response JSONB;
    replay JSONB;
    conflict_response JSONB;
    row_now public.investment_allocations%ROWTYPE;
    audit_count BIGINT;
BEGIN
    IF NOT pg_catalog.has_function_privilege('authenticated',
        'public.apply_investment_allocation_change(uuid,text,uuid,bigint,bigint,date)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('anon',
        'public.apply_investment_allocation_change(uuid,text,uuid,bigint,bigint,date)', 'EXECUTE') THEN
        RAISE EXCEPTION 'investment RPC grants are incorrect';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc AS f
        WHERE f.oid = 'public.apply_investment_allocation_change(uuid,text,uuid,bigint,bigint,date)'::REGPROCEDURE
          AND f.prosecdef AND f.proowner = 'postgres'::REGROLE
          AND f.proconfig @> ARRAY['search_path=""']) THEN
        RAISE EXCEPTION 'investment RPC security configuration is incorrect';
    END IF;

    PERFORM public.create_accounting_period(
        '62000000-0000-0000-0000-000000000001',
        '63000000-0000-0000-0000-000000000001',
        '64000000-0000-0000-0000-000000000001',
        '2026-11-01', 'calendar_month', NULL);

    response := public.apply_investment_allocation_change(
        '65000000-0000-0000-0000-000000000001', 'create',
        '66000000-0000-0000-0000-000000000001', 0,
        9007199254740993, '2026-11-09');
    IF response ->> 'status' <> 'applied'
        OR response #>> '{allocation,amount_centavos}' <> '9007199254740993'
        OR response #>> '{allocation,accounting_period_id}' <> '63000000-0000-0000-0000-000000000001' THEN
        RAISE EXCEPTION 'investment create failed exact amount or period assignment: %', response;
    END IF;
    replay := public.apply_investment_allocation_change(
        '65000000-0000-0000-0000-000000000001', 'create',
        '66000000-0000-0000-0000-000000000001', 0,
        9007199254740993, '2026-11-09');
    IF replay IS DISTINCT FROM response THEN RAISE EXCEPTION 'retry was not idempotent'; END IF;

    response := public.apply_investment_allocation_change(
        '65000000-0000-0000-0000-000000000002', 'update',
        '66000000-0000-0000-0000-000000000001', 1, 0, '2026-11-10');
    IF response #>> '{allocation,amount_centavos}' <> '0'
        OR response #>> '{allocation,version}' <> '2' THEN
        RAISE EXCEPTION 'investment update failed: %', response;
    END IF;

    conflict_response := public.apply_investment_allocation_change(
        '65000000-0000-0000-0000-000000000003', 'update',
        '66000000-0000-0000-0000-000000000001', 1, 10, '2026-11-11');
    IF conflict_response ->> 'status' <> 'conflict'
        OR NOT EXISTS (SELECT 1 FROM public.sync_conflicts c
            WHERE c.owner_id = auth.uid() AND c.id = (conflict_response ->> 'conflict_id')::UUID) THEN
        RAISE EXCEPTION 'stale update did not preserve a conflict: %', conflict_response;
    END IF;

    response := public.apply_investment_allocation_change(
        '65000000-0000-0000-0000-000000000004', 'cancel',
        '66000000-0000-0000-0000-000000000001', 2, NULL, NULL);
    IF response #>> '{allocation,cancelled_at}' IS NULL
        OR response #>> '{allocation,version}' <> '3' THEN
        RAISE EXCEPTION 'investment cancellation failed: %', response;
    END IF;
    SELECT allocation.* INTO row_now FROM public.investment_allocations allocation
    WHERE allocation.owner_id = auth.uid() AND allocation.id = '66000000-0000-0000-0000-000000000001';
    IF row_now.amount_centavos <> 0 THEN RAISE EXCEPTION 'unexpected allocation amount'; END IF;
    SELECT pg_catalog.count(*) INTO audit_count FROM public.audit_events event
    WHERE event.owner_id = auth.uid() AND event.entity_id = row_now.id;
    IF audit_count <> 3 THEN RAISE EXCEPTION 'expected create, update and cancel audit events'; END IF;

    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000002', TRUE);
    BEGIN
        PERFORM public.apply_investment_allocation_change(
            '65000000-0000-0000-0000-000000000005', 'update',
            '66000000-0000-0000-0000-000000000001', 3, 99, '2026-11-12');
        RAISE EXCEPTION 'another user must not be able to change this allocation';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
    IF EXISTS (SELECT 1 FROM public.investment_allocations allocation
        WHERE allocation.owner_id = auth.uid() AND allocation.id = '66000000-0000-0000-0000-000000000001') THEN
        RAISE EXCEPTION 'allocation leaked across users';
    END IF;
END;
$test$;
ROLLBACK;
