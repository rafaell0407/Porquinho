# Entregas da Fase 6 — Investimentos simples e rendimentos manuais (plano)

**Status:** plano APROVADO em 11/11/2026 (decisões D1–D10, seção 5). Entregas 51–58 IMPLEMENTADAS e testadas em 11/11/2026 (a 54 foi removida por D3); **VALIDADAS pelo responsável em 11/11/2026** (roteiro na seção 9). Estado vigente: `docs/estado_atual.md`.

## 1. Objetivo e escopo
Permitir registrar quanto foi destinado a investimentos, uma vez ou de forma recorrente, descontar esse valor da sobra, mostrar o total destinado no período e permitir que rendimentos efetivamente recebidos sejam lançados como receitas comuns.

Dentro: investimento como terceiro tipo de lançamento ("Novo investimento", ao lado de receita e despesa — D10), com valor e data; criação, edição e cancelamento; recorrência mensal ou por período, com valor alterável por ocorrência (D7–D9); investimentos na lista de Lançamentos com filtro próprio; dedução da sobra (RN005, RN021–RN023, RN027); rendimento como receita comum (RN007); offline no Android e online na Web (RN031); sincronização idempotente com conflitos (RN032–RN033); auditoria (RN028–RN030). RFs: RF016, RF017, RF018, RF020, RF021, RF022, RF027.

Fora (fases posteriores ou fora do MVP): categoria, descrição, status pendente/pago, vencimento e alertas de investimento; carteira, ativos, classes, instituições, quantidade, custódia, cotação, rentabilidade, marcação a mercado, compra/venda; integração com corretoras/bancos/Open Finance; importação automática; cálculo de rendimento (taxa fixa/CDI); saldo investido acumulado; total investido no Dashboard (D3 — fora da Fase 6; o total por período fica para o relatório da Fase 7); atalho de rendimento (D4); relatórios e composição completa da sobra (Fase 7); desfazer cancelamento (Fase 4, D7).

## 2. Diagnóstico — o que já existe (não refazer)
| Item | Onde | Situação |
|---|---|---|
| Tabela `investment_allocations` (valor ≥ 0 obrigatório, data, período, `cancelled_at`, versão, timestamps; sem descrição/categoria/status) | `supabase/migrations/20261109000100_initial_schema.sql` | Pronta para avulso; sem campos de recorrência |
| RPC `apply_investment_allocation_change` (criar, editar, cancelar; período por `[início, fim)`; versão; idempotência; auditoria; conflito) | `20261109000500_investment_allocation_rpc.sql`, teste `supabase/tests/rpc_investment_allocation_test.sql` | Pronta; Entrega 7A **sem validação registrada** |
| Resolução de conflito de investimento | `20261110000100_sync_conflict_resolution_rpc.sql` | Pronta (só avulso) |
| Tabela local Drift `InvestmentAllocations` + índice por período | `lib/core/local_database/app_database.dart` (schema v3) | Pronta para avulso |
| Download das destinações (celular) | `lib/features/sync/download_service.dart` | Pronto |
| Envio genérico pela fila (tipo `investment_allocation`) | `lib/features/sync/sync_service.dart`, `local_change_recorder.dart` | Pronto (falta quem grave na fila) |
| Sobra = receitas − despesas − investimentos não cancelados | `lib/core/domain/surplus.dart`, `lib/features/totals/totals_repository.dart` (local e Web), `test/core/domain/surplus_test.dart` | Pronta |
| Recorrência de receitas/despesas: agenda, identificador determinístico, geração no app e no servidor, "Repetir" no formulário, Mais → Recorrências | `lib/core/domain/recurrence_schedule.dart`, `lib/features/recurrence/`, `20261111000300_recurrence_generation_v2.sql` | Pronta; reaproveitável, mas só conhece receita e despesa |
| Rótulo "Investimento" na tela de atenção | `lib/features/attention/attention_models.dart` | Parcial: resumo genérico, sem valor/data |
| Categoria sugerida "Rendimentos" (receita) | RN024 / Fase 4 D13 | Pronta |

Não existe: modelo, repositórios, serviço e telas de investimento no app; opção "Novo investimento"; total no Dashboard; investimentos em Lançamentos; **qualquer estrutura de recorrência de investimento** (modelo, campos de ocorrência, unicidade, geração, RPCs, download).

