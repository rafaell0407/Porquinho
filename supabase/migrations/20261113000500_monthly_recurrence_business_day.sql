-- Reestruturação de períodos, Entrega P5 (13/11/2026; RN010, RN014, RN017,
-- RN038): a repetição é só "Todo mês". Quando o dia de referência não existe
-- no mês (29–31), a ocorrência vai para o último dia do mês se for dia útil;
-- senão, para o dia útil (seg–sex) anterior. Se o dia existe, é mantido mesmo
-- em sábado ou domingo. O vencimento da despesa acompanha a data (RN017).
--  * recurrence_monthly_date: a regra, igual a RecurrenceCalendar.monthlyDate
--    do app (tabela única de casos: recurrence_monthly_date_cases_test.sql);
--  * modelos "por período" (by_period) deixam de existir: os ativos são
--    desativados (histórico preservado, auditado) e nenhum modelo pode ser
--    criado, reativado ou alterado para "por período";
--  * a geração passa a ser só mensal e nunca cria uma segunda ocorrência do
--    mesmo modelo no mesmo mês (ocorrências antigas, geradas com a regra
--    anterior, ficam na data em que foram geradas);
--  * a agenda alterada (D2) não usa mais o fim do período, só o mês.
-- A exigência de período gravado para a despesa/investimento gerado continua
-- até a P6. Migrations anteriores não mudam.
BEGIN;

CREATE FUNCTION public.recurrence_monthly_date(p_month DATE, p_day SMALLINT)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $function$
    SELECT CASE
        WHEN p_day <= EXTRACT(day FROM m.last_day) THEN m.first_day + p_day - 1
        ELSE m.last_day - CASE EXTRACT(isodow FROM m.last_day)
            WHEN 6 THEN 1
            WHEN 7 THEN 2
            ELSE 0 END
    END
    FROM (
        SELECT pg_catalog.date_trunc('month', p_month)::DATE AS first_day,
               (pg_catalog.date_trunc('month', p_month)
                   + INTERVAL '1 month' - INTERVAL '1 day')::DATE AS last_day
    ) AS m
    WHERE p_day BETWEEN 1 AND 31;
