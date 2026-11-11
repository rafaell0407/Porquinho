# Fase 7 — Períodos, Dashboard e relatórios

**Status:** PROPOSTA (planejamento de 11/11/2026). Nenhuma entrega iniciada. Decisões D1–D11 APROVADAS em 11/11/2026 (seção 9.1); D6 acrescenta a Entrega 59A (nome "Dinheiro livre do período").
**Estado vigente:** `docs/estado_atual.md`. Regras: `docs/regras_negocio.md`. Escopo: `docs/requisitos.md` (RF019, RF020, RF024–RF026, §5, §13.7).

## 1. Objetivo

Apresentar a sobra por mês-calendário ou ciclo personalizado: permitir mudar a configuração de período (valendo no próximo período), mostrar no Dashboard a sobra e sua composição, oferecer os cinco relatórios básicos, o tema claro/escuro salvo na conta e o assistente de configuração inicial com etapas opcionais.

## 2. Situação das dependências

| Fase | Situação | O que a Fase 7 aproveita |
|---|---|---|
| 4 | CONCLUÍDA e validada (11/11/2026) | Domínio de períodos com meses curtos e bissexto (`period_calendar.dart`, testes em `test/core/domain/period_calendar_test.dart`), regra de transição de configuração (`PeriodCalendar.transition`), criação sob demanda, sobra no domínio (`surplus.dart`), Dashboard com sobra e navegação entre períodos |
| 5 | CONCLUÍDA e validada (11/11/2026) | Recorrências de receita/despesa e geração por período; receitas pendentes já ficam fora da sobra |
| 6 | IMPLEMENTADA e VALIDADA (11/11/2026), **sem commit** | Investimentos avulsos e recorrentes já entram na sobra; rendimento é receita comum |

Recomendação: fazer o commit da Fase 6 antes de iniciar a Entrega 59, para separar o histórico das fases.

## 3. Estado atual encontrado (o que já existe)

| Tema | Existe hoje | Falta na Fase 7 |
|---|---|---|
| Configuração de período | Escolha no primeiro acesso (`period_setup_screen.dart`); tabela `period_configurations` com `effective_from` (servidor e Drift); `PeriodService._next` já escolhe a configuração vigente por data e aplica a transição (RN002) | Tela para **mudar** a configuração; gravar uma configuração "agendada" para o próximo período. O servidor só cria configuração junto com um período (`create_accounting_period`), então **falta função no servidor** para agendar a mudança |
| Histórico de configuração | Cada período guarda `configuration_id`; períodos antigos não mudam | Exibir o histórico (qual configuração cada período usou) |
| Dashboard | Só o valor da sobra (`dashboard_screen.dart`, decisão D9 da Fase 4); `PeriodTotals` já tem receitas, despesas e investimentos separados | Composição da sobra (depende da decisão D1) |
| Navegação | Três abas Dashboard / Lançamentos / Mais (`main_shell.dart`, `app.dart`); período selecionado compartilhado (`periodAnchorProvider`) | Novos itens em Mais: Período, Relatórios, Tema, Configuração inicial. As abas não mudam |
| Totais | `TotalsRepository` local (Drift) e remoto (Web), ambos somando com `computePeriodTotals` (mesma regra) | Leituras de vários períodos e por categoria para os relatórios |
| Tema | Coluna `theme` (`light`/`dark`/nula) em `user_preferences` no servidor e no Drift; download já traz a linha. App usa tema fixo (`app.dart`) | Função de gravação no servidor (nova migration), envio pela fila no celular, aplicar `ThemeMode` |
| Onboarding | Primeiro acesso obrigatório (período) e sugestões de categorias (`category_suggestions_screen.dart`) | Assistente com etapas opcionais, que pode ser retomado em Mais |

Componentes reaproveitáveis: `PeriodCalendar`, `PeriodService`, `PeriodNavigator`/`selectedPeriodProvider`, `computePeriodTotals`/`countsAsIncome`/`countsAsExpense`, `TotalsRepository`, `refreshFinanceData`, `formatBrl`, repositórios de categorias, `LocalChangeRecorder` (gravação + auditoria + fila), padrão local/remoto por `dataAccessModeProvider`.

## 4. Divergências encontradas (registradas, não corrigidas)

