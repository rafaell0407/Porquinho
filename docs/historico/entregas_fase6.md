# Fase 6 — Investimentos simples e rendimentos manuais (registro compacto)

**Status:** CONCLUÍDA e VALIDADA pelo responsável em 11/11/2026 (Entregas 51–58; a 54 foi removida por D3; commit `3560366`). Estado vigente: `docs/estado_atual.md`. Regras: `docs/regras_negocio.md` RN004–RN008, RN021–RN023, RN027–RN033, RN038, RN045; RFs: RF016–RF018, RF020–RF022, RF027.

## Entregas
| # | Resultado | Banco |
|---|---|---|
| 51 | Domínio e gravação de investimento avulso (celular: registro + auditoria + fila; Web: RPC), com as validações da RPC; `lib/features/investments/` | — |
| 52 | Sincronização ponta a ponta e tela de atenção com valor e data; "Editar" valor e data no conflito (D6); cobre a RPC 7A, antes sem validação | — |
| 53 | "Novo investimento" em Lançamentos (mesmo formulário da despesa, só valor e data); investimentos na lista com filtro "Investimentos"; editar e cancelar | — |
| 54 | REMOVIDA (D3): total no Dashboard fora do MVP | — |
| 55 | Recorrência no servidor: tabela `investment_recurrence_templates`; campos de ocorrência e unicidade `(owner_id, recurrence_template_id, scheduled_for_date)` em `investment_allocations`; RPCs do modelo; conversão do avulso em primeira ocorrência; `generate_due_recurrence_occurrences` passa a gerar investimentos | nova migration; teste `supabase/tests/rpc_investment_recurrence_test.sql` |
| 56 | Recorrência no aparelho: tabela local do modelo e campos novos, geração local com o mesmo identificador, download | **Drift v4** (snapshot + migração v3 → v4 testada) |
| 57 | "Repetir" no formulário de investimento; editar ocorrência "só esta" / "a recorrência"; parar de repetir; investimentos em Mais → Recorrências | — |
| 58 | Rendimentos manuais (receita comum), regressão e fechamento; sem tela nova (D4) | — |

## Decisões (11/11/2026, APROVADAS)
| # | Decisão |
|---|---|
| D1 | Data informada pelo usuário (padrão hoje), passada ou futura, editável; período inexistente → o app pergunta se cria (RN002) |
| D2 | Investimento tem só valor e data: sem descrição, categoria, status pendente/pago ou vencimento |
| D3 | Total investido no Dashboard fora do MVP/da Fase 6; investimentos aparecem em Lançamentos com filtro; total por período no relatório da Fase 7 (`requisitos.md` §13.7). **Revisada pela D1 da Fase 7** (Dashboard mostra investimentos na composição) |
| D4 | Nenhuma tela ou atalho de rendimento; é receita comum (categoria "Rendimentos" sugerida) |
| D5 | Não existe resgate; não lançar resgate como receita. Desfazer = cancelar: o valor volta à sobra **do período original** (RN029–RN030) |
| D6 | Conflito de investimento oferece "Manter do aparelho", "Manter do servidor" e "Editar" (valor e data), mostrando as duas versões |
| D7 | Recorrência igual à despesa recorrente (Fase 5 D1, D2, D4, D7, D8): "Repetir" todo mês/período, o lançamento é a primeira ocorrência, geração ao abrir/sincronizar com atrasadas, id determinístico, mudanças só para as próximas, consulta em Mais → Recorrências; a ocorrência entra na sobra quando gerada, sem confirmação |
| D8 | Valor fixo com edição por ocorrência ("só esta" ou "a recorrência"); sem valor variável nem investimento sem valor |
| D9 | Investimento recorrente sem pendente/pago, vencimento nem alertas |
| D10 | "Novo investimento" na mesma lista de "Nova receita"/"Nova despesa", com o formulário da despesa mostrando só os campos aplicáveis |

Fora da fase: categoria/descrição/status de investimento, carteira, ativos, rentabilidade, cálculo de rendimento, saldo investido acumulado, desfazer cancelamento. Sugestões futuras (não incorporadas): descrição/observação; desfazer cancelamento.

## Divergências do planejamento
V1–V3, V7, V8: resolvidas por D1–D3, D6, D7–D9 e documentos atualizados. V4/V5 (estado da Fase 5 sem commit / "aguardando validação"): resolvidas, o commit `1f97003` registra a Fase 5 como concluída e validada. V6 (bloco duplicado na RN038): sem ação; ver pendências.

## Testes (11/11/2026) e limitações
- `flutter analyze` sem avisos; `flutter test` 341 passaram (15 ignorados já existentes); suíte PostgreSQL inteira; `flutter build web` compila; teste de banco Web (`tooling/web_check`) passa. Cobertura principal: `investment_service_test.dart`, `attention_test.dart`, `transactions_screen_test.dart`, `rpc_investment_recurrence_test.sql` (inclui regressão da geração de receitas/despesas), `migration_test.dart` (v3 → v4), `investment_recurrence_test.dart`, `recurrence_screens_test.dart`, `yield_and_surplus_test.dart`.
- `flutter test --platform chrome` na raiz não conclui nesta máquina (testes só de celular sem marca de plataforma; Chrome não abre testes puros no tempo).
- Teste manual no emulador Android e na Web feito pelo responsável (validação).

## Riscos que permanecem
- Investimento recorrente esquecido continua descontando todo mês até "parar de repetir"; atrasadas geradas de uma vez reduzem a sobra de períodos passados.
- Usuário pode contar o mesmo dinheiro duas vezes (despesa e investimento); o app não detecta (princípio da RN006).

## Pendências
- Bloco "Decisões de 11/11/2026 (Fase 5)" repetido na RN038 de `regras_negocio.md`: remoção depende de autorização.
