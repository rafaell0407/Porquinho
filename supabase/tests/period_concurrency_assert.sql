DO $test$
DECLARE
    period_count BIGINT;
    audit_count BIGINT;
    operation_count BIGINT;
BEGIN
    SELECT pg_catalog.count(*) INTO period_count
    FROM public.accounting_periods AS period
    WHERE period.owner_id = 'A0000000-0000-0000-0000-000000000001';
    IF period_count <> 2 THEN
        RAISE EXCEPTION 'concurrent adjacent requests must create exactly two periods';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.accounting_periods AS first_period
        JOIN public.accounting_periods AS second_period
          ON second_period.owner_id = first_period.owner_id
         AND second_period.start_date = first_period.end_date
        WHERE first_period.owner_id = 'A0000000-0000-0000-0000-000000000001'
          AND first_period.start_date = '2029-01-01'
          AND first_period.end_date = '2029-02-01'
          AND second_period.start_date = '2029-02-01'
          AND second_period.end_date = '2029-03-01'
    ) THEN
        RAISE EXCEPTION 'concurrent period creation must remain contiguous';
    END IF;

    SELECT pg_catalog.count(*) INTO audit_count
    FROM public.audit_events AS event
    WHERE event.owner_id = 'A0000000-0000-0000-0000-000000000001';
    IF audit_count <> 2 THEN
        RAISE EXCEPTION 'each concurrent period must have one audit event';
    END IF;

    SELECT pg_catalog.count(*) INTO operation_count
    FROM public.applied_sync_operations AS operation
    WHERE operation.owner_id = 'A0000000-0000-0000-0000-000000000001';
    IF operation_count <> 2 THEN
        RAISE EXCEPTION 'each concurrent period operation must be recorded once';
    END IF;
END;
$test$;

\echo PASS: concurrent adjacent period creation serialized by per-owner advisory lock.