| # | Divergência | Evidência | Encaminhamento |
|---|---|---|---|
| V1 | Composição no Dashboard × decisão D3 da Fase 6 | `roadmap.md` Fase 7 e `requisitos.md` §5 ("visão resumida de receitas, despesas e investimentos") × `entregas_fase6.md` D3 e `requisitos.md` RF016 ("o Dashboard não exibe esse total no MVP") | Decisão D1 |
| V2 | Leitura Web limitada a 1.000 linhas, sem aviso | `lib/features/sync/remote_table_reader.dart` (`.limit(1000)`) e `supabase/config.toml` (`max_rows = 1000`) | Hoje afeta só períodos com mais de 1.000 lançamentos de um tipo; nos relatórios de vários períodos o limite pode ser atingido e **o total sairia menor sem aviso**. Correção proposta na Entrega 62 (D11) |
| V3 | `banco_de_dados.md` (tabela conceitual de entidades) diz que a preferência do usuário guarda "modalidade de período"; fisicamente a configuração fica em `period_configurations` | `docs/banco_de_dados.md` linha 38 × linha 260 | Ajuste de texto na Entrega 60 |
| V4 | Banco local não tem índice por período nos lançamentos (só índices de unicidade das recorrências) | `lib/core/local_database/app_database.dart` (`@TableIndex` só de ocorrências e fila) | Medir na Entrega 62; índice só se a meta da RN043 não for atingida (exigiria Drift v5) |
| V5 | O valor `theme = null` (preferência não escolhida) não tem comportamento definido | `initial_schema.sql` (`theme TEXT CHECK (...)`, nulo permitido) | Decisão D4 |

## 5. Escopo funcional

### 5.1 Configuração de períodos (RF019; RN001–RN003, RN036, RN037, RN042)
- Em Mais → **Período**: ver a configuração atual, escolher mês-calendário ou ciclo personalizado e o dia inicial (1–31).
- A mudança vale a partir do próximo período (RN002). O primeiro período novo começa no fim do anterior e termina na próxima fronteira da nova configuração (regra de transição já implementada e testada).
- A tela mostra antes de confirmar: "A nova configuração começa em dd/mm/aaaa. O período atual não muda."
- Períodos existentes nunca são recalculados nem movidos; os lançamentos continuam no período em que estão.
- Mostrar o histórico: lista de períodos com as datas e a configuração usada.
- Meses curtos e bissexto: já cobertos no domínio; a Fase 7 acrescenta testes de transição (ex.: mês-calendário → dia 31 em fevereiro de ano bissexto).

### 5.2 Dashboard (RF020; RN005)
- Sobra do período selecionado (já existe) e sua composição: receitas contabilizadas, despesas contabilizadas e — conforme D1 — investimentos. Os três valores vêm do mesmo `PeriodTotals` usado na sobra (nenhuma conta na tela).
- Navegação entre períodos (já existe).
- Atualização após incluir, editar, mudar a data ou cancelar (já existe via `refreshFinanceData`; acrescentar testes da composição).

### 5.3 Relatórios (RF025; `requisitos.md` §13.7; RN044)
Todos usam a mesma regra da sobra (`countsAsIncome`, `countsAsExpense`, investimento não cancelado) e somam em centavos exatos (`BigInt`).

| Relatório | Cálculo |
|---|---|
| 1. Receitas por categoria e período | Receitas **recebidas** do período (`status = received`, com valor), agrupadas pela categoria; sem categoria → "Sem categoria". Soma dos grupos = receitas da sobra do período |
| 2. Despesas por categoria e período | Despesas **pendentes ou pagas com valor** do período, agrupadas pela categoria; "Sem categoria" incluído. Pagas e pendentes contam uma única vez. Soma = despesas da sobra |
| 3. Total destinado a investimentos por período | Soma dos investimentos não cancelados de cada período (avulsos e ocorrências recorrentes) |
| 4. Evolução da sobra entre períodos | Sobra de cada período de uma sequência de períodos (D8), na ordem cronológica |
| 5. Comparativo por período | Receitas, despesas e investimentos de cada período da mesma sequência |

