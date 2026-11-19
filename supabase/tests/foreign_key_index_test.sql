\set ON_ERROR_STOP on

-- T10 (19/11/2026): toda chave estrangeira de public para auth.users tem um
-- índice que começa pela sua coluna. Sem isso, apagar um usuário (exclusão
-- de conta) varre a tabela inteira e pode estourar o tempo do servidor.
DO $test$
DECLARE
    offender TEXT;
BEGIN
    SELECT pg_catalog.string_agg(t.relname || '.' || a.attname, ', ')
      INTO offender
      FROM pg_catalog.pg_constraint AS c
      JOIN pg_catalog.pg_class AS t ON t.oid = c.conrelid
      JOIN pg_catalog.pg_namespace AS n ON n.oid = t.relnamespace
      JOIN pg_catalog.pg_attribute AS a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
     WHERE c.contype = 'f' AND c.confrelid = 'auth.users'::regclass AND n.nspname = 'public'
       AND NOT EXISTS (
           SELECT 1 FROM pg_catalog.pg_index AS i
            WHERE i.indrelid = c.conrelid AND i.indkey[0] = c.conkey[1]
       );
    IF offender IS NOT NULL THEN
        RAISE EXCEPTION 'chaves estrangeiras para auth.users sem índice: %', offender;
    END IF;
END;
$test$;

SELECT 'FOREIGN_KEY_INDEX_OK' AS result;
