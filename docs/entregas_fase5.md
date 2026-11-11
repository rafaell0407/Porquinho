# Entregas da Fase 5 — Recorrências (plano)

**Status:** plano APROVADO em 11/11/2026 (D1–D9, seção 5). IMPLEMENTADA em 11/11/2026 (Entregas 43–50); aguardando validação do responsável (seção 11). Cada entrega é implementada, testada e validada antes da próxima. Estado vigente: `docs/estado_atual.md`.

## 1. Objetivo e escopo
Permitir cadastrar receitas e despesas que se repetem, gerar suas ocorrências sem duplicar, confirmar recebimentos, informar valores variáveis, pagar, editar e cancelar ocorrências individualmente, e avisar no celular sobre vencimentos.

Dentro: modelos recorrentes de receita e despesa; frequências mensal e por período (RN010, RN014); valor fixo ou variável; geração idempotente ao abrir e sincronizar (RN038); confirmação de recebimento (RN011–RN012); edição individual; vencimento e pagamento (RN015–RN017, RN039); fatura do cartão como despesa recorrente variável comum (RN019); alertas móveis Android (RN018, RN035, RN041). RFs: RF006–RF013, RF018, RF021–RF023, RF027.

Fora (Fases 6–8 ou fora do MVP): investimentos, composição da sobra e relatórios no Dashboard, filtros por categoria/status, ambientes hospedados, frequências semanal/quinzenal/anual, pagamento parcial, reativação de recorrência, desfazer recebimento/pagamento.

## 2. Dependências
- Fases 1–4 concluídas e validadas (períodos sob demanda, fila com dependências, categorias, sobra, itens de atenção).
- Já existe da Fase 2 (não refazer): tabelas `*_recurrence_templates` e campos de ocorrência em `income_entries`/`expense_entries` (PostgreSQL e Drift v3), índice único `(owner_id, recurrence_template_id, scheduled_for_date)` nos dois bancos, RPCs `apply_*_recurrence_template_change` (criar, editar, desativar), `generate_due_recurrence_occurrences` e `apply_*_recurrence_occurrence_change` (editar, receber/pagar, cancelar), com auditoria, versão e idempotência; download dessas tabelas (27B); tipos na tela de atenção.
- Não existe: domínio de agenda recorrente no app, geração local, repositórios/serviços/telas de recorrência, notificações (sem pacote nem permissões Android).

## 3. Decisões aprovadas (aplicáveis)
- Mensal: mantém o dia de referência; em mês curto usa o último dia, sem mudar os meses seguintes; primeira ocorrência = primeira data de referência ≥ início (RN038; ex.: criada em 10/05 com dia 31 → 31/05).
- Por período: uma ocorrência no início de cada período; criada no meio do período, também gera a do período atual (RN038).
- Recuperação das atrasadas até hoje em `America/Sao_Paulo`, ao abrir e ao sincronizar, sem segundo plano (RN038, `arquitetura.md` §17.3).
- Unicidade modelo + data programada no armazenamento (RN038) — já implementada.
- Receita recorrente nasce pendente; entra na sobra só ao confirmar, pela data de recebimento, uma única vez (RN011–RN012).
- Despesa recorrente entra na sobra quando gerada e com valor; pagar não deduz de novo; pendente fica no período original (RN014–RN016, RN039).
- Editar ocorrência não altera modelo nem outras ocorrências; desativar impede novas e preserva histórico (RN011, RN038).
- Vencimento não muda o período (RN017). Alertas: 3 dias antes, no dia e diariamente após, enquanto pendente, mesmo após o fim do período; cessam ao pagar/cancelar; só Android (RN018, RN035, RN041).
- Desfazer pagamento/cancelamento fora do MVP por ora (Fase 4, D7); correção de data de pagamento = pagar novamente.

