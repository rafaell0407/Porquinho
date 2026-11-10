-- Keep variable expense occurrences editable before their value is known.
BEGIN;

CREATE OR REPLACE FUNCTION public.apply_expense_recurrence_occurrence_change(
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

COMMENT ON FUNCTION public.apply_expense_recurrence_occurrence_change(UUID,TEXT,UUID,BIGINT,JSONB)
    IS 'Applies versioned, idempotent and audited edits, integral payment and cancellation; variable pending expenses may remain unpriced.';

COMMIT;