Regras de apresentação:
- Ficam fora: cancelados, receitas recorrentes ainda pendentes, despesas variáveis sem valor informado. Não há linha "a receber" (seria indicador novo).
- Categoria desativada continua aparecendo com o nome atual (RN040). Renomear muda o nome exibido em todos os períodos.
- Rendimentos são receitas comuns e aparecem na categoria escolhida pelo usuário (ex.: "Rendimentos").
- Cada lançamento pertence a um único período (`accounting_period_id`), o que impede contar o mesmo valor duas vezes; relatórios agrupam por esse campo, nunca por intervalo de datas.
- Períodos com configurações diferentes aparecem com o intervalo real de datas (ex.: "20/10 a 30/11"), sem ajuste proporcional.
- Edição e cancelamento em período antigo aparecem no relatório na próxima leitura (os relatórios sempre recalculam a partir dos lançamentos; não há total gravado).

### 5.4 Navegação (RF004)
Sem mudança nas três abas. Novas rotas abertas a partir de Mais: `/periodo`, `/relatorios`, `/tema` e `/configuracao-inicial`.

### 5.5 Tema claro e escuro (RF026)
- Mais → **Tema**: Claro ou Escuro (comportamento sem escolha: D4).
- Celular: grava localmente, aplica na hora e envia pela fila (funciona offline). Web: grava direto no servidor.
- Nova função no servidor para gravar `user_preferences.theme` (não existe hoje) — nova migration.
- Ao entrar em outro aparelho, o tema vem no download (já implementado).

### 5.6 Onboarding (RF024; `requisitos.md` §3.1 item 21)
- O período continua obrigatório no primeiro acesso (decisão de 10/11/2026); as demais etapas são opcionais, podem ser puladas e retomadas em Mais → Configuração inicial.
- Etapas propostas (D6): apresentação da sobra, categorias sugeridas (já existe), tema, bloqueio por PIN/biometria (só celular) e orientação de recorrências.
- Etapas concluídas ou puladas não são mostradas de novo (persistência: D7).

## 6. Entregas sequenciais

Ordem: regras e servidor primeiro, depois telas. Numeração continua após a Fase 6.

### Entrega 59 — Mudança de configuração de período: domínio e servidor
1. **Objetivo:** agendar a nova configuração para o próximo período, local e remotamente, com o mesmo resultado.
2. **Funcionalidades:** `PeriodService.scheduleChange(config)`: calcula a data de início (fim do último período existente — D2), grava a configuração agendada e devolve a data para a tela; reagendar substitui a anterior enquanto nenhum período a usar (D3); escolher a configuração atual cancela a mudança.
3. **Regras:** RN001, RN002, RN003, RN036, RN037, RN042.
4. **Dependências:** D2, D3.
5. **Arquivos:** `lib/features/periods/period_service.dart`, `period_repository.dart`, `local_period_repository.dart`, `remote_period_repository.dart`, `period_models.dart`; `lib/features/sync/sync_models.dart` (nova RPC na fila); `test/features/periods/`, `test/core/domain/period_calendar_test.dart`.
6. **Banco remoto:** nova migration `supabase/migrations/2026111200xx_schedule_period_configuration.sql` com a RPC `schedule_period_configuration` (idempotente por `operation_id`, controle de versão, recusa se a data não for o fim do último período, recusa se algum período já usa a configuração, auditoria). Teste SQL `supabase/tests/rpc_schedule_period_configuration_test.sql`. **Banco local:** sem mudança de schema (tabela já existe).
7. **Testes:** transição mês → ciclo e ciclo → mês; ciclo dia 31 entrando em fevereiro comum e bissexto; dia 29/30/31; mudança feita no último dia do período; reagendar; cancelar a mudança; períodos antigos inalterados; `ensureUpTo` cria o período de transição com a nova configuração; recorrências "todo período" seguem os novos períodos; repetição da mesma operação não duplica; equivalência local × servidor das datas.
8. **Aceitação:** depois de agendar, o próximo período criado (no celular offline ou no servidor) tem exatamente as datas da regra de transição; nenhum período existente muda; reenvio não cria configuração duplicada.
9. **Riscos:** períodos futuros já criados sob demanda (D2); dois aparelhos agendando ao mesmo tempo → conflito pela fila existente.