## 4. Lacunas encontradas no diagnóstico
- L1: a geração no servidor cria ocorrências com identificador aleatório (`20261109000800`, `gen_random_uuid()`). Se o celular gerar offline, a mesma ocorrência terá identificadores diferentes no aparelho e no servidor → recusa por duplicidade ou ocorrência "fantasma". Mesmo risco com dois aparelhos.
- L2: editar o modelo permite mudar frequência, início e dia de referência depois de haver ocorrências (`20261109000700`). Ex.: dia 5 → dia 20 gera uma segunda ocorrência no mesmo mês; início antecipado gera ocorrências passadas. Não há regra aprovada.
- L3: o modelo de despesa não tem vencimento padrão (`banco_de_dados.md` §16.8.3: "não há regra aprovada para derivá-lo"). Sem vencimento não há alerta (RN018).
- L4: despesa mensal cuja data programada não tem período é ignorada em silêncio pelo servidor, a cada geração; o mesmo para recorrência por período antes do primeiro período.
- L5: a competência da despesa recorrente gerada com atraso é a data programada (`competence_on = scheduled_for_date`), não o dia em que o app abriu. RN004 fala em "data de geração da ocorrência".
- L6: não há regra para data de início passada/futura do modelo, nem para data de recebimento futura na confirmação.
- L7: notificações exigem dependência nova, permissões Android 13+ (notificações) e de alarme; horário do alerta não definido; mudanças feitas em outro aparelho só são refletidas após sincronizar.

## 5. Decisões do responsável (11/11/2026)
- D1 (L1): identificador determinístico da ocorrência, calculado de modelo + data programada, igual no app e no servidor. Nova migration troca a função de geração.
- D2 (L2): todos os campos do modelo podem mudar, inclusive dia, frequência, início e fixo/variável. A mudança vale **só para ocorrências ainda não geradas**: as já geradas não mudam, e se o mês/período atual já tem ocorrência, a nova agenda começa no próximo. Nunca há duas ocorrências do mesmo modelo no mesmo mês/período, e a mudança não cria ocorrências passadas. Ex.: "Academia dia 5" com 05/11 gerada → muda para dia 20 → próxima em 20/12. Descrição, valor padrão e categoria valem para as próximas.
- D3 (L3): o vencimento da despesa recorrente é preenchido automaticamente com a **mesma data da ocorrência** (mensal: data programada; por período: início do período). O usuário pode alterar o vencimento de cada ocorrência. Sem campo novo no modelo e sem Drift v4.
- D4 (L4): início antes do primeiro período → o app pergunta se cria os períodos (RN002); sem confirmação, não salva com essa data. O servidor não ignora mais em silêncio (nova migration).
- D5 (L5): a "data de geração" da RN004 é a data programada; a despesa recuperada com atraso fica no período da data programada.
- D6 (L6): lançamento avulso entra apenas na data informada; só se repete se o usuário marcar a recorrência. Confirmação de recebimento: padrão hoje, aceita outra data.
- D7: ao desativar ("parar de repetir"), as ocorrências já geradas ficam como estão; sem cancelamento automático.
- D8 (interface): a recorrência é ativada no formulário de criação ou edição do lançamento ("Repetir": todo mês ou todo período). O próprio lançamento é a **primeira ocorrência**; as seguintes seguem o dia dele; data passada gera também as atrasadas até hoje (RN038). Em "todo período", a data da ocorrência é o início do período que contém a data informada (RN038). Receita recorrente nasce pendente, com opção "já recebi" no formulário (análoga ao "já paga" da Fase 4, D10). Ativar a recorrência ao editar um lançamento avulso existente o transforma na primeira ocorrência (exige nova RPC). Ao editar uma ocorrência, o usuário escolhe "só esta" ou "a recorrência", e há "Parar de repetir". Lista de consulta em **Mais → Recorrências**.
- D9 (L7): pacote `flutter_local_notifications` (avaliado na Entrega 49); alerta às 9h em São Paulo; uma notificação por dia resumindo as despesas, sem valores na tela bloqueada; vale para toda despesa pendente com vencimento, avulsa ou recorrente; reagenda ao abrir, sincronizar e salvar (janela de 30 dias); logout apaga todos; alerta pode ficar desatualizado até sincronizar quando pago em outro aparelho.

## 6. Entregas
Numeração continua da Fase 4. Banco remoto só por nova migration. Drift continua v3 (D3 dispensa campo novo); se a implementação exigir coluna nova, incrementar versão, gerar snapshot e testar migração.

