-- Importação de dados por CSV (RF030, RN046–RN055; IM5 e IM6, 18/11/2026).
-- Spec: docs/importacao.md §10–§12.
--  * import_batches: uma importação (um arquivo). Guarda nome, hash, tamanho,
--    linhas e as decisões do usuário (plano), nunca o conteúdo do arquivo.
--  * import_batch_chunks: blocos aplicados (idempotência por conteúdo).
--  * import_batch_items: o que cada importação criou, com a versão logo após a
--    importação (base do desfazer condicional).
--  * Cada item passa pelas RPCs de sempre (validação, versão, auditoria,
--    repetição segura), com operação derivada de (importação|item|etapa).
--  * Bloco atômico: qualquer falha (ou resposta `conflict`) desfaz o bloco
--    inteiro; a importação fica interrompida com a linha indicada.
--  * Desfazer: só o que não mudou depois; nada é apagado.
-- Migrations anteriores não mudam.
BEGIN;

CREATE TABLE public.import_batches (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('processing', 'completed', 'interrupted',
        'undoing', 'undone', 'partially_undone')),
    file_name TEXT NOT NULL CHECK (pg_catalog.char_length(file_name) BETWEEN 1 AND 255),
    file_sha256 TEXT NOT NULL CHECK (file_sha256 ~ '^[0-9a-f]{64}$'),
    file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes >= 0),
    file_rows INTEGER NOT NULL CHECK (file_rows >= 0),
    plan JSONB NOT NULL CHECK (pg_catalog.jsonb_typeof(plan) = 'object'),
    plan_hash TEXT NOT NULL CHECK (plan_hash ~ '^[0-9a-f]{64}$'),
    total_chunks INTEGER NOT NULL CHECK (total_chunks >= 0),
    item_count INTEGER NOT NULL CHECK (item_count >= 0),
    summary JSONB NOT NULL DEFAULT '{}'::JSONB CHECK (pg_catalog.jsonb_typeof(summary) = 'object'),
    result JSONB,
    last_error JSONB,
    undo_summary JSONB,
    version BIGINT NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    undone_at TIMESTAMPTZ,
    PRIMARY KEY (owner_id, id)
);
COMMENT ON TABLE public.import_batches
    IS 'CSV imports (RF030): file metadata and user decisions only, never the file content.';

-- Uma importação em andamento por usuário (RN054).
CREATE UNIQUE INDEX import_batches_one_open_idx
    ON public.import_batches (owner_id)
    WHERE status IN ('processing', 'interrupted', 'undoing');
CREATE INDEX import_batches_owner_hash_idx
    ON public.import_batches (owner_id, file_sha256);

CREATE TABLE public.import_batch_chunks (
    owner_id UUID NOT NULL,
    batch_id UUID NOT NULL,
    chunk_index INTEGER NOT NULL CHECK (chunk_index >= 0),
    content_hash TEXT NOT NULL,
    item_count INTEGER NOT NULL CHECK (item_count > 0),
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (owner_id, batch_id, chunk_index),
    FOREIGN KEY (owner_id, batch_id)
        REFERENCES public.import_batches (owner_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.import_batch_items (
    owner_id UUID NOT NULL,
    batch_id UUID NOT NULL,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('income_entry', 'expense_entry',
        'investment_allocation', 'income_recurrence_template', 'expense_recurrence_template',
        'investment_recurrence_template', 'category', 'subcategory')),
    entity_id UUID NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('created', 'anchor', 'template', 'occurrence',
        'category', 'subcategory')),
    version_after_import BIGINT NOT NULL CHECK (version_after_import > 0),
    source_row INTEGER,
    undo_outcome TEXT CHECK (undo_outcome IN ('cancelled', 'deactivated',
        'preserved_changed', 'preserved_in_use')),
    undo_reason TEXT,
    PRIMARY KEY (owner_id, batch_id, entity_type, entity_id),
    FOREIGN KEY (owner_id, batch_id)
        REFERENCES public.import_batches (owner_id, id) ON DELETE RESTRICT
);
CREATE INDEX import_batch_items_entity_idx
    ON public.import_batch_items (owner_id, entity_type, entity_id);

DO $grants$
DECLARE
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY ARRAY['import_batches', 'import_batch_chunks', 'import_batch_items']
    LOOP
        EXECUTE pg_catalog.format(
            'REVOKE ALL PRIVILEGES ON TABLE public.%I FROM PUBLIC, anon, authenticated', v_table);
        EXECUTE pg_catalog.format('GRANT SELECT ON TABLE public.%I TO authenticated', v_table);
        EXECUTE pg_catalog.format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', v_table);
        EXECUTE pg_catalog.format(
            'CREATE POLICY porquinho_read_own ON public.%I FOR SELECT TO authenticated '
            'USING (auth.uid() IS NOT NULL AND owner_id = auth.uid())', v_table);
    END LOOP;
END;
$grants$;

-- UUID determinístico (md5, versão 5, variante 8), igual a importUuid no app.
CREATE FUNCTION public.import_uuid(p_name TEXT)
RETURNS UUID
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $function$
    SELECT overlay(overlay(pg_catalog.md5(p_name) PLACING '5' FROM 13 FOR 1)
        PLACING '8' FROM 17 FOR 1)::UUID;
