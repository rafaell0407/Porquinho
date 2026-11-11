-- Fase 5, Entrega 44: geração determinística de ocorrências recorrentes,
-- agenda alterada só para o futuro, recusa de início sem período e criação da
-- recorrência a partir de um lançamento (o lançamento vira a primeira ocorrência).
-- Decisões D1–D5 e D8 (docs/entregas_fase5.md). Migrations anteriores não mudam.
BEGIN;

-- D1: identificador igual no aplicativo (Dart) e no servidor. UUID derivado de
-- md5('<modelo>|<data programada>') com versão 5 e variante 8.
CREATE FUNCTION public.recurrence_occurrence_id(p_template_id UUID, p_scheduled DATE)
RETURNS UUID
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $function$
    SELECT overlay(
        overlay(
            pg_catalog.md5(p_template_id::TEXT || '|' || pg_catalog.to_char(p_scheduled, 'YYYY-MM-DD'))
            PLACING '5' FROM 13 FOR 1)
        PLACING '8' FROM 17 FOR 1)::UUID;
$function$;
ALTER FUNCTION public.recurrence_occurrence_id(UUID, DATE) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.recurrence_occurrence_id(UUID, DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recurrence_occurrence_id(UUID, DATE) TO authenticated;
COMMENT ON FUNCTION public.recurrence_occurrence_id(UUID, DATE)
    IS 'Deterministic occurrence id from template and scheduled date; must match RecurrenceCalendar.occurrenceId in the app.';

-- D2 e D4: ao criar ou mudar a agenda de um modelo.
--  * início antes do primeiro período do usuário é recusado (o app pergunta se
--    cria os períodos antes de salvar);
--  * mudar frequência, início ou dia de referência vale só para ocorrências
--    ainda não geradas: o início nunca cai no mesmo mês nem no mesmo período
--    da última ocorrência já gerada.
CREATE FUNCTION public.enforce_recurrence_template_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_first DATE;
    v_last DATE;
    v_period_end DATE;
    v_floor DATE;
BEGIN
    IF TG_OP = 'UPDATE'
        AND NEW.frequency IS NOT DISTINCT FROM OLD.frequency
        AND NEW.starts_on IS NOT DISTINCT FROM OLD.starts_on
        AND NEW.monthly_reference_day IS NOT DISTINCT FROM OLD.monthly_reference_day THEN
        RETURN NEW;
    END IF;

    SELECT pg_catalog.min(p.start_date) INTO v_first
    FROM public.accounting_periods p WHERE p.owner_id = NEW.owner_id;
    IF v_first IS NOT NULL AND NEW.starts_on < v_first THEN
        RAISE EXCEPTION 'recurrence starts before the first accounting period'
            USING ERRCODE = 'check_violation';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        EXECUTE pg_catalog.format(
            'SELECT pg_catalog.max(e.scheduled_for_date) FROM public.%I e '
            'WHERE e.owner_id = $1 AND e.recurrence_template_id = $2',
            CASE TG_TABLE_NAME
                WHEN 'income_recurrence_templates' THEN 'income_entries'
                ELSE 'expense_entries' END)
        INTO v_last USING NEW.owner_id, NEW.id;
        IF v_last IS NOT NULL THEN
            SELECT p.end_date INTO v_period_end FROM public.accounting_periods p
            WHERE p.owner_id = NEW.owner_id AND p.start_date <= v_last AND v_last < p.end_date;
            v_floor := (pg_catalog.date_trunc('month', v_last) + INTERVAL '1 month')::DATE;
            IF v_period_end IS NOT NULL AND v_period_end > v_floor THEN
                v_floor := v_period_end;
            END IF;
            IF NEW.starts_on < v_floor THEN
                NEW.starts_on := v_floor;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;
ALTER FUNCTION public.enforce_recurrence_template_schedule() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.enforce_recurrence_template_schedule() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER income_templates_schedule
    BEFORE INSERT OR UPDATE OF frequency, starts_on, monthly_reference_day ON public.income_recurrence_templates
    FOR EACH ROW EXECUTE FUNCTION public.enforce_recurrence_template_schedule();
CREATE TRIGGER expense_templates_schedule
    BEFORE INSERT OR UPDATE OF frequency, starts_on, monthly_reference_day ON public.expense_recurrence_templates
    FOR EACH ROW EXECUTE FUNCTION public.enforce_recurrence_template_schedule();

-- Geração: identificador determinístico (D1), vencimento = data da ocorrência
-- (D3), competência = data programada (D5) e nada ignorado em silêncio (D4).
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
    v_last_day SMALLINT;
    v_period public.accounting_periods%ROWTYPE;
    v_template RECORD;
    v_entry RECORD;
    v_occurrences JSONB := '[]'::JSONB;
    v_income_count INTEGER := 0;
    v_expense_count INTEGER := 0;
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

    FOR v_template IN
        SELECT t.* FROM public.income_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.is_active
        ORDER BY t.id FOR UPDATE
    LOOP
        IF v_template.frequency='monthly' THEN
            v_month := pg_catalog.date_trunc('month',v_template.starts_on)::DATE;
            v_last_day := EXTRACT(day FROM (v_month + INTERVAL '1 month' - INTERVAL '1 day'))::SMALLINT;
            v_scheduled := v_month + LEAST(v_template.monthly_reference_day,v_last_day) - 1;
            IF v_scheduled < v_template.starts_on THEN
                v_month := (v_month + INTERVAL '1 month')::DATE;
            END IF;
            WHILE v_month <= pg_catalog.date_trunc('month',v_today)::DATE LOOP
                v_last_day := EXTRACT(day FROM (v_month + INTERVAL '1 month' - INTERVAL '1 day'))::SMALLINT;
                v_scheduled := v_month + LEAST(v_template.monthly_reference_day,v_last_day) - 1;
                IF v_scheduled >= v_template.starts_on AND v_scheduled <= v_today THEN
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
        ELSE
            FOR v_period IN
                SELECT p.* FROM public.accounting_periods p
                WHERE p.owner_id=v_owner AND p.end_date>v_template.starts_on AND p.start_date<=v_today
                ORDER BY p.start_date
            LOOP
                v_scheduled := v_period.start_date;
                INSERT INTO public.income_entries(owner_id,id,description,amount_centavos,status,category_id,subcategory_id,
                    recurrence_template_id,scheduled_for_date,scheduled_period_id)
                VALUES(v_owner,public.recurrence_occurrence_id(v_template.id,v_scheduled),v_template.description,
                    v_template.default_amount_centavos,'pending',v_template.category_id,v_template.subcategory_id,
                    v_template.id,v_scheduled,v_period.id)
                ON CONFLICT DO NOTHING
                RETURNING * INTO v_entry;
                IF FOUND THEN
                    INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
                    VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_entry',v_entry.id,'create',v_owner,pg_catalog.to_jsonb(v_entry),p_operation_id);
                    v_income_count := v_income_count+1;
                    v_occurrences := v_occurrences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                        'kind','income','id',v_entry.id,'scheduled_for_date',v_scheduled,'scheduled_period_id',v_period.id));
                END IF;
            END LOOP;
        END IF;
    END LOOP;

    FOR v_template IN
        SELECT t.* FROM public.expense_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.is_active
        ORDER BY t.id FOR UPDATE
    LOOP
        IF v_template.frequency='monthly' THEN
            v_month := pg_catalog.date_trunc('month',v_template.starts_on)::DATE;
            v_last_day := EXTRACT(day FROM (v_month + INTERVAL '1 month' - INTERVAL '1 day'))::SMALLINT;
            v_scheduled := v_month + LEAST(v_template.monthly_reference_day,v_last_day) - 1;
            IF v_scheduled < v_template.starts_on THEN
                v_month := (v_month + INTERVAL '1 month')::DATE;
            END IF;
            WHILE v_month <= pg_catalog.date_trunc('month',v_today)::DATE LOOP
                v_last_day := EXTRACT(day FROM (v_month + INTERVAL '1 month' - INTERVAL '1 day'))::SMALLINT;
                v_scheduled := v_month + LEAST(v_template.monthly_reference_day,v_last_day) - 1;
                IF v_scheduled >= v_template.starts_on AND v_scheduled <= v_today THEN
                    SELECT p.* INTO v_period FROM public.accounting_periods p
                    WHERE p.owner_id=v_owner AND p.start_date<=v_scheduled AND v_scheduled<p.end_date;
                    IF NOT FOUND THEN
                        -- D4: nunca ignorar em silêncio.
                        RAISE EXCEPTION 'no accounting period covers scheduled date %',v_scheduled
                            USING ERRCODE='foreign_key_violation';
                    END IF;
                    INSERT INTO public.expense_entries(owner_id,id,description,amount_centavos,competence_on,due_on,status,category_id,
                        subcategory_id,accounting_period_id,recurrence_template_id,scheduled_for_date)
                    VALUES(v_owner,public.recurrence_occurrence_id(v_template.id,v_scheduled),v_template.description,
                        v_template.default_amount_centavos,v_scheduled,v_scheduled,'pending',v_template.category_id,
                        v_template.subcategory_id,v_period.id,v_template.id,v_scheduled)
                    ON CONFLICT DO NOTHING
                    RETURNING * INTO v_entry;
                    IF FOUND THEN
                        INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
                        VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_entry',v_entry.id,'create',v_owner,pg_catalog.to_jsonb(v_entry),p_operation_id);
                        v_expense_count := v_expense_count+1;
                        v_occurrences := v_occurrences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                            'kind','expense','id',v_entry.id,'scheduled_for_date',v_scheduled,'accounting_period_id',v_period.id));
                    END IF;
                END IF;
                v_month := (v_month + INTERVAL '1 month')::DATE;
            END LOOP;
        ELSE
            FOR v_period IN
                SELECT p.* FROM public.accounting_periods p
                WHERE p.owner_id=v_owner AND p.end_date>v_template.starts_on AND p.start_date<=v_today
                ORDER BY p.start_date
            LOOP
                v_scheduled := v_period.start_date;
                INSERT INTO public.expense_entries(owner_id,id,description,amount_centavos,competence_on,due_on,status,category_id,
                    subcategory_id,accounting_period_id,recurrence_template_id,scheduled_for_date,scheduled_period_id)
                VALUES(v_owner,public.recurrence_occurrence_id(v_template.id,v_scheduled),v_template.description,
                    v_template.default_amount_centavos,v_scheduled,v_scheduled,'pending',v_template.category_id,
                    v_template.subcategory_id,v_period.id,v_template.id,v_scheduled,v_period.id)
                ON CONFLICT DO NOTHING
                RETURNING * INTO v_entry;
                IF FOUND THEN
                    INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
                    VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_entry',v_entry.id,'create',v_owner,pg_catalog.to_jsonb(v_entry),p_operation_id);
                    v_expense_count := v_expense_count+1;
                    v_occurrences := v_occurrences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                        'kind','expense','id',v_entry.id,'scheduled_for_date',v_scheduled,'accounting_period_id',v_period.id));
                END IF;
            END LOOP;
        END IF;
    END LOOP;

    v_response := pg_catalog.jsonb_build_object('status','applied','calendar_date',v_today,
        'income_created',v_income_count,'expense_created',v_expense_count,'occurrences',v_occurrences);
    UPDATE public.applied_sync_operations op
    SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),applied_at=pg_catalog.clock_timestamp()
    WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

