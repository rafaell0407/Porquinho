-- Apagar todos os lançamentos (RF031, RN056; AT1, 19/11/2026).
--  * wipe_entries_preview(): só leitura. Conta o que será apagado (receitas,
--    despesas e investimentos não cancelados e modelos de recorrência ativos),
--    os conflitos em aberto e devolve o instante de corte (`as_of`).
--  * wipe_entries_run(p_operation_id, p_as_of, p_limit): em partes, repetível.
--    Desativa primeiro os modelos de recorrência (para não gerar mais nada) e
--    depois cancela os lançamentos, cada um pela RPC de sempre (versão,
--    auditoria, repetição segura), com operação derivada de
--    (operação|wipe|tipo|id). Só alcança o que existia até `p_as_of`.
--  * Nada é apagado na hora: o cancelado segue a retenção da RN029.
--  * Recusa (`blocked`) enquanto houver conflito de sincronização aberto.
-- Migrations anteriores não mudam.
BEGIN;

-- Alvos pendentes, na ordem: modelos (1) e lançamentos (2).
CREATE FUNCTION public.wipe_entries_targets(p_owner UUID, p_as_of TIMESTAMPTZ)
RETURNS TABLE (step INTEGER, entity_type TEXT, entity_id UUID, recurring BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
    SELECT 1, 'income_recurrence_template', t.id, FALSE
    FROM public.income_recurrence_templates t
    WHERE t.owner_id = p_owner AND t.is_active AND t.created_at <= p_as_of
    UNION ALL
    SELECT 1, 'expense_recurrence_template', t.id, FALSE
    FROM public.expense_recurrence_templates t
    WHERE t.owner_id = p_owner AND t.is_active AND t.created_at <= p_as_of
    UNION ALL
    SELECT 1, 'investment_recurrence_template', t.id, FALSE
    FROM public.investment_recurrence_templates t
    WHERE t.owner_id = p_owner AND t.is_active AND t.created_at <= p_as_of
    UNION ALL
    SELECT 2, 'income_entry', e.id, e.recurrence_template_id IS NOT NULL
    FROM public.income_entries e
    WHERE e.owner_id = p_owner AND e.status <> 'cancelled' AND e.created_at <= p_as_of
    UNION ALL
    SELECT 2, 'expense_entry', e.id, e.recurrence_template_id IS NOT NULL
    FROM public.expense_entries e
    WHERE e.owner_id = p_owner AND e.status <> 'cancelled' AND e.created_at <= p_as_of
    UNION ALL
    SELECT 2, 'investment_allocation', a.id, a.recurrence_template_id IS NOT NULL
    FROM public.investment_allocations a
    WHERE a.owner_id = p_owner AND a.cancelled_at IS NULL AND a.created_at <= p_as_of;
$function$;
ALTER FUNCTION public.wipe_entries_targets(UUID, TIMESTAMPTZ) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.wipe_entries_targets(UUID, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;

-- Contagens do que existe agora (prévia e resposta).
CREATE FUNCTION public.wipe_entries_counts(p_owner UUID, p_as_of TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
    SELECT pg_catalog.jsonb_build_object(
        'income', COUNT(*) FILTER (WHERE x.entity_type = 'income_entry'),
        'expense', COUNT(*) FILTER (WHERE x.entity_type = 'expense_entry'),
        'investment', COUNT(*) FILTER (WHERE x.entity_type = 'investment_allocation'),
        'templates', COUNT(*) FILTER (WHERE x.step = 1))
    FROM public.wipe_entries_targets(p_owner, p_as_of) x;
$function$;
ALTER FUNCTION public.wipe_entries_counts(UUID, TIMESTAMPTZ) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.wipe_entries_counts(UUID, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.wipe_entries_open_conflicts(p_owner UUID)
RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
    SELECT COUNT(*) FROM public.sync_conflicts c
    WHERE c.owner_id = p_owner AND c.status = 'open';
$function$;
ALTER FUNCTION public.wipe_entries_open_conflicts(UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.wipe_entries_open_conflicts(UUID) FROM PUBLIC, anon, authenticated;

-- Prévia: só leitura.
CREATE FUNCTION public.wipe_entries_preview()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_as_of TIMESTAMPTZ := pg_catalog.clock_timestamp();
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    RETURN public.wipe_entries_counts(v_owner, v_as_of)
        || pg_catalog.jsonb_build_object(
            'as_of', v_as_of,
            'open_conflicts', public.wipe_entries_open_conflicts(v_owner));
END;
$function$;
ALTER FUNCTION public.wipe_entries_preview() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.wipe_entries_preview() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.wipe_entries_preview() TO authenticated;
COMMENT ON FUNCTION public.wipe_entries_preview()
    IS 'Read-only preview of "delete all entries" (RN056): counts, open conflicts and the cut-off instant.';

-- Executa em partes (até p_limit chamadas); repetir com a mesma operação é
-- seguro. Resposta: status `running` (falta algo), `done` ou `blocked`.
CREATE FUNCTION public.wipe_entries_run(p_operation_id UUID, p_as_of TIMESTAMPTZ, p_limit INTEGER)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_owner UUID := auth.uid();
    v_item RECORD;
    v_version BIGINT;
    v_active BOOLEAN;
    v_op UUID;
    v_resp JSONB;
    v_calls INTEGER := 0;
    v_income INTEGER := 0;
    v_expense INTEGER := 0;
    v_investment INTEGER := 0;
    v_templates INTEGER := 0;
    v_remaining BOOLEAN := FALSE;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'authentication is required' USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_operation_id IS NULL OR p_as_of IS NULL OR p_limit IS NULL OR p_limit < 1 OR p_limit > 1000 THEN
        RAISE EXCEPTION 'operation, cut-off and a limit from 1 to 1000 are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_as_of > pg_catalog.clock_timestamp() + INTERVAL '1 minute' THEN
        RAISE EXCEPTION 'cut-off cannot be in the future' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- Uma execução por usuário de cada vez.
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::TEXT || '|wipe', 0));

    IF public.wipe_entries_open_conflicts(v_owner) > 0 THEN
        RETURN pg_catalog.jsonb_build_object('status', 'blocked', 'reason', 'open_conflicts',
            'open_conflicts', public.wipe_entries_open_conflicts(v_owner));
    END IF;

    FOR v_item IN
        SELECT * FROM public.wipe_entries_targets(v_owner, p_as_of) t
        ORDER BY t.step, t.entity_type, t.entity_id
    LOOP
        IF v_calls >= p_limit THEN
            v_remaining := TRUE;
            EXIT;
        END IF;

        -- Trava e confere de novo: outro aparelho pode ter mudado a linha.
        v_active := FALSE;
        CASE v_item.entity_type
            WHEN 'income_recurrence_template' THEN
                SELECT t.version, t.is_active INTO v_version, v_active
                FROM public.income_recurrence_templates t
                WHERE t.owner_id = v_owner AND t.id = v_item.entity_id FOR UPDATE;
            WHEN 'expense_recurrence_template' THEN
                SELECT t.version, t.is_active INTO v_version, v_active
                FROM public.expense_recurrence_templates t
                WHERE t.owner_id = v_owner AND t.id = v_item.entity_id FOR UPDATE;
            WHEN 'investment_recurrence_template' THEN
                SELECT t.version, t.is_active INTO v_version, v_active
                FROM public.investment_recurrence_templates t
                WHERE t.owner_id = v_owner AND t.id = v_item.entity_id FOR UPDATE;
            WHEN 'income_entry' THEN
                SELECT e.version, e.status <> 'cancelled' INTO v_version, v_active
                FROM public.income_entries e
                WHERE e.owner_id = v_owner AND e.id = v_item.entity_id FOR UPDATE;
            WHEN 'expense_entry' THEN
                SELECT e.version, e.status <> 'cancelled' INTO v_version, v_active
                FROM public.expense_entries e
                WHERE e.owner_id = v_owner AND e.id = v_item.entity_id FOR UPDATE;
            ELSE
                SELECT a.version, a.cancelled_at IS NULL INTO v_version, v_active
                FROM public.investment_allocations a
                WHERE a.owner_id = v_owner AND a.id = v_item.entity_id FOR UPDATE;
        END CASE;
        CONTINUE WHEN NOT COALESCE(v_active, FALSE);

        v_op := public.import_uuid(p_operation_id::TEXT || '|wipe|' || v_item.entity_type
            || '|' || v_item.entity_id::TEXT);
        v_resp := CASE
            WHEN v_item.entity_type = 'income_recurrence_template' THEN
                public.apply_income_recurrence_template_change(v_op, 'deactivate', v_item.entity_id, v_version, NULL)
            WHEN v_item.entity_type = 'expense_recurrence_template' THEN
                public.apply_expense_recurrence_template_change(v_op, 'deactivate', v_item.entity_id, v_version, NULL)
            WHEN v_item.entity_type = 'investment_recurrence_template' THEN
                public.apply_investment_recurrence_template_change(v_op, 'deactivate', v_item.entity_id, v_version, NULL)
            WHEN v_item.entity_type = 'income_entry' AND NOT v_item.recurring THEN
                public.apply_income_entry_change(v_op, 'cancel', v_item.entity_id, v_version, NULL)
            WHEN v_item.entity_type = 'income_entry' THEN
                public.apply_income_recurrence_occurrence_change(v_op, 'cancel', v_item.entity_id, v_version, NULL)
            WHEN v_item.entity_type = 'expense_entry' AND NOT v_item.recurring THEN
                public.apply_expense_entry_change(v_op, 'cancel', v_item.entity_id, v_version, NULL)
            WHEN v_item.entity_type = 'expense_entry' THEN
                public.apply_expense_recurrence_occurrence_change(v_op, 'cancel', v_item.entity_id, v_version, NULL)
            ELSE
                public.apply_investment_allocation_change(v_op, 'cancel', v_item.entity_id, v_version, NULL, NULL)
        END;
        -- Só 'applied' segue; qualquer outra resposta desfaz esta parte.
        PERFORM public.import_require_applied(v_resp, 'apagar ' || v_item.entity_type);
        v_calls := v_calls + 1;
        CASE v_item.entity_type
            WHEN 'income_entry' THEN v_income := v_income + 1;
            WHEN 'expense_entry' THEN v_expense := v_expense + 1;
            WHEN 'investment_allocation' THEN v_investment := v_investment + 1;
            ELSE v_templates := v_templates + 1;
        END CASE;
    END LOOP;

    IF NOT v_remaining THEN
        -- Registro único da operação inteira (repetir não duplica).
        INSERT INTO public.audit_events(owner_id, id, entity_type, entity_id, operation, actor_id,
            new_values, operation_id)
        VALUES (v_owner, public.import_uuid(p_operation_id::TEXT || '|wipe|summary'), 'entries_wipe',
            p_operation_id, 'wipe_all_entries', v_owner,
            pg_catalog.jsonb_build_object('as_of', p_as_of), p_operation_id)
        ON CONFLICT (owner_id, id) DO NOTHING;
    END IF;

    RETURN pg_catalog.jsonb_build_object(
        'status', CASE WHEN v_remaining THEN 'running' ELSE 'done' END,
        'remaining', v_remaining,
        'calls', v_calls,
        'cancelled', pg_catalog.jsonb_build_object('income', v_income, 'expense', v_expense,
            'investment', v_investment),
        'deactivated_templates', v_templates);
END;
$function$;
ALTER FUNCTION public.wipe_entries_run(UUID, TIMESTAMPTZ, INTEGER) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.wipe_entries_run(UUID, TIMESTAMPTZ, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.wipe_entries_run(UUID, TIMESTAMPTZ, INTEGER) TO authenticated;
COMMENT ON FUNCTION public.wipe_entries_run(UUID, TIMESTAMPTZ, INTEGER)
    IS 'Deletes (cancels) every entry and deactivates every recurrence template up to the cut-off, in parts (RN056).';

COMMIT;
