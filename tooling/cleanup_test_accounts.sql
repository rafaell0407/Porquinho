-- Plano B de tooling/cleanup_test_accounts.ps1: apaga as contas de teste de
-- integração (it-N, f4-N e f5-N @teste.local) e todos os dados delas pela
-- própria delete_my_account, como superusuário (sem o limite de tempo das
-- chamadas do app). Só homologação ou local; NUNCA produção.
-- Uso: colar no SQL Editor do projeto norte-homologacao e rodar até a coluna
-- "restam" mostrar 0. Cada rodada apaga até 20 contas. (O SQL Editor não mostra
-- o aviso do bloco; a contagem vem da consulta do fim.)
DO $cleanup$
DECLARE
    v_user RECORD;
    v_done INTEGER := 0;
    v_left INTEGER;
BEGIN
    FOR v_user IN
        SELECT u.id FROM auth.users u
        WHERE u.email ~ '^(it|f4|f5)-[0-9]+@teste\.local$'
        ORDER BY u.created_at
        LIMIT 20
    LOOP
        PERFORM pg_catalog.set_config('request.jwt.claim.sub', v_user.id::TEXT, TRUE);
        PERFORM public.delete_my_account('DELETE_MY_ACCOUNT');
        v_done := v_done + 1;
    END LOOP;
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '', TRUE);
    SELECT pg_catalog.count(*) INTO v_left FROM auth.users u
    WHERE u.email ~ '^(it|f4|f5)-[0-9]+@teste\.local$';
    RAISE NOTICE 'Contas de teste apagadas: %; restam %', v_done, v_left;
END;
$cleanup$;

SELECT pg_catalog.count(*) AS restam
FROM auth.users u
WHERE u.email ~ '^(it|f4|f5)-[0-9]+@teste\.local$';
