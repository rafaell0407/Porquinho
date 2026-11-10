-- Versioned writes for recurrence models. Occurrence generation is a separate delivery.
BEGIN;

CREATE FUNCTION public.apply_income_recurrence_template_change(
    p_operation_id UUID, p_action TEXT, p_template_id UUID,
    p_expected_version BIGINT, p_payload JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid(); v_request JSONB; v_hash BYTEA; v_claimed UUID;
    v_saved_hash BYTEA; v_saved JSONB; v_template public.income_recurrence_templates%ROWTYPE;
    v_existing public.income_recurrence_templates%ROWTYPE; v_conflict UUID;
    v_response JSONB; v_previous JSONB; v_audit TEXT;
    v_description TEXT; v_frequency TEXT; v_starts DATE; v_day SMALLINT;
    v_mode TEXT; v_amount BIGINT; v_category UUID; v_subcategory UUID;
BEGIN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'authentication is required' USING ERRCODE='invalid_authorization_specification'; END IF;
    IF p_operation_id IS NULL OR p_template_id IS NULL OR p_expected_version IS NULL OR p_action IS NULL THEN
        RAISE EXCEPTION 'operation, action, template and expected version are required' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_action NOT IN ('create','update','deactivate') OR p_expected_version<0
        OR (p_action='create' AND p_expected_version<>0) OR (p_action<>'create' AND p_expected_version=0) THEN
        RAISE EXCEPTION 'unsupported income recurrence action or expected version' USING ERRCODE='invalid_parameter_value';
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
        SELECT t.* INTO v_existing FROM public.income_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.id=p_template_id FOR UPDATE;
        IF FOUND THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_recurrence_template',p_template_id,0,v_existing.version,v_request,pg_catalog.to_jsonb(v_existing)) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_template',pg_catalog.to_jsonb(v_existing));
        END IF;
    ELSE
        SELECT t.* INTO v_template FROM public.income_recurrence_templates t
        WHERE t.owner_id=v_owner AND t.id=p_template_id FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'income recurrence template was not found' USING ERRCODE='no_data_found'; END IF;
        IF v_template.version<>p_expected_version THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_recurrence_template',p_template_id,p_expected_version,v_template.version,v_request,pg_catalog.to_jsonb(v_template)) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_template',pg_catalog.to_jsonb(v_template));
        END IF;
    END IF;
    IF v_response IS NULL THEN
        IF p_action='deactivate' THEN
            v_previous:=pg_catalog.to_jsonb(v_template);
            UPDATE public.income_recurrence_templates t SET is_active=FALSE,version=t.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE t.owner_id=v_owner AND t.id=p_template_id RETURNING t.* INTO v_template;
            v_audit:='deactivate';
        ELSE
            IF p_action='create' THEN
                IF NOT (p_payload?'frequency') OR NOT (p_payload?'starts_on') OR NOT (p_payload?'value_mode') THEN
                    RAISE EXCEPTION 'template creation requires frequency, starts_on and value_mode' USING ERRCODE='invalid_parameter_value';
                END IF;
                v_description:=NULLIF(p_payload->>'description','null'); v_frequency:=p_payload->>'frequency';
                v_starts:=NULLIF(p_payload->>'starts_on','null')::DATE;
                v_day:=NULLIF(p_payload->>'monthly_reference_day','null')::SMALLINT;
                v_mode:=p_payload->>'value_mode'; v_amount:=NULLIF(p_payload->>'default_amount_centavos','null')::BIGINT;
                v_category:=NULLIF(p_payload->>'category_id','null')::UUID; v_subcategory:=NULLIF(p_payload->>'subcategory_id','null')::UUID;
            ELSE
                v_description:=CASE WHEN p_payload?'description' THEN NULLIF(p_payload->>'description','null') ELSE v_template.description END;
                v_frequency:=CASE WHEN p_payload?'frequency' THEN p_payload->>'frequency' ELSE v_template.frequency END;
                v_starts:=CASE WHEN p_payload?'starts_on' THEN NULLIF(p_payload->>'starts_on','null')::DATE ELSE v_template.starts_on END;
                v_day:=CASE WHEN p_payload?'monthly_reference_day' THEN NULLIF(p_payload->>'monthly_reference_day','null')::SMALLINT ELSE v_template.monthly_reference_day END;
                v_mode:=CASE WHEN p_payload?'value_mode' THEN p_payload->>'value_mode' ELSE v_template.value_mode END;
                v_amount:=CASE WHEN p_payload?'default_amount_centavos' THEN NULLIF(p_payload->>'default_amount_centavos','null')::BIGINT ELSE v_template.default_amount_centavos END;
                v_category:=CASE WHEN p_payload?'category_id' THEN NULLIF(p_payload->>'category_id','null')::UUID ELSE v_template.category_id END;
                v_subcategory:=CASE WHEN p_payload?'subcategory_id' THEN NULLIF(p_payload->>'subcategory_id','null')::UUID ELSE v_template.subcategory_id END;
            END IF;
            IF v_frequency IS NULL OR v_frequency NOT IN ('monthly','by_period') OR v_starts IS NULL
                OR v_mode IS NULL OR v_mode NOT IN ('fixed','variable')
                OR (v_frequency='monthly' AND (v_day IS NULL OR v_day NOT BETWEEN 1 AND 31))
                OR (v_frequency='by_period' AND v_day IS NOT NULL)
                OR (v_mode='fixed' AND (v_amount IS NULL OR v_amount<0))
                OR (v_mode='variable' AND v_amount IS NOT NULL) THEN
                RAISE EXCEPTION 'invalid income recurrence schedule or value configuration' USING ERRCODE='invalid_parameter_value';
            END IF;
            IF v_category IS NOT NULL AND (p_action='create' OR v_category IS DISTINCT FROM v_template.category_id) THEN
                IF NOT EXISTS(SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='income' AND c.is_active) THEN
                    RAISE EXCEPTION 'new income category must be active and have income kind' USING ERRCODE='check_violation';
                END IF;
            END IF;
            IF v_subcategory IS NOT NULL AND (p_action='create' OR v_category IS DISTINCT FROM v_template.category_id OR v_subcategory IS DISTINCT FROM v_template.subcategory_id) THEN
                IF NOT EXISTS(SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='income' AND c.is_active)
                    OR NOT EXISTS(SELECT 1 FROM public.subcategories s WHERE s.owner_id=v_owner AND s.category_id=v_category AND s.id=v_subcategory AND s.is_active) THEN
                    RAISE EXCEPTION 'new income subcategory association must be active and belong to an active income category' USING ERRCODE='check_violation';
                END IF;
            END IF;
            IF p_action='create' THEN
                INSERT INTO public.income_recurrence_templates(owner_id,id,description,frequency,starts_on,monthly_reference_day,value_mode,default_amount_centavos,category_id,subcategory_id)
                VALUES(v_owner,p_template_id,v_description,v_frequency,v_starts,v_day,v_mode,v_amount,v_category,v_subcategory) RETURNING * INTO v_template;
                v_audit:='create';
            ELSE
                v_previous:=pg_catalog.to_jsonb(v_template);
                UPDATE public.income_recurrence_templates t SET description=v_description,frequency=v_frequency,starts_on=v_starts,
                    monthly_reference_day=v_day,value_mode=v_mode,default_amount_centavos=v_amount,category_id=v_category,subcategory_id=v_subcategory,
                    version=t.version+1,updated_at=pg_catalog.clock_timestamp() WHERE t.owner_id=v_owner AND t.id=p_template_id RETURNING t.* INTO v_template;
                v_audit:='update';
            END IF;
        END IF;
        IF v_audit IS NOT NULL THEN
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'income_recurrence_template',p_template_id,v_audit,v_owner,v_previous,pg_catalog.to_jsonb(v_template),p_operation_id);
            v_response:=pg_catalog.jsonb_build_object('status','applied','template',pg_catalog.to_jsonb(v_template));
        END IF;
    END IF;
    UPDATE public.applied_sync_operations op SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),applied_at=pg_catalog.clock_timestamp()
    WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

