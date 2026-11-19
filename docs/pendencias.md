# Pendências, ajustes e melhorias — Norte

Lista-mestra única do que falta. **Atualizado em:** 18/11/2026.
Regras: cada item tem ID fixo (não reaproveitar). Concluiu → apagar a linha e registrar na entrega da fase. Achou algo fora da entrega em curso → registrar aqui, não resolver sozinho. Melhorias (M) só com aprovação.

## D — Decisões abertas (responsável)
| ID | Assunto | Situação |
|---|---|---|
| D1 | Nome Norte e `applicationId` `br.com.norte.app` | Aprovados 12/11/2026; confirmar como definitivos antes da 1ª publicação. Falta ícone. Domínio próprio opcional até a Entrega 79. |
| D5 | E-mail Resend / SMTP | Aprovado 12/11/2026; configurar na Entrega 79 (exige domínio). |
| D14 | Política para futura alteração da zona IANA do usuário | Decidido pelo responsável em 18/11/2026: a mudança vale só dali em diante; lançamentos e períodos passados não são recalculados. Falta virar RN em `regras_negocio.md` quando a troca de fuso for implementada. |
| D15 | Guarda de histórico dos lançamentos (auditoria, cancelados) | Implementado (X0–X4, ver §X) e validado pelo responsável em 19/11/2026: cancelado ("Apagar") guardado 12 meses e depois apagado no servidor e no aparelho; auditoria também 12 meses. Falta só a homologação (X5) e a política de privacidade (X-H). |

## R — Ações do responsável
- R1: Validar a Entrega 76 (homologação `norte-homologacao`, exceto SMTP).
- R2: Autorizar e fornecer referências do Supabase gerenciado nas próximas etapas (nunca agir sem autorização).
- R3: Rodar `supabase migration up` no local quando houver migration nova.
- R4: Roteiro manual de validação da Fase 8 (`entregas_fase8.md` §8).
- R6: Buscar o nome "Norte" no INPI antes de publicar nas lojas e, se possível, consultar advogado de propriedade intelectual.

## E — Entregas restantes da Fase 8 (detalhe em `entregas_fase8.md`)
- 75 (final): depende de D1 · 77 backup · 78 regressão Android/Web · 79 produção + SMTP (D5) + monitoramento (tratamento global de erros já feito) · 80 publicação Web · 81 publicação Android · 82 fechamento.

