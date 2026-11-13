-- Reestruturação de períodos, Entrega P6 (13/11/2026; RN001, RN002, RN004,
-- RN036, RN038 D4): configuração única de período, trocável a qualquer momento
-- e valendo para todos os períodos; o servidor deixa de gravar períodos.
--  * period_settings: uma linha por usuário (modalidade + dia inicial), com
--    versão. Escrita só pela RPC set_period_settings, idempotente, auditada e
--    com conflito por versão (resolve_sync_conflict passa a aceitá-la). Os
--    usuários existentes recebem a configuração em vigor hoje.
--  * O vínculo do lançamento com o período (accounting_period_id,
--    scheduled_period_id) fica opcional e deixa de ser gravado: as RPCs de
--    lançamento, ocorrência, conversão e geração não procuram mais período e
--    não recusam data sem período (D4 superada). Totais já somam por data
--    (get_range_report, P3).
--  * accounting_periods, period_configurations, as RPCs de período e
--    get_period_report continuam até a limpeza (P7), sem uso pelo app.
-- Migrations anteriores não mudam.
BEGIN;

CREATE TABLE public.period_settings (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    mode TEXT NOT NULL CHECK (mode IN ('calendar_month', 'custom_cycle')),
    custom_start_day SMALLINT,
    version BIGINT NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (owner_id, id),
    UNIQUE (owner_id),
    CHECK (id = owner_id),
    CHECK (
        (mode = 'calendar_month' AND custom_start_day IS NULL)
        OR (mode = 'custom_cycle'
            AND custom_start_day IS NOT NULL
            AND custom_start_day BETWEEN 1 AND 31)
    )
);
COMMENT ON TABLE public.period_settings
    IS 'Single period configuration per user (RN001/RN002, 13/11/2026); id = owner_id. Periods are computed from it, never stored.';

CREATE INDEX period_settings_owner_updated_idx
    ON public.period_settings (owner_id, updated_at, id);

REVOKE ALL PRIVILEGES ON TABLE public.period_settings FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.period_settings TO authenticated;
ALTER TABLE public.period_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY porquinho_read_own ON public.period_settings
    FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL AND owner_id = auth.uid());

-- Usuários existentes: a configuração em vigor hoje (a de maior início até
-- hoje; se todas forem futuras, a primeira).
INSERT INTO public.period_settings (owner_id, id, mode, custom_start_day)
SELECT DISTINCT ON (c.owner_id) c.owner_id, c.owner_id, c.mode, c.custom_start_day
FROM public.period_configurations AS c
LEFT JOIN public.user_preferences AS pref ON pref.owner_id = c.owner_id
ORDER BY c.owner_id,
    (c.effective_from <= pg_catalog.timezone(
        COALESCE(pref.time_zone_id, 'America/Sao_Paulo'),
        pg_catalog.clock_timestamp())::DATE) DESC,
    CASE WHEN c.effective_from <= pg_catalog.timezone(
        COALESCE(pref.time_zone_id, 'America/Sao_Paulo'),
        pg_catalog.clock_timestamp())::DATE
        THEN c.effective_from END DESC NULLS LAST,
    c.effective_from ASC;

-- Grava a configuração única. p_expected_version 0 = criar (primeiro acesso);
-- > 0 = trocar. Versão diferente da atual gera conflito (nunca "última
-- gravação vence"); repetir a operação devolve a mesma resposta.
CREATE FUNCTION public.set_period_settings(
    p_operation_id UUID,
    p_expected_version BIGINT,
    p_mode TEXT,
    p_custom_start_day SMALLINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB;
    v_hash BYTEA;
    v_saved_hash BYTEA;
    v_saved JSONB;
    v_row public.period_settings%ROWTYPE;
    v_previous JSONB;
    v_conflict UUID;
    v_response JSONB;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_expected_version IS NULL OR p_mode IS NULL
        OR p_expected_version < 0 THEN
        RAISE EXCEPTION 'operation, expected version and mode are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_mode = 'calendar_month' THEN
        IF p_custom_start_day IS NOT NULL THEN
            RAISE EXCEPTION 'calendar month does not accept a custom start day'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSIF p_mode = 'custom_cycle' THEN
        IF p_custom_start_day IS NULL OR p_custom_start_day NOT BETWEEN 1 AND 31 THEN
            RAISE EXCEPTION 'custom cycle requires a start day from 1 through 31'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSE
        RAISE EXCEPTION 'unsupported accounting period mode'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object(
        'action', CASE WHEN p_expected_version = 0 THEN 'create' ELSE 'update' END,
        'expected_version', p_expected_version,
        'mode', p_mode,
        'custom_start_day', p_custom_start_day);
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
            RAISE EXCEPTION 'idempotency key reused with different content'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        RETURN v_saved -> 'response';
    END IF;

    -- Uma gravação por vez por usuário.
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::TEXT, 7));
    SELECT s.* INTO v_row FROM public.period_settings s
    WHERE s.owner_id = v_owner FOR UPDATE;

    IF FOUND AND v_row.version <> p_expected_version THEN
        INSERT INTO public.sync_conflicts(owner_id, id, entity_type, entity_id,
            base_version, remote_version, local_snapshot, remote_snapshot)
        VALUES (v_owner, pg_catalog.gen_random_uuid(), 'period_settings', v_owner,
            p_expected_version, v_row.version, v_request, pg_catalog.to_jsonb(v_row))
        RETURNING id INTO v_conflict;
        v_response := pg_catalog.jsonb_build_object('status', 'conflict',
            'conflict_id', v_conflict, 'remote_settings', pg_catalog.to_jsonb(v_row));
    ELSIF NOT FOUND AND p_expected_version > 0 THEN
        RAISE EXCEPTION 'period settings were not found for the authenticated user'
            USING ERRCODE = 'no_data_found';
    ELSIF NOT FOUND THEN
        INSERT INTO public.period_settings (owner_id, id, mode, custom_start_day)
        VALUES (v_owner, v_owner, p_mode, p_custom_start_day)
        RETURNING * INTO v_row;
        INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id, operation,
            actor_id, new_values, operation_id)
        VALUES (v_owner, pg_catalog.gen_random_uuid(), 'period_settings', v_owner, 'create',
            v_owner, pg_catalog.to_jsonb(v_row), p_operation_id);
        v_response := pg_catalog.jsonb_build_object('status', 'applied',
            'settings', pg_catalog.to_jsonb(v_row));
    ELSE
        v_previous := pg_catalog.to_jsonb(v_row);
        UPDATE public.period_settings s
        SET mode = p_mode, custom_start_day = p_custom_start_day,
            version = s.version + 1, updated_at = pg_catalog.clock_timestamp()
        WHERE s.owner_id = v_owner
        RETURNING s.* INTO v_row;
        INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id, operation,
            actor_id, previous_values, new_values, operation_id)
        VALUES (v_owner, pg_catalog.gen_random_uuid(), 'period_settings', v_owner, 'update',
            v_owner, v_previous, pg_catalog.to_jsonb(v_row), p_operation_id);
        v_response := pg_catalog.jsonb_build_object('status', 'applied',
            'settings', pg_catalog.to_jsonb(v_row));
    END IF;

    UPDATE public.applied_sync_operations op
    SET result_payload = pg_catalog.jsonb_build_object('request', v_request, 'response', v_response),
        applied_at = pg_catalog.clock_timestamp()
    WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id;
    RETURN v_response;
