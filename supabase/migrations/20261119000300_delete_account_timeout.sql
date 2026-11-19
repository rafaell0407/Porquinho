-- T12 (19/11/2026): excluir a conta com muito dado estourava o tempo do
-- servidor. Na homologação, 100 mil lançamentos (com a auditoria e os itens de
-- importação que vêm junto) passaram dos 8 s do papel `authenticated`
-- (`57014`, statement timeout); no Supabase local o mesmo volume leva 0,8 s.
-- A exclusão é uma operação única e rara, então a função ganha o seu próprio
-- limite (verificado no Supabase local: o `SET` da função vale também para a
-- chamada pelo PostgREST). Quem refizer a função com CREATE OR REPLACE deve
-- repetir o `SET`; o teste `rpc_delete_my_account_test.sql` confere.
-- Migrations anteriores não mudam.
BEGIN;

ALTER FUNCTION public.delete_my_account(TEXT) SET statement_timeout = '120s';

COMMIT;