## P — Reestruturação de períodos (aprovada em 13/11/2026)
Decisões do responsável: configuração única, trocável a qualquer momento e valendo para todos os períodos; período calculado por datas (sem tabela de períodos nem vínculo do lançamento ao período); repetição só "Todo mês", dia inexistente vai para o dia útil (seg–sex) anterior; início do ciclo sem dia útil; caso raro 29–31 aceito; dados de desenvolvimento podem ser apagados (sem converter recorrências "por período"). Regras: RN001–RN004, RN010, RN014, RN017, RN036–RN038, RN042; RF006, RF010, RF019. P1 (documentação) validada em 13/11/2026.
Ordem revista em 13/11/2026: o app continua funcionando entre as entregas e nada é removido antes da rede de segurança (P4) passar. O vínculo do lançamento ao período fica opcional na P6 (Drift v7) e é removido na P7 (Drift v8). O responsável valida P2–P7 juntas no fim; cada entrega é testada antes da seguinte.
| ID | Entrega | Situação |
|---|---|---|
| P2 | Domínio: período calculado por data e intervalo de navegação (`PeriodCalendar.between/bounds`, `PeriodConfig.fromDb`); tabela única de casos `test/fixtures/period_cases.json` (243 casos, gerada por implementação independente). Sem caso SQL: o servidor não calcula períodos, recebe os intervalos do app. Não muda o app | Feita 13/11/2026; validada pelo responsável em 18/11/2026 |
| P3 | Totais por intervalo de datas no celular e no servidor (RPC `get_range_report`, migration `20261113000400`, local e homologação); Dashboard, Lançamentos e Relatórios somam e listam pelas datas; períodos gravados continuam existindo | Feita 13/11/2026; validada pelo responsável em 18/11/2026 |
| P4 | Rede de segurança: "soma pelo período gravado" = "soma pelas datas do mesmo período" no celular (totais, categorias, listas), no servidor (`get_period_report` × `get_range_report`) e na suíte SQL; dados reais do Supabase local (4.439 lançamentos, 93 contas) sem nenhum lançamento fora do seu período. Nenhuma diferença encontrada | Feita 13/11/2026 | Testes da rede de segurança retirados na P6 (o vínculo deixou de ser gravado).
| P5 | Repetição só "Todo mês", dia inexistente → último dia útil do mês (domínio `RecurrenceCalendar.monthlyDate`; servidor `recurrence_monthly_date`, migration `20261113000500`, local e homologação; tabela única de 360 casos JSON + SQL). Nunca duas ocorrências do mesmo modelo no mesmo mês (ocorrências antigas ficam na data em que foram geradas). "Todo período" sai do formulário e das telas de edição; recusado no app e no servidor; os 9 modelos "por período" do banco local foram desativados com auditoria. Modelos antigos continuam legíveis (rótulo "Todo período") | Feita 13/11/2026; validada pelo responsável em 18/11/2026 |
| P6 | Configuração única `period_settings` (servidor: tabela + `set_period_settings` com conflito por versão + `get_entry_date_span`; migration `20261113000600`, local e homologação; Drift v7 com migração testada). Troca na hora na tela Período (com aviso); navegação do lançamento mais antigo ao mais distante; fim da pergunta "Criar os períodos…?"; nenhuma gravação de período nem de vínculo (RPCs e app); conflito da configuração em Itens de atenção | Feita 13/11/2026; validada pelo responsável em 18/11/2026 |
| P7 | Limpeza: sem `accounting_periods`, `period_configurations`, colunas de vínculo nem RPCs de período (migration `20261113000700`, local e homologação; Drift v8 com migração testada; pendências e conflitos antigos de período descartados/encerrados). `mapa_app.md`, `banco_de_dados.md` e `arquitetura.md` atualizados | Feita 13/11/2026; validada pelo responsável em 18/11/2026 |
| P8 | Validação do responsável no emulador e na Web (P2–P7 juntas). As migrations `20261113000300`–`0800` já estão em `norte-homologacao` (conferido no `db push --remote` de 14/11/2026). O banco local do aparelho migra sozinho para a v9 ao abrir | Validada pelo responsável em 18/11/2026 (P2–P7) |

