\set ON_ERROR_STOP on

-- Synthetic identities only; assertions run against the temporary local cluster.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('40000000-0000-0000-0000-000000000001'),
    ('40000000-0000-0000-0000-000000000002'),
    ('40000000-0000-0000-0000-000000000003');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '40000000-0000-0000-0000-000000000001',
    TRUE
);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    period_response JSONB;
    replay JSONB;
    period_row public.accounting_periods%ROWTYPE;
    conflict_row public.sync_conflicts%ROWTYPE;
    event_count BIGINT;
    period_count BIGINT;
    conflict_count BIGINT;
    operation_count BIGINT;
BEGIN
    IF NOT pg_catalog.has_function_privilege(
        'authenticated',
        'public.create_accounting_period(uuid,uuid,uuid,date,text,smallint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'authenticated must be able to execute the period RPC';
    END IF;

    IF pg_catalog.has_function_privilege(
        'anon',
        'public.create_accounting_period(uuid,uuid,uuid,date,text,smallint)',
        'EXECUTE'
    ) OR EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS function
        CROSS JOIN LATERAL pg_catalog.aclexplode(
            COALESCE(
                function.proacl,
                pg_catalog.acldefault('f', function.proowner)
            )
        ) AS privilege
        WHERE function.oid = 'public.create_accounting_period(uuid,uuid,uuid,date,text,smallint)'::REGPROCEDURE
          AND privilege.grantee = 0
          AND privilege.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anonymous or PUBLIC execution must be revoked';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS function
        WHERE function.oid = 'public.create_accounting_period(uuid,uuid,uuid,date,text,smallint)'::REGPROCEDURE
          AND function.prosecdef
          AND function.proowner = 'postgres'::REGROLE
    ) THEN
        RAISE EXCEPTION 'period RPC must use the reviewed SECURITY DEFINER owner';
    END IF;

    period_response := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000001',
        '51000000-0000-0000-0000-000000000001',
        '52000000-0000-0000-0000-000000000001',
        '2026-11-01', 'calendar_month', NULL
    );
    IF period_response ->> 'status' <> 'applied'
        OR period_response #>> '{period,start_date}' <> '2026-11-01'
        OR period_response #>> '{period,end_date}' <> '2026-12-01'
        OR period_response #>> '{period,version}' <> '1'
        OR period_response #>> '{configuration,effective_from}' <> '2026-11-01'
    THEN
        RAISE EXCEPTION 'first calendar period has incorrect boundaries: %', period_response;
    END IF;

    replay := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000001',
        '51000000-0000-0000-0000-000000000001',
        '52000000-0000-0000-0000-000000000001',
        '2026-11-01', 'calendar_month', NULL
    );
    IF replay IS DISTINCT FROM period_response THEN
        RAISE EXCEPTION 'period retry must return its original result';
    END IF;

    BEGIN
        PERFORM public.create_accounting_period(
            '50000000-0000-0000-0000-000000000001',
            '51000000-0000-0000-0000-000000000002',
            '52000000-0000-0000-0000-000000000001',
            '2026-12-01', 'calendar_month', NULL
        );
        RAISE EXCEPTION 'reusing an idempotency key with changed content must fail'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;

    period_response := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000002',
        '51000000-0000-0000-0000-000000000002',
        '52000000-0000-0000-0000-000000000001',
        '2026-12-01', 'calendar_month', NULL
    );
    IF period_response #>> '{period,end_date}' <> '2027-01-01' THEN
        RAISE EXCEPTION 'second calendar period has incorrect exclusive end: %', period_response;
    END IF;

    BEGIN
        PERFORM public.create_accounting_period(
            '50000000-0000-0000-0000-000000000003',
            '51000000-0000-0000-0000-000000000003',
            '52000000-0000-0000-0000-000000000001',
            '2027-01-02', 'calendar_month', NULL
        );
        RAISE EXCEPTION 'a period gap must be rejected'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        PERFORM public.create_accounting_period(
            '50000000-0000-0000-0000-000000000004',
            '51000000-0000-0000-0000-000000000004',
            '52000000-0000-0000-0000-000000000001',
            '2026-12-15', 'calendar_month', NULL
        );
        RAISE EXCEPTION 'a period overlap must be rejected'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    -- A changed configuration begins at the previous period's end. The
    -- transition period ends at the next boundary in the new schedule.
    period_response := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000005',
        '51000000-0000-0000-0000-000000000005',
        '52000000-0000-0000-0000-000000000002',
        '2027-01-01', 'custom_cycle', 20::SMALLINT
    );
    IF period_response #>> '{period,start_date}' <> '2027-01-01'
        OR period_response #>> '{period,end_date}' <> '2027-01-20'
        OR period_response #>> '{configuration,effective_from}' <> '2027-01-01'
    THEN
        RAISE EXCEPTION 'custom-cycle transition period has incorrect boundaries: %', period_response;
    END IF;

    period_response := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000006',
        '51000000-0000-0000-0000-000000000006',
        '52000000-0000-0000-0000-000000000002',
        '2027-01-20', 'custom_cycle', 20::SMALLINT
    );
    IF period_response #>> '{period,end_date}' <> '2027-02-20' THEN
        RAISE EXCEPTION 'custom cycle must preserve its configured day: %', period_response;
    END IF;

    period_response := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000007',
        '51000000-0000-0000-0000-000000000007',
        '52000000-0000-0000-0000-000000000003',
        '2027-02-20', 'custom_cycle', 10::SMALLINT
    );
    IF period_response #>> '{period,end_date}' <> '2027-03-10' THEN
        RAISE EXCEPTION 'changed custom cycle must use its next day-10 boundary: %', period_response;
    END IF;

    period_response := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000008',
        '51000000-0000-0000-0000-000000000008',
        '52000000-0000-0000-0000-000000000003',
        '2027-03-10', 'custom_cycle', 10::SMALLINT
    );
    IF period_response #>> '{period,end_date}' <> '2027-04-10' THEN
        RAISE EXCEPTION 'custom-cycle continuation has incorrect boundaries: %', period_response;
    END IF;

    period_response := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000009',
        '51000000-0000-0000-0000-000000000009',
        '52000000-0000-0000-0000-000000000003',
        '2027-04-10', 'calendar_month', NULL
    );
    IF period_response ->> 'status' <> 'conflict'
        OR period_response #>> '{remote_configuration,mode}' <> 'custom_cycle'
    THEN
        RAISE EXCEPTION 'changed configuration under an existing id must be preserved as conflict: %', period_response;
    END IF;
    replay := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000009',
        '51000000-0000-0000-0000-000000000009',
        '52000000-0000-0000-0000-000000000003',
        '2027-04-10', 'calendar_month', NULL
    );
    IF replay IS DISTINCT FROM period_response THEN
        RAISE EXCEPTION 'period-configuration conflict retry must return its original result';
    END IF;

    period_response := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000010',
        '51000000-0000-0000-0000-000000000010',
        '52000000-0000-0000-0000-000000000003',
        '2027-04-10', 'custom_cycle', 10::SMALLINT
    );
    IF period_response ->> 'status' <> 'applied'
        OR period_response #>> '{period,end_date}' <> '2027-05-10'
    THEN
        RAISE EXCEPTION 'period after the configuration transition has incorrect boundaries: %', period_response;
    END IF;

    period_response := public.create_accounting_period(
        '50000000-0000-0000-0000-000000000011',
        '51000000-0000-0000-0000-000000000011',
        '52000000-0000-0000-0000-000000000004',
        '2027-04-10', 'custom_cycle', 10::SMALLINT
    );
    IF period_response ->> 'status' <> 'conflict'
        OR period_response #>> '{remote_period,id}' <> '51000000-0000-0000-0000-000000000010'
    THEN
        RAISE EXCEPTION 'duplicate period start with a new configuration must preserve a conflict';
    END IF;

    SELECT pg_catalog.count(*) INTO period_count
    FROM public.accounting_periods AS period
    WHERE period.owner_id = auth.uid();
    IF period_count <> 7 THEN
        RAISE EXCEPTION 'failed or conflicting operations must not add periods';
    END IF;

    SELECT pg_catalog.count(*) INTO event_count
    FROM public.audit_events AS event
    WHERE event.owner_id = auth.uid();
    IF event_count <> 10 THEN
        RAISE EXCEPTION 'each created configuration and period must have one audit event';
    END IF;

    SELECT pg_catalog.count(*) INTO conflict_count
    FROM public.sync_conflicts AS conflict
    WHERE conflict.owner_id = auth.uid();
    IF conflict_count <> 2 THEN
        RAISE EXCEPTION 'conflicting period/configuration requests must be preserved';
    END IF;

    SELECT pg_catalog.count(*) INTO operation_count
    FROM public.applied_sync_operations AS operation
    WHERE operation.owner_id = auth.uid();
    IF operation_count <> 9 THEN
        RAISE EXCEPTION 'successful and explicit conflicts must have one idempotency result each';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT period.start_date,
                   period.end_date,
                   pg_catalog.lead(period.start_date) OVER (ORDER BY period.start_date) AS next_start
            FROM public.accounting_periods AS period
            WHERE period.owner_id = auth.uid()
        ) AS ordered_periods
        WHERE ordered_periods.next_start IS NOT NULL
          AND ordered_periods.end_date <> ordered_periods.next_start
    ) THEN
        RAISE EXCEPTION 'consecutive periods must have no gaps or overlaps';
    END IF;

    PERFORM pg_catalog.set_config(
        'request.jwt.claim.sub',
        '40000000-0000-0000-0000-000000000002',
        TRUE
    );

    period_response := public.create_accounting_period(
        '60000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000001',
        '62000000-0000-0000-0000-000000000001',
        '2028-01-31', 'custom_cycle', 31::SMALLINT
    );
    IF period_response #>> '{period,end_date}' <> '2028-02-29' THEN
        RAISE EXCEPTION 'day 31 must clamp to February 29 in a leap year';
    END IF;

    period_response := public.create_accounting_period(
        '60000000-0000-0000-0000-000000000002',
        '61000000-0000-0000-0000-000000000002',
        '62000000-0000-0000-0000-000000000001',
        '2028-02-29', 'custom_cycle', 31::SMALLINT
    );
    IF period_response #>> '{period,end_date}' <> '2028-03-31' THEN
        RAISE EXCEPTION 'day 31 must return after February in a leap year';
    END IF;

    period_response := public.create_accounting_period(
        '60000000-0000-0000-0000-000000000003',
        '61000000-0000-0000-0000-000000000003',
        '62000000-0000-0000-0000-000000000001',
        '2028-03-31', 'custom_cycle', 31::SMALLINT
    );
    IF period_response #>> '{period,end_date}' <> '2028-04-30' THEN
        RAISE EXCEPTION 'day 31 must clamp to April 30';
    END IF;

    period_response := public.create_accounting_period(
        '60000000-0000-0000-0000-000000000004',
        '61000000-0000-0000-0000-000000000004',
        '62000000-0000-0000-0000-000000000001',
        '2028-04-30', 'custom_cycle', 31::SMALLINT
    );
    IF period_response #>> '{period,end_date}' <> '2028-05-31' THEN
        RAISE EXCEPTION 'day 31 must return after a short month';
    END IF;

    SELECT pg_catalog.count(*) INTO period_count
    FROM public.accounting_periods AS period;
    IF period_count <> 4 THEN
        RAISE EXCEPTION 'RLS must show only the authenticated user periods';
    END IF;

    PERFORM pg_catalog.set_config(
        'request.jwt.claim.sub',
        '40000000-0000-0000-0000-000000000003',
        TRUE
    );
    BEGIN
        PERFORM public.create_accounting_period(
            '70000000-0000-0000-0000-000000000001',
            '71000000-0000-0000-0000-000000000001',
            '72000000-0000-0000-0000-000000000001',
            '2028-02-27', 'custom_cycle', 31::SMALLINT
        );
        RAISE EXCEPTION 'a custom cycle must start on the configured/clamped day'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    IF EXISTS (
        SELECT 1
        FROM public.period_configurations AS configuration
        WHERE configuration.owner_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'failed period creation must roll back its configuration';
    END IF;

    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '', TRUE);
    BEGIN
        PERFORM public.create_accounting_period(
            '80000000-0000-0000-0000-000000000001',
            '81000000-0000-0000-0000-000000000001',
            '82000000-0000-0000-0000-000000000001',
            '2028-01-01', 'calendar_month', NULL
        );
        RAISE EXCEPTION 'unauthenticated period creation must fail'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_authorization_specification THEN
        NULL;
    END;

    PERFORM pg_catalog.set_config(
        'request.jwt.claim.sub',
        '40000000-0000-0000-0000-000000000001',
        TRUE
    );
    BEGIN
        INSERT INTO public.accounting_periods
            (owner_id, id, configuration_id, start_date, end_date)
        VALUES (
            auth.uid(),
            '90000000-0000-0000-0000-000000000001',
            '92000000-0000-0000-0000-000000000001',
            '2029-01-01',
            '2029-02-01'
        );
        RAISE EXCEPTION 'direct period writes must fail'
            USING ERRCODE = 'P0001';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END;
$test$;

ROLLBACK;

\echo PASS: period RPC boundaries, continuity, configuration changes and isolation.
