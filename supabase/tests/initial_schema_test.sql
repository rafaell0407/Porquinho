\set ON_ERROR_STOP on

-- Synthetic fixtures only; this file is run inside a temporary local cluster.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002');

INSERT INTO public.user_preferences (owner_id) VALUES
    ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002');

-- Configuração única de período (P6); períodos não são gravados (P7).
INSERT INTO public.period_settings (owner_id, id, mode) VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'calendar_month'),
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'calendar_month');

INSERT INTO public.categories (owner_id, id, kind, name, is_active) VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000001001', 'income', 'Fixture: income', TRUE),
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000001002', 'expense', 'Fixture: expense', TRUE),
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000002001', 'income', 'Fixture: other owner', TRUE);

INSERT INTO public.subcategories (owner_id, id, category_id, name, is_active) VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000001003', '00000000-0000-0000-0000-000000001001', 'Fixture: subcategory', TRUE);

INSERT INTO public.income_recurrence_templates
    (owner_id, id, description, frequency, starts_on, monthly_reference_day,
     value_mode, default_amount_centavos, category_id)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000003001',
     'Fixture: monthly income', 'monthly', '2026-11-01', 31, 'fixed', 2500,
     '00000000-0000-0000-0000-000000001001');

INSERT INTO public.income_recurrence_templates
    (owner_id, id, description, frequency, starts_on, monthly_reference_day,
     value_mode, default_amount_centavos)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000003002',
     'Fixture: variable income', 'monthly', '2026-11-01', 1, 'variable', NULL);

INSERT INTO public.expense_recurrence_templates
    (owner_id, id, description, frequency, starts_on, monthly_reference_day,
     value_mode, default_amount_centavos)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000003003',
     'Fixture: variable expense', 'monthly', '2026-11-01', 1, 'variable', NULL);

INSERT INTO public.income_entries
    (owner_id, id, amount_centavos, status, received_on, category_id,
     subcategory_id)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000004001',
     0, 'received', '2026-11-01', '00000000-0000-0000-0000-000000001001',
     '00000000-0000-0000-0000-000000001003'),
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000004002',
     2500, 'received', '2026-11-02', '00000000-0000-0000-0000-000000002001',
     NULL);

INSERT INTO public.income_entries
    (owner_id, id, amount_centavos, status, recurrence_template_id,
     scheduled_for_date)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000004003',
     2500, 'pending', '00000000-0000-0000-0000-000000003001', '2026-11-30');

INSERT INTO public.income_entries
    (owner_id, id, status, recurrence_template_id, scheduled_for_date)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000004008',
     'pending', '00000000-0000-0000-0000-000000003002', '2026-11-01');

INSERT INTO public.expense_entries
    (owner_id, id, amount_centavos, competence_on, status, category_id)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000005001',
     0, '2026-11-01', 'pending', '00000000-0000-0000-0000-000000001002');

INSERT INTO public.expense_entries
    (owner_id, id, competence_on, status,
     recurrence_template_id, scheduled_for_date)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000005005',
     '2026-11-01', 'pending',
     '00000000-0000-0000-0000-000000003003', '2026-11-01');

INSERT INTO public.investment_allocations
    (owner_id, id, amount_centavos, allocated_on)
VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000006001',
     0, '2026-11-01'),
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000006002',
     9007199254740993, '2026-11-02');

UPDATE public.categories
SET is_active = FALSE
WHERE owner_id = '00000000-0000-0000-0000-000000000001'
  AND id = '00000000-0000-0000-0000-000000001001';
UPDATE public.subcategories
SET is_active = FALSE
WHERE owner_id = '00000000-0000-0000-0000-000000000001'
  AND id = '00000000-0000-0000-0000-000000001003';
UPDATE public.income_entries
SET amount_centavos = 1
WHERE owner_id = '00000000-0000-0000-0000-000000000001'
  AND id = '00000000-0000-0000-0000-000000004001';

DO $test$
DECLARE
    protected_table_count BIGINT;
    forbidden_grant_count BIGINT;
