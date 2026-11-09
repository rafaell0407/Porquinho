SET application_name = 'porquinho-period-concurrency-second';
BEGIN;
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    'A0000000-0000-0000-0000-000000000001',
    TRUE
);
SET LOCAL ROLE authenticated;
SELECT public.create_accounting_period(
    'A2000000-0000-0000-0000-000000000002',
    'A3000000-0000-0000-0000-000000000002',
    'A1000000-0000-0000-0000-000000000001',
    '2029-02-01',
    'calendar_month',
    NULL
);
COMMIT;
