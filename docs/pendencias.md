# Pendências, ajustes e melhorias — Norte

Lista-mestra única do que falta. **Atualizado em:** 19/11/2026 (T6 e T12 validados e registrados em `entregas_fase8.md` §9; restos viraram T13 e T14. Antes, limpeza: planos P, GF, RL, IM, X, AT e T10 concluídos foram registrados em `entregas_fase8.md` §9).
Regras: cada item tem ID fixo (não reaproveitar). Concluiu → apagar a linha e registrar na entrega da fase. Achou algo fora da entrega em curso → registrar aqui, não resolver sozinho. Melhorias (M) só com aprovação.

## D — Decisões abertas (responsável)
| ID | Assunto | Situação |
|---|---|---|
| D1 | Nome Norte e `applicationId` `br.com.norte.app` | Aprovados 12/11/2026; confirmar como definitivos antes da 1ª publicação. Falta ícone. Domínio próprio opcional até a Entrega 79. |
| D5 | E-mail Resend / SMTP | Aprovado 12/11/2026; configurar na Entrega 79 (exige domínio). |
| D14 | Política para futura alteração da zona IANA do usuário | Decidido pelo responsável em 18/11/2026: a mudança vale só dali em diante; lançamentos e períodos passados não são recalculados. Falta virar RN em `regras_negocio.md` quando a troca de fuso for implementada. |

## R — Ações do responsável
- R1: Validar a Entrega 76 (homologação `norte-homologacao`, exceto SMTP).
- R2: Autorizar e fornecer referências do Supabase gerenciado nas próximas etapas (nunca agir sem autorização).
- R3: Rodar `supabase migration up` no local quando houver migration nova.
- R4: Roteiro manual de validação da Fase 8 (`entregas_fase8.md` §8).
- R6: Buscar o nome "Norte" no INPI antes de publicar nas lojas e, se possível, consultar advogado de propriedade intelectual.

## E — Entregas restantes da Fase 8 (detalhe em `entregas_fase8.md`)
- 75 (final): depende de D1 · 77 backup · 78 regressão Android/Web · 79 produção + SMTP (D5) + monitoramento (tratamento global de erros já feito) · 80 publicação Web (a política de privacidade, D12, deve informar a guarda de 12 meses dos apagados e da auditoria e o prazo dos backups da Entrega 77 — antigo X-H) · 81 publicação Android · 82 fechamento.

## T — Pendências técnicas
| ID | Item |
|---|---|
| T1 | Processo de promoção homologação → produção; validar grants/RLS/ownership em produção |
| T2 | Backup, restauração e retenção (Entrega 77) |
| T3 | Observabilidade (Vector do Supabase local reiniciando) |
| T4 | Sincronização ponta a ponta: roteiro manual e rodada contra o hospedado |
| T5 | Notificações: validação completa no Android 13+ |
| T7 | Testar no app: ciclos dias 29–31, ano bissexto, repetição com dia útil anterior, troca de configuração, alertas após o fim do período, cinco relatórios |
| T8 | Paridade BRL/datas no Flutter Web × Drift/PostgreSQL |
| T9 | `flutter test --platform chrome` não carrega nenhum teste nesta máquina (inclusive os antigos: "Connection closed before test suite loaded"); investigar o ambiente. Telas novas (Relatórios, Importação, Apagar todos) não foram conferidas pelo agente no navegador |
| T11 | A suíte de integração completa em homologação roda os arquivos ao mesmo tempo; com a importação de 20 mil linhas junto, testes curtos passam de 30 s. Opção: rodar a importação e o volume separados (ou `-j 1`) |
| T13 | Lista de lançamentos de 1 mês na Web acima da meta de 1 s com muito dado: 1.322 ms com 100 mil lançamentos em `norte-homologacao` (cerca de 830 linhas do mês trazidas de uma vez; 970 ms com 20 mil antes das 3 consultas em paralelo). Decidir a correção: pedir só as colunas usadas e/ou paginar a lista. Sobrou do T6 (validado em 19/11/2026) |
| T14 | Limite de 120 s do `delete_my_account` (migration `20261119000300_delete_account_timeout.sql`) aplicado só no Supabase local. Falta: aplicar em `norte-homologacao` (precisa de autorização do responsável), repetir a medição com 100 mil e conferir se "Apagar todos os lançamentos" (RF031) tem o mesmo limite com esse volume. Ressalva: se o gateway da nuvem cortar a chamada antes de 120 s, a exclusão pode seguir no servidor sem o app saber. Sobrou do T12 (validado em 19/11/2026) |

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