## F — Aba Ferramentas (13–14/11/2026)
| ID | Item | Situação |
|---|---|---|
| F3 | A área "Em destaque" está pronta e testada só com ferramenta de teste (nenhuma ferramenta real em destaque). A explicação antes do primeiro uso e as categorias já são usadas pela Calculadora de juros compostos | Aceito |
| F6 | Gestão de Faturas de Cartões (RF029): spec `docs/ferramentas/gestao_de_faturas.md`. GF0.1 validada e GF0.2–GF6.2 autorizadas em sequência em 16/11/2026, com validação de tudo no fim. **GF0.2–GF6.2 feitas em 16/11/2026** (domínio, servidor local, Drift v10, sincronização, telas, catálogo). Falta: validação do responsável (F7 a F9) e GF6.3 homologação (só com autorização, R2) | Validada pelo responsável em 18/11/2026; GF6.3 (F10) aplicada e testada em homologação em 19/11/2026 |
| F7 | Decisões técnicas tomadas pelo agente na implementação, para o responsável confirmar ou mudar: (1) fecha 30 e vence 31 em mês de 30 dias (ou fevereiro) cairia no mesmo dia → vence no dia 31 (ou último dia) do mês seguinte; (2) ao corrigir datas, o fechamento precisa ficar entre os fechamentos das faturas vizinhas (evita ciclos sobrepostos); (3) parcela que cairia em fatura já paga (que não seja a 1ª) conta como paga fora; (4) na edição da compra, a regra da "compra antiga" só vale se mudar cartão, data ou fatura da 1ª parcela; (5) mudança de preço da assinatura não sobrescreve cobrança editada à mão; (6) início da assinatura: fatura atual ou uma das 11 seguintes, sem editar depois; (7) parcela editada à mão precisa ser maior que zero; (8) calculadora aceita até 10 dígitos inteiros e 6 decimais por número; (9) cobranças faltantes após app fechado: no máximo 24 faturas para trás | Aceitas pelo responsável em 18/11/2026 |
| F8 | Validação no emulador (claro e escuro) e na Web: conferido pelo agente no emulador em 16/11/2026 (ver `estado_atual.md`); Web (`flutter test --platform chrome`) não roda neste ambiente (T9) — conferir no navegador | Validada pelo responsável em 18/11/2026 |
| F9 | Textos da explicação, do ⓘ e da tela (`lib/features/card_bills/card_bills_texts.dart`) são rascunho do agente; ícone do catálogo `receipt_long` | Aceitos pelo responsável em 18/11/2026 |
| F10 | GF6.3: migration `20261116000100_card_bills.sql` aplicada em `norte-homologacao` pelo responsável em 18/11/2026 (`supabase db push --remote`) | Aplicada; testes de integração em homologação passaram em 19/11/2026 (41; o de volume levou 4min18 da meta de 5min) |

## RL — Reformulação de Relatórios (aprovada em 17/11/2026)
Spec: `docs/ferramentas/relatorios.md` (8 decisões na §10; RF025 sem mudança de cálculo). Plano RL0–RL7 aprovado; RL1–RL7 autorizadas em sequência em 17/11/2026, com validação de tudo no fim. O redesenho de Relatórios saiu da V8 (passa a ser este plano).
| ID | Entrega | Situação |
|---|---|---|
| RL0 | Especificação, nota no RF025, registro aqui | Feita 17/11/2026, validada pelo responsável em 18/11/2026 |
| RL1 | Preferências: coluna `user_preferences.reports`, RPCs `set_report_selection`/`complete_report_setup`, Drift v11, download, repositório (só Supabase local) | Feita 17/11/2026, validada pelo responsável em 18/11/2026 |
| RL2 | `ReportDefinition`, registro dos 5, catálogo puro, controller | Feita 17/11/2026, validada pelo responsável em 18/11/2026 |
| RL3 | Tela Meus relatórios, cartão em três níveis, rota `/relatorios/<id>`, relatórios 1 e 2 | Feita 17/11/2026, validada pelo responsável em 18/11/2026 |
| RL4 | Relatórios 3–5 nos três níveis + "a mais/a menos que o período anterior" | Feita 17/11/2026, validada pelo responsável em 18/11/2026 |
| RL5 | Configuração guiada | Feita 17/11/2026, validada pelo responsável em 18/11/2026 |
| RL6 | Catálogo e Personalizar | Feita 17/11/2026, validada pelo responsável em 18/11/2026 |
| RL7 | Integração dois aparelhos, emulador, docs; homologação só com autorização (R2) | Feita 17/11/2026, validada pelo responsável em 18/11/2026 |
| RL8 | Homologação: migration `20261117000100_report_preferences.sql` aplicada em `norte-homologacao` pelo responsável em 18/11/2026 | Aplicada; testes de integração em homologação passaram em 19/11/2026 |

Para validar (RL1–RL7): textos novos (frase da configuração guiada, benefícios, "Igual ao período anterior" quando a diferença do relatório 4 é zero, frases de vazio dos relatórios 3–5, "Recebido no período"/"Despesas do período"), nomes curtos nos cartões ("Evolução do dinheiro livre", "Comparativo por período"); cores do comparativo e do gráfico agrupado passaram a ser as da Home (receitas/despesas/investimentos); conferência na Web (T9). Na tela completa com 11–12 períodos, os rótulos do eixo dos gráficos (já existentes) ficam apertados no celular — ajuste visual a decidir (A).

