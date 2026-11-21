# Relatórios (central modular e personalizável) — especificação

**Status:** decisões de produto e arquitetura APROVADAS pelo responsável na discussão de 17/11/2026 (§10) e plano de entregas aprovado (§12). **RL1–RL7 implementadas em 17/11/2026 e validadas pelo responsável em 18/11/2026**; migration aplicada em homologação (testes passaram em 19/11/2026). Requisito: RF025 e `requisitos.md` §13.7 (sem mudança de conteúdo nem de cálculo). Acompanhamento: `entregas_fase8.md` §9.

## 1. Para que serve
Transformar a ferramenta Relatórios numa central em que cada usuário escolhe quais relatórios quer ver, organiza a própria área e acrescenta novos relatórios conforme forem disponibilizados, sem precisar abrir um relatório de cada vez.

## 2. Escopo e limites
- Continua sendo uma ferramenta da aba Ferramentas; rota `/relatorios` preservada. Android e Web com paridade funcional.
- Os cinco relatórios do RF025 (§13.7) são preservados, com os mesmos cálculos:
  1. Receitas por categoria e período.
  2. Despesas por categoria e período.
  3. Total destinado a investimentos por período.
  4. Evolução do dinheiro livre entre períodos.
  5. Comparativo de receitas, despesas e investimentos por período.
- Sem mudança de regra financeira: dinheiro livre = receitas contabilizadas − despesas contabilizadas − investimentos; intervalos `PeriodRange` `[início, fim)`; configuração de período do usuário; cancelados fora; receitas pendentes não contam; centavos inteiros.
- Fora: saldos bancários, carteira, rentabilidade, projeções, estimativas, dados fictícios (inclusive em prévias e gráficos), cálculo financeiro duplicado. `core/domain/reports.dart`, `surplus.dart` e a RPC `get_range_report` não mudam.
- Novos relatórios: só com aprovação própria.

## 3. Situação anterior (diagnóstico de 17/11/2026)
- `lib/features/reports/`: `reports_screen.dart` (menu suspenso com `enum ReportKind` e `switch`; um relatório por vez), `reports_providers.dart` (`selectedPeriodReportProvider` para 1–3; `periodSeriesProvider`, 12 períodos até o selecionado, D8, para 4–5), `reports_repository.dart` (celular: banco local; Web: `get_range_report`, lotes de 60), `series_chart.dart` (`fl_chart`).
- O mesmo repositório alimenta os totais da Web (`totals_repository.dart`): não pode mudar.
- Limitações: lista fechada (enum), tela conhece cada relatório pelo nome, sem resumo, sem preferências, layout anterior à renovação visual (V8).

## 4. Experiência

### 4.1 Primeiro acesso — configuração guiada
- Frase curta sobre a finalidade; os relatórios em **cartões leves selecionáveis** (ícone, nome, benefício, tipo de visualização), **sem prévia**.
- Os **cinco vêm marcados**, na ordem do RF025.
- **Concluir**: desativado com nenhum marcado ("Escolha ao menos um relatório ou toque em Pular").
- **Pular**: marca a configuração como pulada e mostra a lista sugerida (os cinco).
- Aviso: "Você pode mudar isso depois em Personalizar".
- Todos os usuários (inclusive quem já usava Relatórios) veem a configuração **uma vez**.

### 4.2 Meus relatórios (tela principal de `/relatorios`)
- Seletor de período no topo: o mesmo da Home (trocar aqui troca lá).
- Cartões na ordem do usuário; "+ Adicionar relatório" e "Personalizar".
- Celular: 1 coluna; Web larga: 2 colunas.
- Lista vazia (usuário removeu todos em Personalizar): convite para abrir o catálogo.