END;
$function$;
ALTER FUNCTION public.set_period_settings(UUID, BIGINT, TEXT, SMALLINT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.set_period_settings(UUID, BIGINT, TEXT, SMALLINT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_period_settings(UUID, BIGINT, TEXT, SMALLINT) TO authenticated;
COMMENT ON FUNCTION public.set_period_settings(UUID, BIGINT, TEXT, SMALLINT)
    IS 'Creates or changes the single period configuration of the authenticated user, idempotently, audited and with version conflicts.';

-- Vínculo com o período: opcional e não mais gravado.
ALTER TABLE public.expense_entries ALTER COLUMN accounting_period_id DROP NOT NULL;
ALTER TABLE public.investment_allocations ALTER COLUMN accounting_period_id DROP NOT NULL;

-- Receita: a regra de status deixa de exigir o vínculo (mantém o resto).
DO $constraints$
DECLARE
    v_name TEXT;
BEGIN
    FOR v_name IN
        SELECT con.conname FROM pg_catalog.pg_constraint con
        WHERE con.conrelid = 'public.income_entries'::REGCLASS
          AND con.contype = 'c'
          AND pg_catalog.pg_get_constraintdef(con.oid) LIKE '%accounting_period_id%'
    LOOP
        EXECUTE pg_catalog.format('ALTER TABLE public.income_entries DROP CONSTRAINT %I', v_name);
    END LOOP;
END;
$constraints$;
ALTER TABLE public.income_entries ADD CONSTRAINT income_entries_status_dates_check CHECK (
    (status = 'pending' AND recurrence_template_id IS NOT NULL AND received_on IS NULL)
    OR (status = 'received' AND amount_centavos IS NOT NULL AND received_on IS NOT NULL)
    OR (status = 'cancelled'
        AND (received_on IS NULL OR amount_centavos IS NOT NULL))
);

-- Navegação entre períodos calculados (RN002): data do lançamento mais antigo
-- e do mais distante (competência; receita pendente pela data programada).
-- Somente leitura, isolada por RLS.
CREATE FUNCTION public.get_entry_date_span()
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
    WITH dates AS (
        SELECT COALESCE(e.received_on, e.scheduled_for_date) AS d
        FROM public.income_entries e WHERE e.owner_id = auth.uid()
        UNION ALL
        SELECT e.competence_on FROM public.expense_entries e WHERE e.owner_id = auth.uid()
        UNION ALL
        SELECT a.allocated_on FROM public.investment_allocations a WHERE a.owner_id = auth.uid()
    )
    SELECT pg_catalog.jsonb_build_object('oldest', pg_catalog.min(d), 'newest', pg_catalog.max(d))
    FROM dates;
$function$;
REVOKE ALL ON FUNCTION public.get_entry_date_span() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_entry_date_span() TO authenticated;
COMMENT ON FUNCTION public.get_entry_date_span()
    IS 'Oldest and newest competence date among the authenticated user entries (period navigation bounds).';

CREATE OR REPLACE FUNCTION public.apply_income_entry_change(
    p_operation_id UUID, p_action TEXT, p_entry_id UUID,
    p_expected_version BIGINT, p_payload JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB;
    v_hash BYTEA;
    v_claimed UUID;
    v_saved_hash BYTEA;
    v_saved JSONB;
    v_entry public.income_entries%ROWTYPE;
    v_existing public.income_entries%ROWTYPE;
    v_conflict UUID;
    v_response JSONB;
    v_previous JSONB;
    v_audit TEXT;
    v_amount BIGINT;
    v_received DATE;
    v_description TEXT;
    v_category UUID;
    v_subcategory UUID;
BEGIN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification'; END IF;
    IF p_operation_id IS NULL OR p_entry_id IS NULL OR p_expected_version IS NULL OR p_action IS NULL THEN
        RAISE EXCEPTION 'operation, action, entry and expected version are required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_action NOT IN ('create', 'update', 'cancel') OR p_expected_version < 0
        OR (p_action = 'create' AND p_expected_version <> 0)
        OR (p_action <> 'create' AND p_expected_version = 0) THEN
        RAISE EXCEPTION 'unsupported income action or expected version' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_action <> 'cancel' AND (p_payload IS NULL OR pg_catalog.jsonb_typeof(p_payload) <> 'object') THEN
        RAISE EXCEPTION 'income payload must be an object' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    v_request := pg_catalog.jsonb_build_object('action', p_action, 'entry_id', p_entry_id,
        'expected_version', p_expected_version, 'payload', p_payload);
    v_hash := pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT, 'UTF8')), 'hex');
    INSERT INTO public.applied_sync_operations(owner_id, idempotency_key, content_hash, result_payload)
    VALUES (v_owner, p_operation_id, v_hash, pg_catalog.jsonb_build_object('request',v_request,'response',NULL))
    ON CONFLICT (owner_id,idempotency_key) DO NOTHING RETURNING idempotency_key INTO v_claimed;
    IF NOT FOUND THEN
        SELECT op.content_hash, op.result_payload INTO v_saved_hash, v_saved FROM public.applied_sync_operations op
        WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved->'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE='invalid_parameter_value';
        END IF;
        RETURN v_saved->'response';
    END IF;

    IF p_action <> 'create' THEN
        SELECT entry.* INTO v_entry FROM public.income_entries entry
        WHERE entry.owner_id=v_owner AND entry.id=p_entry_id AND entry.recurrence_template_id IS NULL FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'one-time income was not found' USING ERRCODE='no_data_found'; END IF;
        IF v_entry.version <> p_expected_version THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_entry',p_entry_id,p_expected_version,v_entry.version,v_request,pg_catalog.to_jsonb(v_entry))
            RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_entry',pg_catalog.to_jsonb(v_entry));
        END IF;
    ELSE
        SELECT entry.* INTO v_existing FROM public.income_entries entry
        WHERE entry.owner_id=v_owner AND entry.id=p_entry_id FOR UPDATE;
        IF FOUND THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_entry',p_entry_id,0,v_existing.version,v_request,pg_catalog.to_jsonb(v_existing))
            RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_entry',pg_catalog.to_jsonb(v_existing));
        END IF;
    END IF;

    IF v_response IS NULL THEN
        IF p_action='cancel' THEN
            v_previous:=pg_catalog.to_jsonb(v_entry);
            UPDATE public.income_entries entry SET status='cancelled',version=entry.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE entry.owner_id=v_owner AND entry.id=p_entry_id RETURNING entry.* INTO v_entry;
            v_audit:='cancel';
        ELSE
            IF p_action='create' THEN
                IF NOT (p_payload ? 'amount_centavos') OR NOT (p_payload ? 'received_on') THEN
                    RAISE EXCEPTION 'income creation requires amount_centavos and received_on' USING ERRCODE='invalid_parameter_value';
                END IF;
                v_amount:=NULLIF(p_payload->>'amount_centavos','null')::BIGINT;
                v_received:=NULLIF(p_payload->>'received_on','null')::DATE;
                v_description:=NULLIF(p_payload->>'description','null');
                v_category:=NULLIF(p_payload->>'category_id','null')::UUID;
                v_subcategory:=NULLIF(p_payload->>'subcategory_id','null')::UUID;
            ELSE
                v_amount:=CASE WHEN p_payload ? 'amount_centavos' THEN NULLIF(p_payload->>'amount_centavos','null')::BIGINT ELSE v_entry.amount_centavos END;
                v_received:=CASE WHEN p_payload ? 'received_on' THEN NULLIF(p_payload->>'received_on','null')::DATE ELSE v_entry.received_on END;
                v_description:=CASE WHEN p_payload ? 'description' THEN NULLIF(p_payload->>'description','null') ELSE v_entry.description END;
                v_category:=CASE WHEN p_payload ? 'category_id' THEN NULLIF(p_payload->>'category_id','null')::UUID ELSE v_entry.category_id END;
                v_subcategory:=CASE WHEN p_payload ? 'subcategory_id' THEN NULLIF(p_payload->>'subcategory_id','null')::UUID ELSE v_entry.subcategory_id END;
            END IF;
            IF v_amount IS NULL OR v_amount<0 OR v_received IS NULL THEN
                RAISE EXCEPTION 'income amount must be nonnegative and received_on is required' USING ERRCODE='invalid_parameter_value';
            END IF;
            IF v_category IS NOT NULL AND (p_action='create' OR v_category IS DISTINCT FROM v_entry.category_id) THEN
                IF NOT EXISTS (SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='income' AND c.is_active) THEN
                    RAISE EXCEPTION 'new income category must belong to the user, be active and have income kind' USING ERRCODE='check_violation';
                END IF;
            END IF;
            IF v_subcategory IS NOT NULL AND (p_action='create' OR v_category IS DISTINCT FROM v_entry.category_id
                OR v_subcategory IS DISTINCT FROM v_entry.subcategory_id) THEN
                IF NOT EXISTS (SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='income' AND c.is_active) THEN
                    RAISE EXCEPTION 'a new income subcategory association requires an active category' USING ERRCODE='check_violation';
                END IF;
                IF v_subcategory IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.subcategories s
                    WHERE s.owner_id=v_owner AND s.category_id=v_category AND s.id=v_subcategory AND s.is_active) THEN
                    RAISE EXCEPTION 'new income subcategory must belong to the active category' USING ERRCODE='check_violation';
                END IF;
            END IF;
            IF p_action='create' THEN
                INSERT INTO public.income_entries(owner_id,id,description,amount_centavos,status,received_on,category_id,subcategory_id)
                VALUES(v_owner,p_entry_id,v_description,v_amount,'received',v_received,v_category,v_subcategory)
                RETURNING * INTO v_entry;
                v_audit:='create';
            ELSE
                v_previous:=pg_catalog.to_jsonb(v_entry);
                UPDATE public.income_entries entry SET description=v_description,amount_centavos=v_amount,
                    received_on=v_received,category_id=v_category,subcategory_id=v_subcategory,
                    version=entry.version+1,updated_at=pg_catalog.clock_timestamp()
                WHERE entry.owner_id=v_owner AND entry.id=p_entry_id RETURNING entry.* INTO v_entry;
                v_audit:='update';
            END IF;
        END IF;
        IF v_audit IS NOT NULL THEN
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_entry',p_entry_id,v_audit,v_owner,v_previous,pg_catalog.to_jsonb(v_entry),p_operation_id);
            v_response:=pg_catalog.jsonb_build_object('status','applied','entry',pg_catalog.to_jsonb(v_entry));
        END IF;
    END IF;
    UPDATE public.applied_sync_operations op SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),
        applied_at=pg_catalog.clock_timestamp() WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

