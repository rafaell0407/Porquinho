-- Entrega 73 (Fase 8, decisão D3): exclusão definitiva e imediata da conta pelo
-- próprio usuário. Apaga todos os dados financeiros do dono na ordem segura
-- (as chaves estrangeiras são RESTRICT) e depois o usuário do Supabase Auth.
-- Guarda só o id e a data da exclusão em `deleted_accounts`, para que uma
-- restauração de backup não ressuscite a conta (roteiro em docs/entregas_fase8.md).
BEGIN;

CREATE TABLE public.deleted_accounts (
    owner_id UUID PRIMARY KEY,
    deleted_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

ALTER TABLE public.deleted_accounts ENABLE ROW LEVEL SECURITY;
-- Ninguém lê nem escreve pela API; só a função abaixo (dona da tabela).
CREATE POLICY deleted_accounts_no_access ON public.deleted_accounts
    FOR SELECT TO authenticated USING (FALSE);
REVOKE ALL PRIVILEGES ON TABLE public.deleted_accounts
    FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.delete_my_account(p_confirmation TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_owner_id UUID;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_confirmation IS DISTINCT FROM 'DELETE_MY_ACCOUNT' THEN
        RAISE EXCEPTION 'explicit confirmation is required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    DELETE FROM public.income_entries WHERE owner_id = v_owner_id;
    DELETE FROM public.expense_entries WHERE owner_id = v_owner_id;
    DELETE FROM public.investment_allocations WHERE owner_id = v_owner_id;
    DELETE FROM public.income_recurrence_templates WHERE owner_id = v_owner_id;
    DELETE FROM public.expense_recurrence_templates WHERE owner_id = v_owner_id;
    DELETE FROM public.investment_recurrence_templates WHERE owner_id = v_owner_id;
    DELETE FROM public.accounting_periods WHERE owner_id = v_owner_id;
    DELETE FROM public.period_configurations WHERE owner_id = v_owner_id;
    DELETE FROM public.subcategories WHERE owner_id = v_owner_id;
    DELETE FROM public.categories WHERE owner_id = v_owner_id;
    DELETE FROM public.sync_conflicts WHERE owner_id = v_owner_id;
    DELETE FROM public.applied_sync_operations WHERE owner_id = v_owner_id;
    DELETE FROM public.audit_events
     WHERE owner_id = v_owner_id OR actor_id = v_owner_id;
    DELETE FROM public.user_preferences WHERE owner_id = v_owner_id;

    INSERT INTO public.deleted_accounts (owner_id) VALUES (v_owner_id)
    ON CONFLICT (owner_id) DO NOTHING;
    DELETE FROM auth.users WHERE id = v_owner_id;

    RETURN pg_catalog.jsonb_build_object(
        'status', 'deleted',
        'owner_id', v_owner_id
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.delete_my_account(TEXT)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account(TEXT) TO authenticated;

COMMIT;
