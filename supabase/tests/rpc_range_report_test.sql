\set ON_ERROR_STOP on

-- Reestruturação P3: leitura agregada por intervalo de datas
-- (get_range_report). Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('a0000000-0000-0000-0000-000000000001'),
    ('a0000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    'a0000000-0000-0000-0000-000000000001',
    TRUE
);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    r JSONB;
    p JSONB;
    n BIGINT;
BEGIN
    IF pg_catalog.has_function_privilege(
        'anon', 'public.get_range_report(date[], date[])', 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anonymous execution must be revoked';
    END IF;

    PERFORM public.apply_category_change(
        'a4000000-0000-0000-0000-000000000001', 'create',
        'a5000000-0000-0000-0000-000000000001', 0, 'income', 'Renda');
    PERFORM public.apply_category_change(
        'a4000000-0000-0000-0000-000000000002', 'create',
        'a5000000-0000-0000-0000-000000000002', 0, 'expense', 'Moradia');

    -- 01/11 (início, entra), 30/11 (último dia, entra), 01/12 (fim
    -- exclusivo: vai para dezembro). Receita acima de 2^53.
    PERFORM public.apply_income_entry_change(
        'a6000000-0000-0000-0000-000000000001', 'create',
        'a7000000-0000-0000-0000-000000000001', 0,
        '{"amount_centavos":9007199254740993,"received_on":"2026-11-01","category_id":"a5000000-0000-0000-0000-000000000001"}'::JSONB);
    PERFORM public.apply_income_entry_change(
        'a6000000-0000-0000-0000-000000000002', 'create',
        'a7000000-0000-0000-0000-000000000002', 0,
        '{"amount_centavos":1000,"received_on":"2026-11-30"}'::JSONB);
    PERFORM public.apply_income_entry_change(
        'a6000000-0000-0000-0000-000000000003', 'create',
        'a7000000-0000-0000-0000-000000000003', 0,
        '{"amount_centavos":300,"received_on":"2026-12-01"}'::JSONB);
    -- Despesa paga (conta uma vez), pendente (conta) e cancelada (fora).
    PERFORM public.apply_expense_entry_change(
        'a6000000-0000-0000-0000-000000000004', 'create',
        'a7000000-0000-0000-0000-000000000004', 0,
        '{"amount_centavos":5000,"competence_on":"2026-11-07","due_on":"2026-12-20","category_id":"a5000000-0000-0000-0000-000000000002"}'::JSONB);
    PERFORM public.apply_expense_entry_change(
        'a6000000-0000-0000-0000-000000000005', 'pay',
        'a7000000-0000-0000-0000-000000000004', 1,
        '{"paid_on":"2026-12-02"}'::JSONB);
    PERFORM public.apply_expense_entry_change(
        'a6000000-0000-0000-0000-000000000006', 'create',
        'a7000000-0000-0000-0000-000000000005', 0,
        '{"amount_centavos":700,"competence_on":"2026-11-30","due_on":"2026-11-30"}'::JSONB);
    PERFORM public.apply_expense_entry_change(
        'a6000000-0000-0000-0000-000000000007', 'create',
        'a7000000-0000-0000-0000-000000000006', 0,
        '{"amount_centavos":99999,"competence_on":"2026-11-10","due_on":"2026-11-25"}'::JSONB);
    PERFORM public.apply_expense_entry_change(
        'a6000000-0000-0000-0000-000000000008', 'cancel',
        'a7000000-0000-0000-0000-000000000006', 1, NULL);
    -- Investimento ativo (conta) e cancelado (fora).
    PERFORM public.apply_investment_allocation_change(
        'a6000000-0000-0000-0000-000000000009', 'create',
        'a7000000-0000-0000-0000-000000000007', 0, 2000, '2026-11-11');
    PERFORM public.apply_investment_allocation_change(
        'a6000000-0000-0000-0000-00000000000a', 'create',
        'a7000000-0000-0000-0000-000000000008', 0, 888, '2026-11-12');
    PERFORM public.apply_investment_allocation_change(
        'a6000000-0000-0000-0000-00000000000b', 'cancel',
        'a7000000-0000-0000-0000-000000000008', 1, NULL, NULL);

    -- Novembro, dezembro e um ciclo dia 15 que atravessa os dois.
    r := public.get_range_report(
        ARRAY['2026-11-01', '2026-12-01', '2026-11-15']::DATE[],
        ARRAY['2026-12-01', '2027-01-01', '2026-12-15']::DATE[]);

    IF jsonb_array_length(r -> 'ranges') <> 3 THEN
        RAISE EXCEPTION 'expected 3 ranges: %', r;
    END IF;

    SELECT elem INTO p FROM jsonb_array_elements(r -> 'ranges') AS elem
    WHERE (elem ->> 'index')::INT = 1;
    IF p ->> 'start' <> '2026-11-01' OR p ->> 'end' <> '2026-12-01'
        OR p ->> 'income' <> '9007199254741993'
        OR p ->> 'expense' <> '5700'
        OR p ->> 'investment' <> '2000'
    THEN
        RAISE EXCEPTION 'november totals incorrect: %', p;
    END IF;

    -- Dezembro: só a receita do dia 01/12 (fim exclusivo de novembro). O
    -- pagamento em 02/12 não leva a despesa para dezembro.
    SELECT elem INTO p FROM jsonb_array_elements(r -> 'ranges') AS elem
    WHERE (elem ->> 'index')::INT = 2;
    IF p ->> 'income' <> '300' OR p ->> 'expense' <> '0'
        OR p ->> 'investment' <> '0'
    THEN
        RAISE EXCEPTION 'december totals incorrect: %', p;
    END IF;

    -- Ciclo [15/11, 15/12): 30/11 e 01/12 entram; 01/11, 07/11 e 11/11 não.
    SELECT elem INTO p FROM jsonb_array_elements(r -> 'ranges') AS elem
    WHERE (elem ->> 'index')::INT = 3;
    IF p ->> 'income' <> '1300' OR p ->> 'expense' <> '700'
        OR p ->> 'investment' <> '0'
    THEN
        RAISE EXCEPTION 'overlapping cycle totals incorrect: %', p;
    END IF;

    -- Por categoria em novembro: receita com e sem categoria; despesas.
    SELECT count(*) INTO n
    FROM jsonb_array_elements(r -> 'income_by_category') AS elem
    WHERE (elem ->> 'index')::INT = 1
      AND ((elem ->> 'category_id' = 'a5000000-0000-0000-0000-000000000001'
            AND elem ->> 'amount' = '9007199254740993')
        OR (elem ->> 'category_id' IS NULL AND elem ->> 'amount' = '1000'));
    IF n <> 2 THEN
        RAISE EXCEPTION 'income groups incorrect: %', r -> 'income_by_category';
    END IF;
    SELECT count(*) INTO n
    FROM jsonb_array_elements(r -> 'expense_by_category') AS elem
    WHERE (elem ->> 'index')::INT = 1
      AND ((elem ->> 'category_id' = 'a5000000-0000-0000-0000-000000000002'
            AND elem ->> 'amount' = '5000')
        OR (elem ->> 'category_id' IS NULL AND elem ->> 'amount' = '700'));
    IF n <> 2 THEN
        RAISE EXCEPTION 'expense groups incorrect: %', r -> 'expense_by_category';
    END IF;

    -- Intervalo sem lançamentos e período sem registro gravado: zeros.
    r := public.get_range_report(
        ARRAY['2030-01-01']::DATE[], ARRAY['2030-02-01']::DATE[]);
    IF r -> 'ranges' -> 0 ->> 'income' <> '0'
        OR r -> 'ranges' -> 0 ->> 'expense' <> '0'
        OR r -> 'ranges' -> 0 ->> 'investment' <> '0'
    THEN
        RAISE EXCEPTION 'empty range must be zero: %', r;
    END IF;

    -- Lista vazia: sem linhas, sem erro.
    r := public.get_range_report(ARRAY[]::DATE[], ARRAY[]::DATE[]);
    IF jsonb_array_length(r -> 'ranges') <> 0 THEN
        RAISE EXCEPTION 'empty list must return nothing';
    END IF;

    -- Recusas: listas de tamanhos diferentes, início >= fim, nulo, > 60.
    BEGIN
        PERFORM public.get_range_report(
            ARRAY['2026-11-01']::DATE[], ARRAY[]::DATE[]);
        RAISE EXCEPTION 'must reject different lengths';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.get_range_report(
            ARRAY['2026-11-01']::DATE[], ARRAY['2026-11-01']::DATE[]);
        RAISE EXCEPTION 'must reject empty range';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.get_range_report(
            ARRAY[NULL]::DATE[], ARRAY['2026-11-01']::DATE[]);
        RAISE EXCEPTION 'must reject null start';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.get_range_report(NULL, NULL);
        RAISE EXCEPTION 'must reject null lists';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.get_range_report(
            ARRAY(SELECT DATE '2026-01-01' + g FROM generate_series(1, 61) g),
            ARRAY(SELECT DATE '2026-01-02' + g FROM generate_series(1, 61) g));
        RAISE EXCEPTION 'must reject more than 60 ranges';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
END;
$test$;

-- Isolamento: outro usuário não enxerga os valores do primeiro.
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    'a0000000-0000-0000-0000-000000000002',
    TRUE
);

DO $test$
DECLARE
    r JSONB;
BEGIN
    r := public.get_range_report(
        ARRAY['2026-11-01']::DATE[], ARRAY['2026-12-01']::DATE[]);
    IF r -> 'ranges' -> 0 ->> 'income' <> '0'
        OR r -> 'ranges' -> 0 ->> 'expense' <> '0'
        OR r -> 'ranges' -> 0 ->> 'investment' <> '0'
        OR jsonb_array_length(r -> 'income_by_category') <> 0
        OR jsonb_array_length(r -> 'expense_by_category') <> 0
    THEN
        RAISE EXCEPTION 'second user must not see other data: %', r;
    END IF;
END;
$test$;

-- Sem login: recusa.
SELECT pg_catalog.set_config('request.jwt.claim.sub', '', TRUE);

DO $test$
BEGIN
    PERFORM public.get_range_report(
        ARRAY['2026-11-01']::DATE[], ARRAY['2026-12-01']::DATE[]);
    RAISE EXCEPTION 'must require authentication';
EXCEPTION WHEN invalid_authorization_specification THEN NULL;
END;
$test$;

ROLLBACK;
