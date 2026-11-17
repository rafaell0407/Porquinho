\set ON_ERROR_STOP on

-- Gestão de Faturas de Cartões (GF2.1–GF2.7): tabelas, RLS, RPCs de
-- cadastros, pagamento, desfazer, pagamento duplicado, isolamento e excluir
-- conta. Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('a1000000-0000-0000-0000-000000000001'),
    ('a1000000-0000-0000-0000-000000000002');

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', TRUE);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    r JSONB;
    replay JSONB;
    n BIGINT;
    v_text TEXT;
    v_card CONSTANT TEXT := 'c0000000-0000-0000-0000-000000000001';
    v_purchase CONSTANT TEXT := 'c0000000-0000-0000-0000-000000000002';
    v_inst1 CONSTANT TEXT := 'c0000000-0000-0000-0000-000000000003';
    v_inst2 CONSTANT TEXT := 'c0000000-0000-0000-0000-000000000004';
    v_sub CONSTANT TEXT := 'c0000000-0000-0000-0000-000000000005';
    v_charge CONSTANT TEXT := 'c0000000-0000-0000-0000-000000000006';
    v_invoice CONSTANT TEXT := 'c0000000-0000-0000-0000-000000000007';
    v_changes JSONB;
    v_paid JSONB;
BEGIN
    IF pg_catalog.has_function_privilege('anon', 'public.card_bills_apply(uuid,jsonb,text)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('anon', 'public.card_bills_pay_invoice(uuid,jsonb,jsonb,uuid,jsonb,text)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('authenticated', 'public.card_bills_claim_operation(uuid,uuid,jsonb)', 'EXECUTE')
        OR pg_catalog.has_function_privilege('authenticated', 'public.card_bills_insert_event(uuid,jsonb,text,uuid,bigint)', 'EXECUTE')
    THEN
        RAISE EXCEPTION 'anonymous or helper execution must be revoked';
    END IF;

    -- Cartão, compra com 2 parcelas, assinatura e cobrança.
    v_changes := pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('table', 'card_bill_cards', 'row', pg_catalog.jsonb_build_object(
            'id', v_card, 'name', 'Nubank', 'closing_day', 10, 'due_day', 17)),
        pg_catalog.jsonb_build_object('table', 'card_bill_purchases', 'row', pg_catalog.jsonb_build_object(
            'id', v_purchase, 'card_id', v_card, 'description', 'TV',
            'purchased_on', '2026-11-16', 'installment_count', 2, 'amount_mode', 'total')),
        pg_catalog.jsonb_build_object('table', 'card_bill_installments', 'row', pg_catalog.jsonb_build_object(
            'id', v_inst1, 'purchase_id', v_purchase, 'number', 1, 'card_id', v_card,
            'invoice_month', '2026-12', 'amount_centavos', '50001',
            'manually_edited', FALSE, 'paid_outside', FALSE)),
        pg_catalog.jsonb_build_object('table', 'card_bill_installments', 'row', pg_catalog.jsonb_build_object(
            'id', v_inst2, 'purchase_id', v_purchase, 'number', 2, 'card_id', v_card,
            'invoice_month', '2027-01', 'amount_centavos', '50000',
            'manually_edited', FALSE, 'paid_outside', FALSE)),
        pg_catalog.jsonb_build_object('table', 'card_bill_subscriptions', 'row', pg_catalog.jsonb_build_object(
            'id', v_sub, 'card_id', v_card, 'description', 'Streaming',
            'monthly_amount_centavos', '3990', 'start_month', '2026-12')),
        pg_catalog.jsonb_build_object('table', 'card_bill_charges', 'update_columns', '[]'::JSONB,
            'row', pg_catalog.jsonb_build_object(
            'id', v_charge, 'subscription_id', v_sub, 'card_id', v_card,
            'invoice_month', '2026-12', 'description', 'Streaming',
            'amount_centavos', '3990', 'manually_edited', FALSE, 'removed', FALSE))
    ));
    r := public.card_bills_apply('a2000000-0000-0000-0000-000000000001', v_changes, 'Nova compra');
    IF r ->> 'status' <> 'applied' OR (r ->> 'writes')::INT <> 6 THEN
        RAISE EXCEPTION 'first apply incorrect: %', r;
    END IF;
    replay := public.card_bills_apply('a2000000-0000-0000-0000-000000000001', v_changes, 'Nova compra');
    IF replay IS DISTINCT FROM r THEN
        RAISE EXCEPTION 'replay must return the stored response';
    END IF;
    SELECT COUNT(*) INTO n FROM public.card_bill_installments;
    IF n <> 2 THEN RAISE EXCEPTION 'expected 2 installments, got %', n; END IF;
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000001',
            '{"writes": []}'::JSONB);
        RAISE EXCEPTION 'must reject key reuse with different content';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Nenhuma auditoria do app (decisão de 16/11/2026).
    SELECT COUNT(*) INTO n FROM public.audit_events WHERE entity_type LIKE 'card_bill%';
    IF n <> 0 THEN RAISE EXCEPTION 'card bills must not write audit events'; END IF;

    -- Última gravação vence (linha inteira) e troca só das colunas listadas.
    r := public.card_bills_apply('a2000000-0000-0000-0000-000000000002',
        pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('table', 'card_bill_cards', 'row', pg_catalog.jsonb_build_object(
                'id', v_card, 'name', 'Nubank Ultravioleta', 'closing_day', 5, 'due_day', 12)),
            pg_catalog.jsonb_build_object('table', 'card_bill_installments',
                'update_columns', '["amount_centavos", "manually_edited"]'::JSONB,
                'row', pg_catalog.jsonb_build_object(
                'id', v_inst2, 'purchase_id', v_purchase, 'number', 2, 'card_id', v_card,
                'invoice_month', '2099-01', 'amount_centavos', '42000',
                'manually_edited', TRUE, 'paid_outside', FALSE)))));
    SELECT name INTO v_text FROM public.card_bill_cards;
    IF v_text <> 'Nubank Ultravioleta' THEN RAISE EXCEPTION 'last write must win'; END IF;
    SELECT invoice_month || ':' || amount_centavos INTO v_text
    FROM public.card_bill_installments WHERE id = v_inst2::UUID;
    IF v_text <> '2027-01:42000' THEN
        RAISE EXCEPTION 'only listed columns must change: %', v_text;
    END IF;

    -- Inserir só se não existir: cobrança removida não volta.
    r := public.card_bills_apply('a2000000-0000-0000-0000-000000000003',
        pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('table', 'card_bill_charges',
                'update_columns', '["removed"]'::JSONB,
                'row', pg_catalog.jsonb_build_object(
                'id', v_charge, 'subscription_id', v_sub, 'card_id', v_card,
                'invoice_month', '2026-12', 'description', 'Streaming',
                'amount_centavos', '3990', 'manually_edited', FALSE, 'removed', TRUE)))));
    r := public.card_bills_apply('a2000000-0000-0000-0000-000000000004',
        pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('table', 'card_bill_charges',
                'update_columns', '[]'::JSONB,
                'row', pg_catalog.jsonb_build_object(
                'id', v_charge, 'subscription_id', v_sub, 'card_id', v_card,
                'invoice_month', '2026-12', 'description', 'Streaming',
                'amount_centavos', '3990', 'manually_edited', FALSE, 'removed', FALSE)))));
    IF NOT (SELECT removed FROM public.card_bill_charges) THEN
        RAISE EXCEPTION 'insert-if-absent must not resurrect a removed charge';
    END IF;

    -- Recusas: limites, coluna desconhecida, dono forjado, parcelas duplicadas.
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000010',
            pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'card_bill_installments', 'row', pg_catalog.jsonb_build_object(
                    'id', 'c0000000-0000-0000-0000-0000000000a1', 'purchase_id', v_purchase, 'number', 3,
                    'card_id', v_card, 'invoice_month', '2027-02', 'amount_centavos', '100000001',
                    'manually_edited', FALSE, 'paid_outside', FALSE)))));
        RAISE EXCEPTION 'must reject amount above R$ 1.000.000,00';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000011',
            pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'card_bill_purchases', 'row', pg_catalog.jsonb_build_object(
                    'id', 'c0000000-0000-0000-0000-0000000000a2', 'card_id', v_card, 'description', 'X',
                    'purchased_on', '2026-11-16', 'installment_count', 25, 'amount_mode', 'total')))));
        RAISE EXCEPTION 'must reject 25 installments';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000012',
            pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'card_bill_cards', 'row', pg_catalog.jsonb_build_object(
                    'id', 'c0000000-0000-0000-0000-0000000000a3', 'name', 'X', 'closing_day', 32, 'due_day', 1)))));
        RAISE EXCEPTION 'must reject day 32';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000013',
            pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'card_bill_cards', 'row', pg_catalog.jsonb_build_object(
                    'id', 'c0000000-0000-0000-0000-0000000000a4', 'name', 'X', 'closing_day', 1, 'due_day', 1,
                    'owner_id', 'a1000000-0000-0000-0000-000000000002')))));
        RAISE EXCEPTION 'must reject owner_id in the row';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000014',
            pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'card_bill_installments', 'row', pg_catalog.jsonb_build_object(
                    'id', 'c0000000-0000-0000-0000-0000000000a5', 'purchase_id', v_purchase, 'number', 1,
                    'card_id', v_card, 'invoice_month', '2026-12', 'amount_centavos', '1',
                    'manually_edited', FALSE, 'paid_outside', FALSE)))));
        RAISE EXCEPTION 'must reject two installments with the same number';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000015',
            pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'audit_events', 'row', '{"id": "x"}'::JSONB))));
        RAISE EXCEPTION 'must reject other tables';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000016',
            pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'card_bill_invoices', 'row', pg_catalog.jsonb_build_object(
                    'id', v_invoice, 'card_id', v_card, 'invoice_month', '2026-12',
                    'closing_on', '2026-12-10', 'due_on', '2026-12-17', 'dates_manual', FALSE,
                    'status', 'paid', 'payment_id', 'c0000000-0000-0000-0000-0000000000a6')))));
        RAISE EXCEPTION 'payments must not go through apply';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000017',
            pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'card_bill_invoices', 'row', pg_catalog.jsonb_build_object(
                    'id', v_invoice, 'card_id', v_card, 'invoice_month', '2026-12',
                    'closing_on', '2026-12-10', 'due_on', '2026-12-10', 'dates_manual', TRUE)))));
        RAISE EXCEPTION 'due on the closing day must be rejected';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Valor informado (fatura criada) e ajuste da reserva (R$ 1.000,00).
    r := public.card_bills_apply('a2000000-0000-0000-0000-000000000020',
        pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('table', 'card_bill_invoices',
                'update_columns', '["informed_amount_centavos"]'::JSONB,
                'row', pg_catalog.jsonb_build_object(
                'id', v_invoice, 'card_id', v_card, 'invoice_month', '2026-12',
                'closing_on', '2026-12-10', 'due_on', '2026-12-17', 'dates_manual', FALSE,
                'informed_amount_centavos', '120000', 'status', 'pending')),
            pg_catalog.jsonb_build_object('table', 'card_bill_reserve_events', 'row', pg_catalog.jsonb_build_object(
                'id', 'c0000000-0000-0000-0000-0000000000e1', 'kind', 'adjustment', 'direction', 'in',
                'amount_centavos', '100000', 'occurred_at', '2026-11-16T12:00:00Z')))));
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000021',
            pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'card_bill_reserve_events', 'row', pg_catalog.jsonb_build_object(
                    'id', 'c0000000-0000-0000-0000-0000000000e2', 'kind', 'payment', 'direction', 'out',
                    'amount_centavos', '1', 'invoice_id', v_invoice, 'occurred_at', '2026-11-16T12:00:00Z')))));
        RAISE EXCEPTION 'payment events must not go through apply';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM public.card_bills_apply('a2000000-0000-0000-0000-000000000022',
            '{"deletes": [{"table": "card_bill_reserve_events", "id": "c0000000-0000-0000-0000-0000000000e1"}]}'::JSONB);
        RAISE EXCEPTION 'reserve events are never deleted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Pagamento pela reserva maior que ela: R$ 1.237,50, R$ 1.000,00 da reserva.
    v_paid := pg_catalog.jsonb_build_object(
        'id', v_invoice, 'card_id', v_card, 'invoice_month', '2026-12',
        'closing_on', '2026-12-10', 'due_on', '2026-12-17', 'dates_manual', FALSE,
        'informed_amount_centavos', '120000', 'status', 'paid',
        'payment_id', 'c0000000-0000-0000-0000-0000000000b1',
        'paid_amount_centavos', '123750', 'paid_on', '2026-12-15',
        'payment_source', 'reserve', 'reserve_used_centavos', '100000',
        'expected_amount_centavos', '120000', 'card_name', 'Nubank',
        'items_snapshot', '[{"description": "TV (1/2)", "amount_centavos": "50001"}]'::JSONB);
    r := public.card_bills_pay_invoice('a2000000-0000-0000-0000-000000000030', v_paid,
        pg_catalog.jsonb_build_object(
            'id', 'c0000000-0000-0000-0000-0000000000e3', 'kind', 'payment', 'direction', 'out',
            'amount_centavos', '100000', 'invoice_id', v_invoice, 'label', 'pela fatura Nubank',
            'occurred_at', '2026-12-15T12:00:00Z'));
    IF r ->> 'status' <> 'applied' OR r #>> '{invoice,status}' <> 'paid' THEN
        RAISE EXCEPTION 'payment incorrect: %', r;
    END IF;
    SELECT SUM(CASE direction WHEN 'in' THEN amount_centavos ELSE -amount_centavos END)
    INTO n FROM public.card_bill_reserve_events;
    IF n <> 0 THEN RAISE EXCEPTION 'reserve must go to zero, got %', n; END IF;

    -- Evento que não bate com o pagamento é recusado.
    BEGIN
        PERFORM public.card_bills_pay_invoice('a2000000-0000-0000-0000-000000000031',
            v_paid || '{"id": "c0000000-0000-0000-0000-0000000000f1", "invoice_month": "2027-01", "payment_id": "c0000000-0000-0000-0000-0000000000f2"}'::JSONB,
            NULL);
        RAISE EXCEPTION 'missing reserve event must be rejected';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- Fatura paga fica congelada: apply não altera nem apaga.
    r := public.card_bills_apply('a2000000-0000-0000-0000-000000000032',
        pg_catalog.jsonb_build_object('writes', pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('table', 'card_bill_invoices',
                'update_columns', '["informed_amount_centavos"]'::JSONB,
                'row', pg_catalog.jsonb_build_object(
                'id', v_invoice, 'card_id', v_card, 'invoice_month', '2026-12',
                'closing_on', '2026-12-10', 'due_on', '2026-12-17', 'dates_manual', FALSE,
                'informed_amount_centavos', '1', 'status', 'pending'))),
            'deletes', pg_catalog.jsonb_build_array(
                pg_catalog.jsonb_build_object('table', 'card_bill_invoices', 'id', v_invoice))));
    SELECT status || ':' || informed_amount_centavos INTO v_text FROM public.card_bill_invoices;
    IF v_text <> 'paid:120000' THEN RAISE EXCEPTION 'paid invoice must be frozen: %', v_text; END IF;

    -- Pagamento duplicado (outro aparelho, outro pagamento): não aplica.
    r := public.card_bills_pay_invoice('a2000000-0000-0000-0000-000000000033',
        v_paid || '{"payment_id": "c0000000-0000-0000-0000-0000000000b2", "paid_amount_centavos": "120000", "reserve_used_centavos": "0", "payment_source": "other"}'::JSONB,
        NULL);
    IF r ->> 'status' <> 'conflict' OR r #>> '{remote_invoice,payment_id}' <> 'c0000000-0000-0000-0000-0000000000b1'
        OR r ->> 'conflict_id' IS NULL
    THEN
        RAISE EXCEPTION 'duplicate payment must be a conflict: %', r;
    END IF;
    replay := public.card_bills_pay_invoice('a2000000-0000-0000-0000-000000000033',
        v_paid || '{"payment_id": "c0000000-0000-0000-0000-0000000000b2", "paid_amount_centavos": "120000", "reserve_used_centavos": "0", "payment_source": "other"}'::JSONB,
        NULL);
    IF replay IS DISTINCT FROM r THEN RAISE EXCEPTION 'conflict replay must match'; END IF;
    SELECT payment_id::TEXT INTO v_text FROM public.card_bill_invoices;
    IF v_text <> 'c0000000-0000-0000-0000-0000000000b1' THEN
        RAISE EXCEPTION 'duplicate must not replace the payment';
    END IF;

    -- O usuário escolhe manter o segundo: o primeiro é desfeito (volta
    -- R$ 1.000,00 à reserva) e o segundo é aplicado; reserva descontada uma vez.
    r := public.card_bills_pay_invoice('a2000000-0000-0000-0000-000000000034',
        v_paid || '{"payment_id": "c0000000-0000-0000-0000-0000000000b2", "paid_amount_centavos": "120000", "reserve_used_centavos": "0", "payment_source": "other"}'::JSONB,
        NULL,
        'c0000000-0000-0000-0000-0000000000b1',
        pg_catalog.jsonb_build_object(
            'id', 'c0000000-0000-0000-0000-0000000000e4', 'kind', 'payment_undo', 'direction', 'in',
            'amount_centavos', '100000', 'invoice_id', v_invoice, 'occurred_at', '2026-12-16T12:00:00Z'));
    IF r ->> 'status' <> 'applied' OR r #>> '{invoice,payment_id}' <> 'c0000000-0000-0000-0000-0000000000b2' THEN
        RAISE EXCEPTION 'replace payment incorrect: %', r;
    END IF;
    SELECT SUM(CASE direction WHEN 'in' THEN amount_centavos ELSE -amount_centavos END)
    INTO n FROM public.card_bill_reserve_events;
    IF n <> 100000 THEN RAISE EXCEPTION 'reserve after replace must be 100000, got %', n; END IF;

    -- Desfazer pagamento: pagamento diferente não faz nada; o certo volta a pendente.
    r := public.card_bills_undo_payment('a2000000-0000-0000-0000-000000000035',
        v_invoice::UUID, 'c0000000-0000-0000-0000-0000000000b1', NULL);
    IF (SELECT status FROM public.card_bill_invoices) <> 'paid' THEN
        RAISE EXCEPTION 'undo of another payment must do nothing';
    END IF;
    r := public.card_bills_undo_payment('a2000000-0000-0000-0000-000000000036',
        v_invoice::UUID, 'c0000000-0000-0000-0000-0000000000b2', NULL);
    SELECT status || ':' || COALESCE(payment_id::TEXT, '-') || ':' || informed_amount_centavos
    INTO v_text FROM public.card_bill_invoices;
    IF v_text <> 'pending:-:120000' THEN RAISE EXCEPTION 'undo incorrect: %', v_text; END IF;

    -- Apagar o cartão apaga compras, parcelas e assinaturas (em cascata).
    r := public.card_bills_apply('a2000000-0000-0000-0000-000000000040',
        pg_catalog.jsonb_build_object('deletes', pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('table', 'card_bill_cards', 'id', v_card))));
    IF EXISTS (SELECT 1 FROM public.card_bill_purchases)
        OR EXISTS (SELECT 1 FROM public.card_bill_installments)
        OR EXISTS (SELECT 1 FROM public.card_bill_subscriptions)
    THEN
        RAISE EXCEPTION 'card delete must cascade';
    END IF;