## IM — Importação de dados CSV (aprovada em 18/11/2026)
Spec: `docs/importacao.md`. RF030 e RN046–RN055 aprovados pelo responsável em 18/11/2026, com as decisões D16–D31 aceitas (registradas na spec §18; IDs D16–D31 usados, não reaproveitar). Um único CSV por importação. Condição D31 cumprida em 18/11/2026.
| ID | Entrega | Situação |
|---|---|---|
| IM0 | Documentação: RF030, exceção na §3.2, RN046–RN055, spec, este registro | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM1 | Domínio: leitura (encoding, separador, RFC 4180) e formatos do Norte | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM2 | Domínio: colunas, valores, datas, classificação, regras e linhas rejeitadas | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM3 | Domínio: categorias e duplicidades | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM4 | Domínio: séries, âncora, prévia das atrasadas e plano (ids e blocos) | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM5 | Servidor: migration, `begin/apply_chunk/finish`, testes SQL (só Supabase local) | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM6 | Servidor: `undo_preview/undo_batch`, testes SQL | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM7 | Dados e aplicação na Web: escolha do arquivo, repositório, blocos, retomada, integração local | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM8 | Telas das etapas 1–9 | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM9 | Processamento, resultado, histórico e desfazer; item em Mais; conferência no navegador | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM-A1 | Modelo para baixar e passo a passo "Como importar" (pedido do responsável, spec §20) | Feita 18/11/2026, validada pelo responsável em 19/11/2026 |
| IM10 | Homologação: migration `20261118000100_import_batches.sql` aplicada em `norte-homologacao` pelo responsável em 18/11/2026 (junto de RL8 e F10) | Aplicada; testes de integração em homologação passaram em 19/11/2026 |

Revisão antes da implementação (18/11/2026), aceita pelo responsável: D32–D36 (série que colide com o existente, série encerrada, limites, regra "pelo sinal", categoria inativa) e ajustes técnicos V15–V25 na spec; RN047, RN048, RN050–RN052 e RN055 atualizadas. Confirmado em 18/11/2026: desfazer cancela também as ocorrências inalteradas geradas pelo app depois da importação (RN055/§10). Teto de data (01/01/2000 a hoje + 5 anos) e de valor (R$ 10.000.000,00) são sugestão do agente aceita em bloco. Na IM5, medir tempo do bloco e do `finish` com muitas séries antigas.

IM1–IM9 autorizadas pelo responsável em 18/11/2026 ("Pode fazer a implementação de IM1 a IM10, valido todas elas no final"); feitas em 18/11/2026. Migration `20261118000100_import_batches.sql` aplicada **só no Supabase local** (via psql no banco local). Ajustes da implementação na spec §19.

Validado pelo responsável em 19/11/2026 ("aprovado csv"), com os pontos abaixo aceitos como implementados (IM0–IM9 e IM-A1): fluxo completo na Web (Mais → Importar dados), textos das etapas, ajustes da §19 da spec (uma importação aberta inclui interrompida/desfazendo; um formato de data para todas as colunas; campos "Data prevista" e "Valor pago"; "marcar como pagas" não muda as marcadas "pendente"; categorias "criar" são criadas mesmo se as linhas forem ignoradas). **Conferência visual no navegador não foi feita pelo agente** (sem navegador neste ambiente; compilação Web conferida e telas cobertas por testes de widget); `flutter test --platform chrome` segue bloqueado (T9).

Observação: cada linha importada gera auditoria e registro de repetição (ex.: 50 mil linhas ≈ 100 mil registros técnicos). Com a D15, a auditoria sai após 12 meses e a resposta guardada das operações fica sem conteúdo (a chave continua existindo).

