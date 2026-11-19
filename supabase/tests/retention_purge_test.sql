\set ON_ERROR_STOP on

-- D15 (18/11/2026): limpeza de retenção de 12 meses (RN029, RN030).
-- Identidades sintéticas; tudo desfeito no fim.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('d1500000-0000-0000-0000-000000000001'),
    ('d1500000-0000-0000-0000-000000000002');

SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    a CONSTANT UUID := 'd1500000-0000-0000-0000-000000000001';
    b CONSTANT UUID := 'd1500000-0000-0000-0000-000000000002';
    r JSONB;
BEGIN
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', a::TEXT, TRUE);

    -- Avulsos de A: receita, despesa e investimento cancelados (antigos).
    PERFORM public.apply_income_entry_change('d1510000-0000-0000-0000-000000000001', 'create',
        'd1520000-0000-0000-0000-000000000001', 0,
        '{"amount_centavos":1000,"received_on":"2025-01-10","description":"Antiga"}'::JSONB);
    PERFORM public.apply_income_entry_change('d1510000-0000-0000-0000-000000000002', 'cancel',
        'd1520000-0000-0000-0000-000000000001', 1, NULL);
    PERFORM public.apply_expense_entry_change('d1510000-0000-0000-0000-000000000003', 'create',
        'd1520000-0000-0000-0000-000000000002', 0,
        '{"amount_centavos":2000,"competence_on":"2025-01-10","due_on":"2025-01-10"}'::JSONB);
    PERFORM public.apply_expense_entry_change('d1510000-0000-0000-0000-000000000004', 'cancel',
        'd1520000-0000-0000-0000-000000000002', 1, NULL);
    PERFORM public.apply_investment_allocation_change('d1510000-0000-0000-0000-000000000005', 'create',
        'd1520000-0000-0000-0000-000000000003', 0, 3000, '2025-01-10');
    PERFORM public.apply_investment_allocation_change('d1510000-0000-0000-0000-000000000006', 'cancel',
        'd1520000-0000-0000-0000-000000000003', 1, NULL, NULL);

    -- Ativa antiga (não cancelada): nunca é apagada.
    PERFORM public.apply_expense_entry_change('d1510000-0000-0000-0000-000000000007', 'create',
        'd1520000-0000-0000-0000-000000000004', 0,
        '{"amount_centavos":4000,"competence_on":"2025-01-10","due_on":"2025-01-10"}'::JSONB);

    -- Cancelada recente (11 meses): fica.
    PERFORM public.apply_expense_entry_change('d1510000-0000-0000-0000-000000000008', 'create',
        'd1520000-0000-0000-0000-000000000005', 0,
        '{"amount_centavos":5000,"competence_on":"2025-12-10","due_on":"2025-12-10"}'::JSONB);
    PERFORM public.apply_expense_entry_change('d1510000-0000-0000-0000-000000000009', 'cancel',
        'd1520000-0000-0000-0000-000000000005', 1, NULL);

    -- Cancelada antiga com conflito aberto: espera a resolução.
    PERFORM public.apply_expense_entry_change('d1510000-0000-0000-0000-000000000010', 'create',
        'd1520000-0000-0000-0000-000000000006', 0,
        '{"amount_centavos":6000,"competence_on":"2025-01-10","due_on":"2025-01-10"}'::JSONB);
    PERFORM public.apply_expense_entry_change('d1510000-0000-0000-0000-000000000011', 'cancel',
        'd1520000-0000-0000-0000-000000000006', 1, NULL);
    r := public.apply_expense_entry_change('d1510000-0000-0000-0000-000000000012', 'update',
        'd1520000-0000-0000-0000-000000000006', 1, '{"amount_centavos":6100}'::JSONB);
    IF r ->> 'status' <> 'conflict' THEN RAISE EXCEPTION 'expected an open conflict: %', r; END IF;

    -- Recorrência mensal desde jan/2025 com uma ocorrência cancelada antiga.
    PERFORM public.apply_expense_recurrence_template_change('d1510000-0000-0000-0000-000000000013', 'create',
        'd1530000-0000-0000-0000-000000000001', 0,
        '{"description":"Academia","frequency":"monthly","starts_on":"2025-01-05","monthly_reference_day":5,"value_mode":"fixed","default_amount_centavos":9000}'::JSONB);
    PERFORM public.generate_due_recurrence_occurrences('d1510000-0000-0000-0000-000000000014');
    PERFORM public.apply_expense_recurrence_occurrence_change('d1510000-0000-0000-0000-000000000015', 'cancel',
        public.recurrence_occurrence_id('d1530000-0000-0000-0000-000000000001', '2025-02-05'), 1, NULL);

    -- B: uma cancelada antiga também (a limpeza vale para todas as contas).
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', b::TEXT, TRUE);
    PERFORM public.apply_income_entry_change('d1510000-0000-0000-0000-000000000016', 'create',
        'd1520000-0000-0000-0000-000000000007', 0,
        '{"amount_centavos":7000,"received_on":"2025-01-10"}'::JSONB);
    PERFORM public.apply_income_entry_change('d1510000-0000-0000-0000-000000000017', 'cancel',
        'd1520000-0000-0000-0000-000000000007', 1, NULL);
    PERFORM public.apply_income_entry_change('d1510000-0000-0000-0000-000000000018', 'create',
        'd1520000-0000-0000-0000-000000000008', 0,
        '{"amount_centavos":8000,"received_on":"2026-11-10"}'::JSONB);

    -- Clientes não executam a limpeza.
    BEGIN
        PERFORM public.purge_expired_records();
        RAISE EXCEPTION 'authenticated must not run the purge';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END;
