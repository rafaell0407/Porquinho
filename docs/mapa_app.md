# Mapa do app — Norte

Onde fica cada coisa no código, como está hoje. Ler só a linha do módulo que vai mexer. Testes espelham `lib/` em `test/` (integração em `test/integration/`). Atualizar este arquivo quando criar/mover módulo, tela ou rota.

## Telas e rotas (`lib/app/app.dart`)
- Abas (`lib/shared/main_shell.dart`): `/` Dashboard · `/lancamentos` Lançamentos · `/mais` Mais.
- Mais (`features/more/more_screen.dart`): Sincronizar agora (celular) · `/atencao` Itens que precisam de atenção · `/categorias` · `/periodo` · `/relatorios` · `/configuracao-inicial` · `/tema` · `/recorrencias` · `/exportar` (CSV) · `/seguranca` (celular) · Excluir conta · Sair.
- Fora das abas: `/login`, `/nova-senha`, `/bloqueio` (PIN).

## Núcleo (`lib/core/`)
| Arquivo | Papel |
|---|---|
| `domain/money.dart` | BRL em centavos (`BigInt`), parse sem arredondar (RN045) |
| `domain/calendar_date.dart`, `user_clock.dart` | data civil e "hoje" em `America/Sao_Paulo` |
| `domain/period_calendar.dart` | períodos, ciclos, meses curtos (RN001–RN004, RN036–RN037) |
| `domain/recurrence_schedule.dart` | agenda e ID determinístico de ocorrências (RN038) |
| `domain/surplus.dart` | dinheiro livre (RN005) |
| `domain/reports.dart` | cinco relatórios (RF025) |
| `data_access.dart` | modo celular (local) × Web (remoto) |
| `infra_providers.dart` | providers de infraestrutura |
| `local_database/` | Drift (`app_database.dart`), conexão cifrada, chave, limpeza local |

## Módulos (`lib/features/`)
Padrão por módulo: `*_models` · `*_repository` (interface) · `local_*` (Drift+fila) · `remote_*` (RPC) · `*_service` (regras de aplicação) · `*_providers` · `*_screen`.

| Módulo | O que faz | RF / RN | Tabelas |
|---|---|---|---|
| `auth/` | login Google/e-mail, sessão, nova senha, logout com pendências, excluir conta, vínculo do banco ao usuário | RF001–002 | Auth, `deleted_accounts` |
| `app_lock/` | PIN/biometria, tela de bloqueio e Segurança | RF003 | armazenamento seguro |
| `periods/` | primeiro acesso (`period_gate`, `period_setup_screen`), configurações, navegação entre períodos | RF019, RN001–004, RN036–037, RN042 | `period_configurations`, `accounting_periods` |
| `categories/` | categorias, subcategorias, sugestões iniciais; ícone e cor por categoria (`category_appearance.dart`: conjunto fixo de ícones Material e 8 cores); `category_editor.dart` (criar/editar nome, ícone e cor); `category_picker.dart` (escolha da categoria/subcategoria no lançamento, com busca); `category_name_dialog.dart` (nome de subcategoria) | RF014–015, RN024–027, RN040, RN044 | `categories`, `subcategories` |
| `entries/` | receitas e despesas avulsas; formulário único (`entry_form_screen`, inclusive modo investimento e "Repetir"; categoria escolhida pelo seletor, com "Nova categoria" no seletor, só receita/despesa) | RF005, RF009, RF012, RF018, RN008–017, RN028–030, RN039 | `income_entries`, `expense_entries` |
| `recurrence/` | modelos e ocorrências de receita/despesa; geração local; Mais → Recorrências | RF006–008, RF010–011, RF013, RN010–011, RN014, RN019, RN038 | `*_recurrence_templates` |
| `investments/` | investimento avulso e recorrente | RF016–017, RN021–023 | `investment_allocations`, `investment_recurrence_templates` |
| `transactions/` | aba Lançamentos (lista e filtros) | RF004 | — |
| `dashboard/` | dinheiro livre e composição do período | RF020 | — |
| `totals/` | totais por período para o Dashboard | RN005 | — |
| `reports/` | relatórios e gráficos (`fl_chart`) | RF025 | RPC `get_period_report` |
| `alerts/` | notificação diária de vencimentos (Android) | RF023, RN018, RN041 | — |
| `sync/` | fila, envio, download, agendador, indicador de status | RF021–022, RF027, RN031–033 | `sync_outbox`, `sync_cursors`, `applied_sync_operations` |
| `attention/` | conflitos e recusas para o usuário decidir | RN033 | `sync_conflicts` |
| `preferences/` | tema claro/escuro | RF026 | `user_preferences` |
| `app/theme/` | tema central (`norte_theme.dart`): cores Menta claro/escuro, fonte Inter, componentes, e `NorteColors` (receita, despesa, investimento, pendente). Telas devem usar `colorScheme`/`NorteColors`, sem cor própria | — | — |
| `onboarding/` | assistente inicial com etapas puláveis | RF024 | `user_preferences.onboarding` |
| `export/` | CSV (só Web) | requisitos §8, D4 Fase 8 | — |
| `more/` | menu da aba Mais | RF004 | — |

## Fora de `lib/`
- `supabase/migrations/` (20) e `supabase/tests/` — ver `banco_de_dados.md`.
- `tooling/`: `test_postgres_schema.ps1`, `test_integration_local.ps1`, `test_integration_homolog.ps1`, `build_release.ps1`.
- `env/*.example.json` (config por ambiente), `drift_schemas/` (snapshots), `web/excluir-conta.html`.
- `assets/fonts/inter/`: fonte Inter (licença OFL em `OFL-LICENSE.txt`), embutida no app.
