BEGIN;
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    'A0000000-0000-0000-0000-000000000001',
    TRUE
);
SET LOCAL ROLE authenticated;
SELECT public.create_accounting_period(
    'A2000000-0000-0000-0000-000000000001',
    'A3000000-0000-0000-0000-000000000001',
    'A1000000-0000-0000-0000-000000000001',
    '2029-01-01',
    'calendar_month',
    NULL
);
\echo FIRST_PERIOD_CREATED_LOCK_HELD
SELECT pg_catalog.pg_sleep(3);
COMMIT;