### Entrega 60 — Tela "Período" em Mais
1. **Objetivo:** permitir ao usuário ver e mudar a configuração.
2. **Funcionalidades:** configuração atual, mudança agendada (se houver) com a data de início, formulário (reaproveita os campos de `period_setup_screen.dart`), confirmação com a data, histórico de períodos com a configuração de cada um.
3. **Regras:** RN001, RN002, RN042.
4. **Dependências:** 59.
5. **Arquivos:** `lib/features/periods/period_settings_screen.dart` (novo), `period_providers.dart`, `lib/features/more/more_screen.dart`, `lib/app/app.dart`; testes de tela em `test/features/periods/`.
6. **Banco:** nenhum.
7. **Testes:** tela mostra a data correta; confirmação; cancelar mudança; histórico; Web e celular.
8. **Aceitação:** o usuário entende, antes de confirmar, quando a mudança começa; o período atual e os anteriores continuam iguais no Dashboard e em Lançamentos.
9. **Riscos:** baixo.

### Entrega 61 — Domínio dos relatórios
1. **Objetivo:** concentrar os cálculos dos cinco relatórios em funções puras testáveis, reaproveitando a regra da sobra.
2. **Funcionalidades:** agrupamento por categoria (receitas e despesas, com "Sem categoria"); totais por período (receitas, despesas, investimentos, sobra) para uma lista de períodos. Os totais por período reaproveitam `computePeriodTotals` (nenhuma fórmula nova).
3. **Regras:** RN004, RN005, RN007, RN021–RN023, RN028–RN029, RN039, RN044, RN045.
4. **Dependências:** nenhuma (pode ser feita junto da 59).
5. **Arquivos:** `lib/core/domain/reports.dart` (novo) ou extensão de `surplus.dart`; `test/core/domain/reports_test.dart`.
6. **Banco:** nenhum.
7. **Testes:** soma por categoria = total da sobra; "Sem categoria"; cancelados, pendentes e variáveis sem valor fora; pago conta uma vez; investimento cancelado fora; rendimento como receita; sobra negativa; valores acima de 2^53 exatos; período sem lançamentos = zero.
8. **Aceitação:** para os mesmos lançamentos, os relatórios batem centavo a centavo com a sobra do Dashboard.
9. **Riscos:** nenhum relevante.

### Entrega 62 — Leitura dos dados dos relatórios (celular e Web)
1. **Objetivo:** buscar os dados de um ou vários períodos com desempenho adequado e sem truncamento.
2. **Funcionalidades:** `ReportsRepository` local (Drift, consultas agrupadas por período e categoria, somadas em `BigInt` no Dart) e remoto (Web, pela nova RPC de leitura agregada — D11). Os totais do Dashboard na Web também passam a usar a RPC, eliminando o limite de 1.000 linhas nas somas.
3. **Regras:** RN043, RN045; RF027.
4. **Dependências:** 61; D8, D11.
5. **Arquivos:** `lib/features/reports/reports_repository.dart` (novo), `lib/features/sync/remote_table_reader.dart`, `lib/features/totals/totals_repository.dart` (reaproveitar leitura), testes em `test/features/reports/`.
6. **Banco:** remoto — nova migration com a RPC de leitura agregada (somente leitura, isolada por usuário, mesmas regras de `surplus.dart`, valores devolvidos como texto) e teste SQL; índices `*_period_date_idx` e `*_category_date_idx` já existem. Local — índice por período só se a medição não atingir a RN043 (então Drift v5, snapshot em `drift_schemas/` e teste de migração).
7. **Testes:** equivalência local × remoto com os mesmos dados; mais de 1.000 lançamentos na Web; 12 períodos com ~5.000 lançamentos medidos no celular; isolamento por usuário.
8. **Aceitação:** mesmos números no celular e na Web; nenhuma leitura truncada; meta de 1 s para a tela com dados locais.
9. **Riscos:** truncamento silencioso (V2); somar no SQL com conversão numérica perderia exatidão — por isso a soma fica no Dart.