### 4.3 Três níveis de cada relatório (opção híbrida)
- **Compacto** → tocar expande na própria lista → **Expandido** → "Ver tudo" abre a **Tela completa** (`/relatorios/<id>`); "Recolher" fecha.
- Ao entrar, tudo recolhido; estado aberto/fechado **não é salvo**; vários podem ficar abertos; ao expandir, a tela rola até o cartão; na Web larga o expandido ocupa a largura toda.
- Tela completa: seletor de período no topo (mesmo período global), barra inferior com Ferramentas selecionada, Voltar (Android e navegador) retorna à lista.
- Endereço com ID inexistente → volta para `/relatorios`, sem erro. Relatório removido de "Meus relatórios" continua abrindo pela tela completa (remover só tira da lista).

### 4.4 Conteúdo por nível
"Sequência" = últimos 12 períodos até o selecionado (D8). Mini-gráfico = desenho pequeno, sem eixos nem números.

| Relatório | Compacto | Expandido | Tela completa |
|---|---|---|---|
| 1. Receitas por categoria | Total recebido no período; "Maior: <categoria> · <%>"; barra dividida com as maiores categorias (cores delas) | Total + 5 maiores categorias (ícone, valor, %, barra) + "+N categorias" | Total + lista completa (como hoje) com ícone e cor; "Sem categoria" mantida |
| 2. Despesas por categoria | Igual ao 1 (pendentes e pagas) | Igual ao 1 | Igual ao 1 |
| 3. Total destinado a investimentos | Total do período; mini-gráfico com o investimento de cada período da sequência | Total + gráfico de barras por período | Total + gráfico + lista período a período |
| 4. Evolução do dinheiro livre | Dinheiro livre do período (vermelho se negativo); mini-gráfico de barras da sequência; "R$ X a mais/a menos que o período anterior" | Gráfico de barras + os 3 períodos mais recentes | Gráfico + lista dos 12 períodos (como hoje) |
| 5. Comparativo | Os três totais do período; barra dividida proporcional entre os três | Gráfico agrupado da sequência + legenda | Gráfico + cartão por período com dinheiro livre (como hoje) |

Regras:
- Percentual das categorias (relatórios 1 e 2): uma casa decimal, arredondada com meio para cima (88,79% → 88,8%; 12,35% → 12,4%); só exibição, os valores seguem em centavos (A10, decidido pelo responsável em 21/11/2026).
- Período sem lançamentos: o compacto mostra a frase de vazio atual (ex.: "Nenhuma receita recebida neste período."), nunca gráfico zerado.
- Gráficos usam `double` só para desenhar; todo valor escrito vem dos centavos exatos.
- "+N categorias" e a parte "demais" da barra do compacto **não mostram soma nova** (só desenho).
- Relatório 3 mostrando a sequência: aprovado (mesmos totais de investimento já usados no relatório 5).
- "A mais/a menos que o período anterior" (relatório 4): **número novo aprovado** = dinheiro livre do período selecionado − dinheiro livre do período anterior da sequência, subtração em centavos no domínio, com teste; sem período anterior, o texto não aparece.

### 4.5 Catálogo
- Grupos em ordem fixa: **Visão geral** (4, 5), **Receitas e despesas** (1, 2), **Investimentos** (3).
- Cada item: nome, benefício, categoria, tipo de visualização, **prévia com os dados reais** (o próprio cartão compacto, período selecionado; período vazio → ícone e descrição), "Adicionar" e "Ver relatório" (abre a tela completa).
- Tipos de visualização: "Barras por categoria" (1, 2), "Barras por período" (3, 4), "Barras agrupadas por período" (5) — textos ajustáveis na validação.
- Já escolhidos: "Em Meus relatórios", sem botão de adicionar. Adicionar = um por vez, entra no fim de "Meus relatórios".
- Sem busca nem filtro por enquanto (entram quando houver cerca de 8 relatórios, em entrega própria).

### 4.6 Personalizar
- Arrastar para ordenar; remover ("seus dados não são apagados"); abrir o catálogo.
- "Restaurar configuração inicial", com confirmação: volta aos cinco na ordem do RF025, **sem** reabrir a configuração guiada.
- Configurações individuais por relatório: **nenhuma nesta versão** (§7).

