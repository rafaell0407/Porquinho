-- Fase 6, Entrega 55: recorrência de investimento (D7–D9, docs/entregas_fase6.md).
-- Modelo recorrente de investimento (valor fixo, sem descrição/categoria), campos
-- de ocorrência em investment_allocations, geração determinística junto com a de
-- receitas e despesas, criação da recorrência a partir de um investimento e
-- resolução de conflito do novo tipo. Migrations anteriores não mudam.
BEGIN;

CREATE TABLE public.investment_recurrence_templates (
    owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    id UUID NOT NULL,
    frequency TEXT NOT NULL CHECK (frequency IN ('monthly', 'by_period')),
    starts_on DATE NOT NULL,
    monthly_reference_day SMALLINT,
    default_amount_centavos BIGINT NOT NULL CHECK (default_amount_centavos >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    version BIGINT NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (owner_id, id),
    CHECK (
        (frequency = 'monthly'
            AND monthly_reference_day IS NOT NULL
            AND monthly_reference_day BETWEEN 1 AND 31)
        OR (frequency = 'by_period' AND monthly_reference_day IS NULL)
    )
);

CREATE INDEX investment_recurrence_templates_owner_updated_idx
    ON public.investment_recurrence_templates (owner_id, updated_at, id);

ALTER TABLE public.investment_allocations
    ADD COLUMN recurrence_template_id UUID,
    ADD COLUMN scheduled_for_date DATE,
    ADD COLUMN scheduled_period_id UUID,
    ADD FOREIGN KEY (owner_id, recurrence_template_id)
        REFERENCES public.investment_recurrence_templates (owner_id, id) ON DELETE RESTRICT,
    ADD FOREIGN KEY (owner_id, scheduled_period_id)
        REFERENCES public.accounting_periods (owner_id, id) ON DELETE RESTRICT,
    ADD CHECK (
        (recurrence_template_id IS NULL
            AND scheduled_for_date IS NULL
            AND scheduled_period_id IS NULL)
        OR (recurrence_template_id IS NOT NULL AND scheduled_for_date IS NOT NULL)
    );

-- Unicidade: uma única ocorrência por modelo e data programada (RN033, RN038).
CREATE UNIQUE INDEX investment_allocations_recurrence_occurrence_uidx
    ON public.investment_allocations (owner_id, recurrence_template_id, scheduled_for_date)
    WHERE recurrence_template_id IS NOT NULL;

-- Leitura somente do próprio usuário; escritas só pelas RPCs.
REVOKE ALL PRIVILEGES ON TABLE public.investment_recurrence_templates FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.investment_recurrence_templates TO authenticated;
ALTER TABLE public.investment_recurrence_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY porquinho_read_own ON public.investment_recurrence_templates
    FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL AND owner_id = auth.uid());

-- D2/D4: a mesma regra de agenda dos outros modelos (início antes do primeiro
-- período recusado; mudança de agenda só vale para o futuro).
CREATE OR REPLACE FUNCTION public.enforce_recurrence_template_schedule()
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
                WHEN 'investment_recurrence_templates' THEN 'investment_allocations'
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

CREATE TRIGGER investment_templates_schedule
    BEFORE INSERT OR UPDATE OF frequency, starts_on, monthly_reference_day ON public.investment_recurrence_templates
    FOR EACH ROW EXECUTE FUNCTION public.enforce_recurrence_template_schedule();