END;
$test$;

-- Escrita direta nas tabelas é negada.
DO $test$
BEGIN
    BEGIN
        INSERT INTO public.card_bill_cards (owner_id, id, name, closing_day, due_day)
        VALUES ('a1000000-0000-0000-0000-000000000001', pg_catalog.gen_random_uuid(), 'X', 1, 2);
        RAISE EXCEPTION 'direct insert must be denied';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$test$;

-- Isolamento: outro usuário não vê, não apaga nem paga o que é do primeiro.
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000002', TRUE);

DO $test$
DECLARE
    n BIGINT;
    r JSONB;
BEGIN
    SELECT COUNT(*) INTO n FROM public.card_bill_invoices;
    IF n <> 0 THEN RAISE EXCEPTION 'second user must not see invoices'; END IF;
    SELECT COUNT(*) INTO n FROM public.card_bill_reserve_events;
    IF n <> 0 THEN RAISE EXCEPTION 'second user must not see reserve events'; END IF;
    r := public.card_bills_apply('a2000000-0000-0000-0000-000000000050',
        '{"deletes": [{"table": "card_bill_invoices", "id": "c0000000-0000-0000-0000-000000000007"}]}'::JSONB);
    r := public.card_bills_undo_payment('a2000000-0000-0000-0000-000000000051',
        'c0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-0000000000b2', NULL);