## X — Retenção de 12 meses (D15, autorizada em 18/11/2026)
X0–X4 autorizadas pelo responsável em 18/11/2026 ("implementa da x0 a x4, valido td no final"). Regras: RN029, RN030 (retenção), CLAUDE.md regra 9, `requisitos.md` §6 e §8, `arquitetura.md` §4.
| ID | Entrega | Situação |
|---|---|---|
| X0 | Documentação: RN029 e RN030 reescritas, princípio 9, `requisitos.md`, CLAUDE.md regra 9, `arquitetura.md`, `banco_de_dados.md`, `mapa_app.md` | Feita 18/11/2026, validada em 19/11/2026 |
| X1 | Domínio `lib/core/domain/retention.dart` (limite igual ao PostgreSQL, 29/02 → 28/02) e conferência do gerador de recorrência: **ele não só olha para frente**, porque preenche todo mês vazio desde o início do modelo. Por isso a ocorrência de recorrência apagada não é limpa (ver X-A) | Feita 18/11/2026, validada em 19/11/2026 |
| X2 | Servidor: migration `20261118000200_retention_purge.sql` (`purge_expired_records` + `pg_cron` diário), teste `retention_purge_test.sql`. Aplicada **só no Supabase local** via psql (job `norte-retencao-12-meses` agendado lá) | Feita 18/11/2026, validada em 19/11/2026 |
| X3 | Celular e Web: limpeza no aparelho ao fim de cada sincronização; download desde o início após 11 meses sem download completo (e uma vez após a atualização), apagando o que o servidor limpou; motivo em português para edição de lançamento já apagado; "Cancelar" virou **"Apagar"** (lançamento e investimento), com a mesma confirmação | Feita 18/11/2026, validada em 19/11/2026 |
| X4 | Testes: domínio, limpeza local, download desde o início, aparelho parado com edição offline (dois aparelhos no Supabase local) | Feita 18/11/2026, validada em 19/11/2026 |
| X5 | Homologação: `20261118000200_retention_purge.sql` aplicada em `norte-homologacao` pelo responsável em 19/11/2026 (`supabase db push --remote`);  job `norte-retencao-12-meses` (`17 6 * * *`) conferido pelo responsável em 19/11/2026; 42 testes de integração em homologação passaram em 19/11/2026 (inclui `retention_test.dart`) | Concluída |

Validado pelo responsável em 19/11/2026 ("validado"), com os pontos abaixo aceitos como implementados. X-D foi decidido pelo responsável em 19/11/2026: a exportação CSV não traz mais os apagados (feito e testado). X-H segue pendente para a Entrega 80:
- **X-A, ocorrência de recorrência apagada:** fica guardada enquanto o modelo existir, porque sem ela o app gera o mês de novo. A alternativa seria mudar o gerador para só olhar para frente, no app e no servidor, e guardar só a última ocorrência de cada modelo. Isso mexe na geração de recorrências e não foi feito sem aprovação.
- **X-B, auditoria:** 12 meses, escolha do agente pela recomendação. O responsável pode trocar por "até sincronizar".
- **X-C, cópias técnicas:** no servidor, conflitos resolvidos e respostas guardadas das operações seguem os 12 meses. As respostas ficam sem conteúdo e a chave continua. Um aparelho que reenvie uma operação com mais de 12 meses recebe recusa, nunca reaplicação.
- **X-D, exportação CSV:** os apagados não saem mais. A coluna `status` continua.
- **X-E, desfazer importação:** em item já limpo (mais de 12 meses), aparece como "preservado — Não encontrado".
- **X-F, textos:** "Apagar lançamento", "Apagar este lançamento?", "Ele sai do dinheiro livre e some da lista na hora. Não é possível desfazer." Investimento no mesmo padrão. Motivo da recusa: "Este lançamento foi apagado (em outro aparelho ou há mais de 12 meses) e não existe mais no servidor. Descarte a alteração."
- **X-G, primeira sincronização após a atualização:** cada aparelho baixa de novo todos os lançamentos uma vez. Não foi conferido no emulador.
- **X-H, política de privacidade (D12, Entrega 80):** deve informar os 12 meses e o prazo dos backups (Entrega 77).

