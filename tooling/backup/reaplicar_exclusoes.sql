-- Entrega 77: depois de restaurar um backup, apaga de novo as contas que o
-- usuário excluiu DEPOIS da data do backup, para a restauração não ressuscitá-las.
-- Pré-requisito: a tabela public.deleted_accounts já contém os ids a apagar
-- (os do backup + os importados do banco vivo; ver docs/backup.md).
-- Roda como superusuário, pela própria delete_my_account (mesma ordem segura).
-- Idempotente: pode rodar de novo; só mexe em quem ainda existe em auth.users.
DO $reaplicar$
DECLARE
    v_id UUID;
    v_done INTEGER := 0;
BEGIN
    FOR v_id IN
        SELECT d.owner_id FROM public.deleted_accounts d
        WHERE EXISTS (SELECT 1 FROM auth.users u WHERE u.id = d.owner_id)
        ORDER BY d.deleted_at
    LOOP
        PERFORM pg_catalog.set_config('request.jwt.claim.sub', v_id::TEXT, TRUE);
        PERFORM public.delete_my_account('DELETE_MY_ACCOUNT');
        v_done := v_done + 1;
    END LOOP;
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '', TRUE);
    RAISE NOTICE 'Contas apagadas de novo: %', v_done;
END;
$reaplicar$;

SELECT pg_catalog.count(*) AS ressuscitadas_restantes
FROM public.deleted_accounts d
JOIN auth.users u ON u.id = d.owner_id;