$test$;

RESET ROLE;

-- Envelhece os dados (como superusuário): 13 meses para tudo, exceto a
-- despesa cancelada recente (11 meses) e o lançamento atual de B.
UPDATE public.income_entries SET updated_at = pg_catalog.now() - INTERVAL '13 months'
WHERE owner_id IN ('d1500000-0000-0000-0000-000000000001', 'd1500000-0000-0000-0000-000000000002') AND id <> 'd1520000-0000-0000-0000-000000000008';
UPDATE public.expense_entries SET updated_at = pg_catalog.now() - INTERVAL '13 months'
WHERE owner_id IN ('d1500000-0000-0000-0000-000000000001', 'd1500000-0000-0000-0000-000000000002') AND id <> 'd1520000-0000-0000-0000-000000000005';
UPDATE public.expense_entries SET updated_at = pg_catalog.now() - INTERVAL '11 months'
WHERE id = 'd1520000-0000-0000-0000-000000000005';
UPDATE public.investment_allocations SET updated_at = pg_catalog.now() - INTERVAL '13 months'
WHERE owner_id IN ('d1500000-0000-0000-0000-000000000001', 'd1500000-0000-0000-0000-000000000002');
UPDATE public.audit_events SET occurred_at = pg_catalog.now() - INTERVAL '13 months'
WHERE owner_id IN ('d1500000-0000-0000-0000-000000000001', 'd1500000-0000-0000-0000-000000000002') AND entity_id <> 'd1520000-0000-0000-0000-000000000008';
UPDATE public.applied_sync_operations SET applied_at = pg_catalog.now() - INTERVAL '13 months'
WHERE idempotency_key = 'd1510000-0000-0000-0000-000000000001';

DO $test$
DECLARE
    a CONSTANT UUID := 'd1500000-0000-0000-0000-000000000001';
    b CONSTANT UUID := 'd1500000-0000-0000-0000-000000000002';
    r JSONB;
    again JSONB;
    occurrences_before BIGINT;
    occurrences_after BIGINT;
