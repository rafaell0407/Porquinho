-- Versioned, idempotent subcategory lifecycle. Ownership comes from Supabase Auth.
BEGIN;

CREATE FUNCTION public.apply_subcategory_change(
    p_operation_id UUID,
    p_action TEXT,
    p_subcategory_id UUID,
    p_category_id UUID,
    p_expected_version BIGINT,
    p_name TEXT
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
    v_claim UUID;
    v_stored_hash BYTEA;
    v_stored JSONB;
    v_row public.subcategories%ROWTYPE;
    v_conflict UUID;
    v_response JSONB;
    v_previous JSONB;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_action IS NULL OR p_action NOT IN ('create','rename','deactivate')
       OR p_subcategory_id IS NULL OR p_expected_version IS NULL THEN
        RAISE EXCEPTION 'invalid subcategory operation' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_action = 'create' THEN
        IF p_expected_version <> 0 OR p_category_id IS NULL OR p_name IS NULL THEN
            RAISE EXCEPTION 'create requires version zero, category and name' USING ERRCODE = 'invalid_parameter_value';
        END IF;
    ELSIF p_expected_version < 1 OR p_category_id IS NOT NULL
       OR (p_action = 'rename' AND p_name IS NULL)
       OR (p_action = 'deactivate' AND p_name IS NOT NULL) THEN
        RAISE EXCEPTION 'invalid subcategory update parameters' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_request := pg_catalog.jsonb_build_object('action',p_action,'subcategory_id',p_subcategory_id,
        'category_id',p_category_id,'expected_version',p_expected_version,'name',p_name);
    v_hash := pg_catalog.decode(pg_catalog.md5(pg_catalog.convert_to(v_request::TEXT,'UTF8')),'hex');
    INSERT INTO public.applied_sync_operations(owner_id,idempotency_key,content_hash,result_payload)
    VALUES(v_owner,p_operation_id,v_hash,pg_catalog.jsonb_build_object('request',v_request,'response',NULL))
    ON CONFLICT(owner_id,idempotency_key) DO NOTHING RETURNING idempotency_key INTO v_claim;
    IF NOT FOUND THEN
        SELECT content_hash,result_payload INTO v_stored_hash,v_stored
          FROM public.applied_sync_operations WHERE owner_id=v_owner AND idempotency_key=p_operation_id FOR UPDATE;
        IF v_stored_hash IS DISTINCT FROM v_hash OR v_stored->'request' IS DISTINCT FROM v_request THEN
            RAISE EXCEPTION 'idempotency key reused with different request' USING ERRCODE = 'invalid_parameter_value';
        END IF;
        RETURN v_stored->'response';
    END IF;

    IF p_action = 'create' THEN
        PERFORM 1 FROM public.categories c WHERE c.owner_id=v_owner AND c.id=p_category_id AND c.is_active FOR SHARE;
        IF NOT FOUND THEN RAISE EXCEPTION 'active category not found' USING ERRCODE = 'no_data_found'; END IF;
        INSERT INTO public.subcategories(owner_id,id,category_id,name)
        VALUES(v_owner,p_subcategory_id,p_category_id,p_name) RETURNING * INTO v_row;
        v_previous := NULL;
    ELSE
        SELECT s.* INTO v_row FROM public.subcategories s
        WHERE s.owner_id=v_owner AND s.id=p_subcategory_id FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'subcategory not found' USING ERRCODE = 'no_data_found'; END IF;
        IF v_row.version <> p_expected_version THEN
            INSERT INTO public.sync_conflicts(owner_id,id,entity_type,entity_id,base_version,remote_version,local_snapshot,remote_snapshot)
            VALUES(v_owner,pg_catalog.gen_random_uuid(),'subcategory',p_subcategory_id,p_expected_version,v_row.version,v_request,pg_catalog.to_jsonb(v_row))
            RETURNING id INTO v_conflict;
            v_response := pg_catalog.jsonb_build_object('status','conflict','conflict_id',v_conflict,'remote_subcategory',pg_catalog.to_jsonb(v_row));
        ELSE
            v_previous := pg_catalog.to_jsonb(v_row);
            UPDATE public.subcategories SET
                name=CASE WHEN p_action='rename' THEN p_name ELSE name END,
                is_active=CASE WHEN p_action='deactivate' THEN FALSE ELSE is_active END,
                version=version+1, updated_at=pg_catalog.clock_timestamp()
            WHERE owner_id=v_owner AND id=p_subcategory_id RETURNING * INTO v_row;
        END IF;
    END IF;

    IF v_response IS NULL THEN
        INSERT INTO public.audit_events(owner_id,id,entity_type,entity_id,operation,actor_id,previous_values,new_values,operation_id)
        VALUES(v_owner,pg_catalog.gen_random_uuid(),'subcategory',p_subcategory_id,p_action,v_owner,v_previous,pg_catalog.to_jsonb(v_row),p_operation_id);
        v_response := pg_catalog.jsonb_build_object('status','applied','subcategory',pg_catalog.to_jsonb(v_row));
    END IF;
    UPDATE public.applied_sync_operations SET result_payload=pg_catalog.jsonb_build_object('request',v_request,'response',v_response), applied_at=pg_catalog.clock_timestamp()
    WHERE owner_id=v_owner AND idempotency_key=p_operation_id;
    RETURN v_response;
END;
$function$;

ALTER FUNCTION public.apply_subcategory_change(UUID,TEXT,UUID,UUID,BIGINT,TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.apply_subcategory_change(UUID,TEXT,UUID,UUID,BIGINT,TEXT) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_subcategory_change(UUID,TEXT,UUID,UUID,BIGINT,TEXT) TO authenticated;
COMMENT ON FUNCTION public.apply_subcategory_change(UUID,TEXT,UUID,UUID,BIGINT,TEXT)
    IS 'Applies one authenticated subcategory create, rename or deactivate operation with optimistic versioning, idempotency and audit in one transaction.';
COMMIT;
