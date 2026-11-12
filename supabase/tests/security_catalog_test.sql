\set ON_ERROR_STOP on

-- Entrega 72: teste de catálogo do schema public. Não depende de dados; vale
-- para o cluster de teste, o Supabase local e (via psql) os ambientes
-- hospedados. Qualquer violação interrompe a suíte.
DO $test$
DECLARE
    offender TEXT;
BEGIN
    -- 1. Toda tabela de public tem RLS ativa.
    SELECT pg_catalog.string_agg(c.relname, ', ')
      INTO offender
      FROM pg_catalog.pg_class AS c
      JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
       AND NOT c.relrowsecurity;
    IF offender IS NOT NULL THEN
        RAISE EXCEPTION 'tabelas sem RLS: %', offender;
    END IF;

    -- 2. Toda tabela de public tem ao menos uma política de leitura própria.
    SELECT pg_catalog.string_agg(c.relname, ', ')
      INTO offender
      FROM pg_catalog.pg_class AS c
      JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
       AND NOT EXISTS (
           SELECT 1 FROM pg_catalog.pg_policies AS p
            WHERE p.schemaname = 'public' AND p.tablename = c.relname
       );
    IF offender IS NOT NULL THEN
        RAISE EXCEPTION 'tabelas sem política: %', offender;
    END IF;

    -- 3. Nenhuma tabela aceita escrita direta de authenticated, anon ou PUBLIC
    --    (toda escrita passa pelas RPCs).
    SELECT pg_catalog.string_agg(c.relname || ':' || r.rolname || ':' || p.priv, ', ')
      INTO offender
      FROM pg_catalog.pg_class AS c
      JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
      CROSS JOIN (VALUES ('anon'), ('authenticated')) AS r (rolname)
      CROSS JOIN (VALUES ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'),
                         ('REFERENCES'), ('TRIGGER')) AS p (priv)
     WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
       AND pg_catalog.has_table_privilege(r.rolname, c.oid, p.priv);
    IF offender IS NOT NULL THEN
        RAISE EXCEPTION 'escrita direta permitida: %', offender;
    END IF;

    -- 4. anon não lê nenhuma tabela.
    SELECT pg_catalog.string_agg(c.relname, ', ')
      INTO offender
      FROM pg_catalog.pg_class AS c
      JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
       AND pg_catalog.has_table_privilege('anon', c.oid, 'SELECT');
    IF offender IS NOT NULL THEN
        RAISE EXCEPTION 'anon lê tabelas: %', offender;
    END IF;

    -- 5. Nenhuma função de public pode ser executada por anon (nem por PUBLIC).
    SELECT pg_catalog.string_agg(f.proname, ', ')
      INTO offender
      FROM pg_catalog.pg_proc AS f
      JOIN pg_catalog.pg_namespace AS n ON n.oid = f.pronamespace
     WHERE n.nspname = 'public'
       AND pg_catalog.has_function_privilege('anon', f.oid, 'EXECUTE');
    IF offender IS NOT NULL THEN
        RAISE EXCEPTION 'anon executa funções: %', offender;
    END IF;

    -- 6. Funções SECURITY DEFINER fixam search_path vazio.
    SELECT pg_catalog.string_agg(f.proname, ', ')
      INTO offender
      FROM pg_catalog.pg_proc AS f
      JOIN pg_catalog.pg_namespace AS n ON n.oid = f.pronamespace
     WHERE n.nspname = 'public' AND f.prosecdef
       AND NOT (COALESCE(f.proconfig, ARRAY[]::TEXT[])
                @> ARRAY['search_path=""']);
    IF offender IS NOT NULL THEN
        RAISE EXCEPTION 'SECURITY DEFINER sem search_path vazio: %', offender;
    END IF;

    -- 7. Ninguém cria objetos em public.
    IF pg_catalog.has_schema_privilege('anon', 'public', 'CREATE')
       OR pg_catalog.has_schema_privilege('authenticated', 'public', 'CREATE') THEN
        RAISE EXCEPTION 'anon/authenticated podem criar objetos em public';
    END IF;
END;
$test$;

SELECT 'SECURITY_CATALOG_OK' AS result;