CREATE OR REPLACE FUNCTION public.apply_expense_entry_change(
    p_operation_id UUID, p_action TEXT, p_entry_id UUID,
    p_expected_version BIGINT, p_payload JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB;
    v_hash BYTEA;
    v_claimed UUID;
    v_saved_hash BYTEA;
    v_saved JSONB;
    v_entry public.expense_entries%ROWTYPE;
    v_existing public.expense_entries%ROWTYPE;
    v_conflict UUID;
    v_response JSONB;
    v_previous JSONB;
    v_audit TEXT;
    v_amount BIGINT;
    v_competence DATE;
    v_due DATE;
    v_paid DATE;
    v_description TEXT;
    v_category UUID;
    v_subcategory UUID;
BEGIN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification'; END IF;
    IF p_operation_id IS NULL OR p_entry_id IS NULL OR p_expected_version IS NULL OR p_action IS NULL THEN
        RAISE EXCEPTION 'operation, action, entry and expected version are required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_action NOT IN ('create','update','cancel','pay') OR p_expected_version<0
        OR (p_action='create' AND p_expected_version<>0) OR (p_action<>'create' AND p_expected_version=0) THEN
        RAISE EXCEPTION 'unsupported expense action or expected version' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_action<>'cancel' AND (p_payload IS NULL OR pg_catalog.jsonb_typeof(p_payload)<>'object') THEN
        RAISE EXCEPTION 'expense payload must be an object' USING ERRCODE='invalid_parameter_value';
    END IF;
    v_request:=pg_catalog.jsonb_build_object('action',p_action,'entry_id',p_entry_id,'expected_version',p_expected_version,'payload',p_payload);
    v_hash:=pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT,'UTF8')),'hex');
    INSERT INTO public.applied_sync_operations(owner_id,idempotency_key,content_hash,result_payload)
    VALUES(v_owner,p_operation_id,v_hash,pg_catalog.jsonb_build_object('request',v_request,'response',NULL))
    ON CONFLICT(owner_id,idempotency_key) DO NOTHING RETURNING idempotency_key INTO v_claimed;
    IF NOT FOUND THEN
        SELECT op.content_hash,op.result_payload INTO v_saved_hash,v_saved FROM public.applied_sync_operations op
        WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved->'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE='invalid_parameter_value';
        END IF;
        RETURN v_saved->'response';
    END IF;

    IF p_action<>'create' THEN
        SELECT entry.* INTO v_entry FROM public.expense_entries entry
        WHERE entry.owner_id=v_owner AND entry.id=p_entry_id AND entry.recurrence_template_id IS NULL FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'one-time expense was not found' USING ERRCODE='no_data_found'; END IF;
        IF v_entry.version<>p_expected_version THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_entry',p_entry_id,p_expected_version,v_entry.version,v_request,pg_catalog.to_jsonb(v_entry)) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_entry',pg_catalog.to_jsonb(v_entry));
        END IF;
    ELSE
        SELECT entry.* INTO v_existing FROM public.expense_entries entry WHERE entry.owner_id=v_owner AND entry.id=p_entry_id FOR UPDATE;
        IF FOUND THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_entry',p_entry_id,0,v_existing.version,v_request,pg_catalog.to_jsonb(v_existing)) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_entry',pg_catalog.to_jsonb(v_existing));
        END IF;
    END IF;

    IF v_response IS NULL THEN
        IF p_action='cancel' THEN
            v_previous:=pg_catalog.to_jsonb(v_entry);
            UPDATE public.expense_entries entry SET status='cancelled',version=entry.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE entry.owner_id=v_owner AND entry.id=p_entry_id RETURNING entry.* INTO v_entry;
            v_audit:='cancel';
        ELSIF p_action='pay' THEN
            IF NOT (p_payload ? 'paid_on') OR NULLIF(p_payload->>'paid_on','null') IS NULL THEN
                RAISE EXCEPTION 'pay requires paid_on' USING ERRCODE='invalid_parameter_value';
            END IF;
            v_paid:=(p_payload->>'paid_on')::DATE;
            IF v_entry.status='cancelled' THEN RAISE EXCEPTION 'cancelled expense cannot be paid' USING ERRCODE='check_violation'; END IF;
            IF v_entry.amount_centavos IS NULL THEN RAISE EXCEPTION 'expense value is required before payment' USING ERRCODE='check_violation'; END IF;
            v_previous:=pg_catalog.to_jsonb(v_entry);
            UPDATE public.expense_entries entry SET status='paid',paid_on=v_paid,version=entry.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE entry.owner_id=v_owner AND entry.id=p_entry_id RETURNING entry.* INTO v_entry;
            v_audit:='pay';
        ELSE
            IF p_action='create' THEN
                IF NOT (p_payload ? 'amount_centavos') OR NOT (p_payload ? 'competence_on') THEN
                    RAISE EXCEPTION 'expense creation requires amount_centavos and competence_on' USING ERRCODE='invalid_parameter_value';
                END IF;
                v_amount:=NULLIF(p_payload->>'amount_centavos','null')::BIGINT;
                v_competence:=NULLIF(p_payload->>'competence_on','null')::DATE;
                v_due:=NULLIF(p_payload->>'due_on','null')::DATE;
                v_description:=NULLIF(p_payload->>'description','null');
                v_category:=NULLIF(p_payload->>'category_id','null')::UUID;
                v_subcategory:=NULLIF(p_payload->>'subcategory_id','null')::UUID;
            ELSE
                v_amount:=CASE WHEN p_payload ? 'amount_centavos' THEN NULLIF(p_payload->>'amount_centavos','null')::BIGINT ELSE v_entry.amount_centavos END;
                v_competence:=CASE WHEN p_payload ? 'competence_on' THEN NULLIF(p_payload->>'competence_on','null')::DATE ELSE v_entry.competence_on END;
                v_due:=CASE WHEN p_payload ? 'due_on' THEN NULLIF(p_payload->>'due_on','null')::DATE ELSE v_entry.due_on END;
                v_description:=CASE WHEN p_payload ? 'description' THEN NULLIF(p_payload->>'description','null') ELSE v_entry.description END;
                v_category:=CASE WHEN p_payload ? 'category_id' THEN NULLIF(p_payload->>'category_id','null')::UUID ELSE v_entry.category_id END;
                v_subcategory:=CASE WHEN p_payload ? 'subcategory_id' THEN NULLIF(p_payload->>'subcategory_id','null')::UUID ELSE v_entry.subcategory_id END;
            END IF;
            IF v_amount IS NULL OR v_amount<0 OR v_competence IS NULL THEN
                RAISE EXCEPTION 'expense amount must be nonnegative and competence_on is required' USING ERRCODE='invalid_parameter_value';
            END IF;
            IF v_category IS NOT NULL AND (p_action='create' OR v_category IS DISTINCT FROM v_entry.category_id) THEN
                IF NOT EXISTS (SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='expense' AND c.is_active) THEN
                    RAISE EXCEPTION 'new expense category must belong to the user, be active and have expense kind' USING ERRCODE='check_violation';
                END IF;
            END IF;
            IF v_subcategory IS NOT NULL AND (p_action='create' OR v_category IS DISTINCT FROM v_entry.category_id
                OR v_subcategory IS DISTINCT FROM v_entry.subcategory_id) THEN
                IF NOT EXISTS (SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='expense' AND c.is_active) THEN
                    RAISE EXCEPTION 'a new expense subcategory association requires an active category' USING ERRCODE='check_violation';
                END IF;
                IF v_subcategory IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.subcategories s
                    WHERE s.owner_id=v_owner AND s.category_id=v_category AND s.id=v_subcategory AND s.is_active) THEN
                    RAISE EXCEPTION 'new expense subcategory must belong to the active category' USING ERRCODE='check_violation';
                END IF;
            END IF;
            IF p_action='create' THEN
                INSERT INTO public.expense_entries(owner_id,id,description,amount_centavos,competence_on,due_on,status,category_id,subcategory_id)
                VALUES(v_owner,p_entry_id,v_description,v_amount,v_competence,v_due,'pending',v_category,v_subcategory) RETURNING * INTO v_entry;
                v_audit:='create';
            ELSE
                v_previous:=pg_catalog.to_jsonb(v_entry);
                UPDATE public.expense_entries entry SET description=v_description,amount_centavos=v_amount,
                    competence_on=v_competence,due_on=v_due,category_id=v_category,subcategory_id=v_subcategory,
                    version=entry.version+1,updated_at=pg_catalog.clock_timestamp()
                WHERE entry.owner_id=v_owner AND entry.id=p_entry_id RETURNING entry.* INTO v_entry;
                v_audit:='update';
            END IF;
        END IF;
        IF v_audit IS NOT NULL THEN
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_entry',p_entry_id,v_audit,v_owner,v_previous,pg_catalog.to_jsonb(v_entry),p_operation_id);
            v_response:=pg_catalog.jsonb_build_object('status','applied','entry',pg_catalog.to_jsonb(v_entry));
        END IF;
    END IF;
    UPDATE public.applied_sync_operations op SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),
        applied_at=pg_catalog.clock_timestamp() WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

CREATE OR REPLACE FUNCTION public.apply_investment_allocation_change(
    p_operation_id UUID,
    p_action TEXT,
    p_allocation_id UUID,
    p_expected_version BIGINT,
    p_amount_centavos BIGINT,
    p_allocated_on DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB;
    v_hash BYTEA;
    v_claimed UUID;
    v_stored_hash BYTEA;
    v_stored JSONB;
    v_row public.investment_allocations%ROWTYPE;
    v_existing public.investment_allocations%ROWTYPE;
    v_conflict UUID;
    v_response JSONB;
    v_previous JSONB;
    v_audit_operation TEXT;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_allocation_id IS NULL
        OR p_expected_version IS NULL OR p_action IS NULL THEN
        RAISE EXCEPTION 'operation, allocation, action and expected version are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_action NOT IN ('create', 'update', 'cancel') THEN
        RAISE EXCEPTION 'unsupported investment allocation action'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF (p_action = 'create' AND p_expected_version <> 0)
        OR (p_action <> 'create' AND p_expected_version < 1) THEN
        RAISE EXCEPTION 'expected version does not match action'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_action = 'create' OR p_action = 'update' THEN
        IF p_amount_centavos IS NULL OR p_amount_centavos < 0 OR p_allocated_on IS NULL THEN
            RAISE EXCEPTION 'amount must be nonnegative and allocation date is required'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSIF p_amount_centavos IS NOT NULL OR p_allocated_on IS NOT NULL THEN
        RAISE EXCEPTION 'cancel does not accept allocation values'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object(
        'action', p_action, 'allocation_id', p_allocation_id,
        'expected_version', p_expected_version,
        'amount_centavos', p_amount_centavos, 'allocated_on', p_allocated_on
    );
    v_hash := pg_catalog.decode(
        pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT, 'UTF8')), 'hex'
    );
    INSERT INTO public.applied_sync_operations(owner_id, idempotency_key, content_hash, result_payload)
    VALUES (v_owner, p_operation_id, v_hash,
        pg_catalog.jsonb_build_object('request', v_request, 'response', NULL))
    ON CONFLICT (owner_id, idempotency_key) DO NOTHING
    RETURNING idempotency_key INTO v_claimed;
    IF NOT FOUND THEN
        SELECT op.content_hash, op.result_payload INTO v_stored_hash, v_stored
        FROM public.applied_sync_operations AS op
        WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id FOR UPDATE;
        IF v_stored_hash IS DISTINCT FROM v_hash
            OR v_stored -> 'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key was already used with different content'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        RETURN v_stored -> 'response';
    END IF;

    IF p_action = 'create' THEN
        SELECT allocation.* INTO v_existing
        FROM public.investment_allocations AS allocation
        WHERE allocation.owner_id = v_owner AND allocation.id = p_allocation_id
        FOR UPDATE;
        IF FOUND THEN
            INSERT INTO public.sync_conflicts(owner_id, id, entity_type, entity_id,
                base_version, remote_version, local_snapshot, remote_snapshot)
            VALUES (v_owner, pg_catalog.gen_random_uuid(), 'investment_allocation',
                p_allocation_id, 0, v_existing.version, v_request,
                pg_catalog.to_jsonb(v_existing)) RETURNING id INTO v_conflict;
            v_response := pg_catalog.jsonb_build_object('status', 'conflict',
                'conflict_id', v_conflict, 'remote_allocation', pg_catalog.to_jsonb(v_existing));
        ELSE
            INSERT INTO public.investment_allocations(owner_id, id, amount_centavos,
                allocated_on)
            VALUES (v_owner, p_allocation_id, p_amount_centavos, p_allocated_on)
            RETURNING * INTO v_row;
            v_audit_operation := 'create';
        END IF;
    ELSE
        SELECT allocation.* INTO v_row
        FROM public.investment_allocations AS allocation
        WHERE allocation.owner_id = v_owner AND allocation.id = p_allocation_id
        FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'investment allocation was not found for the authenticated user'
                USING ERRCODE = 'no_data_found';
        END IF;
        IF v_row.version <> p_expected_version THEN
            INSERT INTO public.sync_conflicts(owner_id, id, entity_type, entity_id,
                base_version, remote_version, local_snapshot, remote_snapshot)
            VALUES (v_owner, pg_catalog.gen_random_uuid(), 'investment_allocation',
                p_allocation_id, p_expected_version, v_row.version, v_request,
                pg_catalog.to_jsonb(v_row)) RETURNING id INTO v_conflict;
            v_response := pg_catalog.jsonb_build_object('status', 'conflict',
                'conflict_id', v_conflict, 'remote_allocation', pg_catalog.to_jsonb(v_row));
        ELSE
            v_previous := pg_catalog.to_jsonb(v_row);
            IF p_action = 'update' THEN
                UPDATE public.investment_allocations AS allocation
                SET amount_centavos = p_amount_centavos,
                    allocated_on = p_allocated_on,
                    version = allocation.version + 1,
                    updated_at = pg_catalog.clock_timestamp()
                WHERE allocation.owner_id = v_owner AND allocation.id = p_allocation_id
                RETURNING allocation.* INTO v_row;
                v_audit_operation := 'update';
            ELSE
                UPDATE public.investment_allocations AS allocation
                SET cancelled_at = COALESCE(allocation.cancelled_at, pg_catalog.clock_timestamp()),
                    version = allocation.version + 1,
                    updated_at = pg_catalog.clock_timestamp()
                WHERE allocation.owner_id = v_owner AND allocation.id = p_allocation_id
                RETURNING allocation.* INTO v_row;
                v_audit_operation := 'cancel';
            END IF;
        END IF;
    END IF;

    IF v_audit_operation IS NOT NULL THEN
        INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id,
            operation, actor_id, previous_values, new_values, operation_id)
        VALUES (v_owner, pg_catalog.gen_random_uuid(), 'investment_allocation',
            p_allocation_id, v_audit_operation, v_owner, v_previous,
            pg_catalog.to_jsonb(v_row), p_operation_id);
        v_response := pg_catalog.jsonb_build_object('status', 'applied',
            'allocation', pg_catalog.to_jsonb(v_row));
    END IF;
    UPDATE public.applied_sync_operations AS op
    SET result_payload = pg_catalog.jsonb_build_object('request', v_request, 'response', v_response),
        applied_at = pg_catalog.clock_timestamp()
    WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id;
    RETURN v_response;
