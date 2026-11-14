# Banco de dados — Norte

Só o schema vigente. Modelo conceitual, justificativas e status históricos: `historico/banco_de_dados_v05_completo.md`.

## 1. Convenções
- IDs UUID criados no cliente. Tabelas remotas: `owner_id` + PK `(owner_id, id)`; FKs compostas com `owner_id` (impede referência entre usuários); `ON DELETE RESTRICT`.
- Registros mutáveis: `version`, `created_at`, `updated_at`. Nada financeiro é apagado no fluxo normal (cancelar ≠ apagar).
- Centavos: `BIGINT >= 0` no PostgreSQL; `TEXT` decimal no SQLite (→ `BigInt`). Zero válido; `NULL` só em ocorrência variável ainda sem valor.
- Datas civis `DATE`/`TEXT YYYY-MM-DD`; instantes `timestamptz` UTC. Enums em `TEXT` + `CHECK`.
- Período = `[start_date, end_date)`, sem lacuna/sobreposição; criado só por RPC com trava advisory por usuário.

## 2. Tabelas
| Tabela | Campos-chave / regras |
|---|---|
| `user_preferences` | PK `owner_id`; `theme` (`light`/`dark`); `time_zone_id` (padrão `America/Sao_Paulo`); `onboarding` JSON `{etapa: done\|skipped}`; `tools` JSON `{selected?: [IDs na ordem], dismissed_intros?: [IDs]}` (sem `selected` = padrão do app; IDs `^[a-z][a-z0-9_]{0,63}$`) |
| `period_settings` | configuração única por usuário (`id` = dono): `mode` (`calendar_month`/`custom_cycle`), `custom_start_day` 1–31, `version`. Períodos não são gravados: são calculados (`[início, fim)`) a partir dela (RN002, P6/P7) |
| `categories` | `kind` (`income`/`expense`, imutável), `name`, `is_active`, `icon_key` (padrão `category`), `color_key` (uma de 8 chaves; padrão `gray`) |
| `subcategories` | `category_id`, `name`, `is_active` |
| `income_recurrence_templates` / `expense_recurrence_templates` | `description`, `frequency` (só `monthly` aceita desde a P5; `by_period` antigo fica desativado), `starts_on`, `monthly_reference_day`, `value_mode` (`fixed`/`variable`), `default_amount_centavos`, categoria/sub opcionais, ativo |
| `investment_recurrence_templates` | agenda igual; valor sempre fixo; sem descrição/categoria |
| `income_entries` | `amount_centavos`, `status` (`pending`/`received`/`cancelled`), `received_on` nulo enquanto pendente; `recurrence_template_id`, `scheduled_for_date` se recorrente. Sem vínculo com período (P7): o período é o que contém a data |
| `expense_entries` | `competence_on`, `due_on`, `paid_on`, `status` (`pending`/`paid`/`cancelled`); campos de recorrência iguais |
| `investment_allocations` | `amount_centavos`, `allocated_on`, `cancelled_at`; campos de recorrência |
| `audit_events` | entidade, operação, ator, instante, snapshots antes/depois (JSONB), `operation_id`; só inclusão |
| `applied_sync_operations` | `(owner_id, idempotency_key)` único + hash e resposta guardada |
| `sync_conflicts` | snapshots local/remoto, `open`/`resolved`, resolução |
| `deleted_accounts` | só id + data (não ressuscitar na restauração) |
| `sync_outbox`, `sync_cursors` (só locais) | fila de envio e cursores do download |

Unicidade de ocorrência: índice parcial `(owner_id, recurrence_template_id, scheduled_for_date)` nas três tabelas de lançamento.

## 3. RPCs (todas `SECURITY DEFINER`, idempotentes, versionadas, auditadas)
| Assunto | RPC | Migration |
|---|---|---|
| Categorias / subcategorias | `apply_category_change` (ações `create`, `rename`, `restyle`, `deactivate`; ícone e cor opcionais), `apply_subcategory_change` | `20261109000200`, `20261109000400`, `20261113000300` |
| Período (configuração única) | `set_period_settings` (criar com versão 0 ou trocar; conflito por versão, aceito em `resolve_sync_conflict`); `get_entry_date_span` (limites da navegação). As RPCs de período gravado foram removidas na P7 | `20261113000600`, `20261113000700` |
| Lançamentos avulsos | `apply_income_entry_change`, `apply_expense_entry_change`, `apply_investment_allocation_change` | `20261109000600`, `20261109000500` |
| Recorrências | `apply_{income,expense,investment}_recurrence_template_change`, `create_recurrence_from_entry`, `create_investment_recurrence_from_entry`, `generate_due_recurrence_occurrences` (só mensal; no máximo uma ocorrência por modelo e mês), `recurrence_occurrence_id`, `recurrence_monthly_date` (dia inexistente → último dia útil do mês, RN038). Gatilho `enforce_monthly_recurrence`: recusa criar, reativar ou mudar para `by_period`; modelos `by_period` antigos foram desativados (auditado) | `20261109000700–0900`, `20261111000300`, `20261111000400`, `20261113000500` |
| Conflitos | `resolve_sync_conflict` | `20261110000100`, `20261111000400`, `20261113000300` |
| Relatórios (leitura) | `get_range_report(p_starts, p_ends)`: somas exatas como texto por intervalo de datas `[início, fim)` pela data de competência (índices por data) | `20261113000400` |
| Preferências | `set_user_theme`, `set_onboarding_step`; Ferramentas: `set_tool_selection(p_tool_ids text[])` (lista ordenada, `NULL` = padrão; última gravação vence) e `dismiss_tool_intro(p_tool_id)` (soma entre aparelhos) | `20261112000300`, `20261113000800` |
| Conta | `delete_my_account` | `20261113000200`, `20261113000700` |
| Segurança | revoga funções de gatilho para `anon` | `20261113000100` |

Testes SQL: `supabase/tests/*_test.sql` (inclui `security_catalog_test.sql`). Nova mudança = nova migration; nunca editar as existentes.

## 4. Drift (local)
- `lib/core/local_database/app_database.dart`, **schemaVersion 9**; snapshots em `drift_schemas/porquinho/drift_schema_v1..v9.json`; testes em `test/core/local_database/migration_test.dart`.
- v4: recorrência de investimento. v5: `user_preferences.onboarding`. v6: `categories.icon_key` e `color_key` (padrões iguais aos do servidor; o download usa o padrão se o servidor ainda não enviar as colunas). v7: `period_settings` (configuração única, preenchida com a que valia no aparelho) e vínculo com o período opcional. v8: sem `accounting_periods`, `period_configurations` nem colunas de vínculo; pendências e conflitos antigos de período descartados. v9: `user_preferences.tools` (escolhas da aba Ferramentas, padrão `{}`).
- Alterou o schema: incrementar versão, gerar snapshot, testar migração da anterior.
