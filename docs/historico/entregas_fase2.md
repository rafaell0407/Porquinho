# Fase 2 — Modelagem física e base técnica (registro compacto)

**Status:** CONCLUÍDA em 10/11/2026 (Entregas 1–21). Estado vigente: `docs/estado_atual.md`. Detalhe técnico: `docs/banco_de_dados.md` §16.8–16.10, `docs/arquitetura.md` §16–17 e Git. Entrega 22 está na Fase 4 (`docs/entregas_fase4.md`).

## Entregas
| # | Resultado | Validação |
|---|---|---|
| 1–8 | PostgreSQL/Supabase: módulos e testes, schema, migration inicial, RPCs de categorias, períodos, subcategorias, investimentos (7A), lançamentos e modelos recorrentes (7B–7C), ocorrências (8). Migrations `20261109000100`–`000900`, PostgreSQL 18.6, aplicadas no Supabase local `porquinho-dev` | 1, 2, 5, 6 validadas (09/11); 3, 4, 7B–8 sem validação registrada; 7A coberta pela suíte na Fase 6 |
| 9 | Drift local v1 (14 tabelas) e teste de precisão monetária nativo | 09/11 |
| 10 | Drift no navegador (SQLite/WASM): centavos até 2^63−1, `BigInt`, datas ISO/UTC. Runner `dart test -p chrome` em `tooling/web_check` | validada |
| 11 | Prova de criptografia local (SQLite3MultipleCiphers nativo; `sqlite3mc.wasm` + KEK WebCrypto na Web), `tooling/crypto_check` | validada |
| 12 | Drift cifrado (nativo e Web) e schema v2 (4 índices; ganho de desempenho **não medido**) | 10/11 |
| 13 | Origem da chave do banco (`flutter_secure_storage`, Android Keystore); pasta `android/` criada | validada |
| 14–19 | Sessão e logout, Supabase Auth, confirmação de e-mail (RF002), login/cadastro/Google, nova senha, banco local ligado ao app | validadas |
| 20 | PIN de 6 dígitos + biometria opcional (RF003), `lib/features/app_lock/` | validada; biometria só em testes automáticos |
| 21 (A–D) | Protocolo de sincronização: estados, RPC `resolve_sync_conflict`, motor de envio, logout com pendências | 10/11 |

## Decisões exclusivas (10/11/2026, APROVADAS)
- **PIN (E20):** 6 dígitos; pedido só ao abrir o app do zero com sessão ativa; 5 erros → espera crescente (30 s, 1 min, 5 min, 15 min, 1 h) sem apagar dados; PBKDF2-HMAC-SHA256 (100 mil iterações, com sal); removido no logout; Web sem bloqueio.
- **Chave do banco (E13):** Android/iOS usam `flutter_secure_storage`; Web opção B (KEK exige reautenticação a cada sessão); logout com pendências é **bloqueado com aviso**, sem descarte.
- **Sessão Web:** sem persistência (opção B). Nenhuma regra de senha local; o servidor decide.
- **Dependências aprovadas:** `flutter_riverpod` 3.5.0, `go_router` 18.1.4, `supabase_flutter` 2.18.3, `local_auth` 3.0.2, `crypto`, `path_provider`, `sqlite3` com `source: sqlite3mc` (troca o SQLite de todos os builds nativos). Licença do SQLite3MultipleCiphers confirmada; falta registrar texto/versão.
- Confirmação de e-mail ligada no Supabase local (`enable_confirmations = true`); Google habilitado via `config.toml` + `supabase/.env` (ignorado pelo Git).

## Limitações e pendências
- Biometria não testada em aparelho com digital cadastrada.
- Chave secreta do Google apareceu no chat: trocar.
- `flutter test --platform chrome` não abre nesta máquina (Chrome 156 e Edge); usa-se `dart test -p chrome` em `tooling/web_check`. O responsável não reproduziu a execução Web; a validação se apoia na execução registrada.
- Web não tem banco local (depende da KEK com reautenticação); múltiplas abas Web sem teste; iOS sem projeto (fora do MVP).
- `applicationId` provisório `br.com.porquinho.porquinho`, a confirmar.
- Teste manual no emulador (Supabase local): login com Google exige `adb reverse tcp:54321 tcp:54321`; sessão mantida, recuperação de senha por link e logout sem internet funcionaram.
- Autorização testada via API real: usuário B não lê nem altera registros de A; acesso anônimo não lê (RLS e grants).