END;
$function$;

CREATE OR REPLACE FUNCTION public.apply_income_recurrence_occurrence_change(
    p_operation_id UUID,p_action TEXT,p_entry_id UUID,p_expected_version BIGINT,p_payload JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB; v_hash BYTEA; v_saved_hash BYTEA; v_saved JSONB;
    v_entry public.income_entries%ROWTYPE; v_template public.income_recurrence_templates%ROWTYPE;
    v_conflict UUID; v_response JSONB;
    v_previous JSONB; v_operation TEXT;
    v_amount BIGINT; v_received DATE; v_description TEXT; v_category UUID; v_subcategory UUID;
    v_period_id UUID; v_status TEXT;
BEGIN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'authentication is required' USING ERRCODE='invalid_authorization_specification'; END IF;
    IF p_operation_id IS NULL OR p_entry_id IS NULL OR p_expected_version IS NULL OR p_action IS NULL THEN
        RAISE EXCEPTION 'operation, action, entry and expected version are required' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_action NOT IN ('update','receive','cancel') OR p_expected_version<=0 THEN
        RAISE EXCEPTION 'unsupported income occurrence action or expected version' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_action<>'cancel' AND (p_payload IS NULL OR pg_catalog.jsonb_typeof(p_payload)<>'object') THEN
        RAISE EXCEPTION 'income occurrence payload must be an object' USING ERRCODE='invalid_parameter_value';
    END IF;
    v_request:=pg_catalog.jsonb_build_object('action',p_action,'entry_id',p_entry_id,'expected_version',p_expected_version,'payload',p_payload);
    v_hash:=pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT,'UTF8')),'hex');
    INSERT INTO public.applied_sync_operations(owner_id,idempotency_key,content_hash,result_payload)
    VALUES(v_owner,p_operation_id,v_hash,pg_catalog.jsonb_build_object('request',v_request,'response',NULL))
    ON CONFLICT(owner_id,idempotency_key) DO NOTHING;
    IF NOT FOUND THEN
        SELECT op.content_hash,op.result_payload INTO v_saved_hash,v_saved FROM public.applied_sync_operations op
        WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved->'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE='invalid_parameter_value';
        END IF;
        RETURN v_saved->'response';
    END IF;
    SELECT e.* INTO v_entry FROM public.income_entries e
    WHERE e.owner_id=v_owner AND e.id=p_entry_id AND e.recurrence_template_id IS NOT NULL FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'income recurrence occurrence was not found' USING ERRCODE='no_data_found'; END IF;
    IF v_entry.version<>p_expected_version THEN
        INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
        VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_entry',p_entry_id,p_expected_version,v_entry.version,v_request,pg_catalog.to_jsonb(v_entry))
        RETURNING id INTO v_conflict;
        v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_entry',pg_catalog.to_jsonb(v_entry));
    ELSE
        SELECT t.* INTO v_template FROM public.income_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.id=v_entry.recurrence_template_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'income recurrence template was not found' USING ERRCODE='no_data_found'; END IF;
        v_previous:=pg_catalog.to_jsonb(v_entry);
        IF p_action='cancel' THEN
            UPDATE public.income_entries e SET status='cancelled',version=e.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE e.owner_id=v_owner AND e.id=p_entry_id RETURNING e.* INTO v_entry;
            v_operation:='cancel';
        ELSE
            v_amount:=CASE WHEN p_payload?'amount_centavos' THEN NULLIF(p_payload->>'amount_centavos','null')::BIGINT ELSE v_entry.amount_centavos END;
            v_description:=CASE WHEN p_payload?'description' THEN NULLIF(p_payload->>'description','null') ELSE v_entry.description END;
            v_category:=CASE WHEN p_payload?'category_id' THEN NULLIF(p_payload->>'category_id','null')::UUID ELSE v_entry.category_id END;
            v_subcategory:=CASE WHEN p_payload?'subcategory_id' THEN NULLIF(p_payload->>'subcategory_id','null')::UUID ELSE v_entry.subcategory_id END;
            IF v_amount<0 OR (v_template.value_mode='fixed' AND v_amount IS NULL) THEN
                RAISE EXCEPTION 'income occurrence amount is invalid' USING ERRCODE='invalid_parameter_value';
            END IF;
            IF p_action='receive' THEN
                IF v_entry.status<>'pending' OR NOT (p_payload?'received_on') OR NULLIF(p_payload->>'received_on','null') IS NULL THEN
                    RAISE EXCEPTION 'receive requires a pending occurrence and received_on' USING ERRCODE='check_violation';
                END IF;
                IF v_amount IS NULL THEN RAISE EXCEPTION 'income amount is required before receipt' USING ERRCODE='check_violation'; END IF;
                v_received:=(p_payload->>'received_on')::DATE;
                v_status:='received';
                v_operation:='receive';
            ELSE
                IF p_payload?'received_on' AND v_entry.received_on IS NULL THEN
                    RAISE EXCEPTION 'update cannot confirm receipt; use receive action' USING ERRCODE='check_violation';
                END IF;
                v_received:=CASE WHEN p_payload?'received_on' THEN NULLIF(p_payload->>'received_on','null')::DATE ELSE v_entry.received_on END;
                v_status:=v_entry.status;
                IF v_status='received' AND v_received IS NULL THEN RAISE EXCEPTION 'received income requires received_on' USING ERRCODE='check_violation'; END IF;
                v_operation:='update';
            END IF;
            IF v_category IS NOT NULL AND v_category IS DISTINCT FROM v_entry.category_id
                AND NOT EXISTS(SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='income' AND c.is_active) THEN
                RAISE EXCEPTION 'new income category must be active and have income kind' USING ERRCODE='check_violation';
            END IF;
            IF v_subcategory IS NOT NULL AND (v_category IS DISTINCT FROM v_entry.category_id OR v_subcategory IS DISTINCT FROM v_entry.subcategory_id)
                AND (v_category IS NULL OR NOT EXISTS(SELECT 1 FROM public.subcategories s WHERE s.owner_id=v_owner AND s.category_id=v_category AND s.id=v_subcategory AND s.is_active)) THEN
                RAISE EXCEPTION 'new income subcategory must belong to the active category' USING ERRCODE='check_violation';
            END IF;
            v_period_id:=NULL;
            IF v_received IS NOT NULL THEN
                v_period_id:=NULL::UUID;
            END IF;
            UPDATE public.income_entries e SET description=v_description,amount_centavos=v_amount,status=v_status,
                received_on=v_received,category_id=v_category,subcategory_id=v_subcategory,
                version=e.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE e.owner_id=v_owner AND e.id=p_entry_id RETURNING e.* INTO v_entry;
        END IF;
        INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
        VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_entry',p_entry_id,v_operation,v_owner,v_previous,pg_catalog.to_jsonb(v_entry),p_operation_id);
        v_response:=pg_catalog.jsonb_build_object('status','applied','entry',pg_catalog.to_jsonb(v_entry));
    END IF;
    UPDATE public.applied_sync_operations op SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),
        applied_at=pg_catalog.clock_timestamp() WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

