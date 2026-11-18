# Mapa do app — Norte

Onde fica cada coisa no código, como está hoje. Ler só a linha do módulo que vai mexer. Testes espelham `lib/` em `test/` (integração em `test/integration/`). Atualizar este arquivo quando criar/mover módulo, tela ou rota.

## Telas e rotas (`lib/app/app.dart`)
- Barra inferior (`lib/shared/main_shell.dart`, `NorteNavBar`), em pílula: Home (`/`) · Ferramentas (`/ferramentas`) · Adicionar + (abre `showNewEntryChooser`) · Lançamentos (`/lancamentos`) · Mais (`/mais`, com Categorias).
- Ferramentas (`features/tools/`): `/ferramentas` (catálogo) · `/ferramentas/personalizar`. Relatórios é a ferramenta `reports` e abre `/relatorios` (Meus relatórios; configuração guiada no primeiro acesso) + `/relatorios/catalogo`, `/relatorios/personalizar` e `/relatorios/<id>` (tela completa; ID inexistente volta para `/relatorios`), rotas em `features/reports/report_routes.dart`; Calculadora de juros compostos é `compound_interest` e abre `/juros-compostos` (+ `/juros-compostos/retiradas`); Calculadora à vista ou parcelado é `cash_or_installments` e abre `/a-vista-ou-parcelado`; Gestão de faturas é `card_bills` e abre `/gestao-de-faturas` (fatura, compra e parcelas abrem por cima, sem rota própria). Todas fora do shell; a barra mostra Ferramentas selecionada.
- Mais (`features/more/more_screen.dart`): Sincronizar agora (celular) · `/atencao` Itens que precisam de atenção · `/categorias` · `/periodo` · `/configuracao-inicial` · `/tema` · `/recorrencias` · `/exportar` (CSV) · `/seguranca` (celular) · Excluir conta · Sair.
- Fora das abas: `/login`, `/nova-senha`, `/bloqueio` (PIN).

## Núcleo (`lib/core/`)
| Arquivo | Papel |
|---|---|
| `domain/money.dart` | BRL em centavos (`BigInt`), parse sem arredondar (RN045) |
| `domain/calendar_date.dart`, `user_clock.dart` | data civil e "hoje" em `America/Sao_Paulo` |
| `domain/period_calendar.dart` | período calculado por data, ciclos, meses curtos, limites da navegação (`between`, `bounds`) (RN001–RN004, RN036–RN037) |
| `domain/recurrence_schedule.dart` | agenda mensal (dia inexistente → último dia útil do mês), ID determinístico de ocorrências (RN038) |
| `domain/surplus.dart` | dinheiro livre (RN005) |
| `domain/reports.dart` | cinco relatórios (RF025) |
| `data_access.dart` | modo celular (local) × Web (remoto) |
| `infra_providers.dart` | providers de infraestrutura |
| `local_database/` | Drift (`app_database.dart`), conexão cifrada, chave, limpeza local |

## Módulos (`lib/features/`)
Padrão por módulo: `*_models` · `*_repository` (interface) · `local_*` (Drift+fila) · `remote_*` (RPC) · `*_service` (regras de aplicação) · `*_providers` · `*_screen`.