### Entrega 63 — Dashboard com composição da sobra
1. **Objetivo:** mostrar de onde vem a sobra.
2. **Funcionalidades:** linhas Receitas, Despesas e (conforme D1) Investimentos abaixo da sobra, todas do `periodTotalsProvider`.
3. **Regras:** RN005, RN022; D1.
4. **Dependências:** D1 (61 recomendada antes, para testes cruzados).
5. **Arquivos:** `lib/features/dashboard/dashboard_screen.dart`, `test/features/dashboard/`.
6. **Banco:** nenhum.
7. **Testes:** composição após incluir, editar, mudar data para outro período, pagar (não muda) e cancelar; período inexistente; Web.
8. **Aceitação:** receitas − despesas − investimentos exibidos = sobra exibida, sempre.
9. **Riscos:** revisão da D3 da Fase 6.

### Entrega 64 — Relatórios por categoria e investimentos (1, 2 e 3)
1. **Objetivo:** telas dos relatórios de um período.
2. **Funcionalidades:** Mais → Relatórios; seletor de relatório; período escolhido com o mesmo `PeriodNavigator`; lista por categoria com valor e participação; total de investimentos do período.
3. **Regras:** RN044; §13.7.
4. **Dependências:** 61, 62; D9, D10.
5. **Arquivos:** `lib/features/reports/` (telas e providers), `more_screen.dart`, `app.dart`; testes de tela.
6. **Banco:** nenhum.
7. **Testes:** "Sem categoria"; categoria desativada; atualização após edição/cancelamento; período sem dados; Web.
8. **Aceitação:** os totais dos relatórios 1–3 batem com a composição do Dashboard do mesmo período.
9. **Riscos:** baixo.

### Entrega 65 — Evolução da sobra e comparativo (4 e 5)
1. **Objetivo:** telas com vários períodos.
2. **Funcionalidades:** sequência de períodos (D8) com a sobra de cada um e o comparativo receitas/despesas/investimentos; visualização conforme D9.
3. **Regras:** RN002 (períodos com configurações diferentes), RN005, RN042.
4. **Dependências:** 62, 64; D8, D9.
5. **Arquivos:** `lib/features/reports/`; testes.
6. **Banco:** nenhum.
7. **Testes:** sequência que atravessa uma mudança de configuração; períodos futuros vazios; sobra negativa; desempenho com 12 períodos.
8. **Aceitação:** cada linha bate com o Dashboard do período correspondente.
9. **Riscos:** quantidade de períodos (desempenho na Web).

### Entrega 66 — Tema claro e escuro salvo na conta
1. **Objetivo:** RF026.
2. **Funcionalidades:** Mais → Tema; aplica `ThemeMode` em todo o app; celular grava localmente e envia pela fila; Web grava no servidor; tela de login usa o padrão (D4).
3. **Regras:** D4, D5.
4. **Dependências:** D4, D5.
5. **Arquivos:** `lib/app/app.dart`, `lib/features/preferences/` (novo: repositório local/remoto, provider, tela), `sync_models.dart`, `download_service.dart` (já baixa), `attention` (se D5 mantiver conflito visível); testes.
6. **Banco remoto:** nova migration `2026111200xx_user_preferences_write_rpc.sql` com RPC `set_user_theme` (cria a linha se não existir, idempotente, versão, auditoria) e teste SQL. **Banco local:** sem mudança de schema (`theme` já existe).
7. **Testes:** troca e persistência após reabrir; offline e envio posterior; segundo aparelho recebe o tema; repetição não duplica; Web; conflito conforme D5.
8. **Aceitação:** o tema escolhido acompanha a conta em Android e Web.
9. **Riscos:** política de conflito para preferência (D5).

### Entrega 67 — Onboarding com etapas opcionais
1. **Objetivo:** RF024.
2. **Funcionalidades:** assistente após o período obrigatório, com as etapas da D6; "Pular" e "Concluir depois"; Mais → Configuração inicial retoma as etapas pendentes; etapas concluídas não se repetem (D7). Absorve o fluxo atual de categorias sugeridas, sem mudar seu comportamento.
3. **Regras:** RN024; decisão de 10/11/2026 (período obrigatório antes do primeiro lançamento).
4. **Dependências:** 60, 66; D6, D7.
5. **Arquivos:** `lib/features/onboarding/` (novo), `period_providers.dart` (`pendingSuggestionsProvider`), `category_suggestions_screen.dart`, `more_screen.dart`, `app.dart`.
6. **Banco:** se D7 = conta: nova migration (coluna em `user_preferences` + RPC) e Drift v5 com snapshot e teste de migração; se D7 = aparelho: armazenamento local sem migration.
7. **Testes:** primeiro acesso completo; pular tudo; retomar em Mais; não repetir; segundo aparelho (se D7 = conta); Web sem etapa de PIN.
8. **Aceitação:** usuário novo consegue pular qualquer etapa opcional e retomá-la; usuário existente não vê o assistente de novo sem pedir.
9. **Riscos:** conteúdo das etapas sem definição aprovada (D6).