**Conclusão:** o investimento avulso (Entregas 51–54) não exige migration nem Drift novo. A recorrência (Entregas 55–57) exige **nova migration** e **Drift v4**.

## 3. Regras financeiras aplicáveis
**Já aprovadas:**
- **Registro:** valor (BRL em centavos, ≥ 0, até 2 casas, zero permitido — RN045) e data (RN021, RN027). Sem categoria, descrição, ativo, instituição ou status pendente/pago (RN022–RN023, D2).
- **Sobra:** o valor sai da sobra do período da data do investimento, no momento do registro (RN004, RN005, RN022). Total do período = soma dos investimentos não cancelados (RN023).
- **Rendimentos:** receitas comuns, lançadas pelo usuário, somam pela data de recebimento (RN007, RN008). Nenhum cálculo automático.
- **Duplicidade:** cada lançamento deduz uma única vez; repetir o envio não duplica (RN033). O app não detecta duplicidade criada pelo usuário (princípio da RN006).
- **Edição/cancelamento:** a qualquer momento; cancelado sai da sobra e fica no histórico; mudar a data move o valor de período; auditoria (RN028–RN030).
- **Períodos passados:** não há fechamento; continuam editáveis (RN042).
- **Retroativos/futuros (D1):** data passada ou futura aceita; período inexistente → o app pergunta se cria os períodos (RN002); sem confirmação, não salva.

**Recorrência (D7–D9, aprovadas em 11/11/2026):** ver seção 5.

## 4. Divergências encontradas (registradas, não corrigidas)
| # | Divergência | Fontes |
|---|---|---|
| V1 | Data do investimento: "registrada pelo sistema" × "valor e data" | `requisitos.md` RF016–RF017, `roadmap.md` Fase 6 × RN021, RN027, RN028, `banco_de_dados.md` §5.9, `AGENTS.md` §4.5. **Resolvida por D1**; documentos a atualizar |
| V2 | "Sem descrição" × "sem descrição obrigatória" | RN021 × `AGENTS.md` §4.5, `banco_de_dados.md` §5.9. **Resolvida por D2** (sem descrição) |
| V3 | Dashboard só com a sobra na Fase 4 × total de investimentos no Dashboard na Fase 6 | `entregas_fase4.md` D9 × `requisitos.md` RF016 e `roadmap.md` Fase 6. **Resolvida por D3** (sem total no Dashboard na Fase 6); `requisitos.md` RF016 e `roadmap.md` a atualizar |
| V4 | `estado_atual.md` diz que a Fase 5 está sem commit; o Git mostra o commit `1f97003` "conclui fase 5" | `estado_atual.md` × `git log`/`git status` |
| V5 | `entregas_fase5.md` diz "aguardando validação"; `estado_atual.md` diz "validadas" | os dois arquivos |
| V6 | Bloco "Decisões de 11/11/2026 (Fase 5)" repetido na RN038 | `regras_negocio.md` |
| V7 | Tela de atenção mostra conflitos de investimento sem valor/data | `lib/features/attention/attention_models.dart` |
| V8 | Recorrência pedida para investimentos × regras que só preveem recorrência de receita e despesa e investimento sem confirmação posterior | RN010, RN014, RN022, RN038, `AGENTS.md` §4.5. **Resolvida por D7–D9**; documentos a atualizar |

## 5. Decisões
**Aprovadas pelo responsável em 11/11/2026:**
- **D1:** a data é informada pelo usuário (padrão hoje), como na despesa; aceita passada ou futura; pode ser alterada na edição.
- **D2:** investimento tem só valor e data: sem descrição, categoria, status pendente/pago ou vencimento.
- **D10 (interface):** "Novo investimento" entra na mesma lista de "Nova receita" e "Nova despesa" em Lançamentos e usa o mesmo formulário da despesa, mostrando só os campos aplicáveis (valor, data, "Repetir") e textos adaptados.
- **D3:** total investido no Dashboard não é necessário no MVP; fica fora da Fase 6. Os investimentos aparecem na lista de Lançamentos (com filtro "Investimentos"); o total por período continua previsto no relatório da Fase 7 (`requisitos.md` §13.7). Entrega 54 removida.
- **D4:** nenhuma tela ou atalho de rendimento; rendimento é receita comum (categoria "Rendimentos" já sugerida).
- **D7:** recorrência igual à despesa recorrente (Fase 5 D1, D2, D4, D7, D8): "Repetir" todo mês ou todo período no formulário; o próprio lançamento é a primeira ocorrência; geração ao abrir e sincronizar, recuperando atrasadas; identificador determinístico; mudanças no modelo valem só para as próximas; "parar de repetir" mantém as já geradas; consulta em Mais → Recorrências. A ocorrência entra na sobra quando gerada, no período da data programada, sem confirmação.
- **D8:** valor fixo com edição por ocorrência: cada mês nasce com o valor padrão; o usuário altera o valor daquele mês ("só esta") ou das próximas ("a recorrência"). Sem valor variável e sem investimento sem valor.
- **D9:** investimento recorrente não tem pendente/pago, vencimento nem alertas.