## T — Pendências técnicas
| ID | Item |
|---|---|
| T1 | Processo de promoção homologação → produção; validar grants/RLS/ownership em produção |
| T2 | Backup, restauração e retenção (Entrega 77) |
| T3 | Observabilidade (Vector do Supabase local reiniciando) |
| T4 | Sincronização ponta a ponta: roteiro manual e rodada contra o hospedado |
| T5 | Notificações: validação completa no Android 13+ |
| T6 | Medir índices e metas RN043 |
| T7 | Testar no app: ciclos dias 29–31, ano bissexto, repetição com dia útil anterior, troca de configuração, alertas após o fim do período, cinco relatórios (junto da P8) |
| T8 | Paridade BRL/datas no Flutter Web × Drift/PostgreSQL |
| T9 | `flutter test --platform chrome` não carrega nenhum teste nesta máquina (inclusive os antigos: "Connection closed before test suite loaded"); investigar o ambiente |

## A — Ajustes e lacunas conhecidas (comportamento atual a corrigir ou aceito)
| ID | Item | Situação |
|---|---|---|
| A1 | Listas Web limitadas a 1.000 linhas (`remote_table_reader.dart`) | Aceito (D13) |
| A2 | Conflito aberto no servidor não chega ao celular após reinstalar | Aceito (D7) |
| A3 | Dados não sincronizados se perdem ao desinstalar | Aceito |
| A4 | Entregas 3, 4, 7B–8 (Fase 2) sem validação registrada | Aberto |
| A5 | Renomeação Porquinho → Norte: pacote Dart, nomes internos e `drift_schemas/porquinho/` mantidos por compatibilidade | Aceito |
| A6 | Contrato Web × celular só define porta de gravação e modo (`core/data_access.dart`) | Aceito |

## M — Melhorias futuras (fora do MVP; não implementar sem aprovação)
| ID | Ideia | Origem |
|---|---|---|
| M1 | iOS | fora do MVP desde 10/11/2026 |
| M2 | Web offline | hoje somente online |
| M3 | Desfazer pagamento, reativar categoria, desfazer cancelamento | fora do MVP por ora (10/11/2026) |
| M5 | Criar subcategoria direto no formulário de lançamento ("+ Nova subcategoria", mostrando o campo mesmo sem subcategorias). Aguarda aprovação | 12/11/2026, pedido de criação de categoria no lançamento |
| M6 | Novas ferramentas propostas na referência visual da aba Ferramentas: Gasto por dia, E se eu gastar?, Comparar períodos, Nova conta fixa. Cada uma precisa de regra aprovada (ex.: contar hoje ou não, usar receitas pendentes ou não) e módulo próprio | 13/11/2026, referência visual "Norte Ferramentas" |
| M7 | Levar Itens de atenção, Recorrências e Exportar também para o catálogo de Ferramentas (hoje só em Mais) | 13/11/2026, mesma referência |
| M8 | Exportação fiel para ida e volta: id da série de recorrência, ícone e cor das categorias e opção de arquivo único combinado (permitiria importar a conta inteira numa importação só) | 18/11/2026, D30 (planejamento da importação CSV) |
| M4 | Itens de `requisitos.md` §12 (contas, cartão detalhado, carteira, compartilhamento, importação de outros formatos; CSV aprovado no RF030) | baseline v0.5 |

Novas ideias: acrescentar linha com data e origem.

## Critérios de conclusão do MVP
Requisitos aprovados implementados; dinheiro livre coberto por testes unitários e de integração; competência correta; pagamento sem segunda dedução; edição/cancelamento recalculam e auditam; recorrências corretas; offline idempotente com conflitos apresentados; isolamento testado; Android e Web validados; documentação = comportamento; pendências bloqueadoras resolvidas ou excluídas formalmente.