### Entrega 68 — Fechamento e regressão
1. **Objetivo:** validar a fase inteira.
2. **Funcionalidades:** roteiro de validação para o responsável (Android e Web).
3. **Testes:** `dart format`, `flutter analyze`, `flutter test`, `flutter test --platform chrome` nos módulos alterados, suíte PostgreSQL; regressão de lançamentos, recorrências, investimentos, sincronização, conflitos e alertas; medições da RN043.
4. **Aceitação:** todos os testes passam; roteiro validado; documentos atualizados (seção 10).

## 7. Alterações previstas no banco

| Onde | Alteração | Entrega | Condição |
|---|---|---|---|
| Servidor | Nova migration: RPC `schedule_period_configuration` | 59 | Sempre |
| Servidor | Nova migration: RPC de leitura agregada para relatórios e totais da Web (D11) | 62 | Sempre |
| Servidor | Nova migration: RPC `set_user_theme` | 66 | Sempre |
| Servidor | Coluna de progresso do onboarding em `user_preferences` + RPC (D7) | 67 | Sempre (pode ir na mesma migration da 66) |
| Drift | v5: coluna do onboarding (D7) e, se a medição exigir, índice por período | 62/67 | Sempre (D7) |

Nenhuma migration existente será editada. Nada será aplicado no Supabase gerenciado (Fase 8).

## 8. Riscos

| Risco | Tipo | Mitigação |
|---|---|---|
| Totais da Web truncados em 1.000 linhas (V2) | Financeiro (valor errado sem aviso) | Soma no servidor (D11) e teste com mais de 1.000 linhas |
| Regra da sobra em dois lugares (app e servidor, D11) | Financeiro (divergência) | Testes de equivalência com os mesmos dados nas duas implementações (RF027) |
| Mudança de configuração com períodos futuros já criados | Financeiro/períodos | D2; nunca recalcular períodos existentes |
| Dois aparelhos mudando a configuração offline | Sincronização | Controle de versão e tela de atenção existentes |
| Relatório divergir do Dashboard | Financeiro | Uma única regra (`surplus.dart`); testes que comparam os dois |
| Soma em SQL perder exatidão | Financeiro | Somar em `BigInt` no Dart |
| Desempenho com muitos períodos (Web online) | Técnico | Ler só os períodos exibidos (D8), paginação, medir RN043 |
| Nova dependência de gráficos (D9) | Técnico | Avaliar antes de instalar; aprovação do responsável |
| Troca de "sobra" por "dinheiro livre" (D6); nome pode sugerir saldo disponível | Terminologia | Entrega 59A; só textos visíveis e documentos canônicos; fórmula inalterada |

## 9. Decisões que dependem da aprovação do responsável