- **D5:** não existe resgate no Porquinho. O valor investido não volta para a sobra; novas despesas devem ser cobertas pela sobra livre. A orientação é não lançar resgate como receita. Se o usuário quiser desfazer um investimento, ele cancela o lançamento: o valor volta à sobra **do período original do investimento** (RN029–RN030), não do período atual. (O app não impede que o usuário lance qualquer receita — RN007 —, mas não oferece nem orienta o resgate.)
- **D6:** conflito de investimento oferece "Manter do aparelho", "Manter do servidor" e **"Editar"** (valor e data), igual a receitas e despesas; mostra valor e data das duas versões.

Sugestões futuras (não incorporadas): descrição/observação; desfazer cancelamento; relatório de investimentos por período (já previsto na Fase 7).

## 6. Entregas
Numeração continua da Fase 5. Banco remoto só por nova migration, sem editar as existentes. Drift v4 só a partir da Entrega 55, com snapshot em `drift_schemas/` e teste de migração.

### Entrega 51 — Domínio e gravação de investimentos avulsos (sem tela)
1. **Objetivo:** gravar, editar e cancelar investimentos no aparelho (fila) e na Web (RPC), com as mesmas validações da RPC.
2. **Funcionalidades:** modelo; serviço criar/editar/cancelar; leitura do período; períodos sob demanda (`PeriodMissingException`); cancelado não pode ser alterado.
3. **Regras:** RN004, RN021–RN023, RN027–RN033, RN045; D1, D2.
4. **Dependências:** Fases 2–5.
5. **Arquivos:** novos em `lib/features/investments/` (`investment_models.dart`, `investment_repository.dart`, `local_investment_repository.dart`, `remote_investment_repository.dart`, `investment_service.dart`, `investment_providers.dart`); `lib/features/entries/entry_providers.dart` (`refreshFinanceData`).
6. **Banco:** nenhuma mudança. Local: registro + auditoria + fila na mesma transação, com dependência do período.
7. **Testes:** serviço (valor obrigatório, negativo/3 casas recusados, zero aceito, período inexistente, cancelado não edita); repositório local (transação, auditoria, parâmetros iguais à assinatura da RPC, versão); repositório remoto com gateway falso; sobra com criar/editar mudando período/cancelar; fila repetida não duplica.
8. **Aceitação:** investimento salvo offline entra no total do período; editar a data move o valor; cancelar tira da sobra e mantém o registro.
9. **Riscos:** validação do app diferente da RPC gera recusa tardia.

### Entrega 52 — Sincronização ponta a ponta e itens de atenção
1. **Objetivo:** ida e volta com o servidor local; conflitos e recusas compreensíveis.
2. **Funcionalidades:** envio e download; textos com valor e data (V7); "Editar" no conflito de edição de investimento, com valor e data (D6); criação recusada sem registro órfão.
3. **Regras:** RN030–RN033; D6.
4. **Dependências:** 51.
5. **Arquivos:** `lib/features/attention/attention_models.dart` (`canEdit`, resumos), `attention_repository.dart` (`buildEditedRequest`), `attention_screen.dart` (campo de data no diálogo de edição); `lib/features/sync/sync_service.dart` só se a recusa de criação exigir.
6. **Banco:** nenhuma mudança; suíte PostgreSQL existente.
7. **Testes:** aplicado, conflito, recusa, repetição idempotente; download; total local × remoto (RN032); textos de atenção; suíte PostgreSQL.
8. **Aceitação:** mesma operação enviada duas vezes gera um único investimento; conflito mostra as duas versões e resolve (manter ou editar valor/data) em nova versão com auditoria; data editada sem período pede criação de períodos ou é recusada com mensagem clara.
9. **Riscos:** cobre a Entrega 7A, nunca validada.

