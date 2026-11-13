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
| `user_preferences` | PK `owner_id`; `theme` (`light`/`dark`); `time_zone_id` (padrão `America/Sao_Paulo`); `onboarding` JSON `{etapa: done\|skipped}` |
| `period_configurations` | `mode` (`calendar_month`/`custom_cycle`), `custom_start_day` 1–31, `effective_from`; nunca reescritas |
| `accounting_periods` | `configuration_id`, `start_date`, `end_date`; sem aberto/encerrado |
| `categories` | `kind` (`income`/`expense`, imutável), `name`, `is_active` |
| `subcategories` | `category_id`, `name`, `is_active` |
| `income_recurrence_templates` / `expense_recurrence_templates` | `description`, `frequency` (mensal/por período), `starts_on`, `monthly_reference_day`, `value_mode` (`fixed`/`variable`), `default_amount_centavos`, categoria/sub opcionais, ativo |
| `investment_recurrence_templates` | agenda igual; valor sempre fixo; sem descrição/categoria |
| `income_entries` | `amount_centavos`, `status` (`pending`/`received`/`cancelled`), `received_on` e `accounting_period_id` nulos enquanto pendente; `recurrence_template_id`, `scheduled_for_date`, `scheduled_period_id` se recorrente |
| `expense_entries` | `competence_on`, `due_on`, `paid_on`, `status` (`pending`/`paid`/`cancelled`), período obrigatório; campos de recorrência iguais |
| `investment_allocations` | `amount_centavos`, `allocated_on`, período, `cancelled_at`; campos de recorrência |
| `audit_events` | entidade, operação, ator, instante, snapshots antes/depois (JSONB), `operation_id`; só inclusão |
| `applied_sync_operations` | `(owner_id, idempotency_key)` único + hash e resposta guardada |
| `sync_conflicts` | snapshots local/remoto, `open`/`resolved`, resolução |
| `deleted_accounts` | só id + data (não ressuscitar na restauração) |
| `sync_outbox`, `sync_cursors` (só locais) | fila de envio e cursores do download |

Unicidade de ocorrência: índice parcial `(owner_id, recurrence_template_id, scheduled_for_date)` nas três tabelas de lançamento.

## 3. RPCs (todas `SECURITY DEFINER`, idempotentes, versionadas, auditadas)
| Assunto | RPC | Migration |
|---|---|---|
| Categorias / subcategorias | `apply_category_change`, `apply_subcategory_change` | `20261109000200`, `20261109000400` |
| Períodos | `create_accounting_period`, `create_earlier_accounting_period`, `schedule_period_configuration` | `20261109000300`, `20261111000200`, `20261112000100` |
| Lançamentos avulsos | `apply_income_entry_change`, `apply_expense_entry_change`, `apply_investment_allocation_change` | `20261109000600`, `20261109000500` |
| Recorrências | `apply_{income,expense,investment}_recurrence_template_change`, `create_recurrence_from_entry`, `create_investment_recurrence_from_entry`, `generate_due_recurrence_occurrences`, `recurrence_occurrence_id` | `20261109000700–0900`, `20261111000300`, `20261111000400` |
| Conflitos | `resolve_sync_conflict` | `20261110000100` |
| Relatórios (leitura) | `get_period_report` (somas exatas como texto) | `20261112000200` |
| Preferências | `set_user_theme`, `set_onboarding_step` | `20261112000300` |
| Conta | `delete_my_account` | `20261113000200` |
| Segurança | revoga funções de gatilho para `anon` | `20261113000100` |

Testes SQL: `supabase/tests/*_test.sql` (inclui `security_catalog_test.sql`). Nova mudança = nova migration; nunca editar as existentes.

## 4. Drift (local)
- `lib/core/local_database/app_database.dart`, **schemaVersion 5**; snapshots em `drift_schemas/porquinho/drift_schema_v1..v5.json`; testes em `test/core/local_database/migration_test.dart`.
- v4: recorrência de investimento. v5: `user_preferences.onboarding`.
- Alterou o schema: incrementar versão, gerar snapshot, testar migração da anterior.
