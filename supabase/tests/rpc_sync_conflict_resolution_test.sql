\set ON_ERROR_STOP on

-- Synthetic identities only. Isolated PostgreSQL cluster.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('10000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', TRUE);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    cat_a CONSTANT UUID := '10000000-0000-0000-0000-000000002001';
    cat_b CONSTANT UUID := '10000000-0000-0000-0000-000000002002';
    cat_c CONSTANT UUID := '10000000-0000-0000-0000-000000002003';
    alloc CONSTANT UUID := '10000000-0000-0000-0000-000000002004';
    r JSONB;
    c1 UUID; c2 UUID; c3 UUID; c4 UUID;
    replay JSONB;
    v_name TEXT;
    v_version BIGINT;
BEGIN
    IF NOT pg_catalog.has_function_privilege('authenticated',
        'public.resolve_sync_conflict(uuid,uuid,text,jsonb)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('anon',
        'public.resolve_sync_conflict(uuid,uuid,text,jsonb)', 'EXECUTE') THEN
        RAISE EXCEPTION 'only authenticated may execute resolve_sync_conflict';
    END IF;

    -- Three categories, each renamed remotely, then a stale rename -> conflict.
    PERFORM public.apply_category_change('20000000-0000-0000-0000-000000000a01', 'create', cat_a, 0, 'expense', 'A');
    PERFORM public.apply_category_change('20000000-0000-0000-0000-000000000a02', 'create', cat_b, 0, 'expense', 'B');
    PERFORM public.apply_category_change('20000000-0000-0000-0000-000000000a03', 'create', cat_c, 0, 'expense', 'C');
    PERFORM public.apply_category_change('20000000-0000-0000-0000-000000000a11', 'rename', cat_a, 1, NULL, 'A remoto');
    PERFORM public.apply_category_change('20000000-0000-0000-0000-000000000a12', 'rename', cat_b, 1, NULL, 'B remoto');
    PERFORM public.apply_category_change('20000000-0000-0000-0000-000000000a13', 'rename', cat_c, 1, NULL, 'C remoto');
    c1 := (public.apply_category_change('20000000-0000-0000-0000-000000000a21', 'rename', cat_a, 1, NULL, 'A local') ->> 'conflict_id')::UUID;
    c2 := (public.apply_category_change('20000000-0000-0000-0000-000000000a22', 'rename', cat_b, 1, NULL, 'B local') ->> 'conflict_id')::UUID;
    c3 := (public.apply_category_change('20000000-0000-0000-0000-000000000a23', 'rename', cat_c, 1, NULL, 'C local') ->> 'conflict_id')::UUID;

    -- keep_local: local rename wins as a NEW version (3), audited, conflict closed.
    r := public.resolve_sync_conflict('20000000-0000-0000-0000-000000000b01', c1, 'keep_local');
    SELECT name, version INTO v_name, v_version FROM public.categories WHERE id = cat_a;
    IF r ->> 'status' <> 'resolved' OR v_name <> 'A local' OR v_version <> 3 THEN
        RAISE EXCEPTION 'keep_local must create a consolidated version: % % %', r, v_name, v_version;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.sync_conflicts WHERE id = c1 AND status = 'resolved'
        AND resolved_at IS NOT NULL AND local_snapshot ->> 'name' = 'A local'
        AND remote_snapshot ->> 'name' = 'A remoto') THEN
        RAISE EXCEPTION 'conflict must be resolved and keep both original snapshots';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.audit_events WHERE entity_id = c1 AND operation = 'conflict_resolved') THEN
        RAISE EXCEPTION 'resolution must be audited';
    END IF;

    -- Replay is idempotent: same response, no extra version.
    replay := public.resolve_sync_conflict('20000000-0000-0000-0000-000000000b01', c1, 'keep_local');
    SELECT version INTO v_version FROM public.categories WHERE id = cat_a;
    IF replay IS DISTINCT FROM r OR v_version <> 3 THEN
        RAISE EXCEPTION 'replaying a resolution must not apply twice';
    END IF;

    -- Reusing the key with other content, or resolving again, is rejected.
    BEGIN
        PERFORM public.resolve_sync_conflict('20000000-0000-0000-0000-000000000b01', c1, 'keep_remote');
        RAISE EXCEPTION 'key reuse with different content must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.resolve_sync_conflict('20000000-0000-0000-0000-000000000b09', c1, 'keep_remote');
        RAISE EXCEPTION 'resolving twice must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- keep_remote: data untouched (version stays 2), conflict closed, audited.
    r := public.resolve_sync_conflict('20000000-0000-0000-0000-000000000b02', c2, 'keep_remote');
    SELECT name, version INTO v_name, v_version FROM public.categories WHERE id = cat_b;
    IF v_name <> 'B remoto' OR v_version <> 2 OR r #>> '{record,name}' <> 'B remoto'
        OR NOT EXISTS (SELECT 1 FROM public.sync_conflicts WHERE id = c2 AND status = 'resolved') THEN
        RAISE EXCEPTION 'keep_remote must not change data and must close the conflict: %', r;
    END IF;

    -- edit: a third value becomes the consolidated version.
    r := public.resolve_sync_conflict('20000000-0000-0000-0000-000000000b03', c3, 'edit',
        '{"action":"rename","category_id":"10000000-0000-0000-0000-000000002003","name":"C editado"}');
    SELECT name, version INTO v_name, v_version FROM public.categories WHERE id = cat_c;
    IF v_name <> 'C editado' OR v_version <> 3 THEN
        RAISE EXCEPTION 'edit must create a consolidated version: % %', v_name, v_version;
    END IF;

    -- edit requires a request; others must not send one.
    BEGIN
        PERFORM public.resolve_sync_conflict('20000000-0000-0000-0000-000000000b04', c3, 'edit');
        RAISE EXCEPTION 'edit without request must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Investment allocation conflict resolved by keep_local.
    PERFORM public.create_accounting_period('62000000-0000-0000-0000-000000000001',
        '63000000-0000-0000-0000-000000000001', '64000000-0000-0000-0000-000000000001',
        '2026-11-01', 'calendar_month', NULL);
    PERFORM public.apply_investment_allocation_change('20000000-0000-0000-0000-000000000c01', 'create', alloc, 0, 1000, DATE '2026-11-10');
    PERFORM public.apply_investment_allocation_change('20000000-0000-0000-0000-000000000c02', 'update', alloc, 1, 2000, DATE '2026-11-10');
    c4 := (public.apply_investment_allocation_change('20000000-0000-0000-0000-000000000c03', 'update', alloc, 1, 3000, DATE '2026-11-10') ->> 'conflict_id')::UUID;
    PERFORM public.resolve_sync_conflict('20000000-0000-0000-0000-000000000b05', c4, 'keep_local');
    IF (SELECT amount_centavos FROM public.investment_allocations WHERE id = alloc) <> 3000 THEN
        RAISE EXCEPTION 'investment keep_local must apply the local amount';
    END IF;

    -- Another user cannot see or resolve this conflict.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', TRUE);
    BEGIN
        PERFORM public.resolve_sync_conflict('20000000-0000-0000-0000-000000000b06', c1, 'keep_remote');
        RAISE EXCEPTION 'foreign conflict must not resolve' USING ERRCODE = 'P0001';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
END;
$test$;

ROLLBACK;

\echo PASS: sync conflict resolution (keep_local, keep_remote, edit, idempotency, isolation).
