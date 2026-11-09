-- Local-only stand-in for the Supabase Auth objects used by schema tests.
-- This database is created empty by tooling/test_postgres_schema.ps1.
DO $block$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
END;
$block$;

CREATE SCHEMA auth;
CREATE TABLE auth.users (
    id UUID PRIMARY KEY
);

CREATE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE sql
STABLE
AS $function$
    SELECT NULLIF(pg_catalog.current_setting('request.jwt.claim.sub', TRUE), '')::UUID;
$function$;

GRANT USAGE ON SCHEMA auth TO anon, authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated;
