\set ON_ERROR_STOP on

-- Importação CSV (IM5/IM6): começar, blocos, terminar, reenvio, falha que
-- desfaz o bloco, conflito interno, atrasadas uma vez, desfazer condicional,
-- isolamento, volume e exclusão de conta. Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('a7000000-0000-0000-0000-000000000001'),
    ('a7000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config('request.jwt.claim.sub', 'a7000000-0000-0000-0000-000000000001', TRUE);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    b UUID := 'b7000000-0000-4000-8000-000000000001';
    today DATE := pg_catalog.timezone('America/Sao_Paulo', pg_catalog.clock_timestamp())::DATE;
    d1 DATE := (pg_catalog.date_trunc('month', today) - INTERVAL '1 month')::DATE;
    sha TEXT := pg_catalog.repeat('ab', 32);
    r JSONB;
    replay JSONB;
    items0 JSONB;
    n BIGINT;
BEGIN
    -- Funções internas não ficam expostas; as públicas não valem para anon.
    IF pg_catalog.has_function_privilege('authenticated',
        'public.import_apply_item(uuid,uuid,jsonb,date)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('authenticated',
        'public.import_undo_run(uuid,uuid,boolean,integer)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('anon',
        'public.import_apply_chunk(uuid,integer,jsonb)', 'EXECUTE') THEN
        RAISE EXCEPTION 'internal import functions must not be executable';
    END IF;

    -- Categoria que será desativada (para o caso de falha).
    r := public.apply_category_change('c7000000-0000-0000-0000-000000000001', 'create',
        'c7000000-0000-0000-0000-0000000000aa', 0, 'expense', 'Velha');
    r := public.apply_category_change('c7000000-0000-0000-0000-000000000002', 'deactivate',
        'c7000000-0000-0000-0000-0000000000aa', 1, NULL, NULL);

    r := public.import_begin_batch('e7000000-0000-0000-0000-000000000001', b,
        pg_catalog.jsonb_build_object('name', 'extrato.csv', 'sha256', sha, 'size_bytes', 123, 'rows', 6),
        '{"version": 1, "allow_duplicate_file": false}', pg_catalog.repeat('cd', 32), 2, 6,
        '{"rejected": 1, "cancelled": 2}');
    IF r ->> 'status' <> 'applied' OR r #>> '{batch,status}' <> 'processing' THEN
        RAISE EXCEPTION 'begin failed: %', r;
    END IF;
    replay := public.import_begin_batch('e7000000-0000-0000-0000-000000000001', b,
        pg_catalog.jsonb_build_object('name', 'extrato.csv', 'sha256', sha, 'size_bytes', 123, 'rows', 6),
        '{"version": 1, "allow_duplicate_file": false}', pg_catalog.repeat('cd', 32), 2, 6,
        '{"rejected": 1, "cancelled": 2}');
    IF replay IS DISTINCT FROM r THEN
        RAISE EXCEPTION 'begin replay must return the stored response';
    END IF;
    r := public.import_begin_batch('e7000000-0000-0000-0000-000000000002',
        'b7000000-0000-4000-8000-000000000009',
        pg_catalog.jsonb_build_object('name', 'x.csv', 'sha256', pg_catalog.repeat('ef', 32),
            'size_bytes', 1, 'rows', 1), '{}', pg_catalog.repeat('cd', 32), 1, 1, NULL);
    IF r ->> 'status' <> 'blocked' OR r ->> 'reason' <> 'in_progress' THEN
        RAISE EXCEPTION 'second open import must be blocked: %', r;
    END IF;

    items0 := pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('type', 'category', 'id', 'c7000000-0000-0000-0000-000000000011',
            'kind', 'expense', 'name', 'Mercado'),
        pg_catalog.jsonb_build_object('type', 'subcategory', 'id', 'c7000000-0000-0000-0000-000000000012',
            'category_id', 'c7000000-0000-0000-0000-000000000011', 'name', 'Feira'),
        pg_catalog.jsonb_build_object('type', 'income', 'id', 'd7000000-0000-0000-0000-000000000001',
            'row', 2, 'description', 'Salário', 'amount_centavos', 500000, 'received_on', d1,
            'category_id', NULL, 'subcategory_id', NULL),
        pg_catalog.jsonb_build_object('type', 'expense', 'id', 'd7000000-0000-0000-0000-000000000002',
            'row', 3, 'description', 'Feira', 'amount_centavos', 12345, 'competence_on', d1,
            'due_on', NULL, 'paid_on', d1,
            'category_id', 'c7000000-0000-0000-0000-000000000011',
            'subcategory_id', 'c7000000-0000-0000-0000-000000000012'),
        pg_catalog.jsonb_build_object('type', 'investment', 'id', 'd7000000-0000-0000-0000-000000000003',
            'row', 4, 'amount_centavos', 30000, 'allocated_on', d1));
    r := public.import_apply_chunk(b, 0, items0);
    IF r ->> 'status' <> 'applied' OR (r ->> 'replayed')::BOOLEAN THEN
        RAISE EXCEPTION 'chunk 0 failed: %', r;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.expense_entries x
        WHERE x.id = 'd7000000-0000-0000-0000-000000000002' AND x.status = 'paid'
          AND x.version = 2 AND x.subcategory_id = 'c7000000-0000-0000-0000-000000000012') THEN
        RAISE EXCEPTION 'imported paid expense must be paid at version 2';
    END IF;
    IF (SELECT i.version_after_import FROM public.import_batch_items i
        WHERE i.entity_id = 'd7000000-0000-0000-0000-000000000002') <> 2 THEN
        RAISE EXCEPTION 'item must keep the version right after the import';
    END IF;

    -- Reenvio do mesmo bloco: nada muda.
    SELECT pg_catalog.count(*) INTO n FROM public.audit_events;
    r := public.import_apply_chunk(b, 0, items0);
    IF NOT (r ->> 'replayed')::BOOLEAN THEN
        RAISE EXCEPTION 'chunk replay must be recognized: %', r;
    END IF;
    IF (SELECT pg_catalog.count(*) FROM public.audit_events) <> n THEN
        RAISE EXCEPTION 'chunk replay must not write again';
    END IF;
    -- Mesmo índice, conteúdo diferente: recusa.
    BEGIN
        PERFORM public.import_apply_chunk(b, 0, items0 - 0);
        RAISE EXCEPTION 'different content must be rejected';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
