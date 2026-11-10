-- Authenticated write paths for one-time income and expense entries.
-- Recurrence occurrences are intentionally handled by a later delivery.
BEGIN;

CREATE FUNCTION public.apply_income_entry_change(
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
    v_period public.accounting_periods%ROWTYPE;
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
            SELECT period.* INTO v_period FROM public.accounting_periods period
            WHERE period.owner_id=v_owner AND period.start_date<=v_received AND v_received<period.end_date;
            IF NOT FOUND THEN RAISE EXCEPTION 'no accounting period covers received_on' USING ERRCODE='foreign_key_violation'; END IF;
            IF p_action='create' THEN
                INSERT INTO public.income_entries(owner_id,id,description,amount_centavos,status,received_on,category_id,subcategory_id,accounting_period_id)
                VALUES(v_owner,p_entry_id,v_description,v_amount,'received',v_received,v_category,v_subcategory,v_period.id)
                RETURNING * INTO v_entry;
                v_audit:='create';
            ELSE
                v_previous:=pg_catalog.to_jsonb(v_entry);
                UPDATE public.income_entries entry SET description=v_description,amount_centavos=v_amount,
                    received_on=v_received,category_id=v_category,subcategory_id=v_subcategory,
                    accounting_period_id=v_period.id,version=entry.version+1,updated_at=pg_catalog.clock_timestamp()
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

CREATE FUNCTION public.apply_expense_entry_change(
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
    v_period public.accounting_periods%ROWTYPE;
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
            SELECT period.* INTO v_period FROM public.accounting_periods period
            WHERE period.owner_id=v_owner AND period.start_date<=v_competence AND v_competence<period.end_date;
            IF NOT FOUND THEN RAISE EXCEPTION 'no accounting period covers competence_on' USING ERRCODE='foreign_key_violation'; END IF;
            IF p_action='create' THEN
                INSERT INTO public.expense_entries(owner_id,id,description,amount_centavos,competence_on,due_on,status,category_id,subcategory_id,accounting_period_id)
                VALUES(v_owner,p_entry_id,v_description,v_amount,v_competence,v_due,'pending',v_category,v_subcategory,v_period.id) RETURNING * INTO v_entry;
                v_audit:='create';
            ELSE
                v_previous:=pg_catalog.to_jsonb(v_entry);
                UPDATE public.expense_entries entry SET description=v_description,amount_centavos=v_amount,
                    competence_on=v_competence,due_on=v_due,category_id=v_category,subcategory_id=v_subcategory,
                    accounting_period_id=v_period.id,version=entry.version+1,updated_at=pg_catalog.clock_timestamp()
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

ALTER FUNCTION public.apply_income_entry_change(UUID,TEXT,UUID,BIGINT,JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.apply_income_entry_change(UUID,TEXT,UUID,BIGINT,JSONB) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_income_entry_change(UUID,TEXT,UUID,BIGINT,JSONB) TO authenticated;
COMMENT ON FUNCTION public.apply_income_entry_change(UUID,TEXT,UUID,BIGINT,JSONB)
    IS 'Applies authenticated one-time income create, update or cancellation with received-date period assignment, idempotency, version conflicts and audit.';

ALTER FUNCTION public.apply_expense_entry_change(UUID,TEXT,UUID,BIGINT,JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.apply_expense_entry_change(UUID,TEXT,UUID,BIGINT,JSONB) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_expense_entry_change(UUID,TEXT,UUID,BIGINT,JSONB) TO authenticated;
COMMENT ON FUNCTION public.apply_expense_entry_change(UUID,TEXT,UUID,BIGINT,JSONB)
    IS 'Applies authenticated one-time expense create, update, payment or cancellation with competence-date period assignment, idempotency, version conflicts and audit.';
COMMIT;