-- Modelo de investimento: criar, editar (valor padrão e agenda, só para as
-- próximas ocorrências) e parar de repetir. Valor sempre obrigatório (D8).
CREATE FUNCTION public.apply_investment_recurrence_template_change(
    p_operation_id UUID, p_action TEXT, p_template_id UUID,
    p_expected_version BIGINT, p_payload JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid(); v_request JSONB; v_hash BYTEA; v_claimed UUID;
    v_saved_hash BYTEA; v_saved JSONB; v_template public.investment_recurrence_templates%ROWTYPE;
    v_existing public.investment_recurrence_templates%ROWTYPE; v_conflict UUID;
    v_response JSONB; v_previous JSONB; v_audit TEXT;
    v_frequency TEXT; v_starts DATE; v_day SMALLINT; v_amount BIGINT;
BEGIN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'authentication is required' USING ERRCODE='invalid_authorization_specification'; END IF;
    IF p_operation_id IS NULL OR p_template_id IS NULL OR p_expected_version IS NULL OR p_action IS NULL THEN
        RAISE EXCEPTION 'operation, action, template and expected version are required' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_action NOT IN ('create','update','deactivate') OR p_expected_version<0
        OR (p_action='create' AND p_expected_version<>0) OR (p_action<>'create' AND p_expected_version=0) THEN
        RAISE EXCEPTION 'unsupported investment recurrence action or expected version' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_action<>'deactivate' AND (p_payload IS NULL OR pg_catalog.jsonb_typeof(p_payload)<>'object') THEN
        RAISE EXCEPTION 'recurrence payload must be an object' USING ERRCODE='invalid_parameter_value';
    END IF;
    v_request:=pg_catalog.jsonb_build_object('action',p_action,'template_id',p_template_id,'expected_version',p_expected_version,'payload',p_payload);
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
    IF p_action='create' THEN
        SELECT t.* INTO v_existing FROM public.investment_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.id=p_template_id FOR UPDATE;
        IF FOUND THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_recurrence_template',p_template_id,0,v_existing.version,v_request,pg_catalog.to_jsonb(v_existing)) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_template',pg_catalog.to_jsonb(v_existing));
        END IF;
    ELSE
        SELECT t.* INTO v_template FROM public.investment_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.id=p_template_id FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'investment recurrence template was not found' USING ERRCODE='no_data_found'; END IF;
        IF v_template.version<>p_expected_version THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_recurrence_template',p_template_id,p_expected_version,v_template.version,v_request,pg_catalog.to_jsonb(v_template)) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_template',pg_catalog.to_jsonb(v_template));
        END IF;
    END IF;
    IF v_response IS NULL THEN
        IF p_action='deactivate' THEN
            v_previous:=pg_catalog.to_jsonb(v_template);
            UPDATE public.investment_recurrence_templates t SET is_active=FALSE,version=t.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE t.owner_id=v_owner AND t.id=p_template_id RETURNING t.* INTO v_template;
            v_audit:='deactivate';
        ELSE
            IF p_payload?'value_mode' AND p_payload->>'value_mode' IS DISTINCT FROM 'fixed' THEN
                RAISE EXCEPTION 'investment recurrence value must be fixed' USING ERRCODE='invalid_parameter_value';
            END IF;
            IF p_action='create' THEN
                IF NOT (p_payload?'frequency') OR NOT (p_payload?'starts_on') OR NOT (p_payload?'default_amount_centavos') THEN
                    RAISE EXCEPTION 'template creation requires frequency, starts_on and default_amount_centavos' USING ERRCODE='invalid_parameter_value';
                END IF;
                v_frequency:=p_payload->>'frequency';
                v_starts:=NULLIF(p_payload->>'starts_on','null')::DATE;
                v_day:=NULLIF(p_payload->>'monthly_reference_day','null')::SMALLINT;
                v_amount:=NULLIF(p_payload->>'default_amount_centavos','null')::BIGINT;
            ELSE
                v_frequency:=CASE WHEN p_payload?'frequency' THEN p_payload->>'frequency' ELSE v_template.frequency END;
                v_starts:=CASE WHEN p_payload?'starts_on' THEN NULLIF(p_payload->>'starts_on','null')::DATE ELSE v_template.starts_on END;
                v_day:=CASE WHEN p_payload?'monthly_reference_day' THEN NULLIF(p_payload->>'monthly_reference_day','null')::SMALLINT ELSE v_template.monthly_reference_day END;
                v_amount:=CASE WHEN p_payload?'default_amount_centavos' THEN NULLIF(p_payload->>'default_amount_centavos','null')::BIGINT ELSE v_template.default_amount_centavos END;
            END IF;
            IF v_frequency IS NULL OR v_frequency NOT IN ('monthly','by_period') OR v_starts IS NULL
                OR (v_frequency='monthly' AND (v_day IS NULL OR v_day NOT BETWEEN 1 AND 31))
                OR (v_frequency='by_period' AND v_day IS NOT NULL)
                OR v_amount IS NULL OR v_amount<0 THEN
                RAISE EXCEPTION 'invalid investment recurrence schedule or amount' USING ERRCODE='invalid_parameter_value';
            END IF;
            IF p_action='create' THEN
                INSERT INTO public.investment_recurrence_templates(owner_id,id,frequency,starts_on,monthly_reference_day,default_amount_centavos)
                VALUES(v_owner,p_template_id,v_frequency,v_starts,v_day,v_amount) RETURNING * INTO v_template;
                v_audit:='create';
            ELSE
                v_previous:=pg_catalog.to_jsonb(v_template);
                UPDATE public.investment_recurrence_templates t SET frequency=v_frequency,starts_on=v_starts,
                    monthly_reference_day=v_day,default_amount_centavos=v_amount,
                    version=t.version+1,updated_at=pg_catalog.clock_timestamp() WHERE t.owner_id=v_owner AND t.id=p_template_id RETURNING t.* INTO v_template;
                v_audit:='update';
            END IF;
        END IF;
        IF v_audit IS NOT NULL THEN
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_recurrence_template',p_template_id,v_audit,v_owner,v_previous,pg_catalog.to_jsonb(v_template),p_operation_id);
            v_response:=pg_catalog.jsonb_build_object('status','applied','template',pg_catalog.to_jsonb(v_template));
        END IF;
    END IF;
    UPDATE public.applied_sync_operations op SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),applied_at=pg_catalog.clock_timestamp()
    WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

ALTER FUNCTION public.apply_investment_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.apply_investment_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_investment_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB) TO authenticated;
COMMENT ON FUNCTION public.apply_investment_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB)
    IS 'Applies versioned, idempotent and audited changes to authenticated investment recurrence templates; it does not generate occurrences.';