CREATE OR REPLACE FUNCTION public.apply_expense_recurrence_occurrence_change(
    p_operation_id UUID,p_action TEXT,p_entry_id UUID,p_expected_version BIGINT,p_payload JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB; v_hash BYTEA; v_saved_hash BYTEA; v_saved JSONB;
    v_entry public.expense_entries%ROWTYPE; v_template public.expense_recurrence_templates%ROWTYPE;
    v_conflict UUID; v_response JSONB;
    v_previous JSONB; v_operation TEXT;
    v_amount BIGINT; v_competence DATE; v_due DATE; v_paid DATE; v_description TEXT; v_category UUID; v_subcategory UUID;
    v_period_id UUID; v_status TEXT;
BEGIN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'authentication is required' USING ERRCODE='invalid_authorization_specification'; END IF;
    IF p_operation_id IS NULL OR p_entry_id IS NULL OR p_expected_version IS NULL OR p_action IS NULL THEN
        RAISE EXCEPTION 'operation, action, entry and expected version are required' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_action NOT IN ('update','pay','cancel') OR p_expected_version<=0 THEN
        RAISE EXCEPTION 'unsupported expense occurrence action or expected version' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_action<>'cancel' AND (p_payload IS NULL OR pg_catalog.jsonb_typeof(p_payload)<>'object') THEN
        RAISE EXCEPTION 'expense occurrence payload must be an object' USING ERRCODE='invalid_parameter_value';
    END IF;
    v_request:=pg_catalog.jsonb_build_object('action',p_action,'entry_id',p_entry_id,'expected_version',p_expected_version,'payload',p_payload);
    v_hash:=pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT,'UTF8')),'hex');
    INSERT INTO public.applied_sync_operations(owner_id,idempotency_key,content_hash,result_payload)
    VALUES(v_owner,p_operation_id,v_hash,pg_catalog.jsonb_build_object('request',v_request,'response',NULL))
    ON CONFLICT(owner_id,idempotency_key) DO NOTHING;
    IF NOT FOUND THEN
        SELECT op.content_hash,op.result_payload INTO v_saved_hash,v_saved FROM public.applied_sync_operations op
        WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved->'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE='invalid_parameter_value';
        END IF;
        RETURN v_saved->'response';
    END IF;
    SELECT e.* INTO v_entry FROM public.expense_entries e
    WHERE e.owner_id=v_owner AND e.id=p_entry_id AND e.recurrence_template_id IS NOT NULL FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'expense recurrence occurrence was not found' USING ERRCODE='no_data_found'; END IF;
    IF v_entry.version<>p_expected_version THEN
        INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
        VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_entry',p_entry_id,p_expected_version,v_entry.version,v_request,pg_catalog.to_jsonb(v_entry))
        RETURNING id INTO v_conflict;
        v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_entry',pg_catalog.to_jsonb(v_entry));
    ELSE
        SELECT t.* INTO v_template FROM public.expense_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.id=v_entry.recurrence_template_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'expense recurrence template was not found' USING ERRCODE='no_data_found'; END IF;
        v_previous:=pg_catalog.to_jsonb(v_entry);
        IF p_action='cancel' THEN
            UPDATE public.expense_entries e SET status='cancelled',version=e.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE e.owner_id=v_owner AND e.id=p_entry_id RETURNING e.* INTO v_entry;
            v_operation:='cancel';
        ELSE
            v_amount:=CASE WHEN p_payload?'amount_centavos' THEN NULLIF(p_payload->>'amount_centavos','null')::BIGINT ELSE v_entry.amount_centavos END;
            v_competence:=CASE WHEN p_payload?'competence_on' THEN NULLIF(p_payload->>'competence_on','null')::DATE ELSE v_entry.competence_on END;
            v_due:=CASE WHEN p_payload?'due_on' THEN NULLIF(p_payload->>'due_on','null')::DATE ELSE v_entry.due_on END;
            v_description:=CASE WHEN p_payload?'description' THEN NULLIF(p_payload->>'description','null') ELSE v_entry.description END;
            v_category:=CASE WHEN p_payload?'category_id' THEN NULLIF(p_payload->>'category_id','null')::UUID ELSE v_entry.category_id END;
            v_subcategory:=CASE WHEN p_payload?'subcategory_id' THEN NULLIF(p_payload->>'subcategory_id','null')::UUID ELSE v_entry.subcategory_id END;
            IF v_amount<0 OR (v_template.value_mode='fixed' AND v_amount IS NULL) OR v_competence IS NULL THEN
                RAISE EXCEPTION 'expense occurrence amount or competence date is invalid' USING ERRCODE='invalid_parameter_value';
            END IF;
            v_status:=v_entry.status;
            IF p_action='pay' THEN
                IF v_entry.status='cancelled' OR NOT (p_payload?'paid_on') OR NULLIF(p_payload->>'paid_on','null') IS NULL THEN
                    RAISE EXCEPTION 'pay requires a non-cancelled occurrence and paid_on' USING ERRCODE='check_violation';
                END IF;
                IF v_amount IS NULL THEN RAISE EXCEPTION 'expense value is required before payment' USING ERRCODE='check_violation'; END IF;
                v_paid:=(p_payload->>'paid_on')::DATE;
                v_status:='paid';
                v_operation:='pay';
            ELSE
                IF p_payload?'paid_on' AND v_entry.paid_on IS NULL THEN
                    RAISE EXCEPTION 'update cannot confirm payment; use pay action' USING ERRCODE='check_violation';
                END IF;
                v_paid:=CASE WHEN p_payload?'paid_on' THEN NULLIF(p_payload->>'paid_on','null')::DATE ELSE v_entry.paid_on END;
                IF v_status='paid' AND v_paid IS NULL THEN RAISE EXCEPTION 'paid expense requires paid_on' USING ERRCODE='check_violation'; END IF;
                v_operation:='update';
            END IF;
            IF v_status='paid' AND v_amount IS NULL THEN
                RAISE EXCEPTION 'expense value is required for paid status' USING ERRCODE='check_violation';
            END IF;
            IF v_category IS NOT NULL AND v_category IS DISTINCT FROM v_entry.category_id
                AND NOT EXISTS(SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='expense' AND c.is_active) THEN
                RAISE EXCEPTION 'new expense category must be active and have expense kind' USING ERRCODE='check_violation';
            END IF;
            IF v_subcategory IS NOT NULL AND (v_category IS DISTINCT FROM v_entry.category_id OR v_subcategory IS DISTINCT FROM v_entry.subcategory_id)
                AND (v_category IS NULL OR NOT EXISTS(SELECT 1 FROM public.subcategories s WHERE s.owner_id=v_owner AND s.category_id=v_category AND s.id=v_subcategory AND s.is_active)) THEN
                RAISE EXCEPTION 'new expense subcategory must belong to the active category' USING ERRCODE='check_violation';
            END IF;
            v_period_id:=NULL::UUID;
            UPDATE public.expense_entries e SET amount_centavos=v_amount,competence_on=v_competence,due_on=v_due,paid_on=v_paid,
                status=v_status,description=v_description,category_id=v_category,subcategory_id=v_subcategory,version=e.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE e.owner_id=v_owner AND e.id=p_entry_id RETURNING e.* INTO v_entry;
        END IF;
        INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
        VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_entry',p_entry_id,v_operation,v_owner,v_previous,pg_catalog.to_jsonb(v_entry),p_operation_id);
        v_response:=pg_catalog.jsonb_build_object('status','applied','entry',pg_catalog.to_jsonb(v_entry));
    END IF;
    UPDATE public.applied_sync_operations op SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),
        applied_at=pg_catalog.clock_timestamp() WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_recurrence_from_entry(
    p_operation_id UUID, p_kind TEXT, p_template_id UUID, p_entry_id UUID,
    p_expected_entry_version BIGINT, p_template JSONB, p_entry JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB; v_hash BYTEA; v_saved_hash BYTEA; v_saved JSONB;
    v_response JSONB; v_conflict UUID; v_template_op UUID; v_template_response JSONB;
    v_freq TEXT; v_starts DATE; v_day SMALLINT; v_mode TEXT; v_default BIGINT;
    v_entry_date DATE; v_scheduled DATE; v_amount BIGINT; v_due DATE;
    v_sched_period UUID;
    v_income public.income_entries%ROWTYPE;
    v_expense public.expense_entries%ROWTYPE;
    v_previous JSONB; v_new JSONB; v_description TEXT; v_category UUID; v_subcategory UUID;
BEGIN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'authentication is required' USING ERRCODE='invalid_authorization_specification'; END IF;
    IF p_operation_id IS NULL OR p_kind IS NULL OR p_template_id IS NULL OR p_entry_id IS NULL OR p_expected_entry_version IS NULL THEN
        RAISE EXCEPTION 'operation, kind, template, entry and expected entry version are required' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_kind NOT IN ('income','expense') OR p_expected_entry_version<0 THEN
        RAISE EXCEPTION 'unsupported recurrence kind or expected entry version' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_template IS NULL OR pg_catalog.jsonb_typeof(p_template)<>'object'
        OR (p_expected_entry_version=0 AND (p_entry IS NULL OR pg_catalog.jsonb_typeof(p_entry)<>'object')) THEN
        RAISE EXCEPTION 'template and new entry payloads must be objects' USING ERRCODE='invalid_parameter_value';
    END IF;
    v_request:=pg_catalog.jsonb_build_object('kind',p_kind,'template_id',p_template_id,'entry_id',p_entry_id,
        'expected_entry_version',p_expected_entry_version,'template',p_template,'entry',p_entry);
    v_hash:=pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT,'UTF8')),'hex');
    INSERT INTO public.applied_sync_operations(owner_id,idempotency_key,content_hash,result_payload)
    VALUES(v_owner,p_operation_id,v_hash,pg_catalog.jsonb_build_object('request',v_request,'response',NULL))
    ON CONFLICT(owner_id,idempotency_key) DO NOTHING;
    IF NOT FOUND THEN
        SELECT op.content_hash,op.result_payload INTO v_saved_hash,v_saved FROM public.applied_sync_operations op
        WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved->'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE='invalid_parameter_value';
        END IF;
        RETURN v_saved->'response';
    END IF;

    -- Lançamento existente: confere a versão antes de criar qualquer coisa.
    IF p_expected_entry_version>0 THEN
        IF p_kind='income' THEN
            SELECT e.* INTO v_income FROM public.income_entries e WHERE e.owner_id=v_owner AND e.id=p_entry_id FOR UPDATE;
            v_previous:=pg_catalog.to_jsonb(v_income);
        ELSE
            SELECT e.* INTO v_expense FROM public.expense_entries e WHERE e.owner_id=v_owner AND e.id=p_entry_id FOR UPDATE;
            v_previous:=pg_catalog.to_jsonb(v_expense);
        END IF;
        IF NOT FOUND THEN RAISE EXCEPTION 'entry was not found' USING ERRCODE='no_data_found'; END IF;
        IF (v_previous->>'version')::BIGINT<>p_expected_entry_version THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),p_kind||'_entry',p_entry_id,p_expected_entry_version,
                (v_previous->>'version')::BIGINT,v_request,v_previous) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_entry',v_previous);
        ELSIF (v_previous->>'recurrence_template_id') IS NOT NULL OR v_previous->>'status'='cancelled' THEN
            RAISE EXCEPTION 'only an active standalone entry can become a recurrence' USING ERRCODE='check_violation';
        END IF;
    ELSIF (p_kind='income' AND EXISTS(SELECT 1 FROM public.income_entries e WHERE e.owner_id=v_owner AND e.id=p_entry_id))
        OR (p_kind='expense' AND EXISTS(SELECT 1 FROM public.expense_entries e WHERE e.owner_id=v_owner AND e.id=p_entry_id)) THEN
        RAISE EXCEPTION 'entry already exists' USING ERRCODE='unique_violation';
    END IF;

    IF v_response IS NULL THEN
        v_template_op:=overlay(pg_catalog.md5(p_operation_id::TEXT||'|template') PLACING '4' FROM 13 FOR 1)::UUID;
        IF p_kind='income' THEN
            v_template_response:=public.apply_income_recurrence_template_change(v_template_op,'create',p_template_id,0,p_template);
        ELSE
            v_template_response:=public.apply_expense_recurrence_template_change(v_template_op,'create',p_template_id,0,p_template);
        END IF;
        IF v_template_response->>'status'<>'applied' THEN
            RAISE EXCEPTION 'recurrence template already exists' USING ERRCODE='unique_violation';
        END IF;
        v_freq:=v_template_response#>>'{template,frequency}';
        v_starts:=(v_template_response#>>'{template,starts_on}')::DATE;
        v_day:=(v_template_response#>>'{template,monthly_reference_day}')::SMALLINT;
        v_mode:=v_template_response#>>'{template,value_mode}';
        v_default:=(v_template_response#>>'{template,default_amount_centavos}')::BIGINT;

        IF p_expected_entry_version>0 THEN
            v_entry_date:=CASE WHEN p_kind='income' THEN v_income.received_on ELSE v_expense.competence_on END;
        ELSE
            v_entry_date:=NULLIF(p_entry->>'date','null')::DATE;
        END IF;
        IF v_entry_date IS NULL OR v_entry_date<>v_starts THEN
            RAISE EXCEPTION 'recurrence must start on the entry date' USING ERRCODE='invalid_parameter_value';
        END IF;
        IF v_freq='monthly' AND v_day<>EXTRACT(day FROM v_entry_date)::SMALLINT THEN
            RAISE EXCEPTION 'monthly reference day must be the entry day' USING ERRCODE='invalid_parameter_value';
        END IF;

        v_scheduled:=v_entry_date; v_sched_period:=NULL;

        IF p_expected_entry_version=0 THEN
            v_description:=NULLIF(p_entry->>'description','null');
            v_category:=NULLIF(p_entry->>'category_id','null')::UUID;
            v_subcategory:=NULLIF(p_entry->>'subcategory_id','null')::UUID;
            v_amount:=CASE WHEN v_mode='fixed' THEN v_default ELSE NULLIF(p_entry->>'amount_centavos','null')::BIGINT END;
            IF v_amount<0 THEN RAISE EXCEPTION 'amount is invalid' USING ERRCODE='invalid_parameter_value'; END IF;
            IF p_kind='income' THEN
                INSERT INTO public.income_entries(owner_id,id,description,amount_centavos,status,category_id,subcategory_id,
                    recurrence_template_id,scheduled_for_date)
                VALUES(v_owner,p_entry_id,v_description,v_amount,'pending',v_category,v_subcategory,p_template_id,v_scheduled)
                RETURNING * INTO v_income;
                v_new:=pg_catalog.to_jsonb(v_income);
            ELSE
                v_due:=COALESCE(NULLIF(p_entry->>'due_on','null')::DATE,v_scheduled);
                INSERT INTO public.expense_entries(owner_id,id,description,amount_centavos,competence_on,due_on,status,category_id,
                    subcategory_id,recurrence_template_id,scheduled_for_date)
                VALUES(v_owner,p_entry_id,v_description,v_amount,v_scheduled,v_due,'pending',v_category,v_subcategory,p_template_id,v_scheduled)
                RETURNING * INTO v_expense;
                v_new:=pg_catalog.to_jsonb(v_expense);
            END IF;
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),p_kind||'_entry',p_entry_id,'create',v_owner,v_new,p_operation_id);
        ELSE
            IF p_kind='income' THEN
                UPDATE public.income_entries e SET recurrence_template_id=p_template_id,scheduled_for_date=v_scheduled,
                    version=e.version+1,updated_at=pg_catalog.clock_timestamp()
                WHERE e.owner_id=v_owner AND e.id=p_entry_id RETURNING * INTO v_income;
                v_new:=pg_catalog.to_jsonb(v_income);
            ELSE
                UPDATE public.expense_entries e SET recurrence_template_id=p_template_id,scheduled_for_date=v_scheduled,
                    competence_on=v_scheduled,due_on=COALESCE(e.due_on,v_scheduled),
                    version=e.version+1,updated_at=pg_catalog.clock_timestamp()
                WHERE e.owner_id=v_owner AND e.id=p_entry_id RETURNING * INTO v_expense;
                v_new:=pg_catalog.to_jsonb(v_expense);
            END IF;
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),p_kind||'_entry',p_entry_id,'update',v_owner,v_previous,v_new,p_operation_id);
        END IF;
        v_response:=pg_catalog.jsonb_build_object('status','applied','template',v_template_response->'template','entry',v_new);
    END IF;
    UPDATE public.applied_sync_operations op SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),
        applied_at=pg_catalog.clock_timestamp() WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_investment_recurrence_from_entry(
    p_operation_id UUID, p_template_id UUID, p_entry_id UUID,
    p_expected_entry_version BIGINT, p_template JSONB, p_entry JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB; v_hash BYTEA; v_saved_hash BYTEA; v_saved JSONB;
    v_response JSONB; v_conflict UUID; v_template_op UUID; v_template_response JSONB;
    v_freq TEXT; v_starts DATE; v_day SMALLINT; v_default BIGINT;
    v_entry_date DATE; v_scheduled DATE;
    v_sched_period UUID;
    v_alloc public.investment_allocations%ROWTYPE;
    v_found BOOLEAN;
    v_previous JSONB; v_new JSONB;
BEGIN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'authentication is required' USING ERRCODE='invalid_authorization_specification'; END IF;
    IF p_operation_id IS NULL OR p_template_id IS NULL OR p_entry_id IS NULL OR p_expected_entry_version IS NULL OR p_expected_entry_version<0 THEN
        RAISE EXCEPTION 'operation, template, entry and expected entry version are required' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_template IS NULL OR pg_catalog.jsonb_typeof(p_template)<>'object'
        OR (p_expected_entry_version=0 AND (p_entry IS NULL OR pg_catalog.jsonb_typeof(p_entry)<>'object')) THEN
        RAISE EXCEPTION 'template and new entry payloads must be objects' USING ERRCODE='invalid_parameter_value';
    END IF;
    v_request:=pg_catalog.jsonb_build_object('template_id',p_template_id,'entry_id',p_entry_id,
        'expected_entry_version',p_expected_entry_version,'template',p_template,'entry',p_entry);
    v_hash:=pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT,'UTF8')),'hex');
    INSERT INTO public.applied_sync_operations(owner_id,idempotency_key,content_hash,result_payload)
    VALUES(v_owner,p_operation_id,v_hash,pg_catalog.jsonb_build_object('request',v_request,'response',NULL))
    ON CONFLICT(owner_id,idempotency_key) DO NOTHING;
    IF NOT FOUND THEN
        SELECT op.content_hash,op.result_payload INTO v_saved_hash,v_saved FROM public.applied_sync_operations op
        WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved->'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE='invalid_parameter_value';
        END IF;
        RETURN v_saved->'response';
    END IF;

    IF p_expected_entry_version>0 THEN
        SELECT a.* INTO v_alloc FROM public.investment_allocations a
        WHERE a.owner_id=v_owner AND a.id=p_entry_id FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'investment allocation was not found' USING ERRCODE='no_data_found'; END IF;
        v_previous:=pg_catalog.to_jsonb(v_alloc);
        IF v_alloc.version<>p_expected_entry_version THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_allocation',p_entry_id,p_expected_entry_version,
                v_alloc.version,v_request,v_previous) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_allocation',v_previous);
        ELSIF v_alloc.recurrence_template_id IS NOT NULL OR v_alloc.cancelled_at IS NOT NULL THEN
            RAISE EXCEPTION 'only an active standalone investment can become a recurrence' USING ERRCODE='check_violation';
        END IF;
    ELSIF EXISTS(SELECT 1 FROM public.investment_allocations a WHERE a.owner_id=v_owner AND a.id=p_entry_id) THEN
        RAISE EXCEPTION 'investment allocation already exists' USING ERRCODE='unique_violation';
    END IF;

    IF v_response IS NULL THEN
        v_template_op:=overlay(pg_catalog.md5(p_operation_id::TEXT||'|template') PLACING '4' FROM 13 FOR 1)::UUID;
        v_template_response:=public.apply_investment_recurrence_template_change(v_template_op,'create',p_template_id,0,p_template);
        IF v_template_response->>'status'<>'applied' THEN
            RAISE EXCEPTION 'recurrence template already exists' USING ERRCODE='unique_violation';
        END IF;
        v_freq:=v_template_response#>>'{template,frequency}';
        v_starts:=(v_template_response#>>'{template,starts_on}')::DATE;
        v_day:=(v_template_response#>>'{template,monthly_reference_day}')::SMALLINT;
        v_default:=(v_template_response#>>'{template,default_amount_centavos}')::BIGINT;

        IF p_expected_entry_version>0 THEN
            v_entry_date:=v_alloc.allocated_on;
        ELSE
            v_entry_date:=NULLIF(p_entry->>'date','null')::DATE;
        END IF;
        IF v_entry_date IS NULL OR v_entry_date<>v_starts THEN
            RAISE EXCEPTION 'recurrence must start on the entry date' USING ERRCODE='invalid_parameter_value';
        END IF;
        IF v_freq='monthly' AND v_day<>EXTRACT(day FROM v_entry_date)::SMALLINT THEN
            RAISE EXCEPTION 'monthly reference day must be the entry day' USING ERRCODE='invalid_parameter_value';
        END IF;

        v_scheduled:=v_entry_date; v_sched_period:=NULL;

        IF p_expected_entry_version=0 THEN
            INSERT INTO public.investment_allocations(owner_id,id,amount_centavos,allocated_on,
                recurrence_template_id,scheduled_for_date)
            VALUES(v_owner,p_entry_id,v_default,v_scheduled,p_template_id,v_scheduled)
            RETURNING * INTO v_alloc;
            v_new:=pg_catalog.to_jsonb(v_alloc);
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_allocation',p_entry_id,'create',v_owner,v_new,p_operation_id);
        ELSE
            UPDATE public.investment_allocations a SET recurrence_template_id=p_template_id,scheduled_for_date=v_scheduled,
                allocated_on=v_scheduled,
                version=a.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE a.owner_id=v_owner AND a.id=p_entry_id RETURNING * INTO v_alloc;
            v_new:=pg_catalog.to_jsonb(v_alloc);
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_allocation',p_entry_id,'update',v_owner,v_previous,v_new,p_operation_id);
        END IF;
        v_response:=pg_catalog.jsonb_build_object('status','applied','template',v_template_response->'template','allocation',v_new);
    END IF;
    UPDATE public.applied_sync_operations op SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),
        applied_at=pg_catalog.clock_timestamp() WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

CREATE OR REPLACE FUNCTION public.enforce_recurrence_template_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_last DATE;
    v_floor DATE;
BEGIN
    IF TG_OP = 'UPDATE'
        AND NEW.frequency IS NOT DISTINCT FROM OLD.frequency
        AND NEW.starts_on IS NOT DISTINCT FROM OLD.starts_on
        AND NEW.monthly_reference_day IS NOT DISTINCT FROM OLD.monthly_reference_day THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        EXECUTE pg_catalog.format(
            'SELECT pg_catalog.max(e.scheduled_for_date) FROM public.%I e '
            'WHERE e.owner_id = $1 AND e.recurrence_template_id = $2',
            CASE TG_TABLE_NAME
                WHEN 'income_recurrence_templates' THEN 'income_entries'
                WHEN 'investment_recurrence_templates' THEN 'investment_allocations'
                ELSE 'expense_entries' END)
        INTO v_last USING NEW.owner_id, NEW.id;
        IF v_last IS NOT NULL THEN
            v_floor := (pg_catalog.date_trunc('month', v_last) + INTERVAL '1 month')::DATE;
            IF NEW.starts_on < v_floor THEN
                NEW.starts_on := v_floor;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_due_recurrence_occurrences(p_operation_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_zone TEXT;
    v_today DATE;
    v_request JSONB;
    v_hash BYTEA;
    v_saved_hash BYTEA;
    v_saved JSONB;
    v_response JSONB;
    v_month DATE;
    v_scheduled DATE;
    v_template RECORD;
    v_entry RECORD;
    v_occurrences JSONB := '[]'::JSONB;
    v_income_count INTEGER := 0;
    v_expense_count INTEGER := 0;
    v_investment_count INTEGER := 0;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE='invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL THEN
        RAISE EXCEPTION 'operation id is required' USING ERRCODE='invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object('operation','generate_due_recurrence_occurrences');
    v_hash := pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT,'UTF8')),'hex');
    INSERT INTO public.applied_sync_operations(owner_id,idempotency_key,content_hash,result_payload)
    VALUES(v_owner,p_operation_id,v_hash,pg_catalog.jsonb_build_object('request',v_request,'response',NULL))
    ON CONFLICT(owner_id,idempotency_key) DO NOTHING;
    IF NOT FOUND THEN
        SELECT op.content_hash,op.result_payload INTO v_saved_hash,v_saved
        FROM public.applied_sync_operations op
        WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved->'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE='invalid_parameter_value';
        END IF;
        RETURN v_saved->'response';
    END IF;

    SELECT COALESCE(pref.time_zone_id,'America/Sao_Paulo') INTO v_zone
    FROM public.user_preferences pref WHERE pref.owner_id=v_owner;
    v_zone := COALESCE(v_zone,'America/Sao_Paulo');
    v_today := pg_catalog.timezone(v_zone,pg_catalog.clock_timestamp())::DATE;

    -- Receitas: pendentes, sem período (só contam ao confirmar).
    FOR v_template IN
        SELECT t.* FROM public.income_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.is_active AND t.frequency='monthly'
        ORDER BY t.id FOR UPDATE
    LOOP
        v_month := pg_catalog.date_trunc('month',v_template.starts_on)::DATE;
        WHILE v_month <= pg_catalog.date_trunc('month',v_today)::DATE LOOP
            v_scheduled := public.recurrence_monthly_date(v_month,v_template.monthly_reference_day);
            IF v_scheduled >= v_template.starts_on AND v_scheduled <= v_today
                AND NOT EXISTS (
                    SELECT 1 FROM public.income_entries e
                    WHERE e.owner_id=v_owner AND e.recurrence_template_id=v_template.id
                      AND e.scheduled_for_date >= v_month
                      AND e.scheduled_for_date < (v_month + INTERVAL '1 month')::DATE)
            THEN
                INSERT INTO public.income_entries(owner_id,id,description,amount_centavos,status,category_id,subcategory_id,
                    recurrence_template_id,scheduled_for_date)
                VALUES(v_owner,public.recurrence_occurrence_id(v_template.id,v_scheduled),v_template.description,
                    v_template.default_amount_centavos,'pending',v_template.category_id,v_template.subcategory_id,
                    v_template.id,v_scheduled)
                ON CONFLICT DO NOTHING
                RETURNING * INTO v_entry;
                IF FOUND THEN
                    INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
                    VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_entry',v_entry.id,'create',v_owner,pg_catalog.to_jsonb(v_entry),p_operation_id);
                    v_income_count := v_income_count+1;
                    v_occurrences := v_occurrences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                        'kind','income','id',v_entry.id,'scheduled_for_date',v_scheduled));
                END IF;
            END IF;
            v_month := (v_month + INTERVAL '1 month')::DATE;
        END LOOP;
    END LOOP;

    -- Despesas: contam ao gerar, no período da data programada.
    FOR v_template IN
        SELECT t.* FROM public.expense_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.is_active AND t.frequency='monthly'
        ORDER BY t.id FOR UPDATE
    LOOP
        v_month := pg_catalog.date_trunc('month',v_template.starts_on)::DATE;
        WHILE v_month <= pg_catalog.date_trunc('month',v_today)::DATE LOOP
            v_scheduled := public.recurrence_monthly_date(v_month,v_template.monthly_reference_day);
            IF v_scheduled >= v_template.starts_on AND v_scheduled <= v_today
                AND NOT EXISTS (
                    SELECT 1 FROM public.expense_entries e
                    WHERE e.owner_id=v_owner AND e.recurrence_template_id=v_template.id
                      AND e.scheduled_for_date >= v_month
                      AND e.scheduled_for_date < (v_month + INTERVAL '1 month')::DATE)
            THEN
                INSERT INTO public.expense_entries(owner_id,id,description,amount_centavos,competence_on,due_on,status,category_id,
                    subcategory_id,recurrence_template_id,scheduled_for_date)
                VALUES(v_owner,public.recurrence_occurrence_id(v_template.id,v_scheduled),v_template.description,
                    v_template.default_amount_centavos,v_scheduled,v_scheduled,'pending',v_template.category_id,
                    v_template.subcategory_id,v_template.id,v_scheduled)
                ON CONFLICT DO NOTHING
                RETURNING * INTO v_entry;
                IF FOUND THEN
                    INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
                    VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_entry',v_entry.id,'create',v_owner,pg_catalog.to_jsonb(v_entry),p_operation_id);
                    v_expense_count := v_expense_count+1;
                    v_occurrences := v_occurrences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                        'kind','expense','id',v_entry.id,'scheduled_for_date',v_scheduled));
                END IF;
            END IF;
            v_month := (v_month + INTERVAL '1 month')::DATE;
        END LOOP;
    END LOOP;

    -- Investimentos (Fase 6, D7/D9): contam ao gerar, sem confirmação.
    FOR v_template IN
        SELECT t.* FROM public.investment_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.is_active AND t.frequency='monthly'
        ORDER BY t.id FOR UPDATE
    LOOP
        v_month := pg_catalog.date_trunc('month',v_template.starts_on)::DATE;
        WHILE v_month <= pg_catalog.date_trunc('month',v_today)::DATE LOOP
            v_scheduled := public.recurrence_monthly_date(v_month,v_template.monthly_reference_day);
            IF v_scheduled >= v_template.starts_on AND v_scheduled <= v_today
                AND NOT EXISTS (
                    SELECT 1 FROM public.investment_allocations e
                    WHERE e.owner_id=v_owner AND e.recurrence_template_id=v_template.id
                      AND e.scheduled_for_date >= v_month
                      AND e.scheduled_for_date < (v_month + INTERVAL '1 month')::DATE)
            THEN
                INSERT INTO public.investment_allocations(owner_id,id,amount_centavos,allocated_on,
                    recurrence_template_id,scheduled_for_date)
                VALUES(v_owner,public.recurrence_occurrence_id(v_template.id,v_scheduled),v_template.default_amount_centavos,
                    v_scheduled,v_template.id,v_scheduled)
                ON CONFLICT DO NOTHING
                RETURNING * INTO v_entry;
                IF FOUND THEN
                    INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
                    VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_allocation',v_entry.id,'create',v_owner,pg_catalog.to_jsonb(v_entry),p_operation_id);
                    v_investment_count := v_investment_count+1;
                    v_occurrences := v_occurrences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                        'kind','investment','id',v_entry.id,'scheduled_for_date',v_scheduled));
                END IF;
            END IF;
            v_month := (v_month + INTERVAL '1 month')::DATE;
        END LOOP;
    END LOOP;

    v_response := pg_catalog.jsonb_build_object('status','applied','calendar_date',v_today,
        'income_created',v_income_count,'expense_created',v_expense_count,
        'investment_created',v_investment_count,'occurrences',v_occurrences);
    UPDATE public.applied_sync_operations op
    SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),applied_at=pg_catalog.clock_timestamp()
    WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