BEGIN
    SELECT count(*) INTO protected_table_count
    FROM pg_catalog.pg_class AS relation
    JOIN pg_catalog.pg_namespace AS namespace ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname IN (
          'user_preferences', 'period_settings',
          'categories', 'subcategories', 'income_recurrence_templates',
          'expense_recurrence_templates', 'income_entries', 'expense_entries',
          'investment_allocations', 'audit_events', 'applied_sync_operations',
          'sync_conflicts'
      )
      AND relation.relrowsecurity;

    IF protected_table_count <> 12 THEN
        RAISE EXCEPTION 'expected RLS on all 12 remote tables, found %', protected_table_count;
    END IF;

    -- P7: períodos não são mais gravados (tabelas e vínculos removidos).
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c
               JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname = 'public'
                 AND c.relname IN ('accounting_periods', 'period_configurations'))
       OR EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public'
                    AND column_name IN ('accounting_period_id', 'scheduled_period_id')) THEN
        RAISE EXCEPTION 'stored periods or period links still exist';
    END IF;

    SELECT count(*) INTO forbidden_grant_count
    FROM information_schema.table_privileges
    WHERE grantee IN ('anon', 'authenticated')
      AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER');

    IF forbidden_grant_count <> 0 THEN
        RAISE EXCEPTION 'client roles hold % forbidden table grants', forbidden_grant_count;
    END IF;

    BEGIN
        INSERT INTO public.expense_entries
            (owner_id, id, amount_centavos, competence_on, status)
        VALUES
            ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000005002',
             -1, '2026-11-01', 'pending');
        RAISE EXCEPTION 'negative money value was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.period_settings (owner_id, id, mode, custom_start_day)
        VALUES
            ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002',
             'custom_cycle', NULL);
        RAISE EXCEPTION 'custom cycle without a start day was accepted';
    EXCEPTION WHEN check_violation OR unique_violation THEN
        NULL;
    END;

    BEGIN
        UPDATE public.period_settings SET custom_start_day = 5
        WHERE owner_id = '00000000-0000-0000-0000-000000000001';
        RAISE EXCEPTION 'calendar month with a start day was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.period_settings (owner_id, id, mode)
        VALUES
            ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002',
             'calendar_month');
        RAISE EXCEPTION 'second settings row for the same owner was accepted';
    EXCEPTION WHEN check_violation OR unique_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.income_recurrence_templates
            (owner_id, id, frequency, starts_on, monthly_reference_day,
             value_mode, default_amount_centavos)
        VALUES
            ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000003004',
             'monthly', '2026-11-01', NULL, 'fixed', 100);
        RAISE EXCEPTION 'monthly recurrence without reference day was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    -- P5 (13/11/2026): só "Todo mês"; "por período" é recusado.
    BEGIN
        INSERT INTO public.expense_recurrence_templates
            (owner_id, id, frequency, starts_on, value_mode,
             default_amount_centavos)
        VALUES
            ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000003005',
             'by_period', '2026-11-01', 'variable', NULL);
        RAISE EXCEPTION 'by-period recurrence was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.expense_entries
            (owner_id, id, competence_on, status)
        VALUES
            ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000005006',
             '2026-11-01', 'pending');
        RAISE EXCEPTION 'unvalued ad hoc expense was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.investment_allocations
            (owner_id, id, amount_centavos, allocated_on)
        VALUES
            ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000006003',
             9223372036854775808, '2026-11-03');
        RAISE EXCEPTION '64-bit overflow value was accepted';
    EXCEPTION WHEN numeric_value_out_of_range THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.expense_entries
            (owner_id, id, amount_centavos, competence_on, status,
             category_id)
        VALUES
            ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000005003',
             1, '2026-11-01', 'pending', '00000000-0000-0000-0000-000000002001');
        RAISE EXCEPTION 'cross-owner category reference was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.income_entries
            (owner_id, id, amount_centavos, status, recurrence_template_id,
             scheduled_for_date)
        VALUES
            ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000004004',
             2500, 'pending', '00000000-0000-0000-0000-000000003001', '2026-11-30');
        RAISE EXCEPTION 'duplicate recurrence occurrence was accepted';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.income_entries
            (owner_id, id, amount_centavos, status, received_on, category_id)
        VALUES
            ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000004005',
             1, 'received', '2026-11-01', '00000000-0000-0000-0000-000000001002');
        RAISE EXCEPTION 'income with expense category was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        UPDATE public.categories
        SET kind = 'expense'
        WHERE owner_id = '00000000-0000-0000-0000-000000000001'
          AND id = '00000000-0000-0000-0000-000000001001';
        RAISE EXCEPTION 'category kind mutation was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        DELETE FROM auth.users
        WHERE id = '00000000-0000-0000-0000-000000000001';
        RAISE EXCEPTION 'user deletion bypassed dependent-record cleanup';
    EXCEPTION WHEN restrict_violation THEN
        NULL;
    END;

    IF (SELECT amount_centavos FROM public.investment_allocations
        WHERE owner_id = '00000000-0000-0000-0000-000000000001'
          AND id = '00000000-0000-0000-0000-000000006002') <> 9007199254740993 THEN
        RAISE EXCEPTION '64-bit cent value above the JavaScript safe integer range changed';
    END IF;
END;
$test$;

SELECT pg_catalog.set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', FALSE);
SET ROLE authenticated;
DO $test$
DECLARE
    visible_count BIGINT;
BEGIN
    SELECT count(*) INTO visible_count FROM public.categories;
    IF visible_count <> 2 THEN
        RAISE EXCEPTION 'user 1 expected to see 2 categories, saw %', visible_count;
    END IF;

    BEGIN
        UPDATE public.categories SET is_active = FALSE;
        RAISE EXCEPTION 'authenticated direct update was accepted';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.categories (owner_id, id, kind, name)
        VALUES ('00000000-0000-0000-0000-000000000001',
                '00000000-0000-0000-0000-000000009901', 'income', 'Fixture: forbidden insert');
        RAISE EXCEPTION 'authenticated direct insert was accepted';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;

    BEGIN
        DELETE FROM public.categories;
        RAISE EXCEPTION 'authenticated direct delete was accepted';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END;
$test$;
RESET ROLE;

SELECT pg_catalog.set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', FALSE);
SET ROLE authenticated;
DO $test$
DECLARE
    visible_count BIGINT;
BEGIN
    SELECT count(*) INTO visible_count FROM public.categories;
    IF visible_count <> 1 THEN
        RAISE EXCEPTION 'user 2 expected to see 1 category, saw %', visible_count;
    END IF;
END;
$test$;
RESET ROLE;

SELECT pg_catalog.set_config('request.jwt.claim.sub', '', FALSE);
SET ROLE authenticated;
DO $test$
DECLARE
    visible_count BIGINT;
BEGIN
    SELECT count(*) INTO visible_count FROM public.categories;
    IF visible_count <> 0 THEN
        RAISE EXCEPTION 'anonymous identity saw % categories', visible_count;
    END IF;
END;
$test$;
RESET ROLE;

SET ROLE anon;
DO $test$
BEGIN
    BEGIN
        PERFORM count(*) FROM public.categories;
        RAISE EXCEPTION 'anon role read was accepted';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END;
$test$;
RESET ROLE;

ROLLBACK;
\echo 'PASS: schema constraints, ownership references, RLS isolation and direct-write denial'
