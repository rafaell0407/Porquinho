# Pendências, ajustes e melhorias — Norte

Lista-mestra única do que falta. **Atualizado em:** 18/11/2026.
Regras: cada item tem ID fixo (não reaproveitar). Concluiu → apagar a linha e registrar na entrega da fase. Achou algo fora da entrega em curso → registrar aqui, não resolver sozinho. Melhorias (M) só com aprovação.

## D — Decisões abertas (responsável)
| ID | Assunto | Situação |
|---|---|---|
| D1 | Nome Norte e `applicationId` `br.com.norte.app` | Aprovados 12/11/2026; confirmar como definitivos antes da 1ª publicação. Falta ícone. Domínio próprio opcional até a Entrega 79. |
| D5 | E-mail Resend / SMTP | Aprovado 12/11/2026; configurar na Entrega 79 (exige domínio). |
| D14 | Política para futura alteração da zona IANA do usuário | Pendente. |
| D15 | Rever a guarda de histórico dos lançamentos (auditoria, versões antigas, cancelados): o que guardar, por quanto tempo e como mostrar ao usuário | Pendente (registrado em 16/11/2026, a pedido do responsável). |

## R — Ações do responsável
- R1: Validar a Entrega 76 (homologação `norte-homologacao`, exceto SMTP).
- R2: Autorizar e fornecer referências do Supabase gerenciado nas próximas etapas (nunca agir sem autorização).
- R3: Rodar `supabase migration up` no local quando houver migration nova.
- R4: Roteiro manual de validação da Fase 8 (`entregas_fase8.md` §8).
- R5: Validar a V1 (tema) no emulador, claro e escuro.
- R6: Buscar o nome "Norte" no INPI antes de publicar nas lojas e, se possível, consultar advogado de propriedade intelectual.

## E — Entregas restantes da Fase 8 (detalhe em `entregas_fase8.md`)
- 75 (final): depende de D1 · 77 backup · 78 regressão Android/Web · 79 produção + SMTP (D5) + monitoramento (tratamento global de erros já feito) · 80 publicação Web · 81 publicação Android · 82 fechamento.

## P — Reestruturação de períodos (aprovada em 13/11/2026)
Decisões do responsável: configuração única, trocável a qualquer momento e valendo para todos os períodos; período calculado por datas (sem tabela de períodos nem vínculo do lançamento ao período); repetição só "Todo mês", dia inexistente vai para o dia útil (seg–sex) anterior; início do ciclo sem dia útil; caso raro 29–31 aceito; dados de desenvolvimento podem ser apagados (sem converter recorrências "por período"). Regras: RN001–RN004, RN010, RN014, RN017, RN036–RN038, RN042; RF006, RF010, RF019. P1 (documentação) validada em 13/11/2026.
Ordem revista em 13/11/2026: o app continua funcionando entre as entregas e nada é removido antes da rede de segurança (P4) passar. O vínculo do lançamento ao período fica opcional na P6 (Drift v7) e é removido na P7 (Drift v8). O responsável valida P2–P7 juntas no fim; cada entrega é testada antes da seguinte.
| ID | Entrega | Situação |
|---|---|---|
| P2 | Domínio: período calculado por data e intervalo de navegação (`PeriodCalendar.between/bounds`, `PeriodConfig.fromDb`); tabela única de casos `test/fixtures/period_cases.json` (243 casos, gerada por implementação independente). Sem caso SQL: o servidor não calcula períodos, recebe os intervalos do app. Não muda o app | Feita 13/11/2026 |
| P3 | Totais por intervalo de datas no celular e no servidor (RPC `get_range_report`, migration `20261113000400`, local e homologação); Dashboard, Lançamentos e Relatórios somam e listam pelas datas; períodos gravados continuam existindo | Feita 13/11/2026 |
| P4 | Rede de segurança: "soma pelo período gravado" = "soma pelas datas do mesmo período" no celular (totais, categorias, listas), no servidor (`get_period_report` × `get_range_report`) e na suíte SQL; dados reais do Supabase local (4.439 lançamentos, 93 contas) sem nenhum lançamento fora do seu período. Nenhuma diferença encontrada | Feita 13/11/2026 | Testes da rede de segurança retirados na P6 (o vínculo deixou de ser gravado).
| P5 | Repetição só "Todo mês", dia inexistente → último dia útil do mês (domínio `RecurrenceCalendar.monthlyDate`; servidor `recurrence_monthly_date`, migration `20261113000500`, local e homologação; tabela única de 360 casos JSON + SQL). Nunca duas ocorrências do mesmo modelo no mesmo mês (ocorrências antigas ficam na data em que foram geradas). "Todo período" sai do formulário e das telas de edição; recusado no app e no servidor; os 9 modelos "por período" do banco local foram desativados com auditoria. Modelos antigos continuam legíveis (rótulo "Todo período") | Feita 13/11/2026 |
| P6 | Configuração única `period_settings` (servidor: tabela + `set_period_settings` com conflito por versão + `get_entry_date_span`; migration `20261113000600`, local e homologação; Drift v7 com migração testada). Troca na hora na tela Período (com aviso); navegação do lançamento mais antigo ao mais distante; fim da pergunta "Criar os períodos…?"; nenhuma gravação de período nem de vínculo (RPCs e app); conflito da configuração em Itens de atenção | Feita 13/11/2026 |
| P7 | Limpeza: sem `accounting_periods`, `period_configurations`, colunas de vínculo nem RPCs de período (migration `20261113000700`, local e homologação; Drift v8 com migração testada; pendências e conflitos antigos de período descartados/encerrados). `mapa_app.md`, `banco_de_dados.md` e `arquitetura.md` atualizados | Feita 13/11/2026 |
| P8 | Validação do responsável no emulador e na Web (P2–P7 juntas). As migrations `20261113000300`–`0800` já estão em `norte-homologacao` (conferido no `db push --remote` de 14/11/2026). O banco local do aparelho migra sozinho para a v9 ao abrir | A fazer |
| P9 | Texto superado não pôde ir para `docs/historico/` (pasta bloqueada para o agente); está no commit `07c9226`. Responsável decide se copia para o histórico | Aberto |