END;
$test$;

-- Bloco que falha volta inteiro: conflito interno (id já existe) e categoria
-- desativada. A importação fica interrompida com a linha.
DO $test$
DECLARE
    b UUID := 'b7000000-0000-4000-8000-000000000001';
    today DATE := pg_catalog.timezone('America/Sao_Paulo', pg_catalog.clock_timestamp())::DATE;
    d1 DATE := (pg_catalog.date_trunc('month', today) - INTERVAL '1 month')::DATE;
    series JSONB;
    r JSONB;
BEGIN
    series := pg_catalog.jsonb_build_object('type', 'series', 'kind', 'expense',
        'template_id', 'f7000000-0000-0000-0000-000000000001',
        'id', 'd7000000-0000-0000-0000-000000000004', 'row', 5, 'state', 'paid',
        'entry', pg_catalog.jsonb_build_object('description', 'Aluguel', 'amount_centavos', 10000,
            'competence_on', d1, 'due_on', NULL, 'paid_on', d1, 'category_id', NULL,
            'subcategory_id', NULL),
        'template', pg_catalog.jsonb_build_object('description', 'Aluguel', 'frequency', 'monthly',
            'starts_on', d1, 'monthly_reference_day', EXTRACT(day FROM d1)::INTEGER,
            'value_mode', 'fixed', 'default_amount_centavos', 10000,
            'category_id', NULL, 'subcategory_id', NULL));

    r := public.import_apply_chunk(b, 1, pg_catalog.jsonb_build_array(series,
        pg_catalog.jsonb_build_object('type', 'expense', 'id', 'd7000000-0000-0000-0000-000000000002',
            'row', 9, 'description', 'Repetida', 'amount_centavos', 1, 'competence_on', d1,
            'due_on', NULL, 'paid_on', NULL, 'category_id', NULL, 'subcategory_id', NULL)));
    IF r ->> 'status' <> 'failed' OR (r ->> 'row')::INTEGER <> 9 THEN
        RAISE EXCEPTION 'conflicting item must fail the chunk with its row: %', r;
    END IF;
    IF EXISTS (SELECT 1 FROM public.expense_entries e WHERE e.id = 'd7000000-0000-0000-0000-000000000004')
        OR EXISTS (SELECT 1 FROM public.expense_recurrence_templates t
            WHERE t.id = 'f7000000-0000-0000-0000-000000000001')
        OR EXISTS (SELECT 1 FROM public.sync_conflicts)
        OR EXISTS (SELECT 1 FROM public.import_batch_chunks c WHERE c.chunk_index = 1) THEN
        RAISE EXCEPTION 'failed chunk must be rolled back entirely (no conflict left behind)';
    END IF;
    IF (SELECT b2.status FROM public.import_batches b2 WHERE b2.id = b) <> 'interrupted'
        OR (SELECT (b2.last_error ->> 'row')::INTEGER FROM public.import_batches b2 WHERE b2.id = b) <> 9 THEN
        RAISE EXCEPTION 'batch must be interrupted with the failing row';
    END IF;

    r := public.import_apply_chunk(b, 1, pg_catalog.jsonb_build_array(series,
        pg_catalog.jsonb_build_object('type', 'expense', 'id', 'd7000000-0000-0000-0000-000000000005',
            'row', 10, 'description', 'X', 'amount_centavos', 1, 'competence_on', d1,
            'due_on', NULL, 'paid_on', NULL,
            'category_id', 'c7000000-0000-0000-0000-0000000000aa', 'subcategory_id', NULL)));
    IF r ->> 'status' <> 'failed' OR (r ->> 'row')::INTEGER <> 10 THEN
        RAISE EXCEPTION 'inactive category must fail the chunk: %', r;
    END IF;

    -- Validação repetida no servidor: valor acima do teto.
    r := public.import_apply_chunk(b, 1, pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('type', 'investment', 'id', 'd7000000-0000-0000-0000-000000000006',
            'row', 11, 'amount_centavos', 1000000001, 'allocated_on', d1)));
    IF r ->> 'status' <> 'failed' OR r ->> 'message' NOT LIKE 'Valor fora da faixa%' THEN
        RAISE EXCEPTION 'server must repeat the value limit: %', r;
    END IF;

    -- Retomada: o bloco certo entra; a importação volta a andar.
    r := public.import_apply_chunk(b, 1, pg_catalog.jsonb_build_array(series));
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'resumed chunk failed: %', r;
    END IF;
    IF (SELECT b2.status FROM public.import_batches b2 WHERE b2.id = b) <> 'processing' THEN
        RAISE EXCEPTION 'resume must put the batch back in processing';
    END IF;
