\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users(id) VALUES
    ('10000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;
SELECT pg_catalog.set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',TRUE);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE
    cat UUID := '10000000-0000-0000-0000-000000001101';
    sub UUID := '10000000-0000-0000-0000-000000001102';
    second_cat UUID := '10000000-0000-0000-0000-000000001201';
    second_sub UUID := '10000000-0000-0000-0000-000000001202';
    op UUID := '20000000-0000-0000-0000-000000001101';
    category_op UUID := '20000000-0000-0000-0000-000000001100';
    response JSONB;
    replay JSONB;
    version_now BIGINT;
BEGIN
    IF NOT pg_catalog.has_function_privilege(
        'authenticated',
        'public.apply_subcategory_change(uuid,text,uuid,uuid,bigint,text)',
        'EXECUTE'
    ) OR pg_catalog.has_function_privilege(
        'anon',
        'public.apply_subcategory_change(uuid,text,uuid,uuid,bigint,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'only authenticated users may execute the subcategory RPC';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS function
        WHERE function.oid = 'public.apply_subcategory_change(uuid,text,uuid,uuid,bigint,text)'::REGPROCEDURE
          AND (
              NOT function.prosecdef
              OR function.proowner <> 'postgres'::REGROLE
              OR NOT (function.proconfig @> ARRAY['search_path=""'])
          )
    ) THEN
        RAISE EXCEPTION 'subcategory RPC must use SECURITY DEFINER, postgres ownership and an empty search_path';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS function
        CROSS JOIN LATERAL pg_catalog.aclexplode(
            COALESCE(function.proacl, pg_catalog.acldefault('f', function.proowner))
        ) AS privilege
        WHERE function.oid = 'public.apply_subcategory_change(uuid,text,uuid,uuid,bigint,text)'::REGPROCEDURE
          AND privilege.grantee = 0
          AND privilege.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'PUBLIC execution must be revoked from the subcategory RPC';
    END IF;

    PERFORM public.apply_category_change(category_op,'create',cat,0,'expense','Casa');
    response := public.apply_subcategory_change(op,'create',sub,cat,0,'Aluguel');
    IF response->>'status'<>'applied' OR response#>>'{subcategory,version}'<>'1' THEN
        RAISE EXCEPTION 'subcategory create failed: %',response;
    END IF;
    replay := public.apply_subcategory_change(op,'create',sub,cat,0,'Aluguel');
    IF replay IS DISTINCT FROM response THEN RAISE EXCEPTION 'idempotent replay differs'; END IF;
    BEGIN
        PERFORM public.apply_subcategory_change(op,'create',sub,cat,0,'Outro nome');
        RAISE EXCEPTION 'reusing an idempotency key with changed content must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;
    response := public.apply_subcategory_change('20000000-0000-0000-0000-000000001102','rename',sub,NULL,1,'Moradia');
    IF response#>>'{subcategory,name}'<>'Moradia' OR response#>>'{subcategory,version}'<>'2' THEN
        RAISE EXCEPTION 'subcategory rename failed: %',response;
    END IF;
    response := public.apply_subcategory_change('20000000-0000-0000-0000-000000001103','rename',sub,NULL,1,'Stale');
    IF response->>'status'<>'conflict' OR response#>>'{remote_subcategory,version}'<>'2' THEN
        RAISE EXCEPTION 'stale subcategory version did not conflict: %',response;
    END IF;
    replay := public.apply_subcategory_change('20000000-0000-0000-0000-000000001103','rename',sub,NULL,1,'Stale');
    IF replay IS DISTINCT FROM response THEN RAISE EXCEPTION 'replayed conflict differs'; END IF;
    SELECT version INTO version_now FROM public.subcategories WHERE owner_id=auth.uid() AND id=sub;
    IF version_now<>2 THEN RAISE EXCEPTION 'conflict changed the subcategory'; END IF;
    response := public.apply_subcategory_change('20000000-0000-0000-0000-000000001104','deactivate',sub,NULL,2,NULL);
    IF response#>>'{subcategory,is_active}'<>'false' OR response#>>'{subcategory,version}'<>'3' THEN
        RAISE EXCEPTION 'subcategory deactivation failed: %',response;
    END IF;
    IF (SELECT count(*) FROM public.audit_events WHERE owner_id=auth.uid() AND entity_id=sub)<>3 THEN
        RAISE EXCEPTION 'expected exactly three successful audit events';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.audit_events
        WHERE owner_id=auth.uid() AND entity_id=sub AND operation='rename'
          AND previous_values->>'name'='Aluguel' AND new_values->>'name'='Moradia'
    ) THEN
        RAISE EXCEPTION 'rename audit did not preserve previous and new values';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.sync_conflicts WHERE owner_id=auth.uid() AND entity_id=sub AND entity_type='subcategory') THEN
        RAISE EXCEPTION 'conflict snapshot was not persisted';
    END IF;
    IF (SELECT count(*) FROM public.sync_conflicts WHERE owner_id=auth.uid() AND entity_id=sub AND entity_type='subcategory')<>1 THEN
        RAISE EXCEPTION 'replaying a conflict must not duplicate its snapshot';
    END IF;

    PERFORM public.apply_category_change(
        '20000000-0000-0000-0000-000000001105','deactivate',cat,1,NULL,NULL
    );
    BEGIN
        PERFORM public.apply_subcategory_change(
            '20000000-0000-0000-0000-000000001106','create',
            '10000000-0000-0000-0000-000000001103',cat,0,'Categoria inativa'
        );
        RAISE EXCEPTION 'a subcategory must not be created under an inactive category' USING ERRCODE = 'P0001';
    EXCEPTION WHEN no_data_found THEN
        NULL;
    END;

    PERFORM pg_catalog.set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',TRUE);
    BEGIN
        PERFORM public.apply_subcategory_change(
            '30000000-0000-0000-0000-000000001201','rename',sub,NULL,3,'Acesso cruzado'
        );
        RAISE EXCEPTION 'one user must not mutate another user subcategory' USING ERRCODE = 'P0001';
    EXCEPTION WHEN no_data_found THEN
        NULL;
    END;
    IF EXISTS (SELECT 1 FROM public.subcategories WHERE id=sub) THEN
        RAISE EXCEPTION 'RLS must hide another user subcategory';
    END IF;

    PERFORM public.apply_category_change(
        '30000000-0000-0000-0000-000000001202','create',second_cat,0,'expense','Casa do usuário 2'
    );
    response := public.apply_subcategory_change(
        '30000000-0000-0000-0000-000000001203','create',second_sub,second_cat,0,'Contas'
    );
    IF response->>'status'<>'applied' OR response#>>'{subcategory,owner_id}'<>'10000000-0000-0000-0000-000000000002' THEN
        RAISE EXCEPTION 'second user could not create an owned subcategory: %',response;
    END IF;
    BEGIN
        PERFORM public.apply_subcategory_change(
            '30000000-0000-0000-0000-000000001204','create',
            '10000000-0000-0000-0000-000000001204',cat,0,'Categoria de outro usuário'
        );
        RAISE EXCEPTION 'one user must not create a subcategory under another user category' USING ERRCODE = 'P0001';
    EXCEPTION WHEN no_data_found THEN
        NULL;
    END;

    BEGIN
        PERFORM public.apply_subcategory_change(
            '30000000-0000-0000-0000-000000001205',NULL,
            '10000000-0000-0000-0000-000000001205',NULL,0,NULL
        );
        RAISE EXCEPTION 'a null action must be rejected' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;

    PERFORM pg_catalog.set_config('request.jwt.claim.sub','',TRUE);
    BEGIN
        PERFORM public.apply_subcategory_change(
            '30000000-0000-0000-0000-000000001206','create',
            '10000000-0000-0000-0000-000000001206',second_cat,0,'Sem sessão'
        );
        RAISE EXCEPTION 'unauthenticated subcategory operations must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN invalid_authorization_specification THEN
        NULL;
    END;

    PERFORM pg_catalog.set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',TRUE);
    BEGIN
        INSERT INTO public.subcategories(owner_id,id,category_id,name)
        VALUES(auth.uid(),'10000000-0000-0000-0000-000000001207',second_cat,'DML direto');
        RAISE EXCEPTION 'direct subcategory writes must fail' USING ERRCODE = 'P0001';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END;
$test$;
ROLLBACK;
\echo 'PASS: subcategory lifecycle, permissions, ownership, idempotency, version conflict and audit.'
