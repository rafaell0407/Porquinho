-- Entrega 62 (Fase 7, decisão D11): leitura agregada para o Dashboard e os
-- relatórios da Web. Somente leitura, isolada por usuário (auth.uid()), com as
-- mesmas regras do dinheiro livre (surplus.dart):
--   receita contabilizada  = status 'received' com valor;
--   despesa contabilizada  = status 'pending' ou 'paid' com valor;
--   investimento           = não cancelado.
-- Somas em NUMERIC (exatas) e devolvidas como TEXTO, para não perder
-- precisão no JSON. Agrupa sempre por accounting_period_id, nunca por data.
BEGIN;

CREATE FUNCTION public.get_period_report(p_period_ids UUID[])
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
    v_owner_id UUID;
    v_result JSONB;
BEGIN
    v_owner_id := auth.uid();
    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication is required'
            USING ERRCODE = 'invalid_authorization_specification';
    END IF;
    IF p_period_ids IS NULL THEN
        RAISE EXCEPTION 'period ids are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF pg_catalog.cardinality(p_period_ids) > 60 THEN
        RAISE EXCEPTION 'too many periods requested'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    WITH wanted AS (
        SELECT DISTINCT period.id
        FROM public.accounting_periods AS period
        WHERE period.owner_id = v_owner_id
          AND period.id = ANY (p_period_ids)
    ),
    income AS (
        SELECT entry.accounting_period_id AS period_id,
               entry.category_id,
               SUM(entry.amount_centavos)::NUMERIC AS amount
        FROM public.income_entries AS entry
        WHERE entry.owner_id = v_owner_id
          AND entry.accounting_period_id IN (SELECT id FROM wanted)
          AND entry.status = 'received'
          AND entry.amount_centavos IS NOT NULL
        GROUP BY entry.accounting_period_id, entry.category_id
    ),
    expense AS (
        SELECT entry.accounting_period_id AS period_id,
               entry.category_id,
               SUM(entry.amount_centavos)::NUMERIC AS amount
        FROM public.expense_entries AS entry
        WHERE entry.owner_id = v_owner_id
          AND entry.accounting_period_id IN (SELECT id FROM wanted)
          AND entry.status IN ('pending', 'paid')
          AND entry.amount_centavos IS NOT NULL
        GROUP BY entry.accounting_period_id, entry.category_id
    ),
    investment AS (
        SELECT allocation.accounting_period_id AS period_id,
               SUM(allocation.amount_centavos)::NUMERIC AS amount
        FROM public.investment_allocations AS allocation
        WHERE allocation.owner_id = v_owner_id
          AND allocation.accounting_period_id IN (SELECT id FROM wanted)
          AND allocation.cancelled_at IS NULL
        GROUP BY allocation.accounting_period_id
    )
    SELECT pg_catalog.jsonb_build_object(
        'periods',
        COALESCE((
            SELECT pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                    'period_id', wanted.id,
                    'income', COALESCE((
                        SELECT SUM(i.amount) FROM income AS i
                        WHERE i.period_id = wanted.id), 0)::TEXT,
                    'expense', COALESCE((
                        SELECT SUM(e.amount) FROM expense AS e
                        WHERE e.period_id = wanted.id), 0)::TEXT,
                    'investment', COALESCE((
                        SELECT v.amount FROM investment AS v
                        WHERE v.period_id = wanted.id), 0)::TEXT
                )
                ORDER BY wanted.id
            )
            FROM wanted
        ), '[]'::JSONB),
        'income_by_category',
        COALESCE((
            SELECT pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                    'period_id', i.period_id,
                    'category_id', i.category_id,
                    'amount', i.amount::TEXT
                )
                ORDER BY i.period_id, i.category_id
            )
            FROM income AS i
        ), '[]'::JSONB),
        'expense_by_category',
        COALESCE((
            SELECT pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                    'period_id', e.period_id,
                    'category_id', e.category_id,
                    'amount', e.amount::TEXT
                )
                ORDER BY e.period_id, e.category_id
            )
            FROM expense AS e
        ), '[]'::JSONB)
    )
    INTO v_result;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_period_report(UUID[])
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_period_report(UUID[])
    TO authenticated;

COMMENT ON FUNCTION public.get_period_report(UUID[])
    IS 'Read-only totals per period and per category for the authenticated user, summed exactly and returned as text.';

COMMIT;