| # | Objetivo | Depende de | Banco | Critério de aceitação |
|---|---|---|---|---|
| 43 | Domínio da agenda: datas programadas mensais (dia 1–31, meses curtos, bissexto, primeira ocorrência), por período (sobre os períodos existentes, incluindo o atual), lista das devidas até hoje, próxima data livre após mudança de agenda (D2), vencimento = data da ocorrência (D3), identificador determinístico (D1) | — | — | Exemplos da RN038; dia 31 e 29/02 por 48 meses; criada no meio do mês/período; mudança de agenda nunca gera duas no mesmo mês/período; datas iguais às da RPC no Supabase local |
| 44 | Servidor: nova migration com geração por identificador determinístico e vencimento preenchido (D1, D3), mudança de agenda só para o futuro (D2), data sem período recusada em vez de ignorada (D4), RPC que cria a recorrência a partir de um lançamento novo ou avulso existente, tornando-o a primeira ocorrência (D8) | 43 | Nova migration; RPCs existentes só substituídas onde necessário | Suíte PostgreSQL: gerar 2× não duplica; duas sessões simultâneas geram uma vez; identificador igual ao do Dart; mudança de agenda não duplica nem cria passadas; avulso convertido não é duplicado pela geração; nada ignorado em silêncio |
| 45 | Recorrência no formulário de lançamento (D8): "Repetir" (todo mês/todo período) ao criar ou editar; "só esta" × "a recorrência"; "Parar de repetir"; "já recebi" na receita; lista de consulta em Mais → Recorrências; local (Drift + fila com dependências) e remoto (Web) | 44 | — | Lançamento vira a primeira ocorrência; data passada gera as atrasadas; fixo exige valor; categoria inativa não aparece; períodos faltantes perguntados (D4); offline no celular; conflito e recusa vão para atenção; auditoria |
| 46 | Geração: no celular, local ao abrir e ao sincronizar; na sincronização, chamar a geração do servidor depois dos períodos/modelos e antes das alterações de ocorrências; download reconcilia pelo mesmo identificador; na Web, RPC ao abrir | 43–45 | — | Abrir N vezes não duplica; offline 3 meses recupera as atrasadas; dois aparelhos offline geram a mesma ocorrência sem conflito; modelo desativado não gera; ocorrência cancelada não renasce; alteração local pendente não é sobrescrita pelo download |
| 47 | Receitas recorrentes: ocorrências pendentes em Lançamentos, confirmar recebimento (valor e data), editar (inclusive valor de fixa), cancelar | 46 | — | Pendente fora da sobra; confirmada entra uma vez no período da data de recebimento; mudar a data move o período; variável exige valor para confirmar; modelo e outras ocorrências intactos |
| 48 | Despesas recorrentes: informar valor da variável, vencimento automático editável (D3), pagar, editar, cancelar; fatura do cartão como exemplo de variável | 46 | — | Fixa entra na sobra ao gerar; variável entra ao informar o valor; vencimento = data da ocorrência e pode ser alterado; pagar não muda a sobra; vencimento não muda o período; pendente permanece no período original |
| 49 | Alertas móveis Android (D9): dependência avaliada (manutenção, licença, segurança), permissões, agendar/atualizar/cancelar, logout e troca de usuário; nada na Web | 48 | — | 3 dias antes, no dia e diários após; pagar/cancelar remove; editar vencimento reagenda; permissão negada não quebra o app; após reiniciar o aparelho continuam; vencimento antigo não gera rajada |
| 50 | Fechamento: equivalência local × servidor no Supabase local, cenário com dois aparelhos, regressão no emulador e no Chrome, documentos | todas | — | Critérios de conclusão abaixo |

**Ordem:** 43 → 44 → 45 → 46 → 47 → 48 → 49 → 50.

### Riscos por entrega
- 43/44: divergência de datas entre Dart e PostgreSQL (meses curtos, bissexto); algoritmo do identificador precisa ser idêntico nos dois lados.
- 44: substituir a função de geração com dados existentes no Supabase local (ocorrências antigas com identificador aleatório continuam válidas; o índice único evita duplicar). Lançamento convertido em primeira ocorrência deve ocupar a data programada para a geração não criar outra.
- 45: formulário com mais opções (escolha "só esta" × "a recorrência" precisa ser clara); edição de modelo com alteração pendente na fila; dependência de categoria criada offline. Em "todo período", a data da ocorrência é o início do período, não a data digitada — o formulário precisa mostrar isso.
- 46: maior risco da fase — ordem da sincronização, ocorrência editada offline cujo modelo foi desativado em outro aparelho (vira recusa em atenção, sem perda), períodos criados offline ainda não enviados.
- 47/48: integridade da sobra ao editar data/valor de ocorrência já confirmada ou paga; variável sem valor com status pendente.
- 49: limites do Android (alarmes exatos, economia de bateria, máximo de alarmes); alerta desatualizado até a próxima sincronização quando a despesa é paga em outro aparelho (limitação documentada).

