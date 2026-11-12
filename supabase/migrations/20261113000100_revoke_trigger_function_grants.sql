-- Entrega 72: no Supabase, funções novas em public recebem EXECUTE para anon e
-- authenticated por privilégio padrão. As duas funções de gatilho não são
-- chamadas pela API; remove a permissão para que nenhuma função de public
-- fique acessível a anon (verificado por supabase/tests/security_catalog_test.sql).
REVOKE ALL ON FUNCTION public.prevent_category_kind_change()
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validate_category_assignment()
    FROM PUBLIC, anon, authenticated;
