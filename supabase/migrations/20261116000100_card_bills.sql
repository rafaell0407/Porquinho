-- Gestão de Faturas de Cartões (RF029; spec docs/ferramentas/gestao_de_faturas.md).
-- Ferramenta separada e opcional: não cria lançamentos nem mexe no dinheiro
-- livre. Exceções aprovadas em 16/11/2026, válidas só aqui: cadastros apagados
-- de verdade, sem versões antigas nem auditoria; última gravação vence nos
-- cadastros; reserva = soma de eventos.
--
-- Os cálculos (datas, ciclos, parcelas, valor da fatura, reserva) ficam só no
-- domínio em Dart (spec §13). O servidor guarda e valida: dono, centavos
-- inteiros e limites, fatura paga uma só vez, unicidade de parcelas e
-- cobranças. Toda escrita passa pelas RPCs abaixo, com idempotência.
BEGIN;

-- ---------------------------------------------------------------- tabelas

CREATE TABLE public.card_bill_cards (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    name TEXT NOT NULL CHECK (pg_catalog.length(pg_catalog.btrim(name)) BETWEEN 1 AND 100),
    closing_day SMALLINT NOT NULL CHECK (closing_day BETWEEN 1 AND 31),
    due_day SMALLINT NOT NULL CHECK (due_day BETWEEN 1 AND 31),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    PRIMARY KEY (owner_id, id)
);

