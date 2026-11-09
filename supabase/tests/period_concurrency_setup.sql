-- Synthetic fixture for the two-session advisory-lock acceptance test.
INSERT INTO auth.users (id)
VALUES ('A0000000-0000-0000-0000-000000000001');

INSERT INTO public.period_configurations
    (owner_id, id, mode, effective_from)
VALUES
    ('A0000000-0000-0000-0000-000000000001',
     'A1000000-0000-0000-0000-000000000001',
     'calendar_month',
     '2029-01-01');
