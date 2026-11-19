-- D15 (18/11/2026): retenção de 12 meses (RN029 e RN030).
--
-- O lançamento cancelado ("Apagar" na interface) fica guardado, invisível,
-- por 12 meses contados da última alteração (`updated_at`) e depois é
-- apagado fisicamente. Ficam de fora, até deixarem de se encaixar:
--   - ocorrências de recorrência (têm `recurrence_template_id`): o gerador
--     preenche os meses vazios desde o início do modelo, então apagar a
--     ocorrência cancelada faria o mês voltar;
--   - registros com conflito de sincronização em aberto.
-- A auditoria, os conflitos já resolvidos e o conteúdo das respostas
-- guardadas de operações também seguem os 12 meses. A chave da operação
-- fica: um reenvio antigo passa a ser recusado (conteúdo diferente), nunca
-- reaplicado.
--
-- A mesma regra roda no aparelho (lib/core/domain/retention.dart).
-- Nenhum total muda: o cancelado já não conta.

-- p_now: instante de referência (padrão: agora). p_owner: só esta conta
-- (padrão: todas; usado em testes, para não tocar nas demais contas).
CREATE FUNCTION public.purge_expired_records(
    p_now TIMESTAMPTZ DEFAULT NULL,
    p_owner UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_now TIMESTAMPTZ := COALESCE(p_now, pg_catalog.clock_timestamp());
    v_cutoff TIMESTAMPTZ := v_now - INTERVAL '12 months';
    v_income BIGINT;
    v_expense BIGINT;
    v_investment BIGINT;
    v_audit BIGINT;
    v_conflicts BIGINT;
    v_operations BIGINT;
BEGIN
    DELETE FROM public.income_entries e
    WHERE (p_owner IS NULL OR e.owner_id = p_owner)
      AND e.status = 'cancelled'
      AND e.recurrence_template_id IS NULL
      AND e.updated_at < v_cutoff
      AND NOT EXISTS (
          SELECT 1 FROM public.sync_conflicts c
          WHERE c.owner_id = e.owner_id AND c.entity_type = 'income_entry'
            AND c.entity_id = e.id AND c.status = 'open');
    GET DIAGNOSTICS v_income = ROW_COUNT;

    DELETE FROM public.expense_entries e
    WHERE (p_owner IS NULL OR e.owner_id = p_owner)
      AND e.status = 'cancelled'
      AND e.recurrence_template_id IS NULL
      AND e.updated_at < v_cutoff
      AND NOT EXISTS (
          SELECT 1 FROM public.sync_conflicts c
          WHERE c.owner_id = e.owner_id AND c.entity_type = 'expense_entry'
            AND c.entity_id = e.id AND c.status = 'open');
    GET DIAGNOSTICS v_expense = ROW_COUNT;

    DELETE FROM public.investment_allocations a
    WHERE (p_owner IS NULL OR a.owner_id = p_owner)
      AND a.cancelled_at IS NOT NULL
      AND a.recurrence_template_id IS NULL
      AND a.updated_at < v_cutoff
      AND NOT EXISTS (
          SELECT 1 FROM public.sync_conflicts c
          WHERE c.owner_id = a.owner_id AND c.entity_type = 'investment_allocation'
            AND c.entity_id = a.id AND c.status = 'open');
    GET DIAGNOSTICS v_investment = ROW_COUNT;

    DELETE FROM public.audit_events a
    WHERE (p_owner IS NULL OR a.owner_id = p_owner) AND a.occurred_at < v_cutoff;
    GET DIAGNOSTICS v_audit = ROW_COUNT;

    DELETE FROM public.sync_conflicts c
    WHERE (p_owner IS NULL OR c.owner_id = p_owner)
      AND c.status = 'resolved' AND c.resolved_at < v_cutoff;
    GET DIAGNOSTICS v_conflicts = ROW_COUNT;

    UPDATE public.applied_sync_operations op
    SET result_payload = '{"expired": true}'::JSONB
    WHERE (p_owner IS NULL OR op.owner_id = p_owner)
      AND op.applied_at < v_cutoff
      AND op.result_payload IS DISTINCT FROM '{"expired": true}'::JSONB;
    GET DIAGNOSTICS v_operations = ROW_COUNT;

    RETURN pg_catalog.jsonb_build_object(
        'cutoff', v_cutoff,
        'income_entries', v_income,
        'expense_entries', v_expense,
        'investment_allocations', v_investment,
        'audit_events', v_audit,
        'sync_conflicts', v_conflicts,
        'applied_sync_operations', v_operations);
END;
$function$;

ALTER FUNCTION public.purge_expired_records(TIMESTAMPTZ, UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.purge_expired_records(TIMESTAMPTZ, UUID) FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.purge_expired_records(TIMESTAMPTZ, UUID)
    IS 'D15 retention: physically removes cancelled one-time entries, audit events, resolved conflicts and stored operation responses older than 12 months. Internal (scheduled job); no client access.';

-- Agendamento diário (03:17 em Brasília) quando o banco tem o pg_cron
-- (Supabase local e hospedado). Sem a extensão (cluster de teste), segue sem
-- agendar; a função continua disponível para chamada manual.
DO $schedule$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_available_extensions WHERE name = 'pg_cron') THEN
        BEGIN
            CREATE EXTENSION IF NOT EXISTS pg_cron;
            EXECUTE pg_catalog.format(
                'SELECT cron.schedule(%L, %L, %L)',
                'norte-retencao-12-meses', '17 6 * * *',
                'SELECT public.purge_expired_records()');
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'pg_cron indisponível; limpeza de retenção não agendada: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'pg_cron ausente; limpeza de retenção não agendada.';
    END IF;
END;
$schedule$;