CREATE OR REPLACE FUNCTION public.resolve_sync_conflict(
    p_operation_id UUID,
    p_conflict_id UUID,
    p_resolution TEXT,
    p_request JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB;
    v_hash BYTEA;
    v_claimed UUID;
    v_saved_hash BYTEA;
    v_saved JSONB;
    v_conflict public.sync_conflicts%ROWTYPE;
    v_chosen JSONB;
    v_inner_operation UUID;
    v_version BIGINT;
    v_has_template BOOLEAN;
    v_inner JSONB;
    v_remote JSONB;
    v_response JSONB;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_conflict_id IS NULL OR p_resolution IS NULL
        OR p_resolution NOT IN ('keep_local', 'keep_remote', 'edit') THEN
        RAISE EXCEPTION 'operation, conflict and a valid resolution are required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF (p_resolution = 'edit') <> (p_request IS NOT NULL)
        OR (p_request IS NOT NULL AND pg_catalog.jsonb_typeof(p_request) <> 'object') THEN
        RAISE EXCEPTION 'edit requires a request object and the other resolutions must not send one'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object('conflict_id', p_conflict_id,
        'resolution', p_resolution, 'request', p_request);
    v_hash := pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT, 'UTF8')), 'hex');
    INSERT INTO public.applied_sync_operations(owner_id, idempotency_key, content_hash, result_payload)
    VALUES (v_owner, p_operation_id, v_hash, pg_catalog.jsonb_build_object('request', v_request, 'response', NULL))
    ON CONFLICT (owner_id, idempotency_key) DO NOTHING RETURNING idempotency_key INTO v_claimed;
    IF NOT FOUND THEN
        SELECT op.content_hash, op.result_payload INTO v_saved_hash, v_saved
        FROM public.applied_sync_operations op
        WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id FOR UPDATE;
        IF v_saved_hash IS DISTINCT FROM v_hash OR v_saved -> 'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different content' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        RETURN v_saved -> 'response';
    END IF;

    SELECT c.* INTO v_conflict FROM public.sync_conflicts c
    WHERE c.owner_id = v_owner AND c.id = p_conflict_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'conflict was not found for the authenticated user' USING ERRCODE = 'no_data_found';
    END IF;
    IF v_conflict.status <> 'open' THEN
        RAISE EXCEPTION 'conflict is already resolved' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_resolution = 'keep_remote' THEN
        v_remote := v_conflict.remote_snapshot;
        v_response := pg_catalog.jsonb_build_object('status', 'resolved', 'resolution', p_resolution,
            'conflict_id', p_conflict_id, 'record', v_remote);
    ELSE
        IF v_conflict.entity_type NOT IN ('category', 'subcategory', 'investment_allocation',
            'income_entry', 'expense_entry', 'income_recurrence_template', 'expense_recurrence_template',
            'investment_recurrence_template', 'period_settings') THEN
            RAISE EXCEPTION 'this conflict type only supports keep_remote' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        v_chosen := CASE p_resolution WHEN 'keep_local' THEN v_conflict.local_snapshot ELSE p_request END;
        IF v_chosen ->> 'action' IS NULL OR v_chosen ->> 'action' = 'create' THEN
            RAISE EXCEPTION 'only updates can be re-applied; use keep_remote for a create conflict'
                USING ERRCODE = 'invalid_parameter_value';
        END IF;
        v_inner_operation := pg_catalog.md5(p_operation_id::TEXT || ':apply')::UUID;

        -- Current remote version, read under lock so the inner call cannot conflict again.
        EXECUTE pg_catalog.format(
            'SELECT t.version, %s FROM public.%I t WHERE t.owner_id = $1 AND t.id = $2 FOR UPDATE',
            CASE WHEN v_conflict.entity_type IN ('income_entry', 'expense_entry')
                 THEN 't.recurrence_template_id IS NOT NULL' ELSE 'false' END,
            CASE v_conflict.entity_type
                WHEN 'category' THEN 'categories'
                WHEN 'subcategory' THEN 'subcategories'
                WHEN 'investment_allocation' THEN 'investment_allocations'
                WHEN 'income_entry' THEN 'income_entries'
                WHEN 'expense_entry' THEN 'expense_entries'
                WHEN 'investment_recurrence_template' THEN 'investment_recurrence_templates'
                WHEN 'income_recurrence_template' THEN 'income_recurrence_templates'
                WHEN 'period_settings' THEN 'period_settings'
                ELSE 'expense_recurrence_templates' END)
        INTO v_version, v_has_template USING v_owner, v_conflict.entity_id;
        IF v_version IS NULL THEN
            RAISE EXCEPTION 'record was not found for the authenticated user' USING ERRCODE = 'no_data_found';
        END IF;

        v_inner := CASE v_conflict.entity_type
            WHEN 'category' THEN public.apply_category_change(v_inner_operation, v_chosen ->> 'action',
                v_conflict.entity_id, v_version, v_chosen ->> 'kind', v_chosen ->> 'name',
                v_chosen ->> 'icon_key', v_chosen ->> 'color_key')
            WHEN 'subcategory' THEN public.apply_subcategory_change(v_inner_operation, v_chosen ->> 'action',
                v_conflict.entity_id, (v_chosen ->> 'category_id')::UUID, v_version, v_chosen ->> 'name')
            WHEN 'investment_allocation' THEN public.apply_investment_allocation_change(v_inner_operation,
                v_chosen ->> 'action', v_conflict.entity_id, v_version,
                (v_chosen ->> 'amount_centavos')::BIGINT, (v_chosen ->> 'allocated_on')::DATE)
            WHEN 'income_entry' THEN CASE WHEN v_has_template
                THEN public.apply_income_recurrence_occurrence_change(v_inner_operation, v_chosen ->> 'action',
                    v_conflict.entity_id, v_version, v_chosen -> 'payload')
                ELSE public.apply_income_entry_change(v_inner_operation, v_chosen ->> 'action',
                    v_conflict.entity_id, v_version, v_chosen -> 'payload') END
            WHEN 'expense_entry' THEN CASE WHEN v_has_template
                THEN public.apply_expense_recurrence_occurrence_change(v_inner_operation, v_chosen ->> 'action',
                    v_conflict.entity_id, v_version, v_chosen -> 'payload')
                ELSE public.apply_expense_entry_change(v_inner_operation, v_chosen ->> 'action',
                    v_conflict.entity_id, v_version, v_chosen -> 'payload') END
            WHEN 'investment_recurrence_template' THEN public.apply_investment_recurrence_template_change(
                v_inner_operation, v_chosen ->> 'action', v_conflict.entity_id, v_version, v_chosen -> 'payload')
            WHEN 'income_recurrence_template' THEN public.apply_income_recurrence_template_change(
                v_inner_operation, v_chosen ->> 'action', v_conflict.entity_id, v_version, v_chosen -> 'payload')
            WHEN 'period_settings' THEN public.set_period_settings(v_inner_operation, v_version,
                v_chosen ->> 'mode', (v_chosen ->> 'custom_start_day')::SMALLINT)
            ELSE public.apply_expense_recurrence_template_change(
                v_inner_operation, v_chosen ->> 'action', v_conflict.entity_id, v_version, v_chosen -> 'payload')
        END;
        IF v_inner ->> 'status' IS DISTINCT FROM 'applied' THEN
            RAISE EXCEPTION 'consolidated version could not be applied: %', v_inner
                USING ERRCODE = 'serialization_failure';
        END IF;
        v_response := pg_catalog.jsonb_build_object('status', 'resolved', 'resolution', p_resolution,
            'conflict_id', p_conflict_id, 'result', v_inner);
    END IF;

    UPDATE public.sync_conflicts c
    SET status = 'resolved',
        resolution_payload = pg_catalog.jsonb_build_object('resolution', p_resolution,
            'operation_id', p_operation_id, 'request', p_request, 'response', v_response),
        resolved_at = pg_catalog.clock_timestamp(),
        version = c.version + 1,
        updated_at = pg_catalog.clock_timestamp()
    WHERE c.owner_id = v_owner AND c.id = p_conflict_id;

    INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id, operation, actor_id,
        previous_values, new_values, operation_id)
    VALUES (v_owner, pg_catalog.gen_random_uuid(), 'sync_conflict', p_conflict_id, 'conflict_resolved', v_owner,
        pg_catalog.jsonb_build_object('status', 'open', 'local', v_conflict.local_snapshot,
            'remote', v_conflict.remote_snapshot),
        pg_catalog.jsonb_build_object('status', 'resolved', 'resolution', p_resolution, 'response', v_response),
        p_operation_id);

    UPDATE public.applied_sync_operations op
    SET result_payload = pg_catalog.jsonb_build_object('request', v_request, 'response', v_response),
        applied_at = pg_catalog.clock_timestamp()
    WHERE op.owner_id = v_owner AND op.idempotency_key = p_operation_id;

    RETURN v_response;
END;
$function$;

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

    DELETE FROM public.income_entries WHERE owner_id = v_owner_id;
    DELETE FROM public.expense_entries WHERE owner_id = v_owner_id;
    DELETE FROM public.investment_allocations WHERE owner_id = v_owner_id;
    DELETE FROM public.income_recurrence_templates WHERE owner_id = v_owner_id;
    DELETE FROM public.expense_recurrence_templates WHERE owner_id = v_owner_id;
    DELETE FROM public.investment_recurrence_templates WHERE owner_id = v_owner_id;
    DELETE FROM public.accounting_periods WHERE owner_id = v_owner_id;
    DELETE FROM public.period_configurations WHERE owner_id = v_owner_id;
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
