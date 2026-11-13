-- Reestruturação de períodos, Entrega P7 (13/11/2026): limpeza. Desde a P6 o
-- app e o servidor não gravam nem leem períodos (são calculados a partir de
-- period_settings) e os totais somam por data (get_range_report). Remove:
--  * as RPCs de período e o relatório pelo vínculo;
--  * o vínculo do lançamento com o período (accounting_period_id e
--    scheduled_period_id), com seus índices e chaves estrangeiras;
--  * as tabelas accounting_periods e period_configurations.
-- Conflitos abertos de período/configuração antiga deixam de ter objeto e são
-- encerrados, com o motivo registrado. Migrations anteriores não mudam.
BEGIN;

DROP FUNCTION public.create_accounting_period(UUID, UUID, UUID, DATE, TEXT, SMALLINT);
DROP FUNCTION public.create_earlier_accounting_period(UUID, UUID, DATE);
DROP FUNCTION public.schedule_period_configuration(UUID, TEXT, UUID, BIGINT, DATE, TEXT, SMALLINT);
DROP FUNCTION public.get_period_report(UUID[]);

-- Vínculo com o período: sai das três tabelas de lançamento. As restrições
-- que citavam scheduled_period_id saem junto; a regra continua sem ele.
ALTER TABLE public.income_entries
    DROP COLUMN accounting_period_id,
    DROP COLUMN scheduled_period_id;
ALTER TABLE public.income_entries ADD CONSTRAINT income_entries_occurrence_check CHECK (
    (recurrence_template_id IS NULL AND scheduled_for_date IS NULL)
    OR (recurrence_template_id IS NOT NULL AND scheduled_for_date IS NOT NULL)
);

ALTER TABLE public.expense_entries
    DROP COLUMN accounting_period_id,
    DROP COLUMN scheduled_period_id;
ALTER TABLE public.expense_entries ADD CONSTRAINT expense_entries_occurrence_check CHECK (
    (recurrence_template_id IS NULL AND scheduled_for_date IS NULL)
    OR (recurrence_template_id IS NOT NULL AND scheduled_for_date IS NOT NULL)
);

ALTER TABLE public.investment_allocations
    DROP COLUMN accounting_period_id,
    DROP COLUMN scheduled_period_id;
ALTER TABLE public.investment_allocations ADD CONSTRAINT investment_allocations_occurrence_check CHECK (
    (recurrence_template_id IS NULL AND scheduled_for_date IS NULL)
    OR (recurrence_template_id IS NOT NULL AND scheduled_for_date IS NOT NULL)
);

-- Os índices por data (owner_id + data de competência) já existem desde a
-- P3 (20261113000400); os índices pelo vínculo saem com as colunas.

DROP TABLE public.accounting_periods;
DROP TABLE public.period_configurations;

-- Conflitos de objetos que não existem mais: encerrados (histórico mantido).
UPDATE public.sync_conflicts c
SET status = 'resolved',
    resolution_payload = pg_catalog.jsonb_build_object(
        'resolution', 'obsolete',
        'reason', 'stored periods removed (P7, 13/11/2026)'),
    resolved_at = pg_catalog.clock_timestamp(),
    version = c.version + 1,
    updated_at = pg_catalog.clock_timestamp()
WHERE c.status = 'open'
  AND c.entity_type IN ('accounting_period', 'period_configuration');

-- Excluir conta: sem as tabelas de período.
CREATE OR REPLACE FUNCTION public.delete_my_account(p_confirmation TEXT)
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
    DELETE FROM public.period_settings WHERE owner_id = v_owner_id;
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

COMMIT;