$function$;
ALTER FUNCTION public.import_uuid(TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_uuid(TEXT) FROM PUBLIC, anon, authenticated;

-- Resposta de RPC interna: só 'applied' segue; qualquer outra (inclusive
-- 'conflict', que grava em sync_conflicts) vira erro e desfaz o bloco.
CREATE FUNCTION public.import_require_applied(p_response JSONB, p_what TEXT)
RETURNS JSONB
LANGUAGE plpgsql IMMUTABLE SET search_path = ''
AS $function$
BEGIN
    IF p_response IS NULL OR p_response ->> 'status' IS DISTINCT FROM 'applied' THEN
        RAISE EXCEPTION 'Não foi possível gravar (%): resposta %.', p_what,
            COALESCE(p_response ->> 'status', 'vazia')
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN p_response;
END;
$function$;
ALTER FUNCTION public.import_require_applied(JSONB, TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_require_applied(JSONB, TEXT) FROM PUBLIC, anon, authenticated;

-- Validação repetida no servidor (RN048, D34): valor, data e textos.
CREATE FUNCTION public.import_check_values(
    p_amount BIGINT, p_amount_required BOOLEAN, p_date DATE, p_today DATE,
    p_description TEXT
)
RETURNS VOID
LANGUAGE plpgsql IMMUTABLE SET search_path = ''
AS $function$
BEGIN
    IF p_amount IS NULL AND p_amount_required THEN
        RAISE EXCEPTION 'Valor obrigatório.' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_amount IS NOT NULL AND (p_amount < 0 OR p_amount > 1000000000) THEN
        RAISE EXCEPTION 'Valor fora da faixa aceita (0 a R$ 10.000.000,00).'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_date IS NULL OR p_date < DATE '2000-01-01'
        OR p_date > (p_today + INTERVAL '5 years')::DATE THEN
        RAISE EXCEPTION 'Data fora da faixa aceita (01/01/2000 até hoje + 5 anos).'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_description IS NOT NULL AND pg_catalog.char_length(p_description) > 120 THEN
        RAISE EXCEPTION 'Descrição com mais de 120 caracteres.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
END;
$function$;
ALTER FUNCTION public.import_check_values(BIGINT, BOOLEAN, DATE, DATE, TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_check_values(BIGINT, BOOLEAN, DATE, DATE, TEXT)
    FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.import_check_name(p_name TEXT)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE SET search_path = ''
AS $function$
BEGIN
    IF p_name IS NULL OR pg_catalog.btrim(p_name) = '' OR pg_catalog.char_length(p_name) > 60 THEN
        RAISE EXCEPTION 'Nome de categoria vazio ou com mais de 60 caracteres.'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    RETURN p_name;
END;
$function$;
ALTER FUNCTION public.import_check_name(TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_check_name(TEXT) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.import_record_item(
    p_owner UUID, p_batch UUID, p_entity_type TEXT, p_entity UUID, p_role TEXT,
    p_version BIGINT, p_row INTEGER
)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $function$
    INSERT INTO public.import_batch_items(owner_id, batch_id, entity_type, entity_id, role,
        version_after_import, source_row)
    VALUES (p_owner, p_batch, p_entity_type, p_entity, p_role, p_version, p_row);
$function$;
ALTER FUNCTION public.import_record_item(UUID, UUID, TEXT, UUID, TEXT, BIGINT, INTEGER) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_record_item(UUID, UUID, TEXT, UUID, TEXT, BIGINT, INTEGER)
    FROM PUBLIC, anon, authenticated;

-- Um item do bloco, pelas RPCs existentes. Qualquer problema gera erro.
CREATE FUNCTION public.import_apply_item(p_owner UUID, p_batch UUID, p_item JSONB, p_today DATE)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_type TEXT := p_item ->> 'type';
    v_id UUID := (p_item ->> 'id')::UUID;
    v_row INTEGER := NULLIF(p_item ->> 'row', 'null')::INTEGER;
    v_prefix TEXT := p_batch::TEXT || '|' || (p_item ->> 'id') || '|';
    v_resp JSONB;
    v_kind TEXT;
    v_state TEXT;
    v_entry JSONB;
    v_template JSONB;
    v_template_id UUID;
    v_version BIGINT;
    v_amount BIGINT;
    v_date DATE;
    v_entity TEXT;
BEGIN
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Item sem identificador.' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF v_type = 'category' THEN
        v_resp := public.import_require_applied(public.apply_category_change(
            public.import_uuid(v_prefix || 'create'), 'create', v_id, 0,
            p_item ->> 'kind', public.import_check_name(p_item ->> 'name')), 'categoria');
        PERFORM public.import_record_item(p_owner, p_batch, 'category', v_id, 'category',
            (v_resp #>> '{category,version}')::BIGINT, v_row);

    ELSIF v_type = 'subcategory' THEN
        v_resp := public.import_require_applied(public.apply_subcategory_change(
            public.import_uuid(v_prefix || 'create'), 'create', v_id,
            (p_item ->> 'category_id')::UUID, 0, public.import_check_name(p_item ->> 'name')),
            'subcategoria');
        PERFORM public.import_record_item(p_owner, p_batch, 'subcategory', v_id, 'subcategory',
            (v_resp #>> '{subcategory,version}')::BIGINT, v_row);

    ELSIF v_type = 'income' THEN
        PERFORM public.import_check_values(NULLIF(p_item ->> 'amount_centavos', 'null')::BIGINT,
            TRUE, NULLIF(p_item ->> 'received_on', 'null')::DATE, p_today,
            NULLIF(p_item ->> 'description', 'null'));
        v_resp := public.import_require_applied(public.apply_income_entry_change(
            public.import_uuid(v_prefix || 'create'), 'create', v_id, 0,
            pg_catalog.jsonb_build_object(
                'description', p_item -> 'description',
                'amount_centavos', p_item -> 'amount_centavos',
                'received_on', p_item -> 'received_on',
                'category_id', p_item -> 'category_id',
                'subcategory_id', p_item -> 'subcategory_id')), 'receita');
        PERFORM public.import_record_item(p_owner, p_batch, 'income_entry', v_id, 'created',
            (v_resp #>> '{entry,version}')::BIGINT, v_row);

    ELSIF v_type = 'expense' THEN
        PERFORM public.import_check_values(NULLIF(p_item ->> 'amount_centavos', 'null')::BIGINT,
            TRUE, NULLIF(p_item ->> 'competence_on', 'null')::DATE, p_today,
            NULLIF(p_item ->> 'description', 'null'));
        v_resp := public.import_require_applied(public.apply_expense_entry_change(
            public.import_uuid(v_prefix || 'create'), 'create', v_id, 0,
            pg_catalog.jsonb_build_object(
                'description', p_item -> 'description',
                'amount_centavos', p_item -> 'amount_centavos',
                'competence_on', p_item -> 'competence_on',
                'due_on', p_item -> 'due_on',
                'category_id', p_item -> 'category_id',
                'subcategory_id', p_item -> 'subcategory_id')), 'despesa');
        IF NULLIF(p_item ->> 'paid_on', 'null') IS NOT NULL THEN
            PERFORM public.import_check_values(0, TRUE, (p_item ->> 'paid_on')::DATE, p_today, NULL);
            v_resp := public.import_require_applied(public.apply_expense_entry_change(
                public.import_uuid(v_prefix || 'pay'), 'pay', v_id,
                (v_resp #>> '{entry,version}')::BIGINT,
                pg_catalog.jsonb_build_object('paid_on', p_item -> 'paid_on')), 'pagamento');
        END IF;
        PERFORM public.import_record_item(p_owner, p_batch, 'expense_entry', v_id, 'created',
            (v_resp #>> '{entry,version}')::BIGINT, v_row);

    ELSIF v_type = 'investment' THEN
        v_amount := NULLIF(p_item ->> 'amount_centavos', 'null')::BIGINT;
        v_date := NULLIF(p_item ->> 'allocated_on', 'null')::DATE;
        PERFORM public.import_check_values(v_amount, TRUE, v_date, p_today, NULL);
        v_resp := public.import_require_applied(public.apply_investment_allocation_change(
            public.import_uuid(v_prefix || 'create'), 'create', v_id, 0, v_amount, v_date),
            'investimento');
        PERFORM public.import_record_item(p_owner, p_batch, 'investment_allocation', v_id,
            'created', (v_resp #>> '{allocation,version}')::BIGINT, v_row);

    ELSIF v_type = 'series' THEN
        v_kind := p_item ->> 'kind';
        v_state := p_item ->> 'state';
        v_entry := p_item -> 'entry';
        v_template := p_item -> 'template';
        v_template_id := (p_item ->> 'template_id')::UUID;
        IF v_template_id IS NULL OR v_entry IS NULL OR v_template IS NULL
            OR pg_catalog.jsonb_typeof(v_entry) <> 'object'
            OR pg_catalog.jsonb_typeof(v_template) <> 'object' THEN
            RAISE EXCEPTION 'Série incompleta.' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        v_amount := NULLIF(v_entry ->> 'amount_centavos', 'null')::BIGINT;

        IF v_kind = 'investment' THEN
            v_date := NULLIF(v_entry ->> 'allocated_on', 'null')::DATE;
            PERFORM public.import_check_values(v_amount, TRUE, v_date, p_today, NULL);
            v_resp := public.import_require_applied(public.create_investment_recurrence_from_entry(
                public.import_uuid(v_prefix || 'series'), v_template_id, v_id, 0, v_template,
                pg_catalog.jsonb_build_object('date', v_date, 'amount_centavos', v_amount)),
                'recorrência de investimento');
            v_entity := 'investment_allocation';
            v_version := (v_resp #>> '{allocation,version}')::BIGINT;

        ELSIF v_kind = 'income' THEN
            v_date := NULLIF(v_entry ->> 'received_on', 'null')::DATE;
            PERFORM public.import_check_values(v_amount, v_state = 'received', v_date, p_today,
                NULLIF(v_entry ->> 'description', 'null'));
            IF v_state = 'received' THEN
                v_resp := public.import_require_applied(public.apply_income_entry_change(
                    public.import_uuid(v_prefix || 'create'), 'create', v_id, 0,
                    pg_catalog.jsonb_build_object(
                        'description', v_entry -> 'description',
                        'amount_centavos', v_entry -> 'amount_centavos',
                        'received_on', v_entry -> 'received_on',
                        'category_id', v_entry -> 'category_id',
                        'subcategory_id', v_entry -> 'subcategory_id')), 'receita');
                v_resp := public.import_require_applied(public.create_recurrence_from_entry(
                    public.import_uuid(v_prefix || 'series'), 'income', v_template_id, v_id,
                    (v_resp #>> '{entry,version}')::BIGINT, v_template, NULL), 'recorrência de receita');
            ELSIF v_state = 'pending' THEN
                v_resp := public.import_require_applied(public.create_recurrence_from_entry(
                    public.import_uuid(v_prefix || 'series'), 'income', v_template_id, v_id, 0,
                    v_template, pg_catalog.jsonb_build_object(
                        'date', v_date,
                        'description', v_entry -> 'description',
                        'amount_centavos', v_entry -> 'amount_centavos',
                        'category_id', v_entry -> 'category_id',
                        'subcategory_id', v_entry -> 'subcategory_id')), 'recorrência de receita');
            ELSE
                RAISE EXCEPTION 'Situação de receita inválida.' USING ERRCODE = 'invalid_parameter_value';
            END IF;
            v_entity := 'income_entry';
            v_version := (v_resp #>> '{entry,version}')::BIGINT;

        ELSIF v_kind = 'expense' THEN
            v_date := NULLIF(v_entry ->> 'competence_on', 'null')::DATE;
            PERFORM public.import_check_values(v_amount, FALSE, v_date, p_today,
                NULLIF(v_entry ->> 'description', 'null'));
            IF v_amount IS NULL THEN
                IF v_state <> 'pending' THEN
                    RAISE EXCEPTION 'Despesa paga precisa de valor.' USING ERRCODE = 'invalid_parameter_value';
                END IF;
                v_resp := public.import_require_applied(public.create_recurrence_from_entry(
                    public.import_uuid(v_prefix || 'series'), 'expense', v_template_id, v_id, 0,
                    v_template, pg_catalog.jsonb_build_object(
                        'date', v_date,
                        'description', v_entry -> 'description',
                        'amount_centavos', NULL,
                        'due_on', v_entry -> 'due_on',
                        'category_id', v_entry -> 'category_id',
                        'subcategory_id', v_entry -> 'subcategory_id')), 'recorrência de despesa');
            ELSE
                v_resp := public.import_require_applied(public.apply_expense_entry_change(
                    public.import_uuid(v_prefix || 'create'), 'create', v_id, 0,
                    pg_catalog.jsonb_build_object(
                        'description', v_entry -> 'description',
                        'amount_centavos', v_entry -> 'amount_centavos',
                        'competence_on', v_entry -> 'competence_on',
                        'due_on', v_entry -> 'due_on',
                        'category_id', v_entry -> 'category_id',
                        'subcategory_id', v_entry -> 'subcategory_id')), 'despesa');
                IF v_state = 'paid' THEN
                    PERFORM public.import_check_values(0, TRUE,
                        NULLIF(v_entry ->> 'paid_on', 'null')::DATE, p_today, NULL);
                    v_resp := public.import_require_applied(public.apply_expense_entry_change(
                        public.import_uuid(v_prefix || 'pay'), 'pay', v_id,
                        (v_resp #>> '{entry,version}')::BIGINT,
                        pg_catalog.jsonb_build_object('paid_on', v_entry -> 'paid_on')), 'pagamento');
                END IF;
                v_resp := public.import_require_applied(public.create_recurrence_from_entry(
                    public.import_uuid(v_prefix || 'series'), 'expense', v_template_id, v_id,
                    (v_resp #>> '{entry,version}')::BIGINT, v_template, NULL), 'recorrência de despesa');
            END IF;
            v_entity := 'expense_entry';
            v_version := (v_resp #>> '{entry,version}')::BIGINT;
        ELSE
            RAISE EXCEPTION 'Tipo de série inválido.' USING ERRCODE = 'invalid_parameter_value';
        END IF;

        PERFORM public.import_record_item(p_owner, p_batch, v_entity, v_id, 'anchor', v_version, v_row);
        PERFORM public.import_record_item(p_owner, p_batch, v_kind || '_recurrence_template',
            v_template_id, 'template', (v_resp #>> '{template,version}')::BIGINT, v_row);
    ELSE
        RAISE EXCEPTION 'Tipo de item desconhecido: %.', v_type USING ERRCODE = 'invalid_parameter_value';
    END IF;
END;
$function$;
ALTER FUNCTION public.import_apply_item(UUID, UUID, JSONB, DATE) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_apply_item(UUID, UUID, JSONB, DATE) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.import_user_today(p_owner UUID)
RETURNS DATE
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
    SELECT pg_catalog.timezone(COALESCE(
        (SELECT pref.time_zone_id FROM public.user_preferences pref WHERE pref.owner_id = p_owner),
        'America/Sao_Paulo'), pg_catalog.clock_timestamp())::DATE;
$function$;
ALTER FUNCTION public.import_user_today(UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_user_today(UUID) FROM PUBLIC, anon, authenticated;

-- Começa uma importação. Repetir a operação devolve a mesma resposta.
-- 'blocked' quando há outra em andamento ou o arquivo já foi importado e o
-- plano não traz a confirmação explícita (allow_duplicate_file).
CREATE FUNCTION public.import_begin_batch(
    p_operation_id UUID, p_batch_id UUID, p_file JSONB, p_plan JSONB, p_plan_hash TEXT,
    p_total_chunks INTEGER, p_item_count INTEGER, p_summary JSONB
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB;
    v_hash BYTEA;
    v_saved_hash BYTEA;
    v_saved JSONB;
    v_open public.import_batches%ROWTYPE;
    v_batch public.import_batches%ROWTYPE;
    v_response JSONB;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_batch_id IS NULL OR p_file IS NULL OR p_plan IS NULL
        OR p_plan_hash IS NULL OR p_total_chunks IS NULL OR p_item_count IS NULL
        OR pg_catalog.jsonb_typeof(p_file) <> 'object' OR pg_catalog.jsonb_typeof(p_plan) <> 'object'
        OR p_total_chunks < 0 OR p_item_count < 0
        OR (p_total_chunks = 0) <> (p_item_count = 0)
        OR (p_summary IS NOT NULL AND pg_catalog.jsonb_typeof(p_summary) <> 'object') THEN
        RAISE EXCEPTION 'invalid import batch parameters' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object('batch_id', p_batch_id, 'file', p_file,
        'plan', p_plan, 'plan_hash', p_plan_hash, 'total_chunks', p_total_chunks,
        'item_count', p_item_count, 'summary', p_summary);
    v_hash := pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT, 'UTF8')), 'hex');
    INSERT INTO public.applied_sync_operations(owner_id, idempotency_key, content_hash, result_payload)
    VALUES (v_owner, p_operation_id, v_hash,
        pg_catalog.jsonb_build_object('request', v_request, 'response', NULL))
    ON CONFLICT (owner_id, idempotency_key) DO NOTHING;
    IF NOT FOUND THEN
        SELECT op.content_hash, op.result_payload INTO v_saved_hash, v_saved
        FROM public.applied_sync_operations op
        WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved -> 'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        RETURN v_saved -> 'response';
    END IF;

    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::TEXT || '|import', 0));

    SELECT b.* INTO v_open FROM public.import_batches b
    WHERE b.owner_id = v_owner AND b.status IN ('processing', 'interrupted', 'undoing')
    LIMIT 1;
    IF FOUND THEN
        v_response := pg_catalog.jsonb_build_object('status', 'blocked', 'reason', 'in_progress',
            'batch_id', v_open.id);
    ELSIF EXISTS (SELECT 1 FROM public.import_batches b
        WHERE b.owner_id = v_owner AND b.id = p_batch_id) THEN
        RAISE EXCEPTION 'import batch already exists' USING ERRCODE = 'unique_violation';
    ELSIF EXISTS (SELECT 1 FROM public.import_batches b
        WHERE b.owner_id = v_owner AND b.file_sha256 = p_file ->> 'sha256'
          AND b.status <> 'undone')
        AND (p_plan ->> 'allow_duplicate_file') IS DISTINCT FROM 'true' THEN
        v_response := pg_catalog.jsonb_build_object('status', 'blocked',
            'reason', 'file_already_imported');
    ELSE
        INSERT INTO public.import_batches(owner_id, id, status, file_name, file_sha256,
            file_size_bytes, file_rows, plan, plan_hash, total_chunks, item_count, summary)
        VALUES (v_owner, p_batch_id, 'processing', p_file ->> 'name', p_file ->> 'sha256',
            (p_file ->> 'size_bytes')::BIGINT, (p_file ->> 'rows')::INTEGER, p_plan, p_plan_hash,
            p_total_chunks, p_item_count, COALESCE(p_summary, '{}'::JSONB))
        RETURNING * INTO v_batch;
        INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id, operation, actor_id,
            new_values, operation_id)
        VALUES (v_owner, pg_catalog.gen_random_uuid(), 'import_batch', p_batch_id, 'import_begin',
            v_owner, pg_catalog.jsonb_build_object('file_name', v_batch.file_name,
                'file_sha256', v_batch.file_sha256, 'item_count', v_batch.item_count,
                'total_chunks', v_batch.total_chunks), p_operation_id);
        v_response := pg_catalog.jsonb_build_object('status', 'applied',
            'batch', pg_catalog.to_jsonb(v_batch) - 'plan');
    END IF;

    UPDATE public.applied_sync_operations op
    SET result_payload = pg_catalog.jsonb_build_object('request', v_request, 'response', v_response),
        applied_at = pg_catalog.clock_timestamp()
    WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id;
    RETURN v_response;
END;
$function$;
ALTER FUNCTION public.import_begin_batch(UUID, UUID, JSONB, JSONB, TEXT, INTEGER, INTEGER, JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_begin_batch(UUID, UUID, JSONB, JSONB, TEXT, INTEGER, INTEGER, JSONB)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.import_begin_batch(UUID, UUID, JSONB, JSONB, TEXT, INTEGER, INTEGER, JSONB)
    TO authenticated;
COMMENT ON FUNCTION public.import_begin_batch(UUID, UUID, JSONB, JSONB, TEXT, INTEGER, INTEGER, JSONB)
    IS 'Starts a CSV import (RN054): one open import per user; a file already imported needs explicit confirmation in the plan.';

-- Aplica um bloco numa transação. Bloco já aplicado com o mesmo conteúdo:
-- devolve 'applied' sem refazer; conteúdo diferente: recusa. Falha em um
-- item desfaz o bloco inteiro e deixa a importação interrompida com a linha.
CREATE FUNCTION public.import_apply_chunk(p_batch_id UUID, p_chunk_index INTEGER, p_items JSONB)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_batch public.import_batches%ROWTYPE;
    v_chunk public.import_batch_chunks%ROWTYPE;
    v_hash TEXT;
    v_item JSONB;
    v_row INTEGER;
    v_count INTEGER;
    v_today DATE;
    v_message TEXT;
    v_state TEXT;
    v_response JSONB;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_batch_id IS NULL OR p_chunk_index IS NULL OR p_items IS NULL
        OR pg_catalog.jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION 'batch, chunk index and item array are required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    v_count := pg_catalog.jsonb_array_length(p_items);
    IF v_count = 0 OR v_count > 500 THEN
        RAISE EXCEPTION 'a chunk must have from 1 to 500 items' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT b.* INTO v_batch FROM public.import_batches b
    WHERE b.owner_id = v_owner AND b.id = p_batch_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'import batch was not found' USING ERRCODE = 'no_data_found';
    END IF;
    IF p_chunk_index < 0 OR p_chunk_index >= v_batch.total_chunks THEN
        RAISE EXCEPTION 'chunk index out of range' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_hash := pg_catalog.md5(p_items::TEXT);
    SELECT c.* INTO v_chunk FROM public.import_batch_chunks c
    WHERE c.owner_id = v_owner AND c.batch_id = p_batch_id AND c.chunk_index = p_chunk_index;
    IF FOUND THEN
        IF v_chunk.content_hash <> v_hash THEN
            RAISE EXCEPTION 'chunk already applied with different content' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        RETURN pg_catalog.jsonb_build_object('status', 'applied', 'replayed', TRUE,
            'chunk_index', p_chunk_index, 'items', v_chunk.item_count);
    END IF;
    IF v_batch.status NOT IN ('processing', 'interrupted') THEN
        RAISE EXCEPTION 'import is not in progress' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_today := public.import_user_today(v_owner);
    BEGIN
        FOR v_item IN SELECT value FROM pg_catalog.jsonb_array_elements(p_items) LOOP
            v_row := NULLIF(v_item ->> 'row', 'null')::INTEGER;
            PERFORM public.import_apply_item(v_owner, p_batch_id, v_item, v_today);
        END LOOP;
        INSERT INTO public.import_batch_chunks(owner_id, batch_id, chunk_index, content_hash, item_count)
        VALUES (v_owner, p_batch_id, p_chunk_index, v_hash, v_count);
        UPDATE public.import_batches b
        SET status = 'processing', last_error = NULL, version = b.version + 1,
            updated_at = pg_catalog.clock_timestamp()
        WHERE b.owner_id = v_owner AND b.id = p_batch_id;
        v_response := pg_catalog.jsonb_build_object('status', 'applied', 'replayed', FALSE,
            'chunk_index', p_chunk_index, 'items', v_count);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_message = MESSAGE_TEXT, v_state = RETURNED_SQLSTATE;
        UPDATE public.import_batches b
        SET status = 'interrupted', version = b.version + 1,
            updated_at = pg_catalog.clock_timestamp(),
            last_error = pg_catalog.jsonb_build_object('chunk_index', p_chunk_index,
                'row', v_row, 'message', v_message, 'sqlstate', v_state,
                'at', pg_catalog.clock_timestamp())
        WHERE b.owner_id = v_owner AND b.id = p_batch_id;
        v_response := pg_catalog.jsonb_build_object('status', 'failed',
            'chunk_index', p_chunk_index, 'row', v_row, 'message', v_message);
    END;
    RETURN v_response;
END;
$function$;
ALTER FUNCTION public.import_apply_chunk(UUID, INTEGER, JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_apply_chunk(UUID, INTEGER, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.import_apply_chunk(UUID, INTEGER, JSONB) TO authenticated;
COMMENT ON FUNCTION public.import_apply_chunk(UUID, INTEGER, JSONB)
    IS 'Applies one atomic chunk of a CSV import through the existing write RPCs (RN054).';

-- Conclui: confere os blocos, gera as ocorrências atrasadas uma única vez
-- (RN052), registra as ocorrências dos modelos da importação e o resumo.
CREATE FUNCTION public.import_finish_batch(p_operation_id UUID, p_batch_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_batch public.import_batches%ROWTYPE;
    v_applied INTEGER;
    v_generated JSONB;
    v_occurrences INTEGER;
    v_result JSONB;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_batch_id IS NULL THEN
        RAISE EXCEPTION 'operation and batch are required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    SELECT b.* INTO v_batch FROM public.import_batches b
    WHERE b.owner_id = v_owner AND b.id = p_batch_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'import batch was not found' USING ERRCODE = 'no_data_found';
    END IF;
    IF v_batch.status = 'completed' THEN
        RETURN pg_catalog.jsonb_build_object('status', 'completed',
            'batch', pg_catalog.to_jsonb(v_batch) - 'plan');
    END IF;
    IF v_batch.status NOT IN ('processing', 'interrupted') THEN
        RAISE EXCEPTION 'import is not in progress' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    SELECT pg_catalog.count(*) INTO v_applied FROM public.import_batch_chunks c
    WHERE c.owner_id = v_owner AND c.batch_id = p_batch_id;
    IF v_applied <> v_batch.total_chunks THEN
        RETURN pg_catalog.jsonb_build_object('status', 'incomplete',
            'applied_chunks', v_applied, 'total_chunks', v_batch.total_chunks);
    END IF;

    v_generated := public.generate_due_recurrence_occurrences(
        public.import_uuid(p_batch_id::TEXT || '|finish|generate'));

    -- Ocorrências dos modelos desta importação (inclusive as que outro
    -- aparelho tenha gerado antes do fim), fora as âncoras.
    INSERT INTO public.import_batch_items(owner_id, batch_id, entity_type, entity_id, role,
        version_after_import, source_row)
    SELECT v_owner, p_batch_id, x.entity_type, x.id, 'occurrence', x.version, NULL
    FROM (
        SELECT 'income_entry' AS entity_type, e.id, e.version FROM public.income_entries e
        JOIN public.import_batch_items t ON t.owner_id = v_owner AND t.batch_id = p_batch_id
            AND t.role = 'template' AND t.entity_type = 'income_recurrence_template'
            AND t.entity_id = e.recurrence_template_id
        WHERE e.owner_id = v_owner
        UNION ALL
        SELECT 'expense_entry', e.id, e.version FROM public.expense_entries e
        JOIN public.import_batch_items t ON t.owner_id = v_owner AND t.batch_id = p_batch_id
            AND t.role = 'template' AND t.entity_type = 'expense_recurrence_template'
            AND t.entity_id = e.recurrence_template_id
        WHERE e.owner_id = v_owner
        UNION ALL
        SELECT 'investment_allocation', a.id, a.version FROM public.investment_allocations a
        JOIN public.import_batch_items t ON t.owner_id = v_owner AND t.batch_id = p_batch_id
            AND t.role = 'template' AND t.entity_type = 'investment_recurrence_template'
            AND t.entity_id = a.recurrence_template_id
        WHERE a.owner_id = v_owner
    ) x
    ON CONFLICT (owner_id, batch_id, entity_type, entity_id) DO NOTHING;
    GET DIAGNOSTICS v_occurrences = ROW_COUNT;

    SELECT pg_catalog.jsonb_build_object(
        'categories', pg_catalog.count(*) FILTER (WHERE i.role = 'category'),
        'subcategories', pg_catalog.count(*) FILTER (WHERE i.role = 'subcategory'),
        'incomes', pg_catalog.count(*) FILTER (WHERE i.entity_type = 'income_entry'
            AND i.role IN ('created', 'anchor')),
        'expenses', pg_catalog.count(*) FILTER (WHERE i.entity_type = 'expense_entry'
            AND i.role IN ('created', 'anchor')),
        'investments', pg_catalog.count(*) FILTER (WHERE i.entity_type = 'investment_allocation'
            AND i.role IN ('created', 'anchor')),
        'recurrences', pg_catalog.count(*) FILTER (WHERE i.role = 'template'),
        'occurrences', pg_catalog.count(*) FILTER (WHERE i.role = 'occurrence'))
    INTO v_result
    FROM public.import_batch_items i
    WHERE i.owner_id = v_owner AND i.batch_id = p_batch_id;

    UPDATE public.import_batches b
    SET status = 'completed', result = v_result, last_error = NULL,
        completed_at = pg_catalog.clock_timestamp(), version = b.version + 1,
        updated_at = pg_catalog.clock_timestamp()
    WHERE b.owner_id = v_owner AND b.id = p_batch_id
    RETURNING * INTO v_batch;
    INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id, operation, actor_id,
        new_values, operation_id)
    VALUES (v_owner, pg_catalog.gen_random_uuid(), 'import_batch', p_batch_id, 'import_complete',
        v_owner, v_result, p_operation_id);
    RETURN pg_catalog.jsonb_build_object('status', 'completed',
        'batch', pg_catalog.to_jsonb(v_batch) - 'plan',
        'generated', v_generated -> 'occurrences');
END;
$function$;
ALTER FUNCTION public.import_finish_batch(UUID, UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_finish_batch(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.import_finish_batch(UUID, UUID) TO authenticated;
COMMENT ON FUNCTION public.import_finish_batch(UUID, UUID)
    IS 'Completes a CSV import: checks every chunk, generates due recurrence occurrences once and stores the summary.';

-- IM6 (desfazer) está mais abaixo, na mesma migration.

-- Estado atual de uma entidade da importação. p_lock = travar a linha.
CREATE FUNCTION public.import_entity_state(
    p_owner UUID, p_type TEXT, p_id UUID, p_lock BOOLEAN,
    OUT present BOOLEAN, OUT version BIGINT, OUT active BOOLEAN, OUT initial BOOLEAN,
    OUT template_id UUID
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
    present := FALSE;
    IF p_type = 'income_entry' THEN
        IF p_lock THEN
            SELECT TRUE, e.version, e.status <> 'cancelled', e.status = 'pending', e.recurrence_template_id
            INTO present, version, active, initial, template_id
            FROM public.income_entries e WHERE e.owner_id = p_owner AND e.id = p_id FOR UPDATE;
        ELSE
            SELECT TRUE, e.version, e.status <> 'cancelled', e.status = 'pending', e.recurrence_template_id
            INTO present, version, active, initial, template_id
            FROM public.income_entries e WHERE e.owner_id = p_owner AND e.id = p_id;
        END IF;
    ELSIF p_type = 'expense_entry' THEN
        IF p_lock THEN
            SELECT TRUE, e.version, e.status <> 'cancelled', e.status = 'pending', e.recurrence_template_id
            INTO present, version, active, initial, template_id
            FROM public.expense_entries e WHERE e.owner_id = p_owner AND e.id = p_id FOR UPDATE;
        ELSE
            SELECT TRUE, e.version, e.status <> 'cancelled', e.status = 'pending', e.recurrence_template_id
            INTO present, version, active, initial, template_id
            FROM public.expense_entries e WHERE e.owner_id = p_owner AND e.id = p_id;
        END IF;
    ELSIF p_type = 'investment_allocation' THEN
        IF p_lock THEN
            SELECT TRUE, a.version, a.cancelled_at IS NULL, a.cancelled_at IS NULL, a.recurrence_template_id
            INTO present, version, active, initial, template_id
            FROM public.investment_allocations a WHERE a.owner_id = p_owner AND a.id = p_id FOR UPDATE;
        ELSE
            SELECT TRUE, a.version, a.cancelled_at IS NULL, a.cancelled_at IS NULL, a.recurrence_template_id
            INTO present, version, active, initial, template_id
            FROM public.investment_allocations a WHERE a.owner_id = p_owner AND a.id = p_id;
        END IF;
    ELSIF p_type IN ('income_recurrence_template', 'expense_recurrence_template',
        'investment_recurrence_template', 'category', 'subcategory') THEN
        EXECUTE pg_catalog.format(
            'SELECT TRUE, t.version, t.is_active, t.is_active FROM public.%I t '
            'WHERE t.owner_id = $1 AND t.id = $2 %s',
            CASE p_type
                WHEN 'income_recurrence_template' THEN 'income_recurrence_templates'
                WHEN 'expense_recurrence_template' THEN 'expense_recurrence_templates'
                WHEN 'investment_recurrence_template' THEN 'investment_recurrence_templates'
                WHEN 'category' THEN 'categories'
                ELSE 'subcategories' END,
            CASE WHEN p_lock THEN 'FOR UPDATE' ELSE '' END)
        INTO present, version, active, initial USING p_owner, p_id;
    ELSE
        RAISE EXCEPTION 'unsupported import entity' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    present := COALESCE(present, FALSE);
END;
$function$;
ALTER FUNCTION public.import_entity_state(UUID, TEXT, UUID, BOOLEAN) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_entity_state(UUID, TEXT, UUID, BOOLEAN) FROM PUBLIC, anon, authenticated;

-- Cancela ou desativa pela RPC certa para o papel do item (V23): avulso pela
-- RPC de lançamento; âncora e ocorrências pela de ocorrência; investimento
-- pela de investimento; modelos e categorias pelas suas.
CREATE FUNCTION public.import_undo_call(
    p_batch UUID, p_type TEXT, p_role TEXT, p_id UUID, p_version BIGINT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_op UUID := public.import_uuid(p_batch::TEXT || '|undo|' || p_type || '|' || p_id::TEXT);
    v_resp JSONB;
BEGIN
    v_resp := CASE
        WHEN p_type = 'income_entry' AND p_role = 'created' THEN
            public.apply_income_entry_change(v_op, 'cancel', p_id, p_version, NULL)
        WHEN p_type = 'income_entry' THEN
            public.apply_income_recurrence_occurrence_change(v_op, 'cancel', p_id, p_version, NULL)
        WHEN p_type = 'expense_entry' AND p_role = 'created' THEN
            public.apply_expense_entry_change(v_op, 'cancel', p_id, p_version, NULL)
        WHEN p_type = 'expense_entry' THEN
            public.apply_expense_recurrence_occurrence_change(v_op, 'cancel', p_id, p_version, NULL)
        WHEN p_type = 'investment_allocation' THEN
            public.apply_investment_allocation_change(v_op, 'cancel', p_id, p_version, NULL, NULL)
        WHEN p_type = 'income_recurrence_template' THEN
            public.apply_income_recurrence_template_change(v_op, 'deactivate', p_id, p_version, NULL)
        WHEN p_type = 'expense_recurrence_template' THEN
            public.apply_expense_recurrence_template_change(v_op, 'deactivate', p_id, p_version, NULL)
        WHEN p_type = 'investment_recurrence_template' THEN
            public.apply_investment_recurrence_template_change(v_op, 'deactivate', p_id, p_version, NULL)
        WHEN p_type = 'category' THEN
            public.apply_category_change(v_op, 'deactivate', p_id, p_version, NULL, NULL)
        WHEN p_type = 'subcategory' THEN
            public.apply_subcategory_change(v_op, 'deactivate', p_id, NULL, p_version, NULL)
    END;
    PERFORM public.import_require_applied(v_resp, 'desfazer ' || p_type);
END;
$function$;
ALTER FUNCTION public.import_undo_call(UUID, TEXT, TEXT, UUID, BIGINT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_undo_call(UUID, TEXT, TEXT, UUID, BIGINT) FROM PUBLIC, anon, authenticated;

-- Classifica (p_execute = FALSE) ou executa (TRUE, até p_limit chamadas) o
-- desfazer condicional (RN055), na ordem da spec §10: modelos, ocorrências,
-- âncoras e avulsos, subcategorias e categorias. Item já resolvido não é
-- refeito, então repetir é seguro.
CREATE FUNCTION public.import_undo_run(p_owner UUID, p_batch UUID, p_execute BOOLEAN, p_limit INTEGER)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_item RECORD;
    v_state RECORD;
    v_outcome TEXT;
    v_reason TEXT;
    v_calls INTEGER := 0;
    v_stopped BOOLEAN := FALSE;
    v_ok_templates UUID[] := ARRAY[]::UUID[];
    v_planned UUID[] := ARRAY[]::UUID[];
    v_counts JSONB := '{}'::JSONB;
    v_preserved JSONB := '[]'::JSONB;
    v_in_use BOOLEAN;
    v_step INTEGER;
BEGIN
    IF p_execute THEN
        -- Ocorrências geradas depois pelo app para modelos ainda inalterados
        -- (confirmado em 18/11/2026) entram na lista antes de tudo.
        INSERT INTO public.import_batch_items(owner_id, batch_id, entity_type, entity_id, role,
            version_after_import, source_row)
        SELECT p_owner, p_batch, x.entity_type, x.id, 'occurrence', 1, NULL
        FROM (
            SELECT 'income_entry' AS entity_type, e.id, e.recurrence_template_id AS tid
            FROM public.income_entries e WHERE e.owner_id = p_owner
            UNION ALL
            SELECT 'expense_entry', e.id, e.recurrence_template_id
            FROM public.expense_entries e WHERE e.owner_id = p_owner
            UNION ALL
            SELECT 'investment_allocation', a.id, a.recurrence_template_id
            FROM public.investment_allocations a WHERE a.owner_id = p_owner
        ) x
        JOIN public.import_batch_items t ON t.owner_id = p_owner AND t.batch_id = p_batch
            AND t.role = 'template' AND t.entity_id = x.tid
        ON CONFLICT (owner_id, batch_id, entity_type, entity_id) DO NOTHING;
    END IF;

    FOR v_step IN 1..5 LOOP
        EXIT WHEN v_stopped;
        FOR v_item IN
            SELECT i.entity_type, i.entity_id, i.role, i.version_after_import, i.source_row,
                i.undo_outcome, FALSE AS virtual
            FROM public.import_batch_items i
            WHERE i.owner_id = p_owner AND i.batch_id = p_batch
              AND i.role = ANY (CASE v_step
                  WHEN 1 THEN ARRAY['template']
                  WHEN 2 THEN ARRAY['occurrence']
                  WHEN 3 THEN ARRAY['anchor', 'created']
                  WHEN 4 THEN ARRAY['subcategory']
                  ELSE ARRAY['category'] END)
            UNION ALL
            -- Prévia: ocorrências geradas depois, ainda fora da lista.
            SELECT x.entity_type, x.id, 'occurrence', 1, NULL, NULL, TRUE
            FROM (
                SELECT 'income_entry' AS entity_type, e.id, e.recurrence_template_id AS tid
                FROM public.income_entries e WHERE e.owner_id = p_owner
                UNION ALL
                SELECT 'expense_entry', e.id, e.recurrence_template_id
                FROM public.expense_entries e WHERE e.owner_id = p_owner
                UNION ALL
                SELECT 'investment_allocation', a.id, a.recurrence_template_id
                FROM public.investment_allocations a WHERE a.owner_id = p_owner
            ) x
            JOIN public.import_batch_items t ON t.owner_id = p_owner AND t.batch_id = p_batch
                AND t.role = 'template' AND t.entity_id = x.tid
            WHERE v_step = 2 AND NOT p_execute
              AND NOT EXISTS (SELECT 1 FROM public.import_batch_items o
                  WHERE o.owner_id = p_owner AND o.batch_id = p_batch
                    AND o.entity_type = x.entity_type AND o.entity_id = x.id)
            ORDER BY 1, 2
        LOOP
            v_reason := NULL;
            IF v_item.undo_outcome IS NOT NULL THEN
                v_outcome := v_item.undo_outcome;
                IF v_outcome = 'deactivated' AND v_item.role = 'template' THEN
                    v_ok_templates := v_ok_templates || v_item.entity_id;
                END IF;
            ELSE
                SELECT * INTO v_state FROM public.import_entity_state(p_owner, v_item.entity_type,
                    v_item.entity_id, p_execute);
                IF NOT v_state.present THEN
                    v_outcome := 'preserved_changed';
                    v_reason := 'Não encontrado.';
                ELSIF v_item.role = 'template' THEN
                    IF v_state.active AND v_state.version = v_item.version_after_import THEN
                        v_outcome := 'deactivated';
                        v_ok_templates := v_ok_templates || v_item.entity_id;
                    ELSE
                        v_outcome := 'preserved_changed';
                        v_reason := 'Recorrência alterada depois da importação.';
                    END IF;
                ELSIF v_item.role IN ('occurrence', 'anchor')
                    AND NOT COALESCE(v_state.template_id = ANY (v_ok_templates), FALSE) THEN
                    v_outcome := 'preserved_changed';
                    v_reason := 'A recorrência foi alterada depois da importação.';
                ELSIF v_item.role IN ('occurrence', 'anchor', 'created') THEN
                    IF v_state.active AND v_state.version = v_item.version_after_import
                        AND (v_item.role <> 'occurrence' OR v_state.initial) THEN
                        v_outcome := 'cancelled';
                    ELSE
                        v_outcome := 'preserved_changed';
                        v_reason := CASE WHEN v_state.active
                            THEN 'Alterado, pago ou recebido depois da importação.'
                            ELSE 'Cancelado depois da importação.' END;
                    END IF;
                ELSE
                    IF NOT v_state.active OR v_state.version <> v_item.version_after_import THEN
                        v_outcome := 'preserved_changed';
                        v_reason := 'Alterada depois da importação.';
                    ELSE
                        IF v_item.role = 'subcategory' THEN
                            v_in_use :=
                                EXISTS (SELECT 1 FROM public.income_entries e WHERE e.owner_id = p_owner
                                    AND e.subcategory_id = v_item.entity_id AND e.status <> 'cancelled'
                                    AND NOT (e.id = ANY (v_planned)))
                                OR EXISTS (SELECT 1 FROM public.expense_entries e WHERE e.owner_id = p_owner
                                    AND e.subcategory_id = v_item.entity_id AND e.status <> 'cancelled'
                                    AND NOT (e.id = ANY (v_planned)))
                                OR EXISTS (SELECT 1 FROM public.income_recurrence_templates t WHERE t.owner_id = p_owner
                                    AND t.subcategory_id = v_item.entity_id AND t.is_active
                                    AND NOT (t.id = ANY (v_planned)))
                                OR EXISTS (SELECT 1 FROM public.expense_recurrence_templates t WHERE t.owner_id = p_owner
                                    AND t.subcategory_id = v_item.entity_id AND t.is_active
                                    AND NOT (t.id = ANY (v_planned)));
                        ELSE
                            v_in_use :=
                                EXISTS (SELECT 1 FROM public.income_entries e WHERE e.owner_id = p_owner
                                    AND e.category_id = v_item.entity_id AND e.status <> 'cancelled'
                                    AND NOT (e.id = ANY (v_planned)))
                                OR EXISTS (SELECT 1 FROM public.expense_entries e WHERE e.owner_id = p_owner
                                    AND e.category_id = v_item.entity_id AND e.status <> 'cancelled'
                                    AND NOT (e.id = ANY (v_planned)))
                                OR EXISTS (SELECT 1 FROM public.income_recurrence_templates t WHERE t.owner_id = p_owner
                                    AND t.category_id = v_item.entity_id AND t.is_active
                                    AND NOT (t.id = ANY (v_planned)))
                                OR EXISTS (SELECT 1 FROM public.expense_recurrence_templates t WHERE t.owner_id = p_owner
                                    AND t.category_id = v_item.entity_id AND t.is_active
                                    AND NOT (t.id = ANY (v_planned)))
                                OR EXISTS (SELECT 1 FROM public.subcategories s WHERE s.owner_id = p_owner
                                    AND s.category_id = v_item.entity_id AND s.is_active
                                    AND NOT (s.id = ANY (v_planned)));
                        END IF;
                        IF v_in_use THEN
                            v_outcome := 'preserved_in_use';
                            v_reason := 'Em uso por lançamento ou recorrência.';
                        ELSE
                            v_outcome := 'deactivated';
                        END IF;
                    END IF;
                END IF;

                IF v_outcome IN ('cancelled', 'deactivated') THEN
                    v_planned := v_planned || v_item.entity_id;
                END IF;
                IF p_execute THEN
                    IF v_outcome IN ('cancelled', 'deactivated') THEN
                        IF p_limit IS NOT NULL AND v_calls >= p_limit THEN
                            v_stopped := TRUE;
                            EXIT;
                        END IF;
                        PERFORM public.import_undo_call(p_batch, v_item.entity_type, v_item.role,
                            v_item.entity_id, v_state.version);
                        v_calls := v_calls + 1;
                    END IF;
                    UPDATE public.import_batch_items i
                    SET undo_outcome = v_outcome, undo_reason = v_reason
                    WHERE i.owner_id = p_owner AND i.batch_id = p_batch
                      AND i.entity_type = v_item.entity_type AND i.entity_id = v_item.entity_id;
                END IF;
            END IF;

            v_counts := pg_catalog.jsonb_set(v_counts, ARRAY[v_outcome],
                pg_catalog.to_jsonb(COALESCE((v_counts ->> v_outcome)::INTEGER, 0) + 1));
            v_counts := pg_catalog.jsonb_set(v_counts, ARRAY[v_outcome || ':' || v_item.role],
                pg_catalog.to_jsonb(COALESCE((v_counts ->> (v_outcome || ':' || v_item.role))::INTEGER, 0) + 1));
            IF v_outcome LIKE 'preserved%' AND pg_catalog.jsonb_array_length(v_preserved) < 200 THEN
                v_preserved := v_preserved || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                    'entity_type', v_item.entity_type, 'entity_id', v_item.entity_id,
                    'role', v_item.role, 'row', v_item.source_row, 'outcome', v_outcome,
                    'reason', COALESCE(v_reason, (SELECT i.undo_reason FROM public.import_batch_items i
                        WHERE i.owner_id = p_owner AND i.batch_id = p_batch
                          AND i.entity_type = v_item.entity_type AND i.entity_id = v_item.entity_id))));
            END IF;
        END LOOP;
    END LOOP;

    RETURN pg_catalog.jsonb_build_object('remaining', v_stopped, 'calls', v_calls,
        'counts', v_counts, 'preserved', v_preserved);
END;
$function$;
ALTER FUNCTION public.import_undo_run(UUID, UUID, BOOLEAN, INTEGER) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_undo_run(UUID, UUID, BOOLEAN, INTEGER) FROM PUBLIC, anon, authenticated;

-- Prévia do desfazer: só leitura.
CREATE FUNCTION public.import_undo_preview(p_batch_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_batch public.import_batches%ROWTYPE;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    SELECT b.* INTO v_batch FROM public.import_batches b
    WHERE b.owner_id = v_owner AND b.id = p_batch_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'import batch was not found' USING ERRCODE = 'no_data_found';
    END IF;
    RETURN public.import_undo_run(v_owner, p_batch_id, FALSE, NULL)
        || pg_catalog.jsonb_build_object('batch_status', v_batch.status);
END;
$function$;
ALTER FUNCTION public.import_undo_preview(UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_undo_preview(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.import_undo_preview(UUID) TO authenticated;
COMMENT ON FUNCTION public.import_undo_preview(UUID)
    IS 'Read-only preview of the conditional undo of a CSV import (RN055).';

-- Desfaz em partes (até p_limit chamadas por vez); repetir é seguro. Ao fim,
-- 'undone' (tudo cancelado/desativado) ou 'partially_undone' (algo
-- preservado). Não pode ser desfeito.
CREATE FUNCTION public.import_undo_batch(p_batch_id UUID, p_limit INTEGER)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_batch public.import_batches%ROWTYPE;
    v_run JSONB;
    v_preserved INTEGER;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_batch_id IS NULL OR p_limit IS NULL OR p_limit < 1 OR p_limit > 1000 THEN
        RAISE EXCEPTION 'batch and a limit from 1 to 1000 are required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    SELECT b.* INTO v_batch FROM public.import_batches b
    WHERE b.owner_id = v_owner AND b.id = p_batch_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'import batch was not found' USING ERRCODE = 'no_data_found';
    END IF;
    IF v_batch.status IN ('undone', 'partially_undone') THEN
        RETURN pg_catalog.jsonb_build_object('remaining', FALSE, 'calls', 0,
            'counts', v_batch.undo_summary -> 'counts',
            'preserved', v_batch.undo_summary -> 'preserved',
            'batch', pg_catalog.to_jsonb(v_batch) - 'plan');
    END IF;
    IF v_batch.status = 'processing' AND EXISTS (SELECT 1 FROM public.import_batches b
        WHERE b.owner_id = v_owner AND b.status = 'undoing' AND b.id <> p_batch_id) THEN
        RAISE EXCEPTION 'another undo is in progress' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF v_batch.status <> 'undoing' THEN
        IF v_batch.status NOT IN ('completed', 'processing', 'interrupted') THEN
            RAISE EXCEPTION 'this import cannot be undone' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::TEXT || '|import', 0));
        IF v_batch.status = 'completed' AND EXISTS (SELECT 1 FROM public.import_batches b
            WHERE b.owner_id = v_owner AND b.id <> p_batch_id
              AND b.status IN ('processing', 'interrupted', 'undoing')) THEN
            RETURN pg_catalog.jsonb_build_object('status', 'blocked', 'reason', 'in_progress');
        END IF;
        UPDATE public.import_batches b
        SET status = 'undoing', version = b.version + 1, updated_at = pg_catalog.clock_timestamp()
        WHERE b.owner_id = v_owner AND b.id = p_batch_id;
    END IF;

    v_run := public.import_undo_run(v_owner, p_batch_id, TRUE, p_limit);
    IF (v_run ->> 'remaining')::BOOLEAN THEN
        RETURN v_run || pg_catalog.jsonb_build_object('status', 'undoing');
    END IF;

    v_preserved := COALESCE((v_run #>> '{counts,preserved_changed}')::INTEGER, 0)
        + COALESCE((v_run #>> '{counts,preserved_in_use}')::INTEGER, 0);
    UPDATE public.import_batches b
    SET status = CASE WHEN v_preserved > 0 THEN 'partially_undone' ELSE 'undone' END,
        undo_summary = pg_catalog.jsonb_build_object('counts', v_run -> 'counts',
            'preserved', v_run -> 'preserved'),
        undone_at = pg_catalog.clock_timestamp(), version = b.version + 1,
        updated_at = pg_catalog.clock_timestamp()
    WHERE b.owner_id = v_owner AND b.id = p_batch_id
    RETURNING * INTO v_batch;
    INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id, operation, actor_id,
        new_values)
    VALUES (v_owner, pg_catalog.gen_random_uuid(), 'import_batch', p_batch_id, 'import_undo',
        v_owner, v_batch.undo_summary);
    RETURN v_run || pg_catalog.jsonb_build_object('status', v_batch.status,
        'batch', pg_catalog.to_jsonb(v_batch) - 'plan');
END;
$function$;
ALTER FUNCTION public.import_undo_batch(UUID, INTEGER) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.import_undo_batch(UUID, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.import_undo_batch(UUID, INTEGER) TO authenticated;
COMMENT ON FUNCTION public.import_undo_batch(UUID, INTEGER)
    IS 'Conditional undo of a CSV import (RN055), in parts; only what was not changed afterwards is cancelled or deactivated.';

-- Exclusão de conta inclui a importação.
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

    DELETE FROM public.import_batch_items WHERE owner_id = v_owner_id;
    DELETE FROM public.import_batch_chunks WHERE owner_id = v_owner_id;
    DELETE FROM public.import_batches WHERE owner_id = v_owner_id;
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
