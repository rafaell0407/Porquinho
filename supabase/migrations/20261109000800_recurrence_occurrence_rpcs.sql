-- Generate due recurrence occurrences and apply versioned changes to each one.
-- The effective calendar date is derived from the authenticated user's IANA zone.
BEGIN;

CREATE FUNCTION public.generate_due_recurrence_occurrences(p_operation_id UUID)
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
                    VALUES(v_owner,pg_catalog.gen_random_uuid(),v_template.description,v_template.default_amount_centavos,'pending',
                        v_template.category_id,v_template.subcategory_id,v_template.id,v_scheduled)
                    ON CONFLICT(owner_id,recurrence_template_id,scheduled_for_date) WHERE recurrence_template_id IS NOT NULL DO NOTHING
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
                VALUES(v_owner,pg_catalog.gen_random_uuid(),v_template.description,v_template.default_amount_centavos,'pending',
                    v_template.category_id,v_template.subcategory_id,v_template.id,v_scheduled,v_period.id)
                ON CONFLICT(owner_id,recurrence_template_id,scheduled_for_date) WHERE recurrence_template_id IS NOT NULL DO NOTHING
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
                    IF FOUND THEN
                        INSERT INTO public.expense_entries(owner_id,id,description,amount_centavos,competence_on,status,category_id,
                            subcategory_id,accounting_period_id,recurrence_template_id,scheduled_for_date)
                        VALUES(v_owner,pg_catalog.gen_random_uuid(),v_template.description,v_template.default_amount_centavos,
                            v_scheduled,'pending',v_template.category_id,v_template.subcategory_id,v_period.id,v_template.id,v_scheduled)
                        ON CONFLICT(owner_id,recurrence_template_id,scheduled_for_date) WHERE recurrence_template_id IS NOT NULL DO NOTHING
                        RETURNING * INTO v_entry;
                        IF FOUND THEN
                            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,new_values,operation_id)
                            VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_entry',v_entry.id,'create',v_owner,pg_catalog.to_jsonb(v_entry),p_operation_id);
                            v_expense_count := v_expense_count+1;
                            v_occurrences := v_occurrences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
                                'kind','expense','id',v_entry.id,'scheduled_for_date',v_scheduled,'accounting_period_id',v_period.id));
                        END IF;
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
                INSERT INTO public.expense_entries(owner_id,id,description,amount_centavos,competence_on,status,category_id,
                    subcategory_id,accounting_period_id,recurrence_template_id,scheduled_for_date,scheduled_period_id)
                VALUES(v_owner,pg_catalog.gen_random_uuid(),v_template.description,v_template.default_amount_centavos,
                    v_scheduled,'pending',v_template.category_id,v_template.subcategory_id,v_period.id,v_template.id,v_scheduled,v_period.id)
                ON CONFLICT(owner_id,recurrence_template_id,scheduled_for_date) WHERE recurrence_template_id IS NOT NULL DO NOTHING
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