## F — Aba Ferramentas (13–14/11/2026)
| ID | Item | Situação |
|---|---|---|
| F3 | A área "Em destaque" está pronta e testada só com ferramenta de teste (nenhuma ferramenta real em destaque). A explicação antes do primeiro uso e as categorias já são usadas pela Calculadora de juros compostos | Aceito |
| F6 | Gestão de Faturas de Cartões (RF029): spec `docs/ferramentas/gestao_de_faturas.md`. GF0.1 validada e GF0.2–GF6.2 autorizadas em sequência em 16/11/2026, com validação de tudo no fim. **GF0.2–GF6.2 feitas em 16/11/2026** (domínio, servidor local, Drift v10, sincronização, telas, catálogo). Falta: validação do responsável (F7 a F9) e GF6.3 homologação (só com autorização, R2) | Feita, aguardando validação |
| F7 | Decisões técnicas tomadas pelo agente na implementação, para o responsável confirmar ou mudar: (1) fecha 30 e vence 31 em mês de 30 dias (ou fevereiro) cairia no mesmo dia → vence no dia 31 (ou último dia) do mês seguinte; (2) ao corrigir datas, o fechamento precisa ficar entre os fechamentos das faturas vizinhas (evita ciclos sobrepostos); (3) parcela que cairia em fatura já paga (que não seja a 1ª) conta como paga fora; (4) na edição da compra, a regra da "compra antiga" só vale se mudar cartão, data ou fatura da 1ª parcela; (5) mudança de preço da assinatura não sobrescreve cobrança editada à mão; (6) início da assinatura: fatura atual ou uma das 11 seguintes, sem editar depois; (7) parcela editada à mão precisa ser maior que zero; (8) calculadora aceita até 10 dígitos inteiros e 6 decimais por número; (9) cobranças faltantes após app fechado: no máximo 24 faturas para trás | Aguardando validação |
| F8 | Validação no emulador (claro e escuro) e na Web: conferido pelo agente no emulador em 16/11/2026 (ver `estado_atual.md`); Web (`flutter test --platform chrome`) não roda neste ambiente (T9) — conferir no navegador | A fazer (responsável) |
| F9 | Textos da explicação, do ⓘ e da tela (`lib/features/card_bills/card_bills_texts.dart`) são rascunho do agente; ícone do catálogo `receipt_long` | Aguardando ajuste do responsável |
| F10 | GF6.3: aplicar a migration `20261116000100_card_bills.sql` em `norte-homologacao` e rodar `tooling/test_integration_homolog.ps1` | Só com autorização (R2) |