### Entrega 53 — "Novo investimento" em Lançamentos
1. **Objetivo:** registrar, ver, editar e cancelar investimentos pela mesma lista e formulário da despesa (D10).
2. **Funcionalidades:** "Novo investimento" abaixo de "Nova despesa"; formulário da despesa com só valor e data (padrão hoje) e textos adaptados ("Valor investido", "Data do investimento", "Salvar investimento"); investimentos na lista, identificados; filtro "Investimentos"; editar e cancelar com confirmação; pergunta de criação de períodos; estados de carregamento, erro e vazio; aviso de sem conexão na Web.
3. **Regras:** RN021–RN023, RN027–RN029, RN042; D1, D2, D3, D10.
4. **Dependências:** 51 (52 recomendada).
5. **Arquivos:** `lib/features/entries/entry_form_screen.dart` (modo investimento), `lib/features/transactions/transactions_screen.dart` (opção, lista mista, filtro).
6. **Banco:** nenhuma mudança.
7. **Testes de widget:** criar, editar valor, editar data para outro período, cancelar, filtro, vazio, erro; regressão de `test/features/entries/transactions_screen_test.dart` e dos testes do formulário.
8. **Aceitação:** o formulário não mostra categoria, descrição, vencimento, "já paga" nem pagar; cancelado aparece como cancelado e não soma; receitas e despesas seguem iguais.
9. **Riscos:** o formulário e a lista hoje só conhecem receita/despesa (`EntryRecord`); adaptar sem quebrar pagar/receber.

### Entrega 54 — REMOVIDA (D3)
Total investido no Dashboard fora do MVP. A sobra do Dashboard já desconta os investimentos sem mudança de tela; a regressão do Dashboard entra na Entrega 58.

### Entrega 55 — Recorrência de investimento no servidor (nova migration)
1. **Objetivo:** estrutura e regras de recorrência de investimento no PostgreSQL.
2. **Funcionalidades:** tabela `investment_recurrence_templates` (frequência, início, dia de referência, valor padrão, ativo, versão, timestamps; sem descrição/categoria); em `investment_allocations`: `recurrence_template_id`, `scheduled_for_date`, `scheduled_period_id` e unicidade `(owner_id, recurrence_template_id, scheduled_for_date)`; RPC do modelo (criar, editar, parar); conversão do avulso em primeira ocorrência; `generate_due_recurrence_occurrences` passa a gerar investimentos com o mesmo identificador determinístico; edição de ocorrência pela RPC de investimento (nova versão, se a assinatura mudar); resolução de conflito, grants e leitura com RLS para o novo tipo. Valor sempre obrigatório (D8).
3. **Regras:** RN038 (aplicada a investimento), RN022, RN033; D7–D9.
4. **Dependências:** aprovação de D7–D9; 51–52.
5. **Arquivos:** nova migration em `supabase/migrations/`; novo teste em `supabase/tests/`; `tooling/test_postgres_schema.ps1` (incluir o teste).
6. **Banco remoto:** nova migration (não altera as existentes). Somente Supabase local.
7. **Testes PostgreSQL:** geração mensal/por período, mês curto, atrasadas, unicidade, idempotência, identificador igual ao do app, mudança de agenda só para as próximas, parar de repetir, edição de valor de uma ocorrência, isolamento por usuário, conflito.
8. **Aceitação:** gerar duas vezes não duplica; ocorrência gerada entra na sobra do período da data programada; suíte inteira passa.
9. **Riscos:** alterar a função de geração afeta receitas e despesas — regressão obrigatória da Fase 5.