CREATE FUNCTION public.apply_income_recurrence_occurrence_change(
    p_operation_id UUID,p_action TEXT,p_entry_id UUID,p_expected_version BIGINT,p_payload JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB; v_hash BYTEA; v_saved_hash BYTEA; v_saved JSONB;
    v_entry public.income_entries%ROWTYPE; v_template public.income_recurrence_templates%ROWTYPE;
    v_period public.accounting_periods%ROWTYPE; v_conflict UUID; v_response JSONB;
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
                SELECT p.* INTO v_period FROM public.accounting_periods p
                WHERE p.owner_id=v_owner AND p.start_date<=v_received AND v_received<p.end_date;
                IF NOT FOUND THEN RAISE EXCEPTION 'no accounting period covers received_on' USING ERRCODE='foreign_key_violation'; END IF;
                v_period_id:=v_period.id;
            END IF;
            UPDATE public.income_entries e SET description=v_description,amount_centavos=v_amount,status=v_status,
                received_on=v_received,accounting_period_id=v_period_id,category_id=v_category,subcategory_id=v_subcategory,
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

CREATE FUNCTION public.apply_expense_recurrence_occurrence_change(
    p_operation_id UUID,p_action TEXT,p_entry_id UUID,p_expected_version BIGINT,p_payload JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_request JSONB; v_hash BYTEA; v_saved_hash BYTEA; v_saved JSONB;
    v_entry public.expense_entries%ROWTYPE; v_template public.expense_recurrence_templates%ROWTYPE;
    v_period public.accounting_periods%ROWTYPE; v_conflict UUID; v_response JSONB;
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
            IF v_status IN ('pending','paid') AND v_amount IS NULL THEN
                RAISE EXCEPTION 'expense value is required for this status' USING ERRCODE='check_violation';
            END IF;
            IF v_category IS NOT NULL AND v_category IS DISTINCT FROM v_entry.category_id
                AND NOT EXISTS(SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='expense' AND c.is_active) THEN
                RAISE EXCEPTION 'new expense category must be active and have expense kind' USING ERRCODE='check_violation';
            END IF;
            IF v_subcategory IS NOT NULL AND (v_category IS DISTINCT FROM v_entry.category_id OR v_subcategory IS DISTINCT FROM v_entry.subcategory_id)
                AND (v_category IS NULL OR NOT EXISTS(SELECT 1 FROM public.subcategories s WHERE s.owner_id=v_owner AND s.category_id=v_category AND s.id=v_subcategory AND s.is_active)) THEN
                RAISE EXCEPTION 'new expense subcategory must belong to the active category' USING ERRCODE='check_violation';
            END IF;
            SELECT p.* INTO v_period FROM public.accounting_periods p
            WHERE p.owner_id=v_owner AND p.start_date<=v_competence AND v_competence<p.end_date;
            IF NOT FOUND THEN RAISE EXCEPTION 'no accounting period covers competence_on' USING ERRCODE='foreign_key_violation'; END IF;
            v_period_id:=v_period.id;
            UPDATE public.expense_entries e SET amount_centavos=v_amount,competence_on=v_competence,due_on=v_due,paid_on=v_paid,
                status=v_status,description=v_description,category_id=v_category,subcategory_id=v_subcategory,accounting_period_id=v_period_id,
                version=e.version+1,updated_at=pg_catalog.clock_timestamp()
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

ALTER FUNCTION public.generate_due_recurrence_occurrences(UUID) OWNER TO postgres;
ALTER FUNCTION public.apply_income_recurrence_occurrence_change(UUID,TEXT,UUID,BIGINT,JSONB) OWNER TO postgres;
ALTER FUNCTION public.apply_expense_recurrence_occurrence_change(UUID,TEXT,UUID,BIGINT,JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.generate_due_recurrence_occurrences(UUID) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.apply_income_recurrence_occurrence_change(UUID,TEXT,UUID,BIGINT,JSONB) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.apply_expense_recurrence_occurrence_change(UUID,TEXT,UUID,BIGINT,JSONB) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.generate_due_recurrence_occurrences(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_income_recurrence_occurrence_change(UUID,TEXT,UUID,BIGINT,JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_expense_recurrence_occurrence_change(UUID,TEXT,UUID,BIGINT,JSONB) TO authenticated;
COMMENT ON FUNCTION public.generate_due_recurrence_occurrences(UUID)
    IS 'Idempotently catches up due recurrence occurrences using the authenticated user calendar zone; called on app open and sync.';
COMMENT ON FUNCTION public.apply_income_recurrence_occurrence_change(UUID,TEXT,UUID,BIGINT,JSONB)
    IS 'Applies versioned, idempotent and audited edits, receipt confirmation and cancellation for a generated recurring income occurrence.';
COMMENT ON FUNCTION public.apply_expense_recurrence_occurrence_change(UUID,TEXT,UUID,BIGINT,JSONB)
    IS 'Applies versioned, idempotent and audited edits, integral payment and cancellation for a generated recurring expense occurrence.';

COMMIT;
