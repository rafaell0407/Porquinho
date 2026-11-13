-- Reestruturação de períodos, Entrega P3 (13/11/2026): leitura agregada por
-- INTERVALO DE DATAS, não mais por accounting_period_id. O app manda os
-- intervalos [início, fim) dos períodos que quer ver (RN036) e o servidor soma
-- os lançamentos cuja data de competência está dentro de cada um (RN004):
--   receita       = received_on,   status 'received' com valor;
--   despesa       = competence_on, status 'pending' ou 'paid' com valor;
--   investimento  = allocated_on,  não cancelado.
-- Mesmas regras do dinheiro livre (surplus.dart) e de get_period_report, que
-- continua existindo até a limpeza (P7) para a rede de segurança (P4).
-- Somas em NUMERIC (exatas) devolvidas como TEXTO. Cada intervalo é
-- identificado pela posição no pedido ("index", começando em 1).
BEGIN;

CREATE INDEX income_entries_owner_received_idx
    ON public.income_entries (owner_id, received_on);
CREATE INDEX expense_entries_owner_competence_idx
    ON public.expense_entries (owner_id, competence_on);
CREATE INDEX investment_allocations_owner_allocated_idx
    ON public.investment_allocations (owner_id, allocated_on);

CREATE FUNCTION public.get_range_report(p_starts DATE[], p_ends DATE[])
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
    IF p_starts IS NULL OR p_ends IS NULL THEN
        RAISE EXCEPTION 'range starts and ends are required'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF pg_catalog.cardinality(p_starts) <> pg_catalog.cardinality(p_ends) THEN
        RAISE EXCEPTION 'range starts and ends must have the same length'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF pg_catalog.cardinality(p_starts) > 60 THEN
        RAISE EXCEPTION 'too many ranges requested'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM unnest(p_starts, p_ends) AS r(start_date, end_date)
        WHERE r.start_date IS NULL OR r.end_date IS NULL
           OR r.end_date <= r.start_date
    ) THEN
        RAISE EXCEPTION 'each range must have a start before its end'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    WITH wanted AS (
        SELECT r.idx::INTEGER AS idx, r.start_date, r.end_date
        FROM unnest(p_starts, p_ends) WITH ORDINALITY
            AS r(start_date, end_date, idx)
    ),
    income AS (
        SELECT wanted.idx,
               entry.category_id,
               SUM(entry.amount_centavos)::NUMERIC AS amount
        FROM wanted
        JOIN public.income_entries AS entry
          ON entry.owner_id = v_owner_id
         AND entry.received_on >= wanted.start_date
         AND entry.received_on < wanted.end_date
        WHERE entry.status = 'received'
          AND entry.amount_centavos IS NOT NULL
        GROUP BY wanted.idx, entry.category_id
    ),
    expense AS (
        SELECT wanted.idx,
               entry.category_id,
               SUM(entry.amount_centavos)::NUMERIC AS amount
        FROM wanted
        JOIN public.expense_entries AS entry
          ON entry.owner_id = v_owner_id
         AND entry.competence_on >= wanted.start_date
         AND entry.competence_on < wanted.end_date
        WHERE entry.status IN ('pending', 'paid')
          AND entry.amount_centavos IS NOT NULL
        GROUP BY wanted.idx, entry.category_id
    ),
    investment AS (
        SELECT wanted.idx,
               SUM(allocation.amount_centavos)::NUMERIC AS amount
        FROM wanted
        JOIN public.investment_allocations AS allocation
          ON allocation.owner_id = v_owner_id
         AND allocation.allocated_on >= wanted.start_date
         AND allocation.allocated_on < wanted.end_date
        WHERE allocation.cancelled_at IS NULL
        GROUP BY wanted.idx
    )
    SELECT pg_catalog.jsonb_build_object(
        'ranges',
        COALESCE((
            SELECT pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                    'index', wanted.idx,
                    'start', wanted.start_date,
                    'end', wanted.end_date,
                    'income', COALESCE((
                        SELECT SUM(i.amount) FROM income AS i
                        WHERE i.idx = wanted.idx), 0)::TEXT,
                    'expense', COALESCE((
                        SELECT SUM(e.amount) FROM expense AS e
                        WHERE e.idx = wanted.idx), 0)::TEXT,
                    'investment', COALESCE((
                        SELECT v.amount FROM investment AS v
                        WHERE v.idx = wanted.idx), 0)::TEXT
                )
                ORDER BY wanted.idx
            )
            FROM wanted
        ), '[]'::JSONB),
        'income_by_category',
        COALESCE((
            SELECT pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                    'index', i.idx,
                    'category_id', i.category_id,
                    'amount', i.amount::TEXT
                )
                ORDER BY i.idx, i.category_id
            )
            FROM income AS i
        ), '[]'::JSONB),
        'expense_by_category',
        COALESCE((
            SELECT pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                    'index', e.idx,
                    'category_id', e.category_id,
                    'amount', e.amount::TEXT
                )
                ORDER BY e.idx, e.category_id
            )
            FROM expense AS e
        ), '[]'::JSONB)
    )
    INTO v_result;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_range_report(DATE[], DATE[])
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_range_report(DATE[], DATE[])
    TO authenticated;

COMMENT ON FUNCTION public.get_range_report(DATE[], DATE[])
    IS 'Read-only totals per date range [start, end) and per category for the authenticated user, by competence date, summed exactly and returned as text.';

COMMIT;