-- Cria o modelo e transforma o investimento (novo ou avulso) na primeira
-- ocorrência, numa única operação (D7). p_expected_entry_version = 0: novo
-- (p_entry traz date e amount_centavos); > 0: avulso existente.
CREATE FUNCTION public.create_investment_recurrence_from_entry(
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
    v_period public.accounting_periods%ROWTYPE;
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

        SELECT p.* INTO v_period FROM public.accounting_periods p
        WHERE p.owner_id=v_owner AND p.start_date<=v_entry_date AND v_entry_date<p.end_date;
        IF NOT FOUND THEN RAISE EXCEPTION 'no accounting period covers the entry date' USING ERRCODE='foreign_key_violation'; END IF;
        IF v_freq='monthly' THEN
            v_scheduled:=v_entry_date; v_sched_period:=NULL;
        ELSE
            v_scheduled:=v_period.start_date; v_sched_period:=v_period.id;
        END IF;

        IF p_expected_entry_version=0 THEN
            INSERT INTO public.investment_allocations(owner_id,id,amount_centavos,allocated_on,accounting_period_id,
                recurrence_template_id,scheduled_for_date,scheduled_period_id)
            VALUES(v_owner,p_entry_id,v_default,v_scheduled,v_period.id,p_template_id,v_scheduled,v_sched_period)
            RETURNING * INTO v_alloc;
            v_new:=pg_catalog.to_jsonb(v_alloc);
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_allocation',p_entry_id,'create',v_owner,v_new,p_operation_id);
        ELSE
            UPDATE public.investment_allocations a SET recurrence_template_id=p_template_id,scheduled_for_date=v_scheduled,
                scheduled_period_id=v_sched_period,allocated_on=v_scheduled,
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

ALTER FUNCTION public.create_investment_recurrence_from_entry(UUID,UUID,UUID,BIGINT,JSONB,JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.create_investment_recurrence_from_entry(UUID,UUID,UUID,BIGINT,JSONB,JSONB) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.create_investment_recurrence_from_entry(UUID,UUID,UUID,BIGINT,JSONB,JSONB) TO authenticated;
COMMENT ON FUNCTION public.create_investment_recurrence_from_entry(UUID,UUID,UUID,BIGINT,JSONB,JSONB)
    IS 'Creates an investment recurrence template and makes a new or standalone investment its first occurrence, atomically, idempotently and audited.';

-- Geração: igual à da Fase 5 (receitas e despesas inalteradas) mais investimentos.
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

    -- Fase 6 (D7): investimentos recorrentes, mesmo identificador determinístico;
    -- entram na sobra do período da data programada, sem confirmação (D9).
    FOR v_template IN
        SELECT t.* FROM public.investment_recurrence_templates t
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
        ELSE
            FOR v_period IN
                SELECT p.* FROM public.accounting_periods p
                WHERE p.owner_id=v_owner AND p.end_date>v_template.starts_on AND p.start_date<=v_today
                ORDER BY p.start_date
            LOOP
                v_scheduled := v_period.start_date;
                INSERT INTO public.investment_allocations(owner_id,id,amount_centavos,allocated_on,accounting_period_id,
                    recurrence_template_id,scheduled_for_date,scheduled_period_id)
                VALUES(v_owner,public.recurrence_occurrence_id(v_template.id,v_scheduled),v_template.default_amount_centavos,
                    v_scheduled,v_period.id,v_template.id,v_scheduled,v_period.id)
                ON CONFLICT DO NOTHING
                RETURNING * INTO v_entry;
                IF FOUND THEN
                    INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
                    VALUES(v_owner,pg_catalog.gen_random_uuid(),'investment_allocation',v_entry.id,'create',v_owner,pg_catalog.to_jsonb(v_entry),p_operation_id);
                    v_investment_count := v_investment_count+1;
                    v_occurrences := v_occurrences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                        'kind','investment','id',v_entry.id,'scheduled_for_date',v_scheduled,'accounting_period_id',v_period.id));
                END IF;
            END LOOP;
        END IF;
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
    IS 'Idempotently catches up due income, expense and investment recurrence occurrences with deterministic ids using the authenticated user calendar zone; called on app open and sync.';

-- Resolução de conflito: passa a aceitar o modelo recorrente de investimento.
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
            'investment_recurrence_template') THEN
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
                ELSE 'expense_recurrence_templates' END)
        INTO v_version, v_has_template USING v_owner, v_conflict.entity_id;
        IF v_version IS NULL THEN
            RAISE EXCEPTION 'record was not found for the authenticated user' USING ERRCODE = 'no_data_found';
        END IF;

        v_inner := CASE v_conflict.entity_type
            WHEN 'category' THEN public.apply_category_change(v_inner_operation, v_chosen ->> 'action',
                v_conflict.entity_id, v_version, v_chosen ->> 'kind', v_chosen ->> 'name')
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

COMMIT;