CREATE TABLE public.card_bill_purchases (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    card_id UUID NOT NULL,
    description TEXT NOT NULL CHECK (pg_catalog.length(pg_catalog.btrim(description)) BETWEEN 1 AND 200),
    purchased_on DATE NOT NULL,
    installment_count SMALLINT NOT NULL CHECK (installment_count BETWEEN 1 AND 24),
    amount_mode TEXT NOT NULL CHECK (amount_mode IN ('total', 'installment')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    PRIMARY KEY (owner_id, id),
    FOREIGN KEY (owner_id, card_id)
        REFERENCES public.card_bill_cards (owner_id, id) ON DELETE CASCADE
);

-- Parcela k de uma compra, na fatura do cartão card_id do mês invoice_month.
-- card_id não referencia o cartão: parcelas já pagas continuam no cartão
-- antigo quando a compra muda de cartão.
CREATE TABLE public.card_bill_installments (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    purchase_id UUID NOT NULL,
    number SMALLINT NOT NULL CHECK (number BETWEEN 1 AND 24),
    card_id UUID NOT NULL,
    invoice_month TEXT NOT NULL CHECK (invoice_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    amount_centavos BIGINT NOT NULL CHECK (amount_centavos BETWEEN 0 AND 100000000),
    manually_edited BOOLEAN NOT NULL DEFAULT FALSE,
    paid_outside BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    PRIMARY KEY (owner_id, id),
    UNIQUE (owner_id, purchase_id, number),
    FOREIGN KEY (owner_id, purchase_id)
        REFERENCES public.card_bill_purchases (owner_id, id) ON DELETE CASCADE
);

CREATE TABLE public.card_bill_subscriptions (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    card_id UUID NOT NULL,
    description TEXT NOT NULL CHECK (pg_catalog.length(pg_catalog.btrim(description)) BETWEEN 1 AND 200),
    monthly_amount_centavos BIGINT NOT NULL CHECK (monthly_amount_centavos BETWEEN 1 AND 100000000),
    start_month TEXT NOT NULL CHECK (start_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    PRIMARY KEY (owner_id, id),
    FOREIGN KEY (owner_id, card_id)
        REFERENCES public.card_bill_cards (owner_id, id) ON DELETE CASCADE
);

-- Cobrança de assinatura numa fatura: item próprio. Fica mesmo depois de a
-- assinatura ser cancelada (cobrança da fatura atual continua, spec §7).
-- `removed` = removida à mão naquela fatura (não reaparece).
CREATE TABLE public.card_bill_charges (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    subscription_id UUID NOT NULL,
    card_id UUID NOT NULL,
    invoice_month TEXT NOT NULL CHECK (invoice_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    description TEXT NOT NULL CHECK (pg_catalog.length(pg_catalog.btrim(description)) BETWEEN 1 AND 200),
    amount_centavos BIGINT NOT NULL CHECK (amount_centavos BETWEEN 0 AND 100000000),
    manually_edited BOOLEAN NOT NULL DEFAULT FALSE,
    removed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    PRIMARY KEY (owner_id, id),
    UNIQUE (owner_id, subscription_id, invoice_month)
);

-- Fatura gravada (as demais são calculadas a partir do cartão). Faturas pagas
-- ficam como histórico, mesmo depois de o cartão ser apagado (card_name).
CREATE TABLE public.card_bill_invoices (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    card_id UUID NOT NULL,
    invoice_month TEXT NOT NULL CHECK (invoice_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    closing_on DATE NOT NULL,
    due_on DATE NOT NULL,
    dates_manual BOOLEAN NOT NULL DEFAULT FALSE,
    informed_amount_centavos BIGINT CHECK (informed_amount_centavos BETWEEN 0 AND 100000000),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
    payment_id UUID,
    paid_amount_centavos BIGINT CHECK (paid_amount_centavos BETWEEN 0 AND 100000000),
    paid_on DATE,
    payment_source TEXT CHECK (payment_source IN ('reserve', 'other')),
    reserve_used_centavos BIGINT CHECK (reserve_used_centavos >= 0),
    expected_amount_centavos BIGINT CHECK (expected_amount_centavos >= 0),
    card_name TEXT CHECK (card_name IS NULL OR pg_catalog.length(card_name) <= 100),
    items_snapshot JSONB CHECK (items_snapshot IS NULL OR pg_catalog.jsonb_typeof(items_snapshot) = 'array'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    PRIMARY KEY (owner_id, id),
    UNIQUE (owner_id, card_id, invoice_month),
    CHECK (due_on > closing_on),
    CHECK (
        (status = 'pending' AND payment_id IS NULL AND paid_amount_centavos IS NULL
            AND paid_on IS NULL AND payment_source IS NULL
            AND reserve_used_centavos IS NULL AND expected_amount_centavos IS NULL
            AND items_snapshot IS NULL)
        OR (status = 'paid' AND payment_id IS NOT NULL
            AND paid_amount_centavos IS NOT NULL AND paid_on IS NOT NULL
            AND payment_source IS NOT NULL AND reserve_used_centavos IS NOT NULL
            AND expected_amount_centavos IS NOT NULL AND items_snapshot IS NOT NULL
            AND card_name IS NOT NULL)
    ),
    CHECK (reserve_used_centavos IS NULL OR reserve_used_centavos <= paid_amount_centavos),
    CHECK (payment_source IS DISTINCT FROM 'other' OR reserve_used_centavos = 0)
);

-- Reserva = soma dos eventos (nunca sobrescrita). Ajuste: diferença digitada;
-- pagamento: saída; desfazer: volta.
CREATE TABLE public.card_bill_reserve_events (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('adjustment', 'payment', 'payment_undo')),
    direction TEXT NOT NULL CHECK (direction IN ('in', 'out')),
    amount_centavos BIGINT NOT NULL CHECK (amount_centavos BETWEEN 1 AND 1000000000000),
    invoice_id UUID,
    label TEXT CHECK (label IS NULL OR pg_catalog.length(label) <= 300),
    occurred_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    PRIMARY KEY (owner_id, id),
    CHECK (
        (kind = 'adjustment' AND invoice_id IS NULL)
        OR (kind = 'payment' AND direction = 'out' AND invoice_id IS NOT NULL)
        OR (kind = 'payment_undo' AND direction = 'in' AND invoice_id IS NOT NULL)
    )
);

CREATE INDEX card_bill_purchases_card_idx ON public.card_bill_purchases (owner_id, card_id);
CREATE INDEX card_bill_subscriptions_card_idx ON public.card_bill_subscriptions (owner_id, card_id);

REVOKE ALL PRIVILEGES ON TABLE
    public.card_bill_cards,
    public.card_bill_purchases,
    public.card_bill_installments,
    public.card_bill_subscriptions,
    public.card_bill_charges,
    public.card_bill_invoices,
    public.card_bill_reserve_events
FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE
    public.card_bill_cards,
    public.card_bill_purchases,
    public.card_bill_installments,
    public.card_bill_subscriptions,
    public.card_bill_charges,
    public.card_bill_invoices,
    public.card_bill_reserve_events
TO authenticated;

DO $block$
DECLARE
    table_name TEXT;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'card_bill_cards',
        'card_bill_purchases',
        'card_bill_installments',
        'card_bill_subscriptions',
        'card_bill_charges',
        'card_bill_invoices',
        'card_bill_reserve_events'
    ]
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
        EXECUTE format(
            'CREATE POLICY porquinho_read_own ON public.%I FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL AND owner_id = auth.uid())',
            table_name
        );
    END LOOP;
END;
$block$;

-- ------------------------------------------------- idempotência (auxiliar)

-- Reivindica a chave da operação. Devolve NULL se a operação é nova; senão a
-- resposta guardada (mesmo conteúdo) ou erro (conteúdo diferente).
CREATE FUNCTION public.card_bills_claim_operation(
    p_owner_id UUID,
    p_operation_id UUID,
    p_request JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_hash BYTEA;
    v_stored_hash BYTEA;
    v_stored JSONB;
BEGIN
    v_hash := pg_catalog.decode(
        pg_catalog.md5(pg_catalog.convert_to(p_request::TEXT, 'UTF8')), 'hex');
    INSERT INTO public.applied_sync_operations (
        owner_id, idempotency_key, content_hash, result_payload
    )
    VALUES (
        p_owner_id, p_operation_id, v_hash,
        pg_catalog.jsonb_build_object('request', p_request, 'response', NULL)
    )
    ON CONFLICT (owner_id, idempotency_key) DO NOTHING;
    IF FOUND THEN
        RETURN NULL;
    END IF;

    SELECT operation.content_hash, operation.result_payload
    INTO v_stored_hash, v_stored
    FROM public.applied_sync_operations AS operation
    WHERE operation.owner_id = p_owner_id
      AND operation.idempotency_key = p_operation_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'idempotency result disappeared during the operation'
            USING ERRCODE = 'serialization_failure';
    END IF;
    IF v_stored_hash IS DISTINCT FROM v_hash
        OR v_stored -> 'request' IS DISTINCT FROM p_request
    THEN
        RAISE EXCEPTION 'idempotency key was already used with different content'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    RETURN v_stored -> 'response';
END;
$function$;

CREATE FUNCTION public.card_bills_store_response(
    p_owner_id UUID,
    p_operation_id UUID,
    p_response JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    UPDATE public.applied_sync_operations AS operation
    SET result_payload = pg_catalog.jsonb_set(
            operation.result_payload, '{response}', p_response),
        applied_at = pg_catalog.clock_timestamp()
    WHERE operation.owner_id = p_owner_id
      AND operation.idempotency_key = p_operation_id;
END;
$function$;

CREATE FUNCTION public.card_bills_require_owner(p_operation_id UUID)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner_id UUID;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL THEN
        RAISE EXCEPTION 'operation id is required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    RETURN v_owner_id;
END;
$function$;

-- Colunas graváveis por tabela (além de owner_id e datas de controle).
CREATE FUNCTION public.card_bills_columns(p_table TEXT)
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $function$
    SELECT CASE p_table
        WHEN 'card_bill_cards' THEN ARRAY['id', 'name', 'closing_day', 'due_day']
        WHEN 'card_bill_purchases' THEN ARRAY['id', 'card_id', 'description',
            'purchased_on', 'installment_count', 'amount_mode']
        WHEN 'card_bill_installments' THEN ARRAY['id', 'purchase_id', 'number',
            'card_id', 'invoice_month', 'amount_centavos', 'manually_edited',
            'paid_outside']
        WHEN 'card_bill_subscriptions' THEN ARRAY['id', 'card_id', 'description',
            'monthly_amount_centavos', 'start_month']
        WHEN 'card_bill_charges' THEN ARRAY['id', 'subscription_id', 'card_id',
            'invoice_month', 'description', 'amount_centavos', 'manually_edited',
            'removed']
        WHEN 'card_bill_invoices' THEN ARRAY['id', 'card_id', 'invoice_month',
            'closing_on', 'due_on', 'dates_manual', 'informed_amount_centavos',
            'status', 'payment_id', 'paid_amount_centavos', 'paid_on',
            'payment_source', 'reserve_used_centavos', 'expected_amount_centavos',
            'card_name', 'items_snapshot']
        WHEN 'card_bill_reserve_events' THEN ARRAY['id', 'kind', 'direction',
            'amount_centavos', 'invoice_id', 'label', 'occurred_at']
    END;
$function$;

-- --------------------------------------------------------- cadastros

-- Aplica uma alteração de cadastros (cartões, compras e parcelas, assinaturas
-- e cobranças, valor informado e datas da fatura, ajustes da reserva):
--   p_changes = {"writes": [{"table", "row", "update_columns"}],
--                "deletes": [{"table", "id"}]}
-- update_columns NULL = substitui todas as colunas (última gravação vence);
-- [] = insere só se não existir; lista = troca só essas colunas.
-- Fatura paga fica congelada: não é alterada nem apagada por aqui.
CREATE FUNCTION public.card_bills_apply(
    p_operation_id UUID,
    p_changes JSONB,
    p_summary TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner_id UUID;
    v_stored JSONB;
    v_write JSONB;
    v_delete JSONB;
    v_table TEXT;
    v_row JSONB;
    v_update JSONB;
    v_allowed TEXT[];
    v_key TEXT;
    v_columns TEXT[];
    v_set TEXT;
    v_conflict TEXT;
    v_now TIMESTAMPTZ := pg_catalog.clock_timestamp();
    v_payment_columns CONSTANT TEXT[] := ARRAY['status', 'payment_id',
        'paid_amount_centavos', 'paid_on', 'payment_source',
        'reserve_used_centavos', 'expected_amount_centavos', 'card_name',
        'items_snapshot'];
    v_writes INTEGER := 0;
    v_deletes INTEGER := 0;
    v_response JSONB;
BEGIN
    v_owner_id := public.card_bills_require_owner(p_operation_id);
    IF p_changes IS NULL OR pg_catalog.jsonb_typeof(p_changes) <> 'object'
        OR pg_catalog.jsonb_typeof(COALESCE(p_changes -> 'writes', '[]')) <> 'array'
        OR pg_catalog.jsonb_typeof(COALESCE(p_changes -> 'deletes', '[]')) <> 'array'
        OR pg_catalog.jsonb_array_length(COALESCE(p_changes -> 'writes', '[]')) > 2000
        OR pg_catalog.jsonb_array_length(COALESCE(p_changes -> 'deletes', '[]')) > 2000
    THEN
        RAISE EXCEPTION 'invalid changes' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_stored := public.card_bills_claim_operation(
        v_owner_id, p_operation_id,
        pg_catalog.jsonb_build_object('card_bills_apply', p_changes));
    IF v_stored IS NOT NULL THEN
        RETURN v_stored;
    END IF;

    FOR v_write IN
        SELECT value FROM pg_catalog.jsonb_array_elements(COALESCE(p_changes -> 'writes', '[]'))
    LOOP
        v_table := v_write ->> 'table';
        v_row := v_write -> 'row';
        v_update := v_write -> 'update_columns';
        v_allowed := public.card_bills_columns(v_table);
        IF v_allowed IS NULL OR pg_catalog.jsonb_typeof(v_row) IS DISTINCT FROM 'object'
            OR NOT (v_row ? 'id')
            OR (v_update IS NOT NULL AND pg_catalog.jsonb_typeof(v_update) NOT IN ('array', 'null'))
        THEN
            RAISE EXCEPTION 'invalid write' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        IF pg_catalog.jsonb_typeof(v_update) = 'null' THEN
            v_update := NULL;
        END IF;
        FOR v_key IN SELECT pg_catalog.jsonb_object_keys(v_row) LOOP
            IF NOT v_key = ANY (v_allowed) THEN
                RAISE EXCEPTION 'column % is not writable in %', v_key, v_table
                    USING ERRCODE = 'invalid_parameter_value';
            END IF;
        END LOOP;

        IF v_table = 'card_bill_invoices' THEN
            -- Pagamento só pelas RPCs de pagamento.
            IF COALESCE(v_row ->> 'status', 'pending') <> 'pending'
                OR EXISTS (
                    SELECT 1 FROM pg_catalog.unnest(v_payment_columns) AS c(name)
                    WHERE c.name <> 'status' AND c.name <> 'card_name'
                      AND v_row ? c.name
                      AND pg_catalog.jsonb_typeof(v_row -> c.name) <> 'null'
                )
            THEN
                RAISE EXCEPTION 'payments use card_bills_pay_invoice'
                    USING ERRCODE = 'invalid_parameter_value';
            END IF;
            v_row := v_row || '{"status": "pending"}'::JSONB;
            v_allowed := ARRAY(
                SELECT a FROM pg_catalog.unnest(v_allowed) AS a
                WHERE NOT a = ANY (v_payment_columns));
        ELSIF v_table = 'card_bill_reserve_events' THEN
            IF v_row ->> 'kind' IS DISTINCT FROM 'adjustment' THEN
                RAISE EXCEPTION 'only adjustments are written here'
                    USING ERRCODE = 'invalid_parameter_value';
            END IF;
            v_update := '[]'::JSONB; -- eventos nunca são reescritos
        END IF;

        IF v_update IS NULL THEN
            v_columns := ARRAY(SELECT a FROM pg_catalog.unnest(v_allowed) AS a WHERE a <> 'id');
        ELSE
            v_columns := ARRAY(SELECT pg_catalog.jsonb_array_elements_text(v_update));
            IF EXISTS (
                SELECT 1 FROM pg_catalog.unnest(v_columns) AS c(name)
                WHERE c.name = 'id' OR NOT c.name = ANY (v_allowed)
                   OR NOT (v_row ? c.name)
            ) THEN
                RAISE EXCEPTION 'invalid update columns'
                    USING ERRCODE = 'invalid_parameter_value';
            END IF;
        END IF;

        IF pg_catalog.cardinality(v_columns) = 0 THEN
            v_conflict := 'NOTHING';
        ELSE
            SELECT pg_catalog.string_agg(pg_catalog.format('%I = EXCLUDED.%I', c, c), ', ')
            INTO v_set
            FROM pg_catalog.unnest(v_columns) AS c;
            v_conflict := 'UPDATE SET ' || v_set || ', updated_at = EXCLUDED.updated_at';
            IF v_table = 'card_bill_invoices' THEN
                v_conflict := v_conflict || ' WHERE t.status = ''pending''';
            END IF;
        END IF;

        v_row := v_row || pg_catalog.jsonb_build_object(
            'owner_id', v_owner_id, 'created_at', v_now, 'updated_at', v_now);
        EXECUTE pg_catalog.format(
            'INSERT INTO public.%1$I AS t SELECT * FROM pg_catalog.jsonb_populate_record(NULL::public.%1$I, $1) ON CONFLICT (owner_id, id) DO %2$s',
            v_table, v_conflict)
        USING v_row;
        v_writes := v_writes + 1;
    END LOOP;

    FOR v_delete IN
        SELECT value FROM pg_catalog.jsonb_array_elements(COALESCE(p_changes -> 'deletes', '[]'))
    LOOP
        v_table := v_delete ->> 'table';
        IF public.card_bills_columns(v_table) IS NULL
            OR v_table = 'card_bill_reserve_events'
            OR v_delete ->> 'id' IS NULL
        THEN
            RAISE EXCEPTION 'invalid delete' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        EXECUTE pg_catalog.format(
            'DELETE FROM public.%I WHERE owner_id = $1 AND id = $2%s',
            v_table,
            CASE WHEN v_table = 'card_bill_invoices' THEN ' AND status = ''pending''' ELSE '' END)
        USING v_owner_id, (v_delete ->> 'id')::UUID;
        v_deletes := v_deletes + 1;
    END LOOP;

    v_response := pg_catalog.jsonb_build_object(
        'status', 'applied', 'writes', v_writes, 'deletes', v_deletes);
    PERFORM public.card_bills_store_response(v_owner_id, p_operation_id, v_response);
    RETURN v_response;
END;
$function$;

-- --------------------------------------------------------- pagamento

-- Valida o evento de reserva enviado junto com um pagamento ou desfazer.
CREATE FUNCTION public.card_bills_insert_event(
    p_owner_id UUID,
    p_event JSONB,
    p_kind TEXT,
    p_invoice_id UUID,
    p_amount BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_event public.card_bill_reserve_events;
BEGIN
    IF p_amount = 0 THEN
        IF p_event IS NOT NULL AND pg_catalog.jsonb_typeof(p_event) <> 'null' THEN
            RAISE EXCEPTION 'no reserve event expected'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        RETURN;
    END IF;
    IF p_event IS NULL OR pg_catalog.jsonb_typeof(p_event) <> 'object' THEN
        RAISE EXCEPTION 'reserve event is required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    v_event := pg_catalog.jsonb_populate_record(
        NULL::public.card_bill_reserve_events,
        p_event || pg_catalog.jsonb_build_object(
            'owner_id', p_owner_id,
            'created_at', pg_catalog.clock_timestamp(),
            'updated_at', pg_catalog.clock_timestamp()));
    IF v_event.kind IS DISTINCT FROM p_kind
        OR v_event.invoice_id IS DISTINCT FROM p_invoice_id
        OR v_event.amount_centavos IS DISTINCT FROM p_amount
    THEN
        RAISE EXCEPTION 'reserve event does not match the payment'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    INSERT INTO public.card_bill_reserve_events SELECT v_event.*
    ON CONFLICT (owner_id, id) DO NOTHING;
END;
$function$;

-- Paga a fatura inteira (spec §8). p_invoice: linha completa já paga (com as
-- datas, para criar a fatura se ainda não existir). Uma fatura é paga uma só
-- vez: outro pagamento já gravado devolve "conflict" (pagamento duplicado,
-- spec §12), salvo se p_replace_payment_id disser qual pagamento substituir
-- (o usuário escolheu manter este); aí o anterior é desfeito antes.
CREATE FUNCTION public.card_bills_pay_invoice(
    p_operation_id UUID,
    p_invoice JSONB,
    p_reserve_event JSONB DEFAULT NULL,
    p_replace_payment_id UUID DEFAULT NULL,
    p_replace_undo_event JSONB DEFAULT NULL,
    p_summary TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner_id UUID;
    v_stored JSONB;
    v_new public.card_bill_invoices;
    v_current public.card_bill_invoices;
    v_now TIMESTAMPTZ := pg_catalog.clock_timestamp();
    v_response JSONB;
    v_key TEXT;
    v_exists BOOLEAN;
BEGIN
    v_owner_id := public.card_bills_require_owner(p_operation_id);
    IF p_invoice IS NULL OR pg_catalog.jsonb_typeof(p_invoice) <> 'object' THEN
        RAISE EXCEPTION 'invoice is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    FOR v_key IN SELECT pg_catalog.jsonb_object_keys(p_invoice) LOOP
        IF NOT v_key = ANY (public.card_bills_columns('card_bill_invoices')) THEN
            RAISE EXCEPTION 'column % is not writable', v_key
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    END LOOP;

    v_stored := public.card_bills_claim_operation(
        v_owner_id, p_operation_id,
        pg_catalog.jsonb_build_object(
            'card_bills_pay_invoice', p_invoice,
            'event', p_reserve_event,
            'replace', p_replace_payment_id,
            'replace_event', p_replace_undo_event));
    IF v_stored IS NOT NULL THEN
        RETURN v_stored;
    END IF;

    v_new := pg_catalog.jsonb_populate_record(
        NULL::public.card_bill_invoices,
        p_invoice || pg_catalog.jsonb_build_object(
            'owner_id', v_owner_id, 'created_at', v_now, 'updated_at', v_now));
    IF v_new.status IS DISTINCT FROM 'paid' OR v_new.payment_id IS NULL THEN
        RAISE EXCEPTION 'invoice must be paid' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT invoice.* INTO v_current
    FROM public.card_bill_invoices AS invoice
    WHERE invoice.owner_id = v_owner_id AND invoice.id = v_new.id
    FOR UPDATE;
    v_exists := FOUND;

    IF v_exists AND v_current.status = 'paid' THEN
        IF v_current.payment_id = v_new.payment_id THEN
            v_response := pg_catalog.jsonb_build_object(
                'status', 'applied', 'invoice', pg_catalog.to_jsonb(v_current));
            PERFORM public.card_bills_store_response(v_owner_id, p_operation_id, v_response);
            RETURN v_response;
        END IF;
        IF p_replace_payment_id IS DISTINCT FROM v_current.payment_id THEN
            -- Pagamento duplicado: não aplica; o aparelho mostra para o
            -- usuário escolher qual manter.
            v_response := pg_catalog.jsonb_build_object(
                'status', 'conflict',
                'conflict_id', pg_catalog.gen_random_uuid(),
                'remote_invoice', pg_catalog.to_jsonb(v_current)
                    || '{"version": 1}'::JSONB);
            PERFORM public.card_bills_store_response(v_owner_id, p_operation_id, v_response);
            RETURN v_response;
        END IF;
        -- Desfaz o pagamento substituído (a reserva recebe de volta só o que
        -- saiu dela) antes de aplicar este.
        PERFORM public.card_bills_insert_event(
            v_owner_id, p_replace_undo_event, 'payment_undo', v_current.id,
            v_current.reserve_used_centavos);
    END IF;

    IF v_exists THEN
        UPDATE public.card_bill_invoices AS invoice
        SET status = 'paid',
            payment_id = v_new.payment_id,
            paid_amount_centavos = v_new.paid_amount_centavos,
            paid_on = v_new.paid_on,
            payment_source = v_new.payment_source,
            reserve_used_centavos = v_new.reserve_used_centavos,
            expected_amount_centavos = v_new.expected_amount_centavos,
            card_name = v_new.card_name,
            items_snapshot = v_new.items_snapshot,
            updated_at = v_now
        WHERE invoice.owner_id = v_owner_id AND invoice.id = v_new.id
        RETURNING invoice.* INTO v_current;
    ELSE
        INSERT INTO public.card_bill_invoices SELECT v_new.*
        RETURNING * INTO v_current;
    END IF;

    PERFORM public.card_bills_insert_event(
        v_owner_id, p_reserve_event, 'payment', v_current.id,
        v_current.reserve_used_centavos);

    v_response := pg_catalog.jsonb_build_object(
        'status', 'applied', 'invoice', pg_catalog.to_jsonb(v_current));
    PERFORM public.card_bills_store_response(v_owner_id, p_operation_id, v_response);
    RETURN v_response;
END;
$function$;

-- Desfaz o pagamento (spec §8): a fatura volta a pendente e a reserva recebe
-- de volta só o que saiu dela. Pagamento diferente (ou fatura já pendente):
-- nada a fazer.
CREATE FUNCTION public.card_bills_undo_payment(
    p_operation_id UUID,
    p_invoice_id UUID,
    p_payment_id UUID,
    p_reserve_event JSONB DEFAULT NULL,
    p_summary TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner_id UUID;
    v_stored JSONB;
    v_current public.card_bill_invoices;
    v_response JSONB;
BEGIN
    v_owner_id := public.card_bills_require_owner(p_operation_id);
    IF p_invoice_id IS NULL OR p_payment_id IS NULL THEN
        RAISE EXCEPTION 'invoice and payment are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    v_stored := public.card_bills_claim_operation(
        v_owner_id, p_operation_id,
        pg_catalog.jsonb_build_object(
            'card_bills_undo_payment', p_invoice_id,
            'payment', p_payment_id,
            'event', p_reserve_event));
    IF v_stored IS NOT NULL THEN
        RETURN v_stored;
    END IF;

    SELECT invoice.* INTO v_current
    FROM public.card_bill_invoices AS invoice
    WHERE invoice.owner_id = v_owner_id AND invoice.id = p_invoice_id
    FOR UPDATE;

    IF FOUND AND v_current.status = 'paid' AND v_current.payment_id = p_payment_id THEN
        PERFORM public.card_bills_insert_event(
            v_owner_id, p_reserve_event, 'payment_undo', v_current.id,
            v_current.reserve_used_centavos);
        UPDATE public.card_bill_invoices AS invoice
        SET status = 'pending',
            payment_id = NULL,
            paid_amount_centavos = NULL,
            paid_on = NULL,
            payment_source = NULL,
            reserve_used_centavos = NULL,
            expected_amount_centavos = NULL,
            card_name = NULL,
            items_snapshot = NULL,
            updated_at = pg_catalog.clock_timestamp()
        WHERE invoice.owner_id = v_owner_id AND invoice.id = p_invoice_id;
    END IF;

    v_response := pg_catalog.jsonb_build_object('status', 'applied');
    PERFORM public.card_bills_store_response(v_owner_id, p_operation_id, v_response);
    RETURN v_response;
END;
$function$;

-- ------------------------------------------------------- permissões

DO $block$
DECLARE
    f TEXT;
BEGIN
    FOREACH f IN ARRAY ARRAY[
        'public.card_bills_claim_operation(uuid, uuid, jsonb)',
        'public.card_bills_store_response(uuid, uuid, jsonb)',
        'public.card_bills_require_owner(uuid)',
        'public.card_bills_columns(text)',
        'public.card_bills_insert_event(uuid, jsonb, text, uuid, bigint)',
        'public.card_bills_apply(uuid, jsonb, text)',
        'public.card_bills_pay_invoice(uuid, jsonb, jsonb, uuid, jsonb, text)',
        'public.card_bills_undo_payment(uuid, uuid, uuid, jsonb, text)'
    ]
    LOOP
        EXECUTE format('ALTER FUNCTION %s OWNER TO postgres', f);
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    END LOOP;
END;
$block$;

GRANT EXECUTE ON FUNCTION public.card_bills_apply(UUID, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.card_bills_pay_invoice(UUID, JSONB, JSONB, UUID, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.card_bills_undo_payment(UUID, UUID, UUID, JSONB, TEXT) TO authenticated;

COMMENT ON FUNCTION public.card_bills_apply(UUID, JSONB, TEXT)
    IS 'Gestão de faturas: grava/apaga cadastros (última gravação vence; fatura paga congelada), com idempotência.';
COMMENT ON FUNCTION public.card_bills_pay_invoice(UUID, JSONB, JSONB, UUID, JSONB, TEXT)
    IS 'Gestão de faturas: paga a fatura inteira uma só vez (duplicado = conflict), com saída da reserva.';
COMMENT ON FUNCTION public.card_bills_undo_payment(UUID, UUID, UUID, JSONB, TEXT)
    IS 'Gestão de faturas: desfaz o pagamento e devolve à reserva só o que saiu dela.';

-- ------------------------------------------------------ excluir conta

-- Excluir conta (Entrega 73): inclui as tabelas da Gestão de Faturas.
CREATE OR REPLACE FUNCTION public.delete_my_account(p_confirmation TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner_id UUID;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_confirmation IS DISTINCT FROM 'DELETE_MY_ACCOUNT' THEN
        RAISE EXCEPTION 'explicit confirmation is required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    DELETE FROM public.card_bill_reserve_events WHERE owner_id = v_owner_id;
    DELETE FROM public.card_bill_invoices WHERE owner_id = v_owner_id;
    DELETE FROM public.card_bill_charges WHERE owner_id = v_owner_id;
    DELETE FROM public.card_bill_subscriptions WHERE owner_id = v_owner_id;
    DELETE FROM public.card_bill_installments WHERE owner_id = v_owner_id;
    DELETE FROM public.card_bill_purchases WHERE owner_id = v_owner_id;
    DELETE FROM public.card_bill_cards WHERE owner_id = v_owner_id;
    DELETE FROM public.income_entries WHERE owner_id = v_owner_id;
    DELETE FROM public.expense_entries WHERE owner_id = v_owner_id;
    DELETE FROM public.investment_allocations WHERE owner_id = v_owner_id;
    DELETE FROM public.income_recurrence_templates WHERE owner_id = v_owner_id;
    DELETE FROM public.expense_recurrence_templates WHERE owner_id = v_owner_id;
    DELETE FROM public.investment_recurrence_templates WHERE owner_id = v_owner_id;
    DELETE FROM public.period_settings WHERE owner_id = v_owner_id;
    DELETE FROM public.subcategories WHERE owner_id = v_owner_id;
    DELETE FROM public.categories WHERE owner_id = v_owner_id;
    DELETE FROM public.sync_conflicts WHERE owner_id = v_owner_id;
    DELETE FROM public.applied_sync_operations WHERE owner_id = v_owner_id;
    DELETE FROM public.audit_events
     WHERE owner_id = v_owner_id OR actor_id = v_owner_id;
    DELETE FROM public.user_preferences WHERE owner_id = v_owner_id;

    INSERT INTO public.deleted_accounts (owner_id) VALUES (v_owner_id)
    ON CONFLICT (owner_id) DO NOTHING;
    DELETE FROM auth.users WHERE id = v_owner_id;

    RETURN pg_catalog.jsonb_build_object(
        'status', 'deleted',
        'owner_id', v_owner_id
    );
END;
$function$;

COMMIT;