| # | Pergunta | Opções | Recomendação |
|---|---|---|---|
| D1 | O Dashboard mostra o total de investimentos na composição da sobra? (V1) | (a) Sim: receitas, despesas e investimentos — revisa a D3 da Fase 6; (b) Não: só receitas e despesas, e a conta não fecha visualmente | (a) |
| D2 | Se já existirem períodos futuros criados sob demanda, quando a nova configuração começa? | (a) Após o último período existente, com aviso da data; (b) bloquear a mudança enquanto houver períodos futuros | (a) — nunca altera períodos existentes |
| D3 | Pode-se trocar ou cancelar uma mudança já agendada antes de ela começar? | (a) Sim, enquanto nenhum período a usar; (b) não | (a) |
| D4 | Tema antes de o usuário escolher (e na tela de login) | (a) Segue o tema do aparelho/navegador; (b) Claro | (a) |
| D5 | Tema alterado em dois aparelhos sem conexão | (a) Vale a última gravação enviada, sem tela de conflito (preferência visual, não financeira — exceção explícita à regra de conflitos); (b) mostrar em "Itens que precisam de atenção" | (a) |
| D6 | Etapas do onboarding | Propostas: apresentação da sobra; categorias sugeridas; tema; PIN/biometria (celular); orientação de recorrências. Pode retirar ou incluir | Aprovar a lista |
| D7 | Onde guardar o progresso do onboarding | (a) Na conta (nova coluna + migration + Drift v5); (b) só no aparelho (pode reaparecer em outro aparelho ou na Web) | (a) |
| D8 | Quais períodos aparecem nos relatórios 4 e 5 | (a) Últimos 12 períodos existentes até o selecionado, navegando para trás; (b) todos os períodos | (a) |
| D9 | Visualização | (a) Listas e barras simples feitas com componentes do Flutter, sem nova biblioteca; (b) biblioteca de gráficos (ex.: `fl_chart`) | (a) |
| D10 | Relatórios 1 e 2 detalham subcategorias? | (a) Só categoria; (b) categoria com subcategorias | (a) — subcategoria fica como sugestão futura |
| D11 | Corrigir o limite de 1.000 linhas da leitura Web (V2) | (a) Paginação no app, mesma regra de cálculo; (b) função de soma no servidor (nova migration, segunda implementação da regra) | (a) |

### 9.1 Decisões do responsável (11/11/2026)

| # | Decisão | Efeito no plano |
|---|---|---|
| D1 | **(a)** Dashboard mostra receitas, despesas e investimentos | Revisa a D3 da Fase 6; Entrega 63 inclui a linha de investimentos |
| D2 | **(a)** Nova configuração começa após o último período existente, com aviso da data | Entrega 59 |
| D3 | **(a)** Mudança agendada pode ser trocada ou cancelada enquanto nenhum período a usar | Entrega 59 |
| D4 | **(a)** Sem escolha, o tema segue o aparelho/navegador | Entrega 66 |
| D5 | **(a)** Tema: vale a última gravação enviada, sem tela de conflito (exceção explícita à política de conflitos, só para a preferência de tema) | Entrega 66; registrar em `regras_negocio.md`/`arquitetura.md` |
| D6 | Etapas aprovadas. **(b)** O indicador muda de nome no app inteiro: **"Dinheiro livre do período"** (revisão confirmada, ver nota) | Nova Entrega 59A (abaixo), antes das telas novas |
| D7 | **(a)** Progresso do onboarding salvo na conta | Entrega 67: coluna em `user_preferences` + RPC (nova migration) e Drift v5 |
| D8 | **(a)** Relatórios 4 e 5: últimos 12 períodos até o selecionado, navegando para trás | Entregas 62 e 65 |
| D9 | **(b)** Biblioteca de gráficos | Entregas 64/65 começam pela avaliação da biblioteca (manutenção, licença, compatibilidade Android/Web, tamanho) e aprovação antes de instalar; candidata `fl_chart` |
| D10 | **(a)** Relatórios por categoria sem subcategorias | Entrega 64 |
| D11 | **(b)** Soma feita no servidor por função de leitura | Entrega 62: nova migration com RPC de leitura agregada (totais por período e por categoria, valores devolvidos como texto exato); a Web (Dashboard e relatórios) passa a usá-la; testes de equivalência celular × servidor obrigatórios |

