# Pendências, ajustes e melhorias — Norte

Lista-mestra única do que falta. **Atualizado em:** 20/11/2026 (R1 validado e registrado em `entregas_fase8.md` §9; T15 corrigido e validado; T7 reduzido ao que falta e A9 registrado após testes de borda de período e conferência no emulador; T13 removido: tempo da lista aceito pelo responsável; T6 e T12 validados e registrados em `entregas_fase8.md` §9; resto era o T14, concluído em 21/11/2026. Antes, limpeza: planos P, GF, RL, IM, X, AT e T10 concluídos foram registrados em `entregas_fase8.md` §9).
Regras: cada item tem ID fixo (não reaproveitar). Concluiu → apagar a linha e registrar na entrega da fase. Achou algo fora da entrega em curso → registrar aqui, não resolver sozinho. Melhorias (M) só com aprovação.

## D — Decisões abertas (responsável)
| ID | Assunto | Situação |
|---|---|---|
| D1 | Nome Norte e `applicationId` `br.com.norte.app` | Aprovados 12/11/2026; confirmar como definitivos antes da 1ª publicação. Falta ícone. Domínio próprio opcional até a Entrega 79. |
| D5 | E-mail Resend / SMTP | Aprovado 12/11/2026; configurar na Entrega 79 (exige domínio). |

## R — Ações do responsável
- R2: Autorização dada em 21/11/2026 para usar o Supabase gerenciado nas próximas etapas (Entregas 77–79). Falta o responsável fornecer as referências (projeto de produção, URL, chaves por canal seguro, nunca no repositório). Ações irreversíveis ou em produção (`db push`, restauração, apagar dados) continuam sendo confirmadas antes.
- R4: Roteiro manual de validação da Fase 8 (`entregas_fase8.md` §8).
- R6: Buscar o nome "Norte" no INPI antes de publicar nas lojas e, se possível, consultar advogado de propriedade intelectual.

## E — Entregas restantes da Fase 8 (detalhe em `entregas_fase8.md`)
- 75 (final): depende de D1 · 77 backup · 78 regressão Android/Web · 79 produção + SMTP (D5) + monitoramento (tratamento global de erros já feito) · 80 publicação Web (a política de privacidade, D12, deve informar a guarda de 12 meses dos apagados e da auditoria e o prazo dos backups da Entrega 77 — antigo X-H) · 81 publicação Android · 82 fechamento.

## T — Pendências técnicas
| ID | Item |
|---|---|
| T1 | Processo de promoção homologação → produção; validar grants/RLS/ownership em produção |
| T2 | Backup (Entrega 77): material pronto e ensaiado no Supabase local (`docs/backup.md`). Falta o responsável montar o repositório privado e os segredos e rodar a 1ª vez contra produção |
| T3 | Observabilidade. Vector do Supabase local reinicia em loop (diagnosticado em 20/11/2026): tenta ler o Docker por TCP `:2375` em IPv6 e recebe "Network unreachable"; é limitação do ambiente Docker/Windows, sem efeito no app (só a tela de Logs do Studio local fica vazia). Aceito; não afeta a produção. Monitoramento de produção segue na Entrega 79 |
| T4 | Sincronização ponta a ponta: roteiro manual e rodada contra o hospedado |
| T5 | Notificações: validação completa no Android 13+ |
| T7 | Feito em 20/11/2026: ciclos 29–31, ano bissexto, troca de configuração e despesa não paga após o fim do período em teste automatizado de ponta a ponta (`test/features/periods/period_edge_totals_test.dart`, 10 casos); repetição com dia útil e alertas já tinham testes; no emulador, ciclo dia 31 (período 31/10–29/11, Home e Lançamentos iguais e iguais ao servidor, configuração devolvida ao dia 20). Falta só: ver os cinco relatórios na tela com ciclo 29–31 e conferir alerta/notificação no aparelho (T5) |
| T8 | Paridade BRL/datas no Flutter Web × Drift/PostgreSQL |
| T9 | `flutter test --platform chrome` não carrega nenhum teste nesta máquina (inclusive os antigos: "Connection closed before test suite loaded"); investigar o ambiente. Telas novas (Relatórios, Importação, Apagar todos) não foram conferidas pelo agente no navegador |
| T11 | A suíte de integração completa em homologação roda os arquivos ao mesmo tempo; com a importação de 20 mil linhas junto, testes curtos passam de 30 s. Opção: rodar a importação e o volume separados (ou `-j 1`). Confirmado em 20/11/2026: `parity_test.dart` estourou os 5 min na rodada completa e passou isolado em 4min19 com `-Defines "--timeout=15m"` em `tooling/test_integration_homolog.ps1` |

## A — Ajustes e lacunas conhecidas (comportamento atual a corrigir ou aceito)
| ID | Item | Situação |
|---|---|---|
| A1 | Listas Web limitadas a 1.000 linhas (`remote_table_reader.dart`) | Aceito (D13) |
| A2 | Conflito aberto no servidor não chega ao celular após reinstalar | Aceito (D7) |
| A3 | Dados não sincronizados se perdem ao desinstalar | Aceito |
| A4 | Entregas 3, 4, 7B–8 (Fase 2) sem validação registrada | Aberto |
| A5 | Renomeação Porquinho → Norte: pacote Dart, nomes internos e `drift_schemas/porquinho/` mantidos por compatibilidade | Aceito |
| A6 | Contrato Web × celular só define porta de gravação e modo (`core/data_access.dart`) | Aceito |
| A7 | Ferramentas: a área "Em destaque" está pronta e testada só com ferramenta de teste (nenhuma ferramenta real em destaque) — antigo F3 | Aceito |
| A8 | Relatórios: na tela completa com 11–12 períodos, os rótulos do eixo dos gráficos ficam apertados no celular | Aberto (ajuste visual a decidir) |

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
| M9 | Recorrência só para frente: gerador (app e servidor) deixaria de preencher meses vazios desde o início do modelo, permitindo limpar ocorrências apagadas com mais de 12 meses (hoje ficam enquanto o modelo existir) | 19/11/2026, X-A (retenção D15) |
| M4 | Itens de `requisitos.md` §12 (contas, cartão detalhado, carteira, compartilhamento, importação de outros formatos; CSV aprovado no RF030) | baseline v0.5 |

Novas ideias: acrescentar linha com data e origem.

## Critérios de conclusão do MVP
Requisitos aprovados implementados; dinheiro livre coberto por testes unitários e de integração; competência correta; pagamento sem segunda dedução; edição/cancelamento recalculam e auditam; recorrências corretas; offline idempotente com conflitos apresentados; isolamento testado; Android e Web validados; documentação = comportamento; pendências bloqueadoras resolvidas ou excluídas formalmente.
