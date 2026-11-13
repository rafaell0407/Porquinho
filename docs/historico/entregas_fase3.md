# Fase 3 — Estrutura Flutter e base offline (registro compacto)

**Status:** CONCLUÍDA e VALIDADA pelo responsável em 10/11/2026 (Entregas 23–31; a 30, iOS, saiu do plano). Estado vigente: `docs/estado_atual.md`. Detalhe técnico: `docs/arquitetura.md` §16–17, `docs/banco_de_dados.md` §16.8–16.10 e Git.

## Entregas
| # | Resultado |
|---|---|
| 23 | Composição pelo Riverpod: banco, sincronização, sessão e bloqueio como providers |
| 24 | Navegação por `StatefulShellRoute`: abas Dashboard, Lançamentos, Mais; Segurança (só celular) e Sair em Mais; `lib/shared/main_shell.dart` |
| 25 | Banco local ligado ao usuário (dono em `porquinho.database_owner`): mesma conta mantém dados; outra sem pendências apaga e vincula; outra **com pendências da anterior é bloqueada** (sessão remota encerrada, nada apagado, aviso no login). Sessão expirada não apaga nada; logout apaga banco, chave, PIN e dono |
| 26 | Gravação local única (`LocalChangeRecorder`: registro + auditoria + fila numa transação). Convenção: registro local = versão anterior + 1; operação leva `expectedVersion` = versão anterior; após envio aplicado o aparelho adota a versão do servidor (`MAX`, nunca recua) |
| 27A/27B | Download de todo o histórico, lançamentos e configurações (escopo ampliado pelo responsável). Detalhes abaixo |
| 28 | Faixa de conexão/atenção no topo e "Sincronizar agora" em Mais; conexão medida por chamada a `/auth/v1/health` (`package:http`, dependência direta) |
| 29 | Web somente online: `web/` criada; `DataAccessMode` (local no celular, remoteOnly na Web) e `WriteGate` (bloqueia gravação sem conexão); sem banco local nem fila na Web |
| 31 | Fechamento e regressão no emulador e Chrome |

## Decisões (10/11/2026, APROVADAS)
| # | Decisão |
|---|---|
| D1 | Entrega 21 validada no emulador; Fase 2 concluída |
| D2 | Outra conta com pendências da anterior no aparelho → entrada bloqueada até sincronizar |
| D3 | Período configurado no primeiro acesso (Fase 4) |
| D4 | iOS fora do MVP |
| D5 | Fase 3 concluída com Supabase local; ambientes hospedados na Fase 8 |
| D6 | Tela de conflitos (Entrega 22) no início da Fase 4 |
| D7 | `test/` espelha `lib/` |
| D8 | Gravação de `user_preferences` (tema) por nova função na Fase 7 |

## Download (27A aprovada / 27B implementada em 11/11/2026)
- **Motor:** `download_service.dart` + `supabase_sync_reader.dart`, leitura via RLS (sem RPC nova), páginas de 500 linhas por (`updated_at`, `id`), na ordem de dependência: preferências → configurações de período → períodos → categorias → subcategorias → recorrências → receitas → despesas → investimentos → auditoria. Roda a cada rodada do agendador, **depois** do envio.
- **Cursor** por usuário/tabela em `sync_cursors` (Drift v3); só avança após a página gravada (uma transação por página); recua 2 minutos a cada rodada (excesso ignorado pela guarda de versão).
- **Idempotente:** grava só se `version` maior que a local. **Pendência local nunca é sobrescrita** (operação na fila para o mesmo registro → linha baixada ignorada; o conflito nasce no envio, fluxo da Entrega 21). Sem lápides (nada é apagado fisicamente). Auditoria já criada no aparelho não é duplicada.
- **Drift v3:** tabela `sync_cursors`; correção `per_period` → `by_period` (o esquema local divergia do servidor); descrição opcional nos lançamentos e adicionada às recorrências.
- **Migration** `20261111000100_download_read_indexes.sql` (só índices `(owner_id, updated_at, id)`), aplicada no Supabase local.
- **Testes:** 8 unitários do motor e 3 de integração no Supabase local (`test/integration/supabase_local_sync_test.dart`, exige `--dart-define` das chaves).

## Limitações e pendências
- **Interpretação a confirmar (E29):** o "contrato com implementação local e remota" ficou como modo + porta de gravação; cada repositório nasce com as duas implementações.
- Faixa "sem conexão" demora até 1 minuto para refletir a volta da rede (intervalo do agendador).
- Na 27B, receitas, despesas, recorrências e investimentos foram validados com dados simulados (campos conferidos com o esquema do servidor); coberto depois pelas Fases 4–6.
- `flutter test --platform chrome` não abre nesta máquina; a verificação Web do app é manual.
- Biometria real, chave do Google e Supabase gerenciado: ver `docs/estado_atual.md`.
