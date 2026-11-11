-- Entrega 27B: leitura incremental (download) por (owner_id, updated_at, id).
-- Somente índices de desempenho; não altera colunas, regras nem permissões.

CREATE INDEX period_configurations_owner_updated_idx
    ON public.period_configurations (owner_id, updated_at, id);
CREATE INDEX accounting_periods_owner_updated_idx
    ON public.accounting_periods (owner_id, updated_at, id);
CREATE INDEX categories_owner_updated_idx
    ON public.categories (owner_id, updated_at, id);
CREATE INDEX subcategories_owner_updated_idx
    ON public.subcategories (owner_id, updated_at, id);
CREATE INDEX income_recurrence_templates_owner_updated_idx
    ON public.income_recurrence_templates (owner_id, updated_at, id);
CREATE INDEX expense_recurrence_templates_owner_updated_idx
    ON public.expense_recurrence_templates (owner_id, updated_at, id);
CREATE INDEX income_entries_owner_updated_idx
    ON public.income_entries (owner_id, updated_at, id);
CREATE INDEX expense_entries_owner_updated_idx
    ON public.expense_entries (owner_id, updated_at, id);
CREATE INDEX investment_allocations_owner_updated_idx
    ON public.investment_allocations (owner_id, updated_at, id);
CREATE INDEX audit_events_owner_occurred_idx
    ON public.audit_events (owner_id, occurred_at, id);