| Módulo | O que faz | RF / RN | Tabelas |
|---|---|---|---|
| `auth/` | login Google/e-mail, sessão, nova senha, logout com pendências, excluir conta, vínculo do banco ao usuário; layout do login em `auth/widgets/` (`login_hero.dart`: cena por tema e marca, adapta à altura; `login_panel.dart`; `norte_mark.dart`: símbolo do Norte; `google_g_icon.dart`), cena em `assets/login/` (gerada por `tooling/gerar_cena_login.py`) | RF001–002 | Auth, `deleted_accounts` |
| `app_lock/` | PIN/biometria, tela de bloqueio e Segurança | RF003 | armazenamento seguro |
| `periods/` | configuração única (`period_service`: primeiro acesso, troca na hora, período de uma data, limites); `period_gate`, `period_setup_screen`, `period_settings_screen` (troca com aviso), `period_navigation` (período calculado e setas limitadas do lançamento mais antigo ao mais distante) | RF019, RN001–004, RN036–037, RN042 | `period_settings`; RPCs `set_period_settings`, `get_entry_date_span` |
| `categories/` | categorias, subcategorias, sugestões iniciais; ícone e cor por categoria (`category_appearance.dart`: conjunto fixo de ícones Material e 8 cores); `category_editor.dart` (criar/editar nome, ícone e cor); `category_picker.dart` (escolha da categoria/subcategoria no lançamento, com busca); `category_name_dialog.dart` (nome de subcategoria) | RF014–015, RN024–027, RN040, RN044 | `categories`, `subcategories` |
| `entries/` | receitas e despesas avulsas; formulário único (`entry_form_screen`, inclusive modo investimento e "Repetir"; categoria escolhida pelo seletor, com "Nova categoria" no seletor, só receita/despesa) | RF005, RF009, RF012, RF018, RN008–017, RN028–030, RN039 | `income_entries`, `expense_entries` |
| `recurrence/` | modelos e ocorrências de receita/despesa; geração local; Mais → Recorrências | RF006–008, RF010–011, RF013, RN010–011, RN014, RN019, RN038 | `*_recurrence_templates` |
| `investments/` | investimento avulso e recorrente | RF016–017, RN021–023 | `investment_allocations`, `investment_recurrence_templates` |
| `transactions/` | aba Lançamentos (lista e filtros) | RF004 | — |
| `dashboard/` | dinheiro livre e composição do período | RF020 | — |
| `totals/` | totais por período (intervalo de datas) para o Dashboard | RN005 | — |
| `reports/` | central modular (spec `docs/ferramentas/relatorios.md`): `models/` (`ReportDefinition`, `ReportLevel`, `ReportPreferences`), `registry/report_registry.dart` (os 5 relatórios, IDs estáveis, lista sugerida), `domain/` (`report_catalog.dart` puro; `free_money_change.dart` = diferença do relatório 4), `report_preferences_controller.dart`, `modules/` (níveis compacto/expandido/completo/prévia de cada relatório), `screens/` (Meus relatórios, configuração guiada, catálogo, Personalizar, tela completa), `widgets/` (moldura do cartão, barra dividida, mini-gráfico); dados pelos mesmos `reports_providers.dart`/`reports_repository.dart` (somam por `PeriodRange`) e gráficos `series_chart.dart` (`fl_chart`) | RF025 | RPC `get_range_report`; `user_preferences.reports`; RPCs `set_report_selection`, `complete_report_setup` |
| `tools/` | aba Ferramentas: `models/` (`ToolDefinition`, `ToolCategory`/`ToolCategories`, `ToolIntroMode`, `ToolPreferences`), `registry/tool_registry.dart` (catálogo único: Relatórios, Juros compostos e À vista ou parcelado; campo opcional `initialAlert` = alerta inicial no topo da apresentação e do ⓘ), `domain/tool_catalog.dart` (Suas/Outras, adicionar, remover, reordenar, busca, categorias), `tools_providers.dart` (estado e gravação), `tool_launcher.dart` (abre respeitando a explicação), `screens/` (catálogo e Personalizar), `widgets/` (cartões, informação, explicação inicial) | RF004, RF025 | `user_preferences.tools`; RPCs `set_tool_selection`, `dismiss_tool_intro` |
| `compound_interest/` | Calculadora de juros compostos (ferramenta `compound_interest`, só simulação em memória, sem lançamentos nem gravação): `domain/` (`simulation_math.dart` taxa, leitura dos campos, limites e ponto fixo `BigInt`; `compound_interest.dart` evolução com aportes; `withdrawal_simulation.dart` retiradas), `application/simulation_controllers.dart` (Riverpod, estado descartado ao sair), `screens/` (`/juros-compostos`, `/juros-compostos/retiradas`), `widgets/` (campos, cartões, gráfico `fl_chart`, tabela) | — (ferramenta aprovada em 14/11/2026) | — |
| `cash_or_installments/` | Calculadora à vista ou parcelado (ferramenta `cash_or_installments`, só simulação em memória, sem lançamentos; spec `docs/ferramentas/a_vista_ou_parcelado.md`): `domain/` (`business_calendar.dart` dias úteis com feriados nacionais só nesta ferramenta; `investment_taxes.dart` IR/IOF; `fixed_point.dart` ponto fixo `BigInt` e taxa diária; `cash_or_installments_engine.dart` os dois caminhos, tabela, veredito; `purchase_input.dart` campos, desconto, divisão, vencimentos), `data/reference_rates.dart` (taxa do Banco Central SGS + cache), `application/` (Riverpod), `screens/` (`/a-vista-ou-parcelado`), `widgets/`, `cash_or_installments_texts.dart` (textos em rascunho) | RF028 | — (cache da taxa no `SecureValueStore`) |
| `card_bills/` | Gestão de Faturas de Cartões (ferramenta `card_bills`; spec `docs/ferramentas/gestao_de_faturas.md`): primeira ferramenta que grava dados, sem lançamentos nem efeito no dinheiro livre. `domain/` (Dart puro: `year_month`, `deterministic_id` UUID v5, `card_bill_models` + formato das linhas, `card_calendar` fechamento/vencimento/ciclo, `purchases` divisão e edição, `subscriptions` cobranças, `invoice_board` valor da fatura/visíveis/indicador, `reserve` eventos e pagamento, `reserve_calculator` conta exata, `cards_and_invoices`, `change_set` alterações comuns ao aparelho e ao servidor), `data/` (`local_card_bills_repository` banco + fila sem auditoria, `remote_card_bills_repository` Web, `card_bills_downloader` lista completa e exclusões por comparação, `card_bills_conflicts` pagamento duplicado), `application/` (serviço e Riverpod; gera cobranças ao abrir), `screens/` (painel, cartão, compra, assinatura, fatura, pagar, calculadora), `widgets/`, `card_bills_texts.dart` (rascunho) | RF029 | `card_bill_*`; RPCs `card_bills_apply`, `card_bills_pay_invoice`, `card_bills_undo_payment` |
| `alerts/` | notificação diária de vencimentos (Android) | RF023, RN018, RN041 | — |
| `sync/` | fila, envio, download (inclui o da Gestão de Faturas ao fim da rodada), agendador, indicador de status | RF021–022, RF027, RN031–033 | `sync_outbox`, `sync_cursors`, `applied_sync_operations` |
| `attention/` | conflitos e recusas para o usuário decidir (inclui pagamento duplicado da Gestão de Faturas, decidido no aparelho) | RN033 | `sync_conflicts` |
| `preferences/` | tema claro/escuro; repositório único das preferências da conta (tema, assistente, Ferramentas) | RF026 | `user_preferences` |
| `app/theme/` | tema central (`norte_theme.dart`): cores Menta claro/escuro, fonte Inter, componentes, e `NorteColors` (receita, despesa, investimento, pendente). Telas devem usar `colorScheme`/`NorteColors`, sem cor própria | — | — |
| `onboarding/` | assistente inicial com etapas puláveis | RF024 | `user_preferences.onboarding` |
| `export/` | CSV (só Web) | requisitos §8, D4 Fase 8 | — |
| `more/` | menu da aba Mais | RF004 | — |

## Fora de `lib/`
- `supabase/migrations/` (26) e `supabase/tests/` — ver `banco_de_dados.md`.
- `tooling/`: `a_vista_ou_parcelado_referencia.py` (referência independente → `test/fixtures/cash_or_installments_cases.json`), `test_postgres_schema.ps1`, `test_integration_local.ps1`, `test_integration_homolog.ps1`, `build_release.ps1`.
- `env/*.example.json` (config por ambiente), `drift_schemas/` (snapshots), `web/excluir-conta.html`.
- `assets/fonts/inter/`: fonte Inter (licença OFL em `OFL-LICENSE.txt`), embutida no app.
