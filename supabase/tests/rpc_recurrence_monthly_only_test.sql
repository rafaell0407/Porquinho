\set ON_ERROR_STOP on

-- Reestruturação P5 (RN038, 13/11/2026): geração só mensal, dia útil anterior
-- quando o dia não existe e no máximo uma ocorrência por modelo e mês, mesmo
-- quando já existe uma ocorrência gerada com a regra anterior (último dia do
-- mês). Identidades sintéticas.
BEGIN;

INSERT INTO auth.users (id) VALUES ('b0000000-0000-0000-0000-000000000001');
INSERT INTO public.user_preferences (owner_id, time_zone_id)
VALUES ('b0000000-0000-0000-0000-000000000001', 'America/Sao_Paulo');

-- Receita mensal dia 31 desde 31/01/2026 (receita não exige período).
INSERT INTO public.income_recurrence_templates (owner_id, id, description,
    frequency, starts_on, monthly_reference_day, value_mode,
    default_amount_centavos)
VALUES ('b0000000-0000-0000-0000-000000000001',
    'b1000000-0000-0000-0000-000000000001', 'Dia 31', 'monthly',
    '2026-01-31', 31, 'fixed', 1000);

-- Ocorrência de fevereiro/2026 já gerada pela regra anterior: 28/02 (sábado).
-- Pela regra nova seria 27/02 (sexta); não pode surgir uma segunda.
INSERT INTO public.income_entries (owner_id, id, amount_centavos, status,
    recurrence_template_id, scheduled_for_date)
VALUES ('b0000000-0000-0000-0000-000000000001',
    public.recurrence_occurrence_id('b1000000-0000-0000-0000-000000000001',
        '2026-02-28'),
    1000, 'pending', 'b1000000-0000-0000-0000-000000000001', '2026-02-28');

SELECT pg_catalog.set_config('request.jwt.claim.sub',
    'b0000000-0000-0000-0000-000000000001', TRUE);
SET LOCAL ROLE authenticated;

DO $test$
DECLARE
    r JSONB;
    n BIGINT;
BEGIN
    r := public.generate_due_recurrence_occurrences(
        'b2000000-0000-0000-0000-000000000001');
    IF r ->> 'status' <> 'applied' THEN
        RAISE EXCEPTION 'generation failed: %', r;
    END IF;

    -- Uma por mês, nunca duas.
    SELECT pg_catalog.count(*) INTO n FROM (
        SELECT pg_catalog.date_trunc('month', e.scheduled_for_date)
        FROM public.income_entries e
        WHERE e.recurrence_template_id = 'b1000000-0000-0000-0000-000000000001'
        GROUP BY 1 HAVING pg_catalog.count(*) > 1) AS dup;
    IF n <> 0 THEN
        RAISE EXCEPTION 'two occurrences in the same month';
    END IF;

    -- Fevereiro: só a antiga (28/02); 27/02 não foi criada.
    IF NOT EXISTS (SELECT 1 FROM public.income_entries e
        WHERE e.recurrence_template_id = 'b1000000-0000-0000-0000-000000000001'
          AND e.scheduled_for_date = '2026-02-28')
       OR EXISTS (SELECT 1 FROM public.income_entries e
        WHERE e.recurrence_template_id = 'b1000000-0000-0000-0000-000000000001'
          AND e.scheduled_for_date = '2026-02-27') THEN
        RAISE EXCEPTION 'old-rule occurrence was duplicated';
    END IF;

    -- Regra nova nos demais meses: 31/01 (sáb., existe: mantém), 31/03,
    -- 30/04 (qui.), 31/05 (dom., existe: mantém), 30/06 (ter.), 30/09 (qua.).
    SELECT pg_catalog.count(*) INTO n FROM public.income_entries e
    WHERE e.recurrence_template_id = 'b1000000-0000-0000-0000-000000000001'
      AND e.scheduled_for_date IN ('2026-01-31', '2026-03-31', '2026-04-30',
          '2026-05-31', '2026-06-30', '2026-09-30');
    IF n <> 6 THEN
        RAISE EXCEPTION 'monthly dates do not follow the weekday rule (% of 6)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM public.income_entries e
        WHERE e.recurrence_template_id = 'b1000000-0000-0000-0000-000000000001'
          AND e.scheduled_for_date
              <> public.recurrence_monthly_date(e.scheduled_for_date, 31::SMALLINT)
          AND e.scheduled_for_date <> '2026-02-28') THEN
        RAISE EXCEPTION 'an occurrence is off the monthly rule';
    END IF;

    -- Segunda rodada: nada novo.
    r := public.generate_due_recurrence_occurrences(
        'b2000000-0000-0000-0000-000000000002');
    IF (r ->> 'income_created')::INT <> 0 THEN
        RAISE EXCEPTION 'second generation created occurrences: %', r;
    END IF;
END;
$test$;

\echo PASS: monthly-only generation, weekday rule and one occurrence per template and month.
ROLLBACK;