END;
$test$;

SELECT pg_catalog.set_config(
    'request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', TRUE);

DO $test$
DECLARE
    n BIGINT;
BEGIN
    SELECT COUNT(*) INTO n FROM public.card_bill_invoices;
    IF n <> 1 THEN RAISE EXCEPTION 'first user invoice must survive the other user'; END IF;
    -- Mesma chave de operação usada por outro usuário não interfere.
    PERFORM public.delete_my_account('DELETE_MY_ACCOUNT');
END;
$test$;

RESET ROLE;

DO $test$
BEGIN
    IF EXISTS (SELECT 1 FROM public.card_bill_invoices
               WHERE owner_id = 'a1000000-0000-0000-0000-000000000001')
        OR EXISTS (SELECT 1 FROM public.card_bill_reserve_events
               WHERE owner_id = 'a1000000-0000-0000-0000-000000000001')
        OR EXISTS (SELECT 1 FROM auth.users WHERE id = 'a1000000-0000-0000-0000-000000000001')
    THEN
        RAISE EXCEPTION 'delete_my_account must remove card bills data';
    END IF;
END;
$test$;

SELECT 'PASS: card bills tables, RLS, cadastros (last write wins), frozen paid invoices, payment, undo, duplicate payment, isolation and account deletion.' AS result;

ROLLBACK;
