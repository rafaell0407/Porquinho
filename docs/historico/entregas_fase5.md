# Fase 5 — Recorrências (registro compacto)

**Status:** CONCLUÍDA e VALIDADA pelo responsável em 11/11/2026 (Entregas 43–50; commit `1f97003`). Estado vigente: `docs/estado_atual.md`. Regras: `docs/regras_negocio.md` RN004, RN010–RN019, RN038–RN039, RN041; RFs: RF006–RF013, RF018, RF021–RF023, RF027.

## Entregas
| # | Resultado | Principais arquivos |
|---|---|---|
| 43 | Domínio da agenda: datas mensais (meses curtos, bissexto, primeira ocorrência), períodos devidos, piso de mudança de agenda (D2), identificador determinístico (D1) | `lib/core/domain/recurrence_schedule.dart` |
| 44 | Migration `20261111000300_recurrence_generation_v2.sql`: id determinístico, gatilho de agenda (início antes do primeiro período recusado; mudança só para o futuro), geração reescrita (vencimento = data da ocorrência), RPC `create_recurrence_from_entry` | `supabase/tests/rpc_recurrence_v2_test.sql` |
| 45 | "Repetir" no formulário (todo mês / todo período, valor variável, "já recebi"/"já paga"); avulso vira primeira ocorrência; Mais → Recorrências (editar a recorrência, parar de repetir); celular (Drift + fila) e Web (RPC) | `lib/features/entries/`, `lib/features/recurrence/` |
| 46 | Geração local ao abrir e após sincronizar; servidor gera na sincronização depois dos modelos e antes das alterações de ocorrência; Web chama a RPC ao abrir | `local_recurrence_repository.dart`, `sync_service.dart`, `sync_providers.dart` |
| 47 | Receita recorrente: pendente no período da data programada, "Confirmar recebimento" (data e valor), editar só esta, cancelar | `transactions_screen.dart`, `entry_service.dart` |
| 48 | Despesa recorrente: "Informar valor" (variável), vencimento editável, pagar, cancelar | idem |
| 49 | Alertas Android: `flutter_local_notifications` 23, 9h, um resumo por dia, janela de 30 dias, cancelados no logout; exigiu AGP 9.1.1 e compileSdk 37 | `lib/features/alerts/`, `android/` |
| 50 | Fechamento: equivalência local × servidor, dois aparelhos | `test/integration/phase5_flow_test.dart` |

## Decisões do responsável (11/11/2026, APROVADAS)
| # | Decisão |
|---|---|
| D1 | Identificador determinístico da ocorrência (modelo + data programada), igual no app e no servidor (resolve ocorrência "fantasma" entre aparelhos) |
| D2 | Todos os campos do modelo podem mudar; vale **só para ocorrências ainda não geradas**; se o mês/período atual já tem ocorrência, a nova agenda começa no próximo; nunca duas no mesmo mês/período nem ocorrências passadas novas. Ex.: "Academia dia 5" com 05/11 gerada → dia 20 → próxima em 20/12 |
| D3 | Vencimento da despesa recorrente = data da ocorrência (mensal: data programada; por período: início do período), editável por ocorrência; sem campo novo no modelo |
| D4 | Início antes do primeiro período → o app pergunta se cria os períodos (RN002); sem confirmação, não salva. O servidor não ignora mais em silêncio |
| D5 | "Data de geração" (RN004) = data programada; despesa recuperada com atraso fica no período da data programada |
| D6 | Avulso entra só na data informada; só se repete se o usuário marcar a recorrência. Confirmação de recebimento: padrão hoje, aceita outra data |
| D7 | "Parar de repetir" mantém as ocorrências já geradas; sem cancelamento automático |
| D8 | Recorrência ativada no formulário ("Repetir": todo mês / todo período); o próprio lançamento é a primeira ocorrência; data passada gera as atrasadas; em "todo período" a data é o início do período; receita recorrente nasce pendente com opção "já recebi"; ao editar ocorrência escolhe-se "só esta" ou "a recorrência"; consulta em Mais → Recorrências |
| D9 | Alertas: `flutter_local_notifications`; 9h em São Paulo; uma notificação por dia resumindo as despesas, sem valores na tela bloqueada; vale para toda despesa pendente com vencimento (avulsa ou recorrente); reagenda ao abrir, sincronizar e salvar (janela de 30 dias); logout apaga todos |

Fora do MVP/da fase: frequências semanal/quinzenal/anual, pagamento parcial, reativação de recorrência, desfazer recebimento/pagamento (correção de data de pagamento = pagar novamente).

## Decisões de implementação (dentro de D1–D9)
- Mudança de agenda: servidor (gatilho) e app calculam o mesmo "piso" (mês seguinte ou fim do período da última ocorrência gerada); o app nunca começa antes de hoje.
- Alertas usam agendamento inexato (sem permissão de alarme exato): chegam por volta das 9h.
- A geração local não grava auditoria nem fila; o servidor gera e audita a sua cópia (mesmo identificador).
- Recorrência recusada pelo servidor (ex.: modelo desativado em outro aparelho) vai para "Itens que precisam de atenção"; descartar remove modelo e ocorrências locais.
- Por período, a primeira ocorrência de um lançamento convertido recebe a competência do início do período.

## Testes (11/11/2026) e limitações
- `flutter analyze` limpo; `flutter test` 314 passaram (inclui integração da Fase 5 e paridade de datas com o Supabase local); suíte PostgreSQL passou (fixtures antigos de modelos movidos para depois do primeiro período); `flutter build web` e `build apk --debug` compilam. Migration aplicada só no Supabase **local**.
- `flutter test --platform chrome` indisponível nesta máquina.
- Alertas em notificação real no emulador e dois aparelhos reais não foram exercitados nos testes automáticos (cálculo de datas, reagendamento e agendador cobertos). Alerta pode ficar desatualizado até sincronizar quando a despesa é paga em outro aparelho.
- Sem teste de duas sessões simultâneas na geração: serialização por `FOR UPDATE` nos modelos e índice único.
- `docs/historico/decisoes.md` não recebeu D1–D9 (acesso negado na sessão); o registro vigente é este arquivo.
