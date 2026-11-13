# Pendências, ajustes e melhorias — Norte

Lista-mestra única do que falta. **Atualizado em:** 12/11/2026.
Regras: cada item tem ID fixo (não reaproveitar). Concluiu → apagar a linha e registrar na entrega da fase. Achou algo fora da entrega em curso → registrar aqui, não resolver sozinho. Melhorias (M) só com aprovação.

## D — Decisões abertas (responsável)
| ID | Assunto | Situação |
|---|---|---|
| D1 | Nome Norte e `applicationId` `br.com.norte.app` | Aprovados 12/11/2026; confirmar como definitivos antes da 1ª publicação. Falta ícone. Domínio próprio opcional até a Entrega 79. |
| D5 | E-mail Resend / SMTP | Aprovado 12/11/2026; configurar na Entrega 79 (exige domínio). |
| D14 | Política para futura alteração da zona IANA do usuário | Pendente. |

## R — Ações do responsável
- R1: Validar a Entrega 76 (homologação `norte-homologacao`, exceto SMTP).
- R2: Autorizar e fornecer referências do Supabase gerenciado nas próximas etapas (nunca agir sem autorização).
- R3: Rodar `supabase migration up` no local quando houver migration nova.
- R4: Roteiro manual de validação da Fase 8 (`entregas_fase8.md` §8).

## E — Entregas restantes da Fase 8 (detalhe em `entregas_fase8.md`)
- 75 (final): depende de D1 · 77 backup · 78 regressão Android/Web · 79 produção + SMTP (D5) + monitoramento (tratamento global de erros já feito) · 80 publicação Web · 81 publicação Android · 82 fechamento.

## T — Pendências técnicas
| ID | Item |
|---|---|
| T1 | Processo de promoção homologação → produção; validar grants/RLS/ownership em produção |
| T2 | Backup, restauração e retenção (Entrega 77) |
| T3 | Observabilidade (Vector do Supabase local reiniciando) |
| T4 | Sincronização ponta a ponta: roteiro manual e rodada contra o hospedado |
| T5 | Notificações: validação completa no Android 13+ |
| T6 | Medir índices e metas RN043 |
| T7 | Testar no app: ciclos dias 29–31, ano bissexto, alertas após o fim do período, cinco relatórios |
| T8 | Paridade BRL/datas no Flutter Web × Drift/PostgreSQL |

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
| M4 | Itens de `requisitos.md` §12 (contas, cartão detalhado, carteira, compartilhamento, importação) | baseline v0.5 |

Novas ideias: acrescentar linha com data e origem.

## Critérios de conclusão do MVP
Requisitos aprovados implementados; dinheiro livre coberto por testes unitários e de integração; competência correta; pagamento sem segunda dedução; edição/cancelamento recalculam e auditam; recorrências corretas; offline idempotente com conflitos apresentados; isolamento testado; Android e Web validados; documentação = comportamento; pendências bloqueadoras resolvidas ou excluídas formalmente.