BEGIN
    IF pg_catalog.has_function_privilege('anon', 'public.purge_expired_records(timestamptz,uuid)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('authenticated', 'public.purge_expired_records(timestamptz,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'purge must not be callable by clients';
    END IF;

    SELECT pg_catalog.count(*) INTO occurrences_before FROM public.expense_entries
    WHERE recurrence_template_id = 'd1530000-0000-0000-0000-000000000001';

    -- Limpeza só de uma conta (B) não toca nas outras.
    r := public.purge_expired_records(NULL, b);
    IF (r ->> 'income_entries')::INT <> 1
        OR EXISTS (SELECT 1 FROM public.income_entries WHERE id = 'd1520000-0000-0000-0000-000000000007')
        OR NOT EXISTS (SELECT 1 FROM public.income_entries WHERE id = 'd1520000-0000-0000-0000-000000000001')
        OR NOT EXISTS (SELECT 1 FROM public.audit_events WHERE owner_id = a
            AND occurred_at < pg_catalog.now() - INTERVAL '12 months') THEN
        RAISE EXCEPTION 'owner-scoped purge must only touch that account: %', r;
    END IF;

    r := public.purge_expired_records();
    -- Limites inferiores: num banco com outras contas a limpeza também as alcança.
    IF (r ->> 'income_entries')::INT < 1 OR (r ->> 'expense_entries')::INT < 1
        OR (r ->> 'investment_allocations')::INT < 1 OR (r ->> 'applied_sync_operations')::INT < 1
        OR (r ->> 'audit_events')::INT < 1 THEN
        RAISE EXCEPTION 'unexpected purge counts: %', r;
    END IF;

    -- Saíram: os três avulsos cancelados antigos de A e o de B.
    IF EXISTS (SELECT 1 FROM public.income_entries WHERE id IN (
            'd1520000-0000-0000-0000-000000000001', 'd1520000-0000-0000-0000-000000000007'))
        OR EXISTS (SELECT 1 FROM public.expense_entries WHERE id = 'd1520000-0000-0000-0000-000000000002')
        OR EXISTS (SELECT 1 FROM public.investment_allocations WHERE id = 'd1520000-0000-0000-0000-000000000003') THEN
        RAISE EXCEPTION 'old cancelled one-time entries must be purged';
    END IF;

    -- Ficaram: ativa antiga, cancelada recente, conflito aberto, ocorrência.
    IF NOT EXISTS (SELECT 1 FROM public.expense_entries WHERE id = 'd1520000-0000-0000-0000-000000000004')
        OR NOT EXISTS (SELECT 1 FROM public.expense_entries WHERE id = 'd1520000-0000-0000-0000-000000000005')
        OR NOT EXISTS (SELECT 1 FROM public.expense_entries WHERE id = 'd1520000-0000-0000-0000-000000000006')
        OR NOT EXISTS (SELECT 1 FROM public.expense_entries
            WHERE id = public.recurrence_occurrence_id('d1530000-0000-0000-0000-000000000001', '2025-02-05')
              AND status = 'cancelled')
        OR NOT EXISTS (SELECT 1 FROM public.income_entries WHERE id = 'd1520000-0000-0000-0000-000000000008') THEN
        RAISE EXCEPTION 'active, recent, conflicted or recurring records must be kept';
    END IF;
    SELECT pg_catalog.count(*) INTO occurrences_after FROM public.expense_entries
    WHERE recurrence_template_id = 'd1530000-0000-0000-0000-000000000001';
    IF occurrences_after <> occurrences_before THEN
        RAISE EXCEPTION 'recurrence occurrences must not be purged';
    END IF;

    -- Auditoria: antiga saiu, recente (lançamento atual de B) ficou.
    IF EXISTS (SELECT 1 FROM public.audit_events WHERE owner_id IN (a, b)
            AND occurred_at < pg_catalog.now() - INTERVAL '12 months')
        OR NOT EXISTS (SELECT 1 FROM public.audit_events WHERE entity_id = 'd1520000-0000-0000-0000-000000000008') THEN
        RAISE EXCEPTION 'audit retention is wrong';
    END IF;
    -- Conflito aberto não é apagado pela limpeza.
    IF NOT EXISTS (SELECT 1 FROM public.sync_conflicts WHERE owner_id = a AND status = 'open') THEN
        RAISE EXCEPTION 'open conflict must be kept';
    END IF;
    -- Resposta antiga sem conteúdo, chave mantida.
    IF (SELECT result_payload FROM public.applied_sync_operations
        WHERE owner_id = a AND idempotency_key = 'd1510000-0000-0000-0000-000000000001')
        IS DISTINCT FROM '{"expired": true}'::JSONB THEN
        RAISE EXCEPTION 'old operation response must be emptied';
    END IF;

    -- Repetir não apaga mais nada.
    again := public.purge_expired_records();
    IF (again ->> 'income_entries')::INT + (again ->> 'expense_entries')::INT
        + (again ->> 'investment_allocations')::INT + (again ->> 'audit_events')::INT
        + (again ->> 'sync_conflicts')::INT + (again ->> 'applied_sync_operations')::INT <> 0 THEN
        RAISE EXCEPTION 'purge must be idempotent: %', again;
    END IF;

    -- Conflito resolvido há mais de 12 meses sai.
    UPDATE public.sync_conflicts SET status = 'resolved', resolution_payload = '{}'::JSONB,
        resolved_at = pg_catalog.now() - INTERVAL '13 months'
    WHERE owner_id = a AND status = 'open';
    r := public.purge_expired_records();
    IF (r ->> 'sync_conflicts')::INT < 1
        OR EXISTS (SELECT 1 FROM public.sync_conflicts WHERE owner_id = a)
        OR EXISTS (SELECT 1 FROM public.expense_entries WHERE id = 'd1520000-0000-0000-0000-000000000006') THEN
        RAISE EXCEPTION 'resolved conflict and its entry must go after 12 months: %', r;
    END IF;
END;
$test$;

SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    a CONSTANT UUID := 'd1500000-0000-0000-0000-000000000001';
    r JSONB;
BEGIN
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', a::TEXT, TRUE);

    -- Aparelho que reenvia a criação de mais de 12 meses: recusado, sem
    -- ressuscitar o lançamento apagado.
    BEGIN
        PERFORM public.apply_income_entry_change('d1510000-0000-0000-0000-000000000001', 'create',
            'd1520000-0000-0000-0000-000000000001', 0,
            '{"amount_centavos":1000,"received_on":"2025-01-10","description":"Antiga"}'::JSONB);
        RAISE EXCEPTION 'expired replay must be refused';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;
    IF EXISTS (SELECT 1 FROM public.income_entries WHERE id = 'd1520000-0000-0000-0000-000000000001') THEN
        RAISE EXCEPTION 'purged entry must not come back';
    END IF;

    -- Aparelho parado que edita um lançamento já apagado: recusado.
    BEGIN
        PERFORM public.apply_expense_entry_change('d1510000-0000-0000-0000-000000000019', 'update',
            'd1520000-0000-0000-0000-000000000002', 1, '{"amount_centavos":2100}'::JSONB);
        RAISE EXCEPTION 'edit of a purged entry must be refused';
    EXCEPTION WHEN no_data_found THEN
        NULL;
    END;

    -- O gerador não recria a ocorrência cancelada (ela continua guardada).
    r := public.generate_due_recurrence_occurrences('d1510000-0000-0000-0000-000000000020');
    IF EXISTS (SELECT 1 FROM public.expense_entries
        WHERE id = public.recurrence_occurrence_id('d1530000-0000-0000-0000-000000000001', '2025-02-05')
          AND status <> 'cancelled') THEN
        RAISE EXCEPTION 'cancelled occurrence must stay cancelled';
    END IF;
END;
$test$;

RESET ROLE;
ROLLBACK;

SELECT 'RETENTION_PURGE_OK' AS result;
