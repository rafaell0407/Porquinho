\set ON_ERROR_STOP on

-- Entrega 62: leitura agregada (get_period_report). Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('80000000-0000-0000-0000-000000000001'),
    ('80000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '80000000-0000-0000-0000-000000000001',
    TRUE
);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    r JSONB;
    p1 JSONB;
    n BIGINT;
BEGIN
    IF pg_catalog.has_function_privilege(
        'anon', 'public.get_period_report(uuid[])', 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anonymous execution must be revoked';
    END IF;

    PERFORM public.create_accounting_period(
        '81000000-0000-0000-0000-000000000001',
        '82000000-0000-0000-0000-000000000001',
        '83000000-0000-0000-0000-000000000001',
        '2026-11-01', 'calendar_month', NULL);
    PERFORM public.create_accounting_period(
        '81000000-0000-0000-0000-000000000002',
        '82000000-0000-0000-0000-000000000002',
        '83000000-0000-0000-0000-000000000001',
        '2026-12-01', 'calendar_month', NULL);
    PERFORM public.apply_category_change(
        '84000000-0000-0000-0000-000000000001', 'create',
        '85000000-0000-0000-0000-000000000001', 0, 'income', 'Renda');
    PERFORM public.apply_category_change(
        '84000000-0000-0000-0000-000000000002', 'create',
        '85000000-0000-0000-0000-000000000002', 0, 'expense', 'Moradia');

    -- Novembro: receita acima de 2^53 com categoria, receita sem categoria,
    -- despesa paga, despesa pendente e investimento.
    PERFORM public.apply_income_entry_change(
        '86000000-0000-0000-0000-000000000001', 'create',
        '87000000-0000-0000-0000-000000000001', 0,
        '{"amount_centavos":9007199254740993,"received_on":"2026-11-05","category_id":"85000000-0000-0000-0000-000000000001"}'::JSONB);
    PERFORM public.apply_income_entry_change(
        '86000000-0000-0000-0000-000000000002', 'create',
        '87000000-0000-0000-0000-000000000002', 0,
        '{"amount_centavos":1000,"received_on":"2026-11-06"}'::JSONB);
    PERFORM public.apply_expense_entry_change(
        '86000000-0000-0000-0000-000000000003', 'create',
        '87000000-0000-0000-0000-000000000003', 0,
        '{"amount_centavos":5000,"competence_on":"2026-11-07","due_on":"2026-11-20","category_id":"85000000-0000-0000-0000-000000000002"}'::JSONB);
    PERFORM public.apply_expense_entry_change(
        '86000000-0000-0000-0000-000000000004', 'pay',
        '87000000-0000-0000-0000-000000000003', 1,
        '{"paid_on":"2026-11-08"}'::JSONB);
    PERFORM public.apply_expense_entry_change(
        '86000000-0000-0000-0000-000000000005', 'create',
        '87000000-0000-0000-0000-000000000004', 0,
        '{"amount_centavos":700,"competence_on":"2026-11-09","due_on":"2026-11-25"}'::JSONB);
    -- Despesa cancelada: fora.
    PERFORM public.apply_expense_entry_change(
        '86000000-0000-0000-0000-000000000006', 'create',
        '87000000-0000-0000-0000-000000000005', 0,
        '{"amount_centavos":99999,"competence_on":"2026-11-10","due_on":"2026-11-25"}'::JSONB);
    PERFORM public.apply_expense_entry_change(
        '86000000-0000-0000-0000-000000000007', 'cancel',
        '87000000-0000-0000-0000-000000000005', 1, NULL);
    PERFORM public.apply_investment_allocation_change(
        '86000000-0000-0000-0000-000000000008', 'create',
        '87000000-0000-0000-0000-000000000006', 0, 2000, '2026-11-11');
    -- Investimento cancelado: fora.
    PERFORM public.apply_investment_allocation_change(
        '86000000-0000-0000-0000-000000000009', 'create',
        '87000000-0000-0000-0000-000000000007', 0, 888, '2026-11-12');
    PERFORM public.apply_investment_allocation_change(
        '86000000-0000-0000-0000-00000000000a', 'cancel',
        '87000000-0000-0000-0000-000000000007', 1, NULL, NULL);

    r := public.get_period_report(ARRAY[
        '82000000-0000-0000-0000-000000000001'::UUID,
        '82000000-0000-0000-0000-000000000002'::UUID]);

    -- Novembro: valores exatos como texto.
    SELECT elem INTO p1
    FROM jsonb_array_elements(r -> 'periods') AS elem
    WHERE elem ->> 'period_id' = '82000000-0000-0000-0000-000000000001';
    IF p1 ->> 'income' <> '9007199254741993'
        OR p1 ->> 'expense' <> '5700'
        OR p1 ->> 'investment' <> '2000'
    THEN
        RAISE EXCEPTION 'november totals incorrect: %', p1;
    END IF;

    -- Dezembro sem lançamentos: zeros.
    SELECT elem INTO p1
    FROM jsonb_array_elements(r -> 'periods') AS elem
    WHERE elem ->> 'period_id' = '82000000-0000-0000-0000-000000000002';
    IF p1 ->> 'income' <> '0' OR p1 ->> 'expense' <> '0'
        OR p1 ->> 'investment' <> '0'
    THEN
        RAISE EXCEPTION 'december totals incorrect: %', p1;
    END IF;

    -- Por categoria: receitas (com e sem categoria) e despesas.
    SELECT count(*) INTO n FROM jsonb_array_elements(r -> 'income_by_category');
    IF n <> 2 THEN
        RAISE EXCEPTION 'expected 2 income groups: %', r -> 'income_by_category';
    END IF;
    SELECT count(*) INTO n
    FROM jsonb_array_elements(r -> 'income_by_category') AS elem
    WHERE elem ->> 'category_id' IS NULL AND elem ->> 'amount' = '1000';
    IF n <> 1 THEN
        RAISE EXCEPTION 'uncategorized income missing: %', r -> 'income_by_category';
    END IF;
    SELECT count(*) INTO n
    FROM jsonb_array_elements(r -> 'expense_by_category') AS elem
    WHERE (elem ->> 'category_id' = '85000000-0000-0000-0000-000000000002'
           AND elem ->> 'amount' = '5000')
       OR (elem ->> 'category_id' IS NULL AND elem ->> 'amount' = '700');
    IF n <> 2 THEN
        RAISE EXCEPTION 'expense groups incorrect: %', r -> 'expense_by_category';
    END IF;

    -- Período inexistente ou lista vazia: sem linhas, sem erro.
    r := public.get_period_report(ARRAY['82000000-0000-0000-0000-0000000000ff'::UUID]);
    IF jsonb_array_length(r -> 'periods') <> 0 THEN
        RAISE EXCEPTION 'unknown period must return nothing: %', r;
    END IF;
    r := public.get_period_report(ARRAY[]::UUID[]);
    IF jsonb_array_length(r -> 'periods') <> 0 THEN
        RAISE EXCEPTION 'empty list must return nothing';
    END IF;

    -- Muitos períodos de uma vez: recusa.
    BEGIN
        PERFORM public.get_period_report(
            ARRAY(SELECT gen_random_uuid() FROM generate_series(1, 61)));
        RAISE EXCEPTION 'must reject more than 60 periods';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
END;
$test$;

-- Isolamento: outro usuário não enxerga os períodos nem os valores.
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '80000000-0000-0000-0000-000000000002',
    TRUE
);

DO $test$
DECLARE
    r JSONB;
BEGIN
    r := public.get_period_report(ARRAY[
        '82000000-0000-0000-0000-000000000001'::UUID]);
    IF jsonb_array_length(r -> 'periods') <> 0
        OR jsonb_array_length(r -> 'income_by_category') <> 0
        OR jsonb_array_length(r -> 'expense_by_category') <> 0
    THEN
        RAISE EXCEPTION 'second user must not see other data: %', r;
    END IF;
END;
$test$;

ROLLBACK;