## 5. Persistência e sincronização
- Coluna própria **`user_preferences.reports`** (JSONB), separada de `tools` (o celular regrava `tools` inteiro e apagaria uma chave extra).
- Formato:
  ```json
  { "setup": "done" | "skipped", "selected": ["income_by_category", "..."], "options": {} }
  ```
  `setup` ausente = configuração guiada ainda não feita; `selected` ausente = lista sugerida; `options` reservado (lido e preservado, não usado).
- IDs estáveis (formato `^[a-z][a-z0-9_]{0,63}$`, nunca reaproveitar): `income_by_category`, `expense_by_category`, `investments_total`, `free_money_evolution`, `period_comparison`. O servidor valida só o formato (sem lista fixa). IDs desconhecidos (de outra versão do app) são preservados no fim da lista e não exibidos.
- RPCs novas, no padrão de `set_tool_selection`/`dismiss_tool_intro` (idempotência por `applied_sync_operations`, auditoria, `SECURITY DEFINER`): `set_report_selection(p_operation_id, p_report_ids)` (`NULL` = lista sugerida) e `complete_report_setup(p_operation_id, p_status)`.
- **Conflito entre aparelhos (aprovado 17/11/2026, mesma exceção à RN033 das Ferramentas):** lista e ordem = a última gravação vence; `setup` se soma (feito em qualquer aparelho, não volta).
- Celular: banco local + fila (`PreferencesRepository`, entidade `user_preferences`), Drift v11 com a coluna `reports` (snapshot e migração testada); download da linha de preferências passa a trazer a coluna (servidor sem a coluna → padrão). Web: RPC direta.

## 6. Arquitetura (proposta técnica)
```
lib/features/reports/
  models/report_definition.dart   ReportDefinition, ReportCategory, ReportVisualization, ReportDataNeed
  models/report_preferences.dart  setup, selected, options
  registry/report_registry.dart   os 5 relatórios
  domain/report_catalog.dart      puro: selecionados, disponíveis, add, remove, move, restaurar
  report_preferences_controller.dart
  reports_repository.dart / reports_providers.dart   sem mudança
  screens/  reports_home, report_setup, report_catalog, manage_reports, report_detail
  widgets/report_card.dart        moldura: compacto/expandido, carregando, erro
  modules/<id>/                   compacto, expandido e tela completa de cada relatório
```
- Cada `ReportDefinition` declara ID, nome, benefício, ícone, categoria, tipo de visualização, dados necessários (período selecionado ou sequência), posição na lista sugerida e os construtores dos três níveis. A tela percorre o registro; não conhece relatório pelo nome (sem `switch` nem enum).
- Os módulos consomem os providers existentes; cinco cartões continuam gerando 2 leituras (período e sequência).
- Erro em um cartão: "Tentar de novo" só nele.

### 6.1 Novo relatório no futuro
Criar o módulo (três níveis + cálculo de domínio com testes, se houver cálculo novo, com aprovação) e registrar a definição. Não mudam: telas, catálogo, configuração guiada, personalização, formato salvo, RPCs, Drift, migrations. O relatório novo entra **fora** da lista sugerida (não altera a lista de ninguém) e aparece no catálogo. Exceções: dados que os providers atuais não trazem exigem consulta local + RPC nova (migration e teste de equivalência); o primeiro uso de `options` exige RPC própria.

## 7. Configurações individuais
Nenhuma nesta versão (aprovado 17/11/2026). D8 (12 períodos) mantida. Quantidade de períodos ou tipo de gráfico, se desejados, vêm como entrega própria.

