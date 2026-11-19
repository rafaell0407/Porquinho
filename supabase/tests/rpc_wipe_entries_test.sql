\set ON_ERROR_STOP on

-- RN056 (19/11/2026): apagar todos os lançamentos. Identidades sintéticas;
-- tudo desfeito no fim.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('a7000000-0000-0000-0000-000000000001'),
    ('a7000000-0000-0000-0000-000000000002'),
    ('a7000000-0000-0000-0000-000000000003');

SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    a CONSTANT UUID := 'a7000000-0000-0000-0000-000000000001';
    b CONSTANT UUID := 'a7000000-0000-0000-0000-000000000002';
    c CONSTANT UUID := 'a7000000-0000-0000-0000-000000000003';
    base DATE := (pg_catalog.now() AT TIME ZONE 'America/Sao_Paulo')::DATE - 70;
    r JSONB;
BEGIN
    -- Sem login: recusado.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '', TRUE);
    BEGIN
        PERFORM public.wipe_entries_preview();
        RAISE EXCEPTION 'preview must require authentication';
    EXCEPTION WHEN invalid_authorization_specification THEN NULL;
    END;
    BEGIN
        PERFORM public.wipe_entries_run('a7100000-0000-0000-0000-000000000099', pg_catalog.now(), 10);
        RAISE EXCEPTION 'run must require authentication';
    EXCEPTION WHEN invalid_authorization_specification THEN NULL;
    END;

    -- A: categoria, avulsos dos três tipos, um já cancelado e recorrências.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', a::TEXT, TRUE);
    PERFORM public.apply_category_change('a7100000-0000-0000-0000-000000000001', 'create',
        'a7300000-0000-0000-0000-000000000001', 0, 'expense', 'Mercado');
    PERFORM public.apply_income_entry_change('a7100000-0000-0000-0000-000000000002', 'create',
        'a7200000-0000-0000-0000-000000000001', 0,
        pg_catalog.jsonb_build_object('amount_centavos', 100000, 'received_on', base));
    PERFORM public.apply_expense_entry_change('a7100000-0000-0000-0000-000000000003', 'create',
        'a7200000-0000-0000-0000-000000000002', 0,
        pg_catalog.jsonb_build_object('amount_centavos', 2500, 'competence_on', base, 'due_on', base,
            'category_id', 'a7300000-0000-0000-0000-000000000001'));
    PERFORM public.apply_investment_allocation_change('a7100000-0000-0000-0000-000000000004', 'create',
        'a7200000-0000-0000-0000-000000000003', 0, 3000, base);
    PERFORM public.apply_expense_entry_change('a7100000-0000-0000-0000-000000000005', 'create',
        'a7200000-0000-0000-0000-000000000004', 0,
        pg_catalog.jsonb_build_object('amount_centavos', 700, 'competence_on', base, 'due_on', base));
    PERFORM public.apply_expense_entry_change('a7100000-0000-0000-0000-000000000006', 'cancel',
        'a7200000-0000-0000-0000-000000000004', 1, NULL);
    -- Lançamento "tardio": criado depois do corte (ajustado abaixo).
    PERFORM public.apply_expense_entry_change('a7100000-0000-0000-0000-000000000007', 'create',
        'a7200000-0000-0000-0000-000000000005', 0,
        pg_catalog.jsonb_build_object('amount_centavos', 900, 'competence_on', base, 'due_on', base));

    PERFORM public.apply_expense_recurrence_template_change('a7100000-0000-0000-0000-000000000008', 'create',
        'a7400000-0000-0000-0000-000000000001', 0,
        pg_catalog.jsonb_build_object('description', 'Aluguel', 'frequency', 'monthly', 'starts_on', base,
            'monthly_reference_day', 5, 'value_mode', 'fixed', 'default_amount_centavos', 150000));
    PERFORM public.apply_income_recurrence_template_change('a7100000-0000-0000-0000-000000000009', 'create',
        'a7400000-0000-0000-0000-000000000002', 0,
        pg_catalog.jsonb_build_object('description', 'Salário', 'frequency', 'monthly', 'starts_on', base,
            'monthly_reference_day', 5, 'value_mode', 'fixed', 'default_amount_centavos', 500000));
    PERFORM public.apply_investment_recurrence_template_change('a7100000-0000-0000-0000-000000000010', 'create',
        'a7400000-0000-0000-0000-000000000003', 0,
        pg_catalog.jsonb_build_object('frequency', 'monthly', 'starts_on', base,
            'monthly_reference_day', 5, 'default_amount_centavos', 20000));
    PERFORM public.generate_due_recurrence_occurrences('a7100000-0000-0000-0000-000000000011');
    IF (SELECT COUNT(*) FROM public.expense_entries
        WHERE recurrence_template_id = 'a7400000-0000-0000-0000-000000000001') < 2
       OR (SELECT COUNT(*) FROM public.income_entries
        WHERE recurrence_template_id = 'a7400000-0000-0000-0000-000000000002') < 2
       OR (SELECT COUNT(*) FROM public.investment_allocations
        WHERE recurrence_template_id = 'a7400000-0000-0000-0000-000000000003') < 2 THEN
        RAISE EXCEPTION 'recurrences must have generated occurrences';
    END IF;

    -- Prévia: conta só o que não está cancelado.
    r := public.wipe_entries_preview();
    IF (r ->> 'income')::INT <> 1 + (SELECT COUNT(*) FROM public.income_entries
            WHERE recurrence_template_id IS NOT NULL)
        OR (r ->> 'expense')::INT <> 2 + (SELECT COUNT(*) FROM public.expense_entries
            WHERE recurrence_template_id IS NOT NULL)
        OR (r ->> 'investment')::INT <> 1 + (SELECT COUNT(*) FROM public.investment_allocations
            WHERE recurrence_template_id IS NOT NULL)
        OR (r ->> 'templates')::INT <> 3
        OR (r ->> 'open_conflicts')::INT <> 0
        OR r ->> 'as_of' IS NULL THEN
        RAISE EXCEPTION 'unexpected preview: %', r;
    END IF;
    PERFORM pg_catalog.set_config('wipe_test.as_of', r ->> 'as_of', FALSE);

    -- Parâmetros inválidos.
    BEGIN
        PERFORM public.wipe_entries_run('a7100000-0000-0000-0000-000000000098', (r ->> 'as_of')::TIMESTAMPTZ, 0);
        RAISE EXCEPTION 'limit 0 must be refused';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.wipe_entries_run('a7100000-0000-0000-0000-000000000098',
            pg_catalog.clock_timestamp() + INTERVAL '1 hour', 10);
        RAISE EXCEPTION 'future cut-off must be refused';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- B: um lançamento que não pode ser tocado.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', b::TEXT, TRUE);
    PERFORM public.apply_income_entry_change('a7100000-0000-0000-0000-000000000020', 'create',
        'a7200000-0000-0000-0000-000000000020', 0,
        pg_catalog.jsonb_build_object('amount_centavos', 4200, 'received_on', base));

    -- C: conflito aberto bloqueia.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', c::TEXT, TRUE);
    PERFORM public.apply_expense_entry_change('a7100000-0000-0000-0000-000000000030', 'create',
        'a7200000-0000-0000-0000-000000000030', 0,
        pg_catalog.jsonb_build_object('amount_centavos', 100, 'competence_on', base, 'due_on', base));
    PERFORM public.apply_expense_entry_change('a7100000-0000-0000-0000-000000000031', 'create',
        'a7200000-0000-0000-0000-000000000031', 0,
        pg_catalog.jsonb_build_object('amount_centavos', 200, 'competence_on', base, 'due_on', base));
    PERFORM public.apply_expense_entry_change('a7100000-0000-0000-0000-000000000032', 'cancel',
        'a7200000-0000-0000-0000-000000000031', 1, NULL);
    r := public.apply_expense_entry_change('a7100000-0000-0000-0000-000000000033', 'update',
        'a7200000-0000-0000-0000-000000000031', 1, '{"amount_centavos":300}'::JSONB);
    IF r ->> 'status' <> 'conflict' THEN RAISE EXCEPTION 'expected a conflict: %', r; END IF;
    r := public.wipe_entries_preview();
    IF (r ->> 'open_conflicts')::INT <> 1 THEN RAISE EXCEPTION 'preview must show the conflict: %', r; END IF;
    r := public.wipe_entries_run('a7100000-0000-0000-0000-000000000034', (r ->> 'as_of')::TIMESTAMPTZ, 100);
    IF r ->> 'status' <> 'blocked' OR r ->> 'reason' <> 'open_conflicts' THEN
        RAISE EXCEPTION 'open conflict must block: %', r;
    END IF;
    IF (SELECT status FROM public.expense_entries WHERE id = 'a7200000-0000-0000-0000-000000000030') <> 'pending' THEN
        RAISE EXCEPTION 'blocked run must not change anything';
    END IF;