-- D8: cria o modelo e transforma o lançamento na primeira ocorrência, numa
-- única operação. p_expected_entry_version = 0: lançamento novo (p_entry traz
-- date, amount_centavos, description, category_id, subcategory_id, due_on);
-- > 0: lançamento avulso existente, que passa a ser a primeira ocorrência.
CREATE FUNCTION public.create_recurrence_from_entry(
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
    v_period public.accounting_periods%ROWTYPE;
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

        SELECT p.* INTO v_period FROM public.accounting_periods p
        WHERE p.owner_id=v_owner AND p.start_date<=v_entry_date AND v_entry_date<p.end_date;
        IF NOT FOUND THEN RAISE EXCEPTION 'no accounting period covers the entry date' USING ERRCODE='foreign_key_violation'; END IF;
        IF v_freq='monthly' THEN
            v_scheduled:=v_entry_date; v_sched_period:=NULL;
        ELSE
            v_scheduled:=v_period.start_date; v_sched_period:=v_period.id;
        END IF;

        IF p_expected_entry_version=0 THEN
            v_description:=NULLIF(p_entry->>'description','null');
            v_category:=NULLIF(p_entry->>'category_id','null')::UUID;
            v_subcategory:=NULLIF(p_entry->>'subcategory_id','null')::UUID;
            v_amount:=CASE WHEN v_mode='fixed' THEN v_default ELSE NULLIF(p_entry->>'amount_centavos','null')::BIGINT END;
            IF v_amount<0 THEN RAISE EXCEPTION 'amount is invalid' USING ERRCODE='invalid_parameter_value'; END IF;
            IF p_kind='income' THEN
                INSERT INTO public.income_entries(owner_id,id,description,amount_centavos,status,category_id,subcategory_id,
                    recurrence_template_id,scheduled_for_date,scheduled_period_id)
                VALUES(v_owner,p_entry_id,v_description,v_amount,'pending',v_category,v_subcategory,p_template_id,v_scheduled,v_sched_period)
                RETURNING * INTO v_income;
                v_new:=pg_catalog.to_jsonb(v_income);
            ELSE
                v_due:=COALESCE(NULLIF(p_entry->>'due_on','null')::DATE,v_scheduled);
                INSERT INTO public.expense_entries(owner_id,id,description,amount_centavos,competence_on,due_on,status,category_id,
                    subcategory_id,accounting_period_id,recurrence_template_id,scheduled_for_date,scheduled_period_id)
                VALUES(v_owner,p_entry_id,v_description,v_amount,v_scheduled,v_due,'pending',v_category,v_subcategory,
                    v_period.id,p_template_id,v_scheduled,v_sched_period)
                RETURNING * INTO v_expense;
                v_new:=pg_catalog.to_jsonb(v_expense);
            END IF;
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),p_kind||'_entry',p_entry_id,'create',v_owner,v_new,p_operation_id);
        ELSE
            IF p_kind='income' THEN
                UPDATE public.income_entries e SET recurrence_template_id=p_template_id,scheduled_for_date=v_scheduled,
                    scheduled_period_id=v_sched_period,version=e.version+1,updated_at=pg_catalog.clock_timestamp()
                WHERE e.owner_id=v_owner AND e.id=p_entry_id RETURNING * INTO v_income;
                v_new:=pg_catalog.to_jsonb(v_income);
            ELSE
                UPDATE public.expense_entries e SET recurrence_template_id=p_template_id,scheduled_for_date=v_scheduled,
                    scheduled_period_id=v_sched_period,competence_on=v_scheduled,due_on=COALESCE(e.due_on,v_scheduled),
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

ALTER FUNCTION public.create_recurrence_from_entry(UUID,TEXT,UUID,UUID,BIGINT,JSONB,JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.create_recurrence_from_entry(UUID,TEXT,UUID,UUID,BIGINT,JSONB,JSONB) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.create_recurrence_from_entry(UUID,TEXT,UUID,UUID,BIGINT,JSONB,JSONB) TO authenticated;
COMMENT ON FUNCTION public.create_recurrence_from_entry(UUID,TEXT,UUID,UUID,BIGINT,JSONB,JSONB)
    IS 'Creates a recurrence template and makes a new or standalone entry its first occurrence, atomically, idempotently and audited.';
COMMENT ON FUNCTION public.generate_due_recurrence_occurrences(UUID)
    IS 'Idempotently catches up due recurrence occurrences with deterministic ids using the authenticated user calendar zone; called on app open and sync.';

COMMIT;