### Entrega 56 — Recorrência de investimento no aparelho (Drift v4) e download
1. **Objetivo:** mesma estrutura no banco local, geração offline e download.
2. **Funcionalidades:** tabela local do modelo e novos campos (Drift v4); geração local ao abrir/sincronizar com o mesmo identificador; download do novo tipo; tipo na fila e na tela de atenção.
3. **Regras:** RN031–RN033, RN038; D7, D8.
4. **Dependências:** 55.
5. **Arquivos:** `lib/core/local_database/app_database.dart`, `schema_versions.dart`, `drift_schemas/`, `test/generated_migrations/`; `lib/features/recurrence/` (generalizar para investimento); `lib/features/sync/download_service.dart`, `sync_service.dart`; `lib/features/attention/attention_models.dart`.
6. **Banco local:** `schemaVersion` 3 → 4, snapshot e teste de migração com dados existentes.
7. **Testes:** migração v3 → v4 preservando dados (nativo e Web); geração local igual à do servidor; geração offline em dois "aparelhos" produz a mesma ocorrência; download; sobra.
8. **Aceitação:** usuário com dados da v3 atualiza sem perda; ocorrência gerada offline e no servidor é a mesma.
9. **Riscos:** migração com dados reais do usuário (só acrescenta tabela e colunas opcionais; valor continua obrigatório — D8).

### Entrega 57 — "Repetir" no investimento e Mais → Recorrências
1. **Objetivo:** usar a recorrência pela interface.
2. **Funcionalidades:** "Repetir" (todo mês / todo período) no formulário de investimento; editar ocorrência "só esta" ou "a recorrência" (inclui mudar o valor do mês — D8); parar de repetir; investimentos recorrentes em Mais → Recorrências.
3. **Regras:** D7–D9; Fase 5 D2, D7, D8.
4. **Dependências:** 53, 56. (Entregas 55–57 dependem de 51–53; nenhuma depende da 54, removida.)
5. **Arquivos:** `lib/features/entries/entry_form_screen.dart`, `lib/features/recurrence/recurrences_screen.dart`, `recurrence_edit_screen.dart`.
6. **Banco:** nenhuma mudança adicional.
7. **Testes de widget e serviço:** criar recorrente, data passada gera atrasadas, mudar valor de um mês, mudar valor das próximas, parar de repetir; regressão das recorrências de receita/despesa.
8. **Aceitação:** mudar o valor de um mês não altera outros meses nem o modelo; nenhuma opção de pagar, vencimento ou alerta aparece.
9. **Riscos:** telas de recorrência pressupõem categoria/descrição; adaptar sem afetar receita/despesa.

### Entrega 58 — Rendimentos manuais, regressão e fechamento
1. **Objetivo:** confirmar rendimento como receita comum, regressão completa e documentação.
2. **Funcionalidades:** nenhuma tela nova (D4); nenhuma operação de resgate (D5).
3. **Regras:** RN007, RN008, RN044; D4, D5.
4. **Dependências:** 51–53, 55–57.
5. **Arquivos:** testes; documentos da seção 8.
6. **Banco:** nenhuma mudança.
7. **Testes:** receita "Rendimentos" soma na sobra pela data de recebimento; nenhum rendimento sem lançamento; sobra do Dashboard desconta investimentos (avulsos e recorrentes); `flutter analyze`, `flutter test`, `flutter test --platform chrome`, suíte PostgreSQL; teste manual no emulador Android (offline → online) e na Web.
8. **Aceitação:** testes passam; documentos atualizados; responsável valida a fase.
9. **Riscos:** dinheiro contado duas vezes por escolha do usuário (previsto, não detectado).

## 7. Riscos principais
- **Financeiros:** dupla dedução (mesma aplicação como despesa e investimento); usuário lançar resgate como receita por conta própria, contrariando D5; cancelar um investimento antigo devolve o valor à sobra daquele período antigo, não à do período atual; investimento recorrente esquecido continua descontando todo mês até "parar de repetir"; ocorrências atrasadas geradas de uma vez ao abrir o app reduzem a sobra de períodos passados.
- **Técnicos:** mudança na função de geração do servidor pode afetar receitas/despesas recorrentes; migração Drift v4 com dados reais; validação do app diferente da RPC; formulário e lista compartilhados com receita/despesa; RPC 7A nunca validada; Web sem fila (depende de conexão).