$function$;
ALTER FUNCTION public.recurrence_monthly_date(DATE, SMALLINT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.recurrence_monthly_date(DATE, SMALLINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recurrence_monthly_date(DATE, SMALLINT) TO authenticated;
COMMENT ON FUNCTION public.recurrence_monthly_date(DATE, SMALLINT)
    IS 'Monthly occurrence date: the reference day, or when it does not exist in the month the last weekday (Mon-Fri) of the month; must match RecurrenceCalendar.monthlyDate in the app.';

-- Só "Todo mês": recusa criar, reativar ou mudar para outra frequência.
CREATE FUNCTION public.enforce_monthly_recurrence()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
    IF NEW.frequency <> 'monthly' AND (
        TG_OP = 'INSERT'
        OR NEW.frequency IS DISTINCT FROM OLD.frequency
        OR (NEW.is_active AND NOT OLD.is_active)
    ) THEN
        RAISE EXCEPTION 'only monthly recurrences are allowed'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$function$;
ALTER FUNCTION public.enforce_monthly_recurrence() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.enforce_monthly_recurrence() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER income_templates_monthly_only
    BEFORE INSERT OR UPDATE OF frequency, is_active ON public.income_recurrence_templates
    FOR EACH ROW EXECUTE FUNCTION public.enforce_monthly_recurrence();
CREATE TRIGGER expense_templates_monthly_only
    BEFORE INSERT OR UPDATE OF frequency, is_active ON public.expense_recurrence_templates
    FOR EACH ROW EXECUTE FUNCTION public.enforce_monthly_recurrence();
CREATE TRIGGER investment_templates_monthly_only
    BEFORE INSERT OR UPDATE OF frequency, is_active ON public.investment_recurrence_templates
    FOR EACH ROW EXECUTE FUNCTION public.enforce_monthly_recurrence();

-- Modelos "por período" ativos: desativados (D7: as ocorrências já geradas
-- ficam como estão), com nova versão (o celular baixa a mudança) e auditoria.
WITH changed AS (
    UPDATE public.income_recurrence_templates t
    SET is_active = FALSE, version = t.version + 1,
        updated_at = pg_catalog.clock_timestamp()
    WHERE t.frequency = 'by_period' AND t.is_active
    RETURNING t.*
)
INSERT INTO public.audit_events (owner_id, id, entity_type, entity_id,
    operation, actor_id, new_values)
SELECT c.owner_id, pg_catalog.gen_random_uuid(), 'income_recurrence_template',
    c.id, 'deactivate', c.owner_id, pg_catalog.to_jsonb(c)
FROM changed AS c;

WITH changed AS (
    UPDATE public.expense_recurrence_templates t
    SET is_active = FALSE, version = t.version + 1,
        updated_at = pg_catalog.clock_timestamp()
    WHERE t.frequency = 'by_period' AND t.is_active
    RETURNING t.*
)
INSERT INTO public.audit_events (owner_id, id, entity_type, entity_id,
    operation, actor_id, new_values)
SELECT c.owner_id, pg_catalog.gen_random_uuid(), 'expense_recurrence_template',
    c.id, 'deactivate', c.owner_id, pg_catalog.to_jsonb(c)
FROM changed AS c;

WITH changed AS (
    UPDATE public.investment_recurrence_templates t
    SET is_active = FALSE, version = t.version + 1,
        updated_at = pg_catalog.clock_timestamp()
    WHERE t.frequency = 'by_period' AND t.is_active
    RETURNING t.*
)
INSERT INTO public.audit_events (owner_id, id, entity_type, entity_id,
    operation, actor_id, new_values)
SELECT c.owner_id, pg_catalog.gen_random_uuid(), 'investment_recurrence_template',
    c.id, 'deactivate', c.owner_id, pg_catalog.to_jsonb(c)
FROM changed AS c;

-- D2: agenda alterada vale do mês seguinte ao da última ocorrência gerada
-- (sem o fim do período). D4 (início antes do primeiro período) continua até
-- a P6.
CREATE OR REPLACE FUNCTION public.enforce_recurrence_template_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_first DATE;
    v_last DATE;
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

-- Geração só mensal, com a regra do dia útil anterior e no máximo uma
-- ocorrência por modelo e mês. Mesmo identificador determinístico (D1),
-- vencimento = data da ocorrência (D3), competência = data programada (D5).
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
    v_period public.accounting_periods%ROWTYPE;
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
                SELECT p.* INTO v_period FROM public.accounting_periods p
                WHERE p.owner_id=v_owner AND p.start_date<=v_scheduled AND v_scheduled<p.end_date;
                IF NOT FOUND THEN
                    -- D4: nunca ignorar em silêncio (até a P6).
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
                SELECT p.* INTO v_period FROM public.accounting_periods p
                WHERE p.owner_id=v_owner AND p.start_date<=v_scheduled AND v_scheduled<p.end_date;
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'no accounting period covers scheduled date %',v_scheduled
                        USING ERRCODE='foreign_key_violation';
                END IF;
                INSERT INTO public.investment_allocations(owner_id,id,amount_centavos,allocated_on,accounting_period_id,
                    recurrence_template_id,scheduled_for_date)
                VALUES(v_owner,public.recurrence_occurrence_id(v_template.id,v_scheduled),v_template.default_amount_centavos,
                    v_scheduled,v_period.id,v_template.id,v_scheduled)
                ON CONFLICT DO NOTHING
                RETURNING * INTO v_entry;
                IF FOUND THEN
                    INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
                    VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_allocation',v_entry.id,'create',v_owner,pg_catalog.to_jsonb(v_entry),p_operation_id);
                    v_investment_count := v_investment_count+1;
                    v_occurrences := v_occurrences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                        'kind','investment','id',v_entry.id,'scheduled_for_date',v_scheduled,'accounting_period_id',v_period.id));
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

COMMENT ON FUNCTION public.generate_due_recurrence_occurrences(UUID)
    IS 'Idempotently catches up due monthly income, expense and investment occurrences (at most one per template and month, weekday rule for missing days) with deterministic ids using the authenticated user calendar zone; called on app open and sync.';

COMMIT;