END;
$test$;

-- Terminar: atrasadas uma única vez, resumo e reenvio.
DO $test$
DECLARE
    b UUID := 'b7000000-0000-4000-8000-000000000001';
    today DATE := pg_catalog.timezone('America/Sao_Paulo', pg_catalog.clock_timestamp())::DATE;
    d1 DATE := (pg_catalog.date_trunc('month', today) - INTERVAL '1 month')::DATE;
    r JSONB;
    n BIGINT;
BEGIN
    r := public.import_finish_batch('e7000000-0000-0000-0000-000000000010', b);
    IF r ->> 'status' <> 'completed'
        OR (r #>> '{batch,result,recurrences}')::INTEGER <> 1
        OR (r #>> '{batch,result,occurrences}')::INTEGER <> 1
        OR (r #>> '{batch,result,expenses}')::INTEGER <> 2
        OR (r #>> '{batch,result,categories}')::INTEGER <> 1 THEN
        RAISE EXCEPTION 'finish result incorrect: %', r;
    END IF;
    SELECT pg_catalog.count(*) INTO n FROM public.expense_entries e
    WHERE e.recurrence_template_id = 'f7000000-0000-0000-0000-000000000001';
    IF n <> 2 THEN
        RAISE EXCEPTION 'anchor plus one overdue occurrence expected, got %', n;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.expense_entries e
        WHERE e.id = public.recurrence_occurrence_id('f7000000-0000-0000-0000-000000000001',
            (pg_catalog.date_trunc('month', today))::DATE)
          AND e.status = 'pending' AND e.amount_centavos = 10000) THEN
        RAISE EXCEPTION 'overdue occurrence must exist for the current month';
    END IF;
    r := public.import_finish_batch('e7000000-0000-0000-0000-000000000010', b);
    SELECT pg_catalog.count(*) INTO n FROM public.expense_entries e
    WHERE e.recurrence_template_id = 'f7000000-0000-0000-0000-000000000001';
    IF r ->> 'status' <> 'completed' OR n <> 2 THEN
        RAISE EXCEPTION 'finish replay must not generate again';
    END IF;
    -- A âncora virou a primeira ocorrência, paga.
    IF NOT EXISTS (SELECT 1 FROM public.expense_entries e
        WHERE e.id = 'd7000000-0000-0000-0000-000000000004' AND e.status = 'paid'
          AND e.scheduled_for_date = d1) THEN
        RAISE EXCEPTION 'anchor must be the paid first occurrence';
    END IF;

    -- Mesmo arquivo de novo: só com confirmação explícita no plano.
    r := public.import_begin_batch('e7000000-0000-0000-0000-000000000020',
        'b7000000-0000-4000-8000-000000000002',
        pg_catalog.jsonb_build_object('name', 'extrato.csv', 'sha256', pg_catalog.repeat('ab', 32),
            'size_bytes', 123, 'rows', 6), '{"allow_duplicate_file": false}',
        pg_catalog.repeat('cd', 32), 1, 1, NULL);
    IF r ->> 'status' <> 'blocked' OR r ->> 'reason' <> 'file_already_imported' THEN
        RAISE EXCEPTION 'same file must be blocked without confirmation: %', r;
    END IF;

    -- Edição posterior: a receita importada muda (será preservada).
    r := public.apply_income_entry_change('e7000000-0000-0000-0000-000000000030', 'update',
        'd7000000-0000-0000-0000-000000000001', 1, '{"description": "Salário de outubro"}');
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'user edit failed: %', r;
    END IF;
END;
$test$;

-- Simula ocorrência gerada depois pelo app (fora da lista da importação).
RESET ROLE;
DELETE FROM public.import_batch_items i
WHERE i.batch_id = 'b7000000-0000-4000-8000-000000000001' AND i.role = 'occurrence';
SET LOCAL ROLE authenticated;

-- Desfazer condicional: prévia, partes, resultado e repetição.
DO $test$
DECLARE
    b UUID := 'b7000000-0000-4000-8000-000000000001';
    today DATE := pg_catalog.timezone('America/Sao_Paulo', pg_catalog.clock_timestamp())::DATE;
    occ UUID := public.recurrence_occurrence_id('f7000000-0000-0000-0000-000000000001',
        (pg_catalog.date_trunc('month', today))::DATE);
    r JSONB;
    n BIGINT;
    loops INTEGER := 0;
BEGIN
    r := public.import_undo_preview(b);
    IF (r #>> '{counts,cancelled}')::INTEGER <> 4
        OR (r #>> '{counts,deactivated}')::INTEGER <> 3
        OR (r #>> '{counts,preserved_changed}')::INTEGER <> 1
        OR r #>> '{preserved,0,entity_id}' <> 'd7000000-0000-0000-0000-000000000001' THEN
        RAISE EXCEPTION 'undo preview incorrect: %', r;
    END IF;
    -- A prévia não muda nada.
    IF EXISTS (SELECT 1 FROM public.import_batch_items i WHERE i.undo_outcome IS NOT NULL)
        OR (SELECT b2.status FROM public.import_batches b2 WHERE b2.id = b) <> 'completed' THEN
        RAISE EXCEPTION 'preview must be read-only';
    END IF;

    LOOP
        loops := loops + 1;
        r := public.import_undo_batch(b, 2);
        EXIT WHEN NOT (r ->> 'remaining')::BOOLEAN OR loops > 10;
        IF r ->> 'status' <> 'undoing' THEN
            RAISE EXCEPTION 'partial undo must keep undoing: %', r;
        END IF;
    END LOOP;
    IF loops < 3 OR r ->> 'status' <> 'partially_undone'
        OR (r #>> '{counts,cancelled}')::INTEGER <> 4
        OR (r #>> '{counts,deactivated}')::INTEGER <> 3
        OR (r #>> '{counts,preserved_changed}')::INTEGER <> 1 THEN
        RAISE EXCEPTION 'undo result incorrect after % calls: %', loops, r;
    END IF;

    IF (SELECT e.status FROM public.expense_entries e WHERE e.id = 'd7000000-0000-0000-0000-000000000002') <> 'cancelled'
        OR (SELECT e.status FROM public.expense_entries e WHERE e.id = 'd7000000-0000-0000-0000-000000000004') <> 'cancelled'
        OR (SELECT e.status FROM public.expense_entries e WHERE e.id = occ) <> 'cancelled'
        OR (SELECT a.cancelled_at IS NULL FROM public.investment_allocations a
            WHERE a.id = 'd7000000-0000-0000-0000-000000000003')
        OR (SELECT t.is_active FROM public.expense_recurrence_templates t
            WHERE t.id = 'f7000000-0000-0000-0000-000000000001')
        OR (SELECT c.is_active FROM public.categories c WHERE c.id = 'c7000000-0000-0000-0000-000000000011')
        OR (SELECT s.is_active FROM public.subcategories s WHERE s.id = 'c7000000-0000-0000-0000-000000000012')
        OR (SELECT e.status FROM public.income_entries e WHERE e.id = 'd7000000-0000-0000-0000-000000000001') <> 'received' THEN
        RAISE EXCEPTION 'undo did not cancel/deactivate/preserve the right items';
    END IF;
    -- Ocorrência gerada depois foi incluída e cancelada (RN055).
    IF NOT EXISTS (SELECT 1 FROM public.import_batch_items i
        WHERE i.entity_id = occ AND i.undo_outcome = 'cancelled') THEN
        RAISE EXCEPTION 'later occurrence must be adopted and cancelled';
    END IF;
    -- Nada apagado e nenhum conflito falso.
    IF EXISTS (SELECT 1 FROM public.sync_conflicts) THEN
        RAISE EXCEPTION 'undo must not create false conflicts';
    END IF;

    SELECT pg_catalog.count(*) INTO n FROM public.audit_events;
    r := public.import_undo_batch(b, 50);
    IF r ->> 'remaining' <> 'false' OR (SELECT pg_catalog.count(*) FROM public.audit_events) <> n THEN
        RAISE EXCEPTION 'repeated undo must not change anything: %', r;
    END IF;
END;
$test$;

-- Modelo alterado preserva suas ocorrências; categoria em uso fica.
DO $test$
DECLARE
    b UUID := 'b7000000-0000-4000-8000-000000000002';
    today DATE := pg_catalog.timezone('America/Sao_Paulo', pg_catalog.clock_timestamp())::DATE;
    d1 DATE := (pg_catalog.date_trunc('month', today) - INTERVAL '1 month')::DATE;
    r JSONB;
BEGIN
    r := public.import_begin_batch('e7000000-0000-0000-0000-000000000040', b,
        pg_catalog.jsonb_build_object('name', 'extrato.csv', 'sha256', pg_catalog.repeat('ab', 32),
            'size_bytes', 123, 'rows', 6), '{"allow_duplicate_file": true}',
        pg_catalog.repeat('cd', 32), 1, 2, NULL);
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'confirmed duplicate file must be accepted: %', r;
    END IF;
    r := public.import_apply_chunk(b, 0, pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('type', 'category', 'id', 'c7000000-0000-0000-0000-000000000021',
            'kind', 'income', 'name', 'Aluguéis'),
        pg_catalog.jsonb_build_object('type', 'series', 'kind', 'income',
            'template_id', 'f7000000-0000-0000-0000-000000000002',
            'id', 'd7000000-0000-0000-0000-000000000021', 'row', 2, 'state', 'received',
            'entry', pg_catalog.jsonb_build_object('description', 'Aluguel recebido',
                'amount_centavos', 7000, 'received_on', d1,
                'category_id', 'c7000000-0000-0000-0000-000000000021', 'subcategory_id', NULL),
            'template', pg_catalog.jsonb_build_object('description', 'Aluguel recebido',
                'frequency', 'monthly', 'starts_on', d1,
                'monthly_reference_day', EXTRACT(day FROM d1)::INTEGER, 'value_mode', 'fixed',
                'default_amount_centavos', 7000,
                'category_id', 'c7000000-0000-0000-0000-000000000021', 'subcategory_id', NULL))));
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'income series chunk failed: %', r;
    END IF;
    r := public.import_finish_batch('e7000000-0000-0000-0000-000000000041', b);
    IF (r #>> '{batch,result,occurrences}')::INTEGER <> 1 THEN
        RAISE EXCEPTION 'income occurrence expected: %', r;
    END IF;

    -- Usuário altera o modelo e lança outra receita na categoria importada.
    r := public.apply_income_recurrence_template_change('e7000000-0000-0000-0000-000000000042',
        'update', 'f7000000-0000-0000-0000-000000000002', 1, '{"description": "Aluguel apto"}');
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'template edit failed: %', r;
    END IF;
    r := public.apply_income_entry_change('e7000000-0000-0000-0000-000000000043', 'create',
        'd7000000-0000-0000-0000-000000000029', 0, pg_catalog.jsonb_build_object(
            'description', 'Outra', 'amount_centavos', 1, 'received_on', d1,
            'category_id', 'c7000000-0000-0000-0000-000000000021'));

    r := public.import_undo_batch(b, 100);
    IF r ->> 'status' <> 'partially_undone'
        OR (r #>> '{counts,preserved_changed}')::INTEGER <> 3
        OR (r #>> '{counts,preserved_in_use}')::INTEGER <> 1
        OR r #> '{counts,cancelled}' IS NOT NULL THEN
        RAISE EXCEPTION 'changed template must preserve everything: %', r;
    END IF;
    IF NOT (SELECT t.is_active FROM public.income_recurrence_templates t
        WHERE t.id = 'f7000000-0000-0000-0000-000000000002') THEN
        RAISE EXCEPTION 'changed template must stay active';
    END IF;
END;
$test$;

-- Isolamento: outro usuário não vê nem mexe na importação do primeiro.
SELECT pg_catalog.set_config('request.jwt.claim.sub', 'a7000000-0000-0000-0000-000000000002', TRUE);

DO $test$
DECLARE
    r JSONB;
BEGIN
    IF EXISTS (SELECT 1 FROM public.import_batches)
        OR EXISTS (SELECT 1 FROM public.import_batch_items)
        OR EXISTS (SELECT 1 FROM public.import_batch_chunks) THEN
        RAISE EXCEPTION 'second user must not read other imports';
    END IF;
    BEGIN
        PERFORM public.import_undo_preview('b7000000-0000-4000-8000-000000000001');
        RAISE EXCEPTION 'preview of another user import must fail';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
    BEGIN
        PERFORM public.import_undo_batch('b7000000-0000-4000-8000-000000000001', 10);
        RAISE EXCEPTION 'undo of another user import must fail';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
    BEGIN
        PERFORM public.import_apply_chunk('b7000000-0000-4000-8000-000000000001', 0, '[{"type": "x"}]');
        RAISE EXCEPTION 'chunk on another user import must fail';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
    -- O mesmo arquivo do outro usuário não conta como já importado.
    r := public.import_begin_batch('e7000000-0000-0000-0000-000000000050',
        'b7000000-0000-4000-8000-000000000003',
        pg_catalog.jsonb_build_object('name', 'extrato.csv', 'sha256', pg_catalog.repeat('ab', 32),
            'size_bytes', 123, 'rows', 6), '{}', pg_catalog.repeat('cd', 32), 0, 0, NULL);
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'other user must import independently: %', r;
    END IF;
    r := public.import_finish_batch('e7000000-0000-0000-0000-000000000051',
        'b7000000-0000-4000-8000-000000000003');
    IF r ->> 'status' <> 'completed' THEN
        RAISE EXCEPTION 'empty import must complete: %', r;
    END IF;
END;
$test$;

-- Volume: o fim gera para todos os modelos do usuário, mês a mês (V25).
DO $test$
DECLARE
    i INTEGER;
    r JSONB;
    t0 TIMESTAMPTZ;
    elapsed INTERVAL;
BEGIN
    FOR i IN 1..60 LOOP
        r := public.apply_expense_recurrence_template_change(
            pg_catalog.md5('vol-op-' || i)::UUID, 'create', pg_catalog.md5('vol-tpl-' || i)::UUID, 0,
            pg_catalog.jsonb_build_object('description', 'Série ' || i, 'frequency', 'monthly',
                'starts_on', '2015-01-05', 'monthly_reference_day', 5, 'value_mode', 'fixed',
                'default_amount_centavos', 100));
    END LOOP;
    r := public.generate_due_recurrence_occurrences('e7000000-0000-0000-0000-000000000060');
    r := public.import_begin_batch('e7000000-0000-0000-0000-000000000061',
        'b7000000-0000-4000-8000-000000000004',
        pg_catalog.jsonb_build_object('name', 'v.csv', 'sha256', pg_catalog.repeat('99', 32),
            'size_bytes', 1, 'rows', 1), '{}', pg_catalog.repeat('cd', 32), 1, 1, NULL);
    r := public.import_apply_chunk('b7000000-0000-4000-8000-000000000004', 0,
        pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('type', 'investment',
            'id', 'd7000000-0000-0000-0000-000000000099', 'row', 2,
            'amount_centavos', 1, 'allocated_on', '2020-01-01')));
    t0 := pg_catalog.clock_timestamp();
    r := public.import_finish_batch('e7000000-0000-0000-0000-000000000062',
        'b7000000-0000-4000-8000-000000000004');
    elapsed := pg_catalog.clock_timestamp() - t0;
    RAISE NOTICE 'import finish with 60 templates since 2015: %', elapsed;
    IF r ->> 'status' <> 'completed' OR elapsed > INTERVAL '20 seconds' THEN
        RAISE EXCEPTION 'finish too slow or failed: % %', elapsed, r;
    END IF;
END;
$test$;

-- Exclusão de conta inclui a importação.
SELECT pg_catalog.set_config('request.jwt.claim.sub', 'a7000000-0000-0000-0000-000000000001', TRUE);
SELECT public.delete_my_account('DELETE_MY_ACCOUNT');
RESET ROLE;
DO $test$
BEGIN
    IF EXISTS (SELECT 1 FROM public.import_batches WHERE owner_id = 'a7000000-0000-0000-0000-000000000001')
        OR EXISTS (SELECT 1 FROM public.import_batch_items WHERE owner_id = 'a7000000-0000-0000-0000-000000000001')
        OR EXISTS (SELECT 1 FROM public.import_batch_chunks WHERE owner_id = 'a7000000-0000-0000-0000-000000000001') THEN
        RAISE EXCEPTION 'account deletion must remove imports';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.import_batches WHERE owner_id = 'a7000000-0000-0000-0000-000000000002') THEN
        RAISE EXCEPTION 'other user imports must stay';
    END IF;
END;
$test$;

SELECT 'RPC_IMPORT_OK' AS result;

ROLLBACK;