END;
$test$;

RESET ROLE;

-- O lançamento "tardio" de A passa a ter sido criado depois do corte.
UPDATE public.expense_entries
SET created_at = pg_catalog.current_setting('wipe_test.as_of')::TIMESTAMPTZ + INTERVAL '1 second'
WHERE owner_id = 'a7000000-0000-0000-0000-000000000001' AND id = 'a7200000-0000-0000-0000-000000000005';

SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    a CONSTANT UUID := 'a7000000-0000-0000-0000-000000000001';
    op CONSTANT UUID := 'a7100000-0000-0000-0000-000000000050';
    as_of TIMESTAMPTZ := pg_catalog.current_setting('wipe_test.as_of')::TIMESTAMPTZ;
    r JSONB;
    rounds INTEGER := 0;
    total_calls INTEGER := 0;
    templates INTEGER := 0;
    cancelled_income INTEGER := 0;
    cancelled_expense INTEGER := 0;
    cancelled_investment INTEGER := 0;
    expected_calls INTEGER;
    occurrences_before BIGINT;
BEGIN
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', a::TEXT, TRUE);
    -- O tardio já não entra (criado depois do corte usado na execução).
    expected_calls :=
        (SELECT COUNT(*) FROM public.income_entries WHERE status <> 'cancelled' AND created_at <= as_of)
        + (SELECT COUNT(*) FROM public.expense_entries WHERE status <> 'cancelled' AND created_at <= as_of)
        + (SELECT COUNT(*) FROM public.investment_allocations WHERE cancelled_at IS NULL AND created_at <= as_of)
        + 3;

    -- Em partes de 2 até terminar.
    LOOP
        r := public.wipe_entries_run(op, as_of, 2);
        rounds := rounds + 1;
        total_calls := total_calls + (r ->> 'calls')::INT;
        templates := templates + (r ->> 'deactivated_templates')::INT;
        cancelled_income := cancelled_income + (r #>> '{cancelled,income}')::INT;
        cancelled_expense := cancelled_expense + (r #>> '{cancelled,expense}')::INT;
        cancelled_investment := cancelled_investment + (r #>> '{cancelled,investment}')::INT;
        EXIT WHEN r ->> 'status' = 'done';
        IF r ->> 'status' <> 'running' OR (r ->> 'calls')::INT <> 2 THEN
            RAISE EXCEPTION 'unexpected partial response: %', r;
        END IF;
        IF rounds > 100 THEN RAISE EXCEPTION 'run does not finish'; END IF;
    END LOOP;
    IF total_calls <> expected_calls OR templates <> 3 OR rounds < 2 THEN
        RAISE EXCEPTION 'unexpected totals: calls % of %, templates %, rounds %',
            total_calls, expected_calls, templates, rounds;
    END IF;

    -- Tudo de A cancelado, exceto o tardio; modelos desativados.
    IF EXISTS (SELECT 1 FROM public.income_entries WHERE owner_id = a AND status <> 'cancelled')
        OR EXISTS (SELECT 1 FROM public.expense_entries WHERE owner_id = a AND status <> 'cancelled'
            AND id <> 'a7200000-0000-0000-0000-000000000005')
        OR EXISTS (SELECT 1 FROM public.investment_allocations WHERE owner_id = a AND cancelled_at IS NULL)
        OR EXISTS (SELECT 1 FROM public.income_recurrence_templates WHERE owner_id = a AND is_active)
        OR EXISTS (SELECT 1 FROM public.expense_recurrence_templates WHERE owner_id = a AND is_active)
        OR EXISTS (SELECT 1 FROM public.investment_recurrence_templates WHERE owner_id = a AND is_active) THEN
        RAISE EXCEPTION 'everything up to the cut-off must be cancelled or deactivated';
    END IF;
    IF (SELECT status FROM public.expense_entries WHERE id = 'a7200000-0000-0000-0000-000000000005') <> 'pending' THEN
        RAISE EXCEPTION 'entry created after the cut-off must stay';
    END IF;
    -- Nada apagado fisicamente; categoria segue ativa.
    IF NOT EXISTS (SELECT 1 FROM public.income_entries WHERE id = 'a7200000-0000-0000-0000-000000000001')
        OR NOT (SELECT is_active FROM public.categories WHERE id = 'a7300000-0000-0000-0000-000000000001') THEN
        RAISE EXCEPTION 'rows must be kept (RN029) and categories untouched';
    END IF;
    PERFORM pg_catalog.set_config('wipe_test.expected_calls', expected_calls::TEXT, FALSE);
    -- Registro único da operação (a auditoria de cada item é conferida abaixo).
    IF (SELECT COUNT(*) FROM public.audit_events WHERE owner_id = a AND entity_type = 'entries_wipe') <> 1 THEN
        RAISE EXCEPTION 'summary audit must exist once';
    END IF;

    -- Repetir não muda nada e não duplica o registro.
    r := public.wipe_entries_run(op, as_of, 50);
    IF r ->> 'status' <> 'done' OR (r ->> 'calls')::INT <> 0 THEN
        RAISE EXCEPTION 'repeat must be a no-op: %', r;
    END IF;
    IF (SELECT COUNT(*) FROM public.audit_events WHERE owner_id = a AND entity_type = 'entries_wipe') <> 1 THEN
        RAISE EXCEPTION 'repeat must not duplicate the summary';
    END IF;

    -- Os modelos desativados não geram mais nada.
    SELECT COUNT(*) INTO occurrences_before FROM public.expense_entries WHERE owner_id = a;
    PERFORM public.generate_due_recurrence_occurrences('a7100000-0000-0000-0000-000000000051');
    IF (SELECT COUNT(*) FROM public.expense_entries WHERE owner_id = a) <> occurrences_before THEN
        RAISE EXCEPTION 'deactivated templates must not generate';
    END IF;
END;
$test$;

RESET ROLE;

DO $test$
DECLARE
    audited BIGINT;
BEGIN
    -- Cada item apagado ou desativado tem auditoria da sua operação derivada.
    SELECT COUNT(*) INTO audited
    FROM (
        SELECT 'income_entry' AS t, id FROM public.income_entries WHERE owner_id = 'a7000000-0000-0000-0000-000000000001'
        UNION ALL SELECT 'expense_entry', id FROM public.expense_entries WHERE owner_id = 'a7000000-0000-0000-0000-000000000001'
        UNION ALL SELECT 'investment_allocation', id FROM public.investment_allocations WHERE owner_id = 'a7000000-0000-0000-0000-000000000001'
        UNION ALL SELECT 'income_recurrence_template', id FROM public.income_recurrence_templates WHERE owner_id = 'a7000000-0000-0000-0000-000000000001'
        UNION ALL SELECT 'expense_recurrence_template', id FROM public.expense_recurrence_templates WHERE owner_id = 'a7000000-0000-0000-0000-000000000001'
        UNION ALL SELECT 'investment_recurrence_template', id FROM public.investment_recurrence_templates WHERE owner_id = 'a7000000-0000-0000-0000-000000000001'
    ) x
    WHERE EXISTS (SELECT 1 FROM public.audit_events e
        WHERE e.owner_id = 'a7000000-0000-0000-0000-000000000001' AND e.entity_id = x.id
          AND e.operation_id = public.import_uuid('a7100000-0000-0000-0000-000000000050|wipe|' || x.t || '|' || x.id::TEXT));
    IF audited <> pg_catalog.current_setting('wipe_test.expected_calls')::BIGINT THEN
        RAISE EXCEPTION 'every change must be audited: % of %', audited,
            pg_catalog.current_setting('wipe_test.expected_calls');
    END IF;

    -- B intocado.
    IF (SELECT status FROM public.income_entries WHERE id = 'a7200000-0000-0000-0000-000000000020') <> 'received' THEN
        RAISE EXCEPTION 'other accounts must be untouched';
    END IF;
    -- Auxiliares internas fora do alcance de clientes.
    IF pg_catalog.has_function_privilege('authenticated', 'public.wipe_entries_targets(uuid,timestamptz)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('authenticated', 'public.wipe_entries_counts(uuid,timestamptz)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('authenticated', 'public.wipe_entries_open_conflicts(uuid)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('anon', 'public.wipe_entries_run(uuid,timestamptz,integer)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('anon', 'public.wipe_entries_preview()', 'EXECUTE') THEN
        RAISE EXCEPTION 'wipe helpers must not be callable by clients';
    END IF;
END;
$test$;

ROLLBACK;

SELECT 'RPC_WIPE_ENTRIES_OK' AS result;