## RL — Reformulação de Relatórios (aprovada em 17/11/2026)
Spec: `docs/ferramentas/relatorios.md` (8 decisões na §10; RF025 sem mudança de cálculo). Plano RL0–RL7 aprovado; RL1–RL7 autorizadas em sequência em 17/11/2026, com validação de tudo no fim. O redesenho de Relatórios saiu da V8 (passa a ser este plano).
| ID | Entrega | Situação |
|---|---|---|
| RL0 | Especificação, nota no RF025, registro aqui | Feita 17/11/2026, aguardando validação |
| RL1 | Preferências: coluna `user_preferences.reports`, RPCs `set_report_selection`/`complete_report_setup`, Drift v11, download, repositório (só Supabase local) | Feita 17/11/2026, aguardando validação |
| RL2 | `ReportDefinition`, registro dos 5, catálogo puro, controller | Feita 17/11/2026, aguardando validação |
| RL3 | Tela Meus relatórios, cartão em três níveis, rota `/relatorios/<id>`, relatórios 1 e 2 | Feita 17/11/2026, aguardando validação |
| RL4 | Relatórios 3–5 nos três níveis + "a mais/a menos que o período anterior" | Feita 17/11/2026, aguardando validação |
| RL5 | Configuração guiada | Feita 17/11/2026, aguardando validação |
| RL6 | Catálogo e Personalizar | Feita 17/11/2026, aguardando validação |
| RL7 | Integração dois aparelhos, emulador, docs; homologação só com autorização (R2) | Feita 17/11/2026, aguardando validação |
| RL8 | Homologação: aplicar `20261117000100_report_preferences.sql` em `norte-homologacao` | Aguarda autorização (R2) |

Para validar (RL1–RL7): textos novos (frase da configuração guiada, benefícios, "Igual ao período anterior" quando a diferença do relatório 4 é zero, frases de vazio dos relatórios 3–5, "Recebido no período"/"Despesas do período"), nomes curtos nos cartões ("Evolução do dinheiro livre", "Comparativo por período"); cores do comparativo e do gráfico agrupado passaram a ser as da Home (receitas/despesas/investimentos); conferência na Web (T9). Na tela completa com 11–12 períodos, os rótulos do eixo dos gráficos (já existentes) ficam apertados no celular — ajuste visual a decidir (A).

## IM — Importação de dados CSV (aprovada em 18/11/2026)
Spec: `docs/importacao.md`. RF030 e RN046–RN055 aprovados pelo responsável em 18/11/2026, com as decisões D16–D31 aceitas (registradas na spec §18; IDs D16–D31 usados, não reaproveitar). Um único CSV por importação. Desenvolvimento só depois de validar RL, GF (F6–F9) e P8 (D31) e com autorização; uma entrega por vez.
| ID | Entrega | Situação |
|---|---|---|
| IM0 | Documentação: RF030, exceção na §3.2, RN046–RN055, spec, este registro | Feita 18/11/2026, aguardando validação |
| IM1 | Domínio: leitura (encoding, separador, RFC 4180) e formatos do Norte | Aguarda autorização |
| IM2 | Domínio: colunas, valores, datas, classificação, regras e linhas rejeitadas | Aguarda autorização |
| IM3 | Domínio: categorias e duplicidades | Aguarda autorização |
| IM4 | Domínio: séries, âncora, prévia das atrasadas e plano (ids e blocos) | Aguarda autorização |
| IM5 | Servidor: migration, `begin/apply_chunk/finish`, testes SQL (só Supabase local) | Aguarda autorização |
| IM6 | Servidor: `undo_preview/undo_batch`, testes SQL | Aguarda autorização |
| IM7 | Dados e aplicação na Web: escolha do arquivo, repositório, blocos, retomada, integração local | Aguarda autorização |
| IM8 | Telas das etapas 1–9 | Aguarda autorização |
| IM9 | Processamento, resultado, histórico e desfazer; item em Mais; conferência no navegador | Aguarda autorização |
| IM10 | Homologação | Só com autorização (R2) |

Observação: cada linha importada gera auditoria e registro de repetição (ex.: 50 mil linhas ≈ 100 mil registros técnicos); considerar na D15.

## V — Renovação visual (aprovada em 12/11/2026; uma entrega por vez)
Visual próprio do Norte (Menta + Inter), sem copiar elementos de outro app: sem mascote, sem barra de assistente, abas só as da barra inferior (RF004), ícones do Material do Flutter, lista de categorias própria.
| ID | Entrega | Situação |
|---|---|---|
| V1–V5 | Tema, ícone/cor nas categorias (V2), Dashboard (V3), Lançamentos e formulário (V4), Categorias e Mais (V5) | Feitas em 12/11/2026; aguardam validação (R5). Ao validar, apagar estas linhas |
| V6 | Subcategoria hoje herda ícone e cor da categoria (sem ícone próprio) | Aceito; ícone próprio por subcategoria só com aprovação |
| V8 | Telas fora do escopo da V3–V5 mantêm o layout antigo, só com cores/fonte novas (Período, Recorrências, Exportar, Segurança, Tema, Configuração inicial, Itens de atenção) | Aberto, sem aprovação para redesenhar |

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