**Nota D6 — Entrega 59A: troca do nome "sobra" → "dinheiro livre".**
- Muda só o **nome** exibido. A fórmula (receitas − despesas − investimentos), as regras e os dados continuam iguais.
- **App:** textos visíveis em `dashboard_screen.dart`, `entry_form_screen.dart` e `transactions_screen.dart` (8 textos hoje) e nas telas novas da Fase 7 (relatórios 4 e 5: "Evolução do dinheiro livre entre períodos").
- **Não muda:** nomes internos do código (`surplus`, `Key('valor-sobra')`), banco e funções do servidor — evita retrabalho sem efeito para o usuário.
- **Documentos canônicos** atualizados juntos (AGENTS.md §4.2 e §10, `requisitos.md`, `regras_negocio.md` RN005, `arquitetura.md`, `banco_de_dados.md`, `roadmap.md`, `estado_atual.md`), com registro da decisão e data (AGENTS §10.8). Os registros históricos (`entregas_fase3.md` a `entregas_fase6.md`, `historico/`) não são reescritos.
- **Testes:** testes de tela que procuram os textos antigos são ajustados; regressão do Dashboard e Lançamentos.
- **Revisão de 11/11/2026 — APROVADO pelo responsável:** o nome é **"Dinheiro livre do período"** (no lugar de "prazeres"); frases como "entra na sobra" viram "entra no dinheiro livre". Ciente do conflito com as exclusões atuais (AGENTS.md §4.1/§4.2; `requisitos.md` §1, §3.2, RF019–RF020, §10, §12; `regras_negocio.md` princípio 4 e RN005; `arquitetura.md` §1), o responsável confirmou a opção (a): na Entrega 59A esses textos serão reescritos para deixar claro que **"dinheiro livre" passa a ser o nome do indicador `receitas − despesas − investimentos` do período**, e que continuam FORA DO MVP o cálculo com reservas, compromissos separados, saldo disponível, saldo atual e saldo bancário (antigo Porquinho virtual). O valor não considera sobras de períodos anteriores nem saldo bancário.

**Nota D11:** a RPC resolve as somas. As listas de lançamentos da Web continuam limitadas a 1.000 linhas por consulta (`remote_table_reader.dart`); risco baixo (exige mais de 1.000 lançamentos de um tipo em um período) e fica registrado como pendência, sem correção nesta fase.

## 10. Documentos a atualizar durante a implementação

| Documento | O que muda |
|---|---|
| `docs/estado_atual.md` | Fase 7 em andamento/concluída, entregas, pendência "user_preferences sem RPC" resolvida, pendência técnica 4 (relatórios) resolvida |
| `docs/roadmap.md` | Plano 59–68 e status da Fase 7 |
| `docs/requisitos.md` | RF016 e §5 conforme D1; RF024 (etapas — D6/D7); RF026 (D4); §13.7 (D8, D10) |
| `docs/regras_negocio.md` | RN002: detalhamento da mudança com períodos futuros e reagendamento (D2, D3); exceção de conflito do tema (D5) se aprovada |
| `docs/arquitetura.md` | §15 item dos relatórios; módulos `reports`, `preferences`, `onboarding`; paginação Web (D11); política de conflito do tema (D5) |
| `docs/banco_de_dados.md` | §16.9 novas RPCs; §16.10 Drift (v5, se houver); correção V3 |
| `docs/entregas_fase6.md` | Nota de revisão da D3, se D1 = (a) |

## 11. Plano de testes (resumo)

| Área | Testes |
|---|---|
| Períodos | mês-calendário; ciclo; dias 29–31; fevereiro comum e bissexto; transição em todas as combinações; vigência no próximo período; histórico preservado; períodos futuros existentes (D2); reagendar/cancelar (D3); equivalência local × servidor; idempotência |
| Sobra e composição | composição = sobra; edição, mudança de data entre períodos, pagamento sem segunda dedução, cancelamento |
| Relatórios | por categoria com "Sem categoria"; categoria desativada/renomeada; investimentos por período; evolução e comparativo atravessando mudança de configuração; recorrências pendentes fora; rendimento como receita; > 1.000 linhas na Web; exatidão em `BigInt` |
| Tema | aplicar, persistir, offline, outro aparelho, Web, idempotência |
| Onboarding | primeiro acesso, pular, retomar, não repetir, Web |
| Regressão | suítes existentes de lançamentos, recorrências, investimentos, sincronização, atenção, alertas e banco (PostgreSQL e Drift) |
| Desempenho | RN043: Dashboard ≤ 1 s, cálculo ≤ 300 ms, relatórios com 12 períodos |

## 12. Fora da Fase 7

Carteira, rentabilidade, corretoras/Open Finance, previsões, IA, exportação/CSV e relatórios avançados, ambientes hospedados e publicação (Fase 8).

## 13. Sugestões futuras (não incluídas)

- Detalhar subcategorias nos relatórios por categoria.
- Mostrar no Dashboard, separado da sobra, quanto de receita recorrente ainda está pendente de confirmação (seria indicador novo; exige decisão).
- Filtro de relatórios por intervalo de datas livre.