## 8. Testes previstos
- Domínio: catálogo puro (adicionar, remover, mover, restaurar, IDs desconhecidos); diferença do relatório 4 (com e sem período anterior, negativos).
- Preferências: leitura/gravação do JSON; repositório local (registro, auditoria e fila) e remoto (parâmetros das RPCs); download da coluna.
- Banco: migração Drift v10→v11 com dados; suíte SQL das RPCs (idempotência, validação, isolamento, auditoria); catálogo de segurança; integração com dois aparelhos (última lista vence, `setup` se soma).
- Tela: configuração guiada (Concluir/Pular), níveis compacto/expandido/completo, rota com ID inexistente, catálogo (prévia, já escolhido, adicionar), Personalizar (ordenar, remover sem apagar dados, restaurar com confirmação, lista vazia); testes atuais adaptados, mantendo as mesmas verificações de valores; equivalência celular × Web dos relatórios inalterada.

## 9. Impacto nos documentos (ao implementar)
`mapa_app.md` (módulo reports e rota `/relatorios/<id>`), `banco_de_dados.md` (coluna e RPCs), `arquitetura.md` (preferências de relatórios), `estado_atual.md`, `pendencias.md`.

## 10. Decisões aprovadas (17/11/2026)
| # | Assunto | Decisão |
|---|---|---|
| 1 | Onde salvar | Coluna própria `user_preferences.reports` + RPCs + Drift v11 (§5) |
| 2 | Conflito entre aparelhos | Lista: última gravação vence; configuração feita: se soma |
| 3 | Detalhes | Híbrido: compacto → expandido na lista → tela completa `/relatorios/<id>`, com as cinco regras da §4.3 |
| 4 | Conteúdo por nível | Tabela da §4.4; relatório 3 com sequência: sim; "a mais/a menos" no relatório 4: sim |
| 5 | Prévia | Catálogo com dados reais (ícone se vazio); configuração guiada sem prévia |
| 6 | Configuração guiada | Cinco marcados, ordem do RF025, Pular = lista sugerida, Concluir exige ≥1, todos veem uma vez; Restaurar não reabre a configuração |
| 7 | Configurações individuais | Nenhuma agora; `options` reservado |
| 8 | Categorias do catálogo | Visão geral, Receitas e despesas, Investimentos; sem busca/filtro por enquanto |

## 11. Ideias não decididas
- Selo "Novo" no catálogo para relatórios recém-lançados.
- Busca e filtro no catálogo (a partir de ~8 relatórios).

## 12. Entregas (uma por vez; cada uma com autorização e validação)
| ID | Entrega | Para o usuário | Testes |
|---|---|---|---|
| RL0 | Esta especificação, nota no RF025 e registro em `pendencias.md` (encerra Relatórios na V8) | Nada no app | — |
| RL1 | Base das preferências: migration (coluna `reports`, `set_report_selection`, `complete_report_setup`), Drift v11 + snapshot, download, modelo e repositório (celular com fila, Web direto). Só no Supabase local | Nada visível | SQL, segurança, migração Drift, repositório local/remoto |
| RL2 | `ReportDefinition`, registro dos 5, catálogo puro, controller | Nada visível | Unitários |
| RL3 | Tela Meus relatórios, moldura do cartão (compacto/expandido/"Ver tudo"), rota `/relatorios/<id>`, relatórios 1 e 2 nos três níveis (3–5 no formato atual dentro do cartão) | Nova tela com os cinco | Tela, regras §4.3, testes atuais adaptados |
| RL4 | Relatórios 3, 4 e 5 nos três níveis + diferença do relatório 4 | Todos no formato novo | Domínio e tela |
| RL5 | Configuração guiada | Primeiro acesso | Tela e gravação |
| RL6 | Catálogo e Personalizar | Personalização completa | Tela e gravação |
| RL7 | Integração com dois aparelhos (Supabase local), emulador claro/escuro, atualização dos docs (§9) | Validação final | Suíte completa e integração |

Homologação (`norte-homologacao`) só com autorização do responsável (R2), depois da RL7. Web conferida pelo responsável (T9).