CREATE FUNCTION public.apply_expense_recurrence_template_change(
    p_operation_id UUID, p_action TEXT, p_template_id UUID,
    p_expected_version BIGINT, p_payload JSONB
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid(); v_request JSONB; v_hash BYTEA; v_claimed UUID;
    v_saved_hash BYTEA; v_saved JSONB; v_template public.expense_recurrence_templates%ROWTYPE;
    v_existing public.expense_recurrence_templates%ROWTYPE; v_conflict UUID;
    v_response JSONB; v_previous JSONB; v_audit TEXT;
    v_description TEXT; v_frequency TEXT; v_starts DATE; v_day SMALLINT;
    v_mode TEXT; v_amount BIGINT; v_category UUID; v_subcategory UUID;
BEGIN
    IF v_owner IS NULL THEN RAISE EXCEPTION 'authentication is required' USING ERRCODE='invalid_authorization_specification'; END IF;
    IF p_operation_id IS NULL OR p_template_id IS NULL OR p_expected_version IS NULL OR p_action IS NULL THEN
        RAISE EXCEPTION 'operation, action, template and expected version are required' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_action NOT IN ('create','update','deactivate') OR p_expected_version<0
        OR (p_action='create' AND p_expected_version<>0) OR (p_action<>'create' AND p_expected_version=0) THEN
        RAISE EXCEPTION 'unsupported expense recurrence action or expected version' USING ERRCODE='invalid_parameter_value';
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
        SELECT t.* INTO v_existing FROM public.expense_recurrence_templates t WHERE t.owner_id=v_owner AND t.id=p_template_id FOR UPDATE;
        IF FOUND THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_recurrence_template',p_template_id,0,v_existing.version,v_request,pg_catalog.to_jsonb(v_existing)) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_template',pg_catalog.to_jsonb(v_existing));
        END IF;
    ELSE
        SELECT t.* INTO v_template FROM public.expense_recurrence_templates t WHERE t.owner_id=v_owner AND t.id=p_template_id FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'expense recurrence template was not found' USING ERRCODE='no_data_found'; END IF;
        IF v_template.version<>p_expected_version THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_recurrence_template',p_template_id,p_expected_version,v_template.version,v_request,pg_catalog.to_jsonb(v_template)) RETURNING id INTO v_conflict;
            v_response:=pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_template',pg_catalog.to_jsonb(v_template));
        END IF;
    END IF;
    IF v_response IS NULL THEN
        IF p_action='deactivate' THEN
            v_previous:=pg_catalog.to_jsonb(v_template);
            UPDATE public.expense_recurrence_templates t SET is_active=FALSE,version=t.version+1,updated_at=pg_catalog.clock_timestamp()
            WHERE t.owner_id=v_owner AND t.id=p_template_id RETURNING t.* INTO v_template;
            v_audit:='deactivate';
        ELSE
            IF p_action='create' THEN
                IF NOT (p_payload?'frequency') OR NOT (p_payload?'starts_on') OR NOT (p_payload?'value_mode') THEN
                    RAISE EXCEPTION 'template creation requires frequency, starts_on and value_mode' USING ERRCODE='invalid_parameter_value';
                END IF;
                v_description:=NULLIF(p_payload->>'description','null'); v_frequency:=p_payload->>'frequency';
                v_starts:=NULLIF(p_payload->>'starts_on','null')::DATE;
                v_day:=NULLIF(p_payload->>'monthly_reference_day','null')::SMALLINT;
                v_mode:=p_payload->>'value_mode'; v_amount:=NULLIF(p_payload->>'default_amount_centavos','null')::BIGINT;
                v_category:=NULLIF(p_payload->>'category_id','null')::UUID; v_subcategory:=NULLIF(p_payload->>'subcategory_id','null')::UUID;
            ELSE
                v_description:=CASE WHEN p_payload?'description' THEN NULLIF(p_payload->>'description','null') ELSE v_template.description END;
                v_frequency:=CASE WHEN p_payload?'frequency' THEN p_payload->>'frequency' ELSE v_template.frequency END;
                v_starts:=CASE WHEN p_payload?'starts_on' THEN NULLIF(p_payload->>'starts_on','null')::DATE ELSE v_template.starts_on END;
                v_day:=CASE WHEN p_payload?'monthly_reference_day' THEN NULLIF(p_payload->>'monthly_reference_day','null')::SMALLINT ELSE v_template.monthly_reference_day END;
                v_mode:=CASE WHEN p_payload?'value_mode' THEN p_payload->>'value_mode' ELSE v_template.value_mode END;
                v_amount:=CASE WHEN p_payload?'default_amount_centavos' THEN NULLIF(p_payload->>'default_amount_centavos','null')::BIGINT ELSE v_template.default_amount_centavos END;
                v_category:=CASE WHEN p_payload?'category_id' THEN NULLIF(p_payload->>'category_id','null')::UUID ELSE v_template.category_id END;
                v_subcategory:=CASE WHEN p_payload?'subcategory_id' THEN NULLIF(p_payload->>'subcategory_id','null')::UUID ELSE v_template.subcategory_id END;
            END IF;
            IF v_frequency IS NULL OR v_frequency NOT IN ('monthly','by_period') OR v_starts IS NULL
                OR v_mode IS NULL OR v_mode NOT IN ('fixed','variable')
                OR (v_frequency='monthly' AND (v_day IS NULL OR v_day NOT BETWEEN 1 AND 31))
                OR (v_frequency='by_period' AND v_day IS NOT NULL)
                OR (v_mode='fixed' AND (v_amount IS NULL OR v_amount<0))
                OR (v_mode='variable' AND v_amount IS NOT NULL) THEN
                RAISE EXCEPTION 'invalid expense recurrence schedule or value configuration' USING ERRCODE='invalid_parameter_value';
            END IF;
            IF v_category IS NOT NULL AND (p_action='create' OR v_category IS DISTINCT FROM v_template.category_id) THEN
                IF NOT EXISTS(SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='expense' AND c.is_active) THEN
                    RAISE EXCEPTION 'new expense category must be active and have expense kind' USING ERRCODE='check_violation';
                END IF;
            END IF;
            IF v_subcategory IS NOT NULL AND (p_action='create' OR v_category IS DISTINCT FROM v_template.category_id OR v_subcategory IS DISTINCT FROM v_template.subcategory_id) THEN
                IF NOT EXISTS(SELECT 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=v_category AND c.kind='expense' AND c.is_active)
                    OR NOT EXISTS(SELECT 1 FROM public.subcategories s WHERE s.owner_id=v_owner AND s.category_id=v_category AND s.id=v_subcategory AND s.is_active) THEN
                    RAISE EXCEPTION 'new expense subcategory association must be active and belong to an active expense category' USING ERRCODE='check_violation';
                END IF;
            END IF;
            IF p_action='create' THEN
                INSERT INTO public.expense_recurrence_templates(owner_id,id,description,frequency,starts_on,monthly_reference_day,value_mode,default_amount_centavos,category_id,subcategory_id)
                VALUES(v_owner,p_template_id,v_description,v_frequency,v_starts,v_day,v_mode,v_amount,v_category,v_subcategory) RETURNING * INTO v_template;
                v_audit:='create';
            ELSE
                v_previous:=pg_catalog.to_jsonb(v_template);
                UPDATE public.expense_recurrence_templates t SET description=v_description,frequency=v_frequency,starts_on=v_starts,
                    monthly_reference_day=v_day,value_mode=v_mode,default_amount_centavos=v_amount,category_id=v_category,subcategory_id=v_subcategory,
                    version=t.version+1,updated_at=pg_catalog.clock_timestamp() WHERE t.owner_id=v_owner AND t.id=p_template_id RETURNING t.* INTO v_template;
                v_audit:='update';
            END IF;
        END IF;
        IF v_audit IS NOT NULL THEN
            INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'expense_recurrence_template',p_template_id,v_audit,v_owner,v_previous,pg_catalog.to_jsonb(v_template),p_operation_id);
            v_response:=pg_catalog.jsonb_build_object('status','applied','template',pg_catalog.to_jsonb(v_template));
        END IF;
    END IF;
    UPDATE public.applied_sync_operations op SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response),applied_at=pg_catalog.clock_timestamp()
    WHERE op.owner_id=v_owner AND op.idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

ALTER FUNCTION public.apply_income_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.apply_income_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_income_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB) TO authenticated;
COMMENT ON FUNCTION public.apply_income_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB)
    IS 'Applies versioned, idempotent and audited changes to authenticated income recurrence templates; it does not generate occurrences.';
ALTER FUNCTION public.apply_expense_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.apply_expense_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_expense_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB) TO authenticated;
COMMENT ON FUNCTION public.apply_expense_recurrence_template_change(UUID,TEXT,UUID,BIGINT,JSONB)
    IS 'Applies versioned, idempotent and audited changes to authenticated expense recurrence templates; it does not generate occurrences.';
COMMIT;