## 7. Casos de teste obrigatórios (datas)
- Mensal dia 31: jan 31, fev 28 (29 em bissexto), mar 31, abr 30.
- Mensal dia 29/30 em fevereiro de ano comum e bissexto (2028).
- Criada em 10/05 com dia 31 → primeira 31/05; criada em 31/05 com dia 10 → primeira 10/06.
- Por período em ciclo dia 31 e após mudança de configuração (RN002): uma ocorrência por período, sem lacuna.
- Criada no meio do período por período → ocorrência do período atual com data anterior à criação.
- Início no passado e app sem abrir por meses → todas as atrasadas, uma vez cada.
- Virada do dia: 23h59 e 00h00 em São Paulo.

## 8. Matriz de testes
| Entrega | Unidade | Widget | Supabase local | PostgreSQL | Emulador | Chrome |
|---|---|---|---|---|---|---|
| 43 | agenda, meses curtos, bissexto, identificador | — | datas = RPC | — | — | — |
| 44 | — | — | aplicar migration | geração 2×, concorrência, bloqueio de agenda, identificador | — | — |
| 45 | serviço, validações, fila | formulário e lista | sincronização do modelo | — | criar offline | criar online |
| 46 | geração local idempotente, ordem da fila | — | dois aparelhos, offline e sync | — | abrir offline/online | geração via RPC |
| 47 | sobra com receita confirmada/editada/cancelada | confirmar | paridade da sobra | — | fluxo completo | fluxo completo |
| 48 | sobra com fixa/variável/paga/cancelada | informar valor, pagar | paridade da sobra | — | fluxo completo | fluxo completo |
| 49 | cálculo das datas de alerta, reagendamento | permissão negada | — | — | notificações reais | sem alertas |
| 50 | regressão completa | regressão | equivalência local × servidor | suíte completa | regressão | regressão |

## 9. Critérios de conclusão da Fase 5
- RF006–RF013 e RF023 atendidos; RN010–RN019, RN038, RN039 e RN041 cobertas por testes.
- Nenhuma ocorrência duplicada em: aberturas repetidas, sincronização repetida, dois aparelhos, offline seguido de sincronização.
- Sobra igual no aparelho e no servidor para os mesmos dados (RF027).
- Alertas funcionando no emulador Android; Web sem alertas e sem erro.
- `flutter analyze`, `flutter test`, testes Web e suíte PostgreSQL passando.
- Documentos atualizados e validação do responsável.

## 10. Documentos a atualizar
- `docs/regras_negocio.md`: RN004 (D5), RN038 (D2, D6, D7, D8), RN017/RN019 (D3), RN018 (D9, horário e agrupamento).
- `docs/requisitos.md`: RF006–RF013 e RF023 (recorrência no formulário e lista em Mais, D8).
- `docs/banco_de_dados.md` §16.8–16.10: identificador determinístico, vencimento preenchido, nova migration e RPC de conversão.
- `docs/arquitetura.md`: §15 (notificações), §17.3 (geração na sincronização), §2.1 (nova dependência).
- `docs/roadmap.md`, `docs/estado_atual.md`: andamento da fase.
- `docs/historico/decisoes.md`: registro das decisões D1–D9.

## 11. Situação da implementação (11/11/2026)

**Implementadas:** Entregas 43 a 50, na ordem. Aguardam validação do responsável.