## 8. Documentos a atualizar durante a implementação
| Documento | O que muda |
|---|---|
| `docs/requisitos.md` | RF016–RF017: data informada (D1); retirar "o Dashboard apresenta um único total" do MVP (D3); investimento recorrente (D7–D8) |
| `docs/roadmap.md` | Fase 6: entregáveis (data, recorrência; "Exibição do total destinado no período" sai — D3), status e conclusão |
| `docs/regras_negocio.md` | RN021/RN027 (D1, D2); RN010/RN014/RN038 passam a incluir investimento (D7–D9); RN022 (ocorrência gerada entra na sobra, sem confirmação); RN023: não existe resgate; desfazer = cancelar (D5); duplicata da RN038 (V6), se autorizado |
| `docs/arquitetura.md` | §17: módulo `lib/features/investments/`, recorrência generalizada, fluxo local/Web |
| `docs/banco_de_dados.md` | §5.9 e §16.8–16.10: nova tabela de modelo, campos de ocorrência, unicidade, RPCs, Drift v4; 7A validada |
| `docs/estado_atual.md` | Fase 6 em andamento/concluída; V4–V5 |
| `AGENTS.md` | §4.5: "descrição obrigatória" → sem descrição (D2); investimento recorrente permitido (D7) |
| `docs/entregas_fase6.md` | Decisões aprovadas e situação de cada entrega |

## 9. Situação das entregas e roteiro de validação (11/11/2026)

| Entrega | Situação | Testes |
|---|---|---|
| 51 — Investimento avulso (domínio) | implementada | `test/features/investments/investment_service_test.dart` (valor obrigatório, negativo/acima do limite recusados, zero aceito, período inexistente pergunta, data futura/passada, editar data move de período, cancelar tira da sobra e trava edição, auditoria e fila com parâmetros iguais aos da RPC, fila repetida não duplica, repositório Web) |
| 52 — Sincronização e atenção | implementada | `attention_test.dart` (textos com valor e data; "Editar" valor e data no conflito; resolução gera nova versão); suíte PostgreSQL cobre a RPC 7A (V7 resolvida) |
| 53 — "Novo investimento" em Lançamentos | implementada | `transactions_screen_test.dart` (criar, editar, cancelar, filtro, vazio, período inexistente) |
| 54 — Total no Dashboard | removida (D3) | — |
| 55 — Recorrência no servidor | implementada | `supabase/tests/rpc_investment_recurrence_test.sql` (geração mensal/por período, atrasadas, unicidade, idempotência, identificador igual ao do app, mudança de agenda, parar, edição por ocorrência, conversão, conflitos, isolamento) e regressão da geração de receitas/despesas na mesma chamada |
| 56 — Recorrência no aparelho (Drift v4) e download | implementada | `migration_test.dart` (v3 → v4 preserva dados), `investment_recurrence_test.dart` (geração local, dois aparelhos com o mesmo id, parâmetros da fila), `download_service_test.dart` |
| 57 — "Repetir" e Mais → Recorrências | implementada | `recurrence_screens_test.dart` (criar recorrente, editar só esta, editar as próximas, parar de repetir, sem pagar/vencimento/alertas) |
| 58 — Rendimentos, regressão e fechamento | implementada | `yield_and_surplus_test.dart`; `flutter analyze` sem avisos; `flutter test` (341 passaram, 15 ignorados já existentes); suíte PostgreSQL inteira; `flutter build web` compila; teste de banco Web (`tooling/web_check`) passa |

**Não executado:** `flutter test --platform chrome` na raiz não conclui neste ambiente (falha de compilação por testes só de celular sem a marca de plataforma, e o Chrome não abre testes puros dentro do tempo); teste manual no emulador Android e na Web (a cargo do responsável).

**Roteiro sugerido de validação manual (Android, depois Web):**
1. Lançamentos → Novo → Novo investimento: o formulário mostra só valor e data (e "Repetir"). Salvar R$ 300,00; a sobra do Dashboard cai R$ 300,00.
2. Editar a data para o mês anterior (confirmar a criação do período, se pedir): a sobra de cada mês acompanha.
3. Cancelar o investimento: some da sobra, fica na lista como "Cancelado".
4. Filtro "Investimentos" mostra só investimentos.
5. Novo investimento com "Repetir" (todo mês) e data de dois meses atrás: as atrasadas aparecem; "Editar só esta" muda um mês; Mais → Recorrências → "Editar a recorrência" muda as próximas; "Parar de repetir" mantém as já criadas.
6. Em modo avião, criar um investimento e voltar à rede: aparece uma única vez no servidor.
7. Lançar uma receita na categoria "Rendimentos": soma na sobra do mês da data de recebimento.
