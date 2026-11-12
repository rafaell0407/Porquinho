\set ON_ERROR_STOP on

-- Entrega 73: exclusão definitiva da conta. Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES
    ('30000000-0000-0000-0000-000000000001'),
    ('30000000-0000-0000-0000-000000000002');

SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    a CONSTANT UUID := '30000000-0000-0000-0000-000000000001';
    b CONSTANT UUID := '30000000-0000-0000-0000-000000000002';
    response JSONB;
    remaining BIGINT;
BEGIN
    -- Cada usuário cria uma categoria.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', a::TEXT, TRUE);
    PERFORM public.apply_category_change(
        '31000000-0000-0000-0000-000000000001', 'create',
        '32000000-0000-0000-0000-000000000001', 0, 'expense', 'Da A');
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', b::TEXT, TRUE);
    PERFORM public.apply_category_change(
        '31000000-0000-0000-0000-000000000002', 'create',
        '32000000-0000-0000-0000-000000000002', 0, 'expense', 'Da B');

    -- Sem confirmação explícita: recusado e nada some.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', a::TEXT, TRUE);
    BEGIN
        PERFORM public.delete_my_account('talvez');
        RAISE EXCEPTION 'confirmation must be required';
    EXCEPTION WHEN invalid_parameter_value THEN
        NULL;
    END;
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE owner_id = a) THEN
        RAISE EXCEPTION 'data must survive a refused deletion';
    END IF;

    -- Sem login: recusado.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '', TRUE);
    BEGIN
        PERFORM public.delete_my_account('DELETE_MY_ACCOUNT');
        RAISE EXCEPTION 'authentication must be required';
    EXCEPTION WHEN invalid_authorization_specification THEN
        NULL;
    END;

    -- A exclui a própria conta.
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', a::TEXT, TRUE);
    response := public.delete_my_account('DELETE_MY_ACCOUNT');
    IF response ->> 'status' <> 'deleted' THEN
        RAISE EXCEPTION 'unexpected response %', response;
    END IF;
END;
$test$;

RESET ROLE;

DO $test$
DECLARE
    a CONSTANT UUID := '30000000-0000-0000-0000-000000000001';
    b CONSTANT UUID := '30000000-0000-0000-0000-000000000002';
BEGIN
    IF EXISTS (SELECT 1 FROM public.categories WHERE owner_id = a)
       OR EXISTS (SELECT 1 FROM public.audit_events WHERE owner_id = a)
       OR EXISTS (SELECT 1 FROM public.applied_sync_operations WHERE owner_id = a)
       OR EXISTS (SELECT 1 FROM auth.users WHERE id = a) THEN
        RAISE EXCEPTION 'account A data must be gone';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.deleted_accounts WHERE owner_id = a) THEN
        RAISE EXCEPTION 'deleted account must be registered';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE owner_id = b)
       OR NOT EXISTS (SELECT 1 FROM public.audit_events WHERE owner_id = b)
       OR NOT EXISTS (SELECT 1 FROM auth.users WHERE id = b) THEN
        RAISE EXCEPTION 'account B must be untouched';
    END IF;
    IF pg_catalog.has_function_privilege(
        'anon', 'public.delete_my_account(text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'anon must not execute delete_my_account';
    END IF;
END;
$test$;

ROLLBACK;

SELECT 'DELETE_MY_ACCOUNT_OK' AS result;