| # | Resultado | Arquivos principais |
|---|---|---|
| 43 | Domínio da agenda: datas mensais (meses curtos, bissexto, primeira ocorrência), períodos devidos, piso de mudança de agenda (D2), identificador determinístico (D1) | `lib/core/domain/recurrence_schedule.dart` |
| 44 | Migration `20261111000300_recurrence_generation_v2.sql`: id determinístico, gatilho de agenda (início antes do primeiro período recusado; mudança só para o futuro), geração reescrita (vencimento = data da ocorrência), RPC `create_recurrence_from_entry` | `supabase/migrations/`, `supabase/tests/rpc_recurrence_v2_test.sql` |
| 45 | "Repetir" no formulário (todo mês / todo período, valor variável, "já recebi"/"já paga"); avulso vira primeira ocorrência; Mais → Recorrências (editar a recorrência, parar de repetir); celular (Drift + fila) e Web (RPC) | `lib/features/entries/`, `lib/features/recurrence/` |
| 46 | Geração local ao abrir e após sincronizar; servidor gera na sincronização depois dos modelos e antes das alterações de ocorrência; Web chama a RPC ao abrir; recusa de recorrência vira reversão local | `local_recurrence_repository.dart`, `sync_service.dart`, `sync_providers.dart` |
| 47 | Receita recorrente: pendente aparece no período da data programada, "Confirmar recebimento" (data e valor), editar só esta, cancelar | `transactions_screen.dart`, `entry_service.dart` |
| 48 | Despesa recorrente: "Informar valor" (variável), vencimento editável, pagar, cancelar | idem |
| 49 | Alertas Android: `flutter_local_notifications` 23, 9h, um resumo por dia, janela de 30 dias, cancelados no logout; AGP 9.1.1 e compileSdk 37 exigidos pelo pacote | `lib/features/alerts/`, `android/` |
| 50 | Fechamento: equivalência local × servidor no Supabase local, dois aparelhos, documentos | `test/integration/phase5_flow_test.dart` |

**Decisões de implementação (dentro de D1–D9):**
- Mudança de agenda: o servidor (gatilho) e o app calculam o mesmo "piso" (mês seguinte ou fim do período da última ocorrência gerada); o app também nunca começa antes de hoje.
- Alertas usam agendamento inexato (sem permissão de alarme exato): chegam por volta das 9h.
- A geração local não grava auditoria nem fila; o servidor gera e audita a sua cópia (mesmo identificador).
- Recorrência recusada pelo servidor (ex.: modelo desativado em outro aparelho) vai para "Itens que precisam de atenção"; descartar remove o modelo e as ocorrências locais dele.
- Por período, a primeira ocorrência de um lançamento convertido recebe a competência do início do período.

**Testes executados (11/11/2026):**
- `flutter analyze`: sem problemas. `flutter test` (inclui 3 testes de integração da Fase 5 e a paridade de datas contra o Supabase local): 314 passaram.
- Suíte PostgreSQL (`tooling/test_postgres_schema.ps1`): todos os arquivos passaram, incluindo `rpc_recurrence_v2_test.sql`; fixtures antigos de modelos foram movidos para depois do primeiro período.
- `flutter build web` e `flutter build apk --debug` compilam; o app abre no emulador sem erro.
- Migration aplicada só no Supabase **local** (`supabase migration up`). Nada foi enviado ao Supabase gerenciado.

**Não executado / pendente de validação:**
- `flutter test --platform chrome` continua indisponível nesta máquina (já registrado nas Fases 2–4); regressão manual no Chrome pendente.
- Alertas em notificação real no emulador e fluxo completo pela interface no emulador (modo avião, dois aparelhos reais) não foram exercitados; cálculo das datas, reagendamento e agendador estão cobertos por testes.
- Concorrência de duas sessões simultâneas na geração: a serialização vem do bloqueio das linhas dos modelos (`FOR UPDATE`) e do índice único; não há teste de duas sessões como o dos períodos.
- `docs/historico/decisoes.md` não foi atualizado (acesso negado nesta sessão); as decisões D1–D9 estão registradas na seção 5 deste arquivo.

**Roteiro de validação sugerido:** (1) criar despesa com "Repetir → todo mês" e data de dois meses atrás e ver as três ocorrências; (2) criar receita recorrente, ver "A receber" e confirmar o recebimento (sobra muda uma vez); (3) criar despesa de valor variável e "Informar valor"; (4) Mais → Recorrências: editar o dia e ver que a próxima ocorrência é no mês seguinte; (5) parar de repetir; (6) despesa com vencimento próximo e conferir a notificação das 9h.
