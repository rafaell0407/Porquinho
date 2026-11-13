# Arquitetura — Norte

Só o que vale hoje. Versão longa (propostas, provas técnicas da Fase 2, histórico de status): `historico/arquitetura_v05_completa.md`. Pendências técnicas: `pendencias.md`.

## 1. Stack (APROVADA)
| Item | Escolha |
|---|---|
| App | Flutter/Dart — Android e Web (iOS fora do MVP) |
| Backend / Auth | Supabase (PostgreSQL 18, Supabase Auth) |
| Banco local | SQLite com Drift, cifrado com SQLite3 Multiple Ciphers (`sqlite3mc`, chacha20, chave 256 bits no `flutter_secure_storage`) |
| Estado / rotas | Riverpod / GoRouter |
| Sincronização | Serviço próprio em Dart |
| Notificações | `flutter_local_notifications` (só Android) |
| Biometria | `local_auth` |
| Datas | pacote `timezone`, zona `America/Sao_Paulo` |
| Gráficos | `fl_chart` |

Nova dependência: avaliar manutenção, licença, segurança e custo antes.

## 2. Camadas e módulos
- Organização por funcionalidade em `lib/features/<módulo>/`; transversal em `lib/core/` (domínio puro em `core/domain/`, banco local em `core/local_database/`); `lib/app/` (inicialização e rotas); `lib/shared/` (shell de navegação e componentes). `test/` espelha `lib/`. Mapa completo: `mapa_app.md`.
- Dependência: apresentação → aplicação (services) → domínio. Regras financeiras só no domínio (`core/domain/`), testáveis sem widgets.
- Cada módulo com dados tem interface de repositório + implementação **local** (Drift + fila, celular) e **remota** (RPCs Supabase, Web), escolhidas por `dataAccessModeProvider` (`core/data_access.dart`).
- Navegação principal: barra inferior fixa com Home, Relatórios, Adicionar (+), Lançamentos e Mais (abas: Home, Lançamentos, Mais).

## 3. Celular × Web
- **Celular (Android):** offline primeiro. Lê do Drift; grava registro + auditoria + operação da fila na mesma transação; só então diz "salvo". PIN/biometria opcional.
- **Web:** somente online; sem banco local, fila ou PIN; lê e grava direto nas RPCs; sessão não persiste (novo login a cada sessão do navegador). Listas limitadas a 1.000 linhas por consulta (aceito, D13). CSV só na Web.

## 4. Sincronização e conflitos
- Toda gravação remota passa por RPC autenticada, transacional, idempotente (chave por operação), versionada e auditada. DML direto bloqueado; RLS só de leitura própria.
- Fila local `sync_outbox`: `pending` → `sending` (volta a `pending` se o app fechar) → removida ao aplicar; `failed` (reenvio com espera crescente); `conflict` (para só a entidade; o resto segue); `rejected` (erro permanente; usuário decide). Operações declaram dependências (`depends_on`): lançamento espera a categoria.
- Rodada: envia configuração/modelos → `generate_due_recurrence_occurrences` no servidor → baixa (incremental, sem sobrescrever pendência) → gera localmente o que faltar. "Sincronizado" só se o download terminou. Offline: nova tentativa a cada 15 s.
- Conflito: versão esperada divergente → servidor guarda as duas versões em `sync_conflicts`. Usuário escolhe (a) aparelho, (b) servidor, (c) editar; (a)/(c) geram nova versão consolidada; sempre auditado (`conflict_resolved`). Criação duplicada só aceita (b); a configuração de período aceita (a) e (b). Cancelamento × edição = conflito. Web resolve conflitos no servidor na mesma tela "Itens que precisam de atenção". Conflito antigo após reinstalar aparece só na Web (D7). Tema: última gravação vence (exceção aprovada).
- Ocorrência recorrente tem ID determinístico (modelo + data programada), igual no app e no servidor → gerar em dois lugares não duplica.

## 5. Segurança
- Isolamento por usuário: RLS + filtro `auth.uid()` em toda RPC (`SECURITY DEFINER`, dono `postgres`, `search_path` vazio, `EXECUTE` só para `authenticated`; nada para `anon`). Teste de catálogo e teste A×B cobrem isso.
- Banco local cifrado; backup automático do Android desligado (`allowBackup=false`). Banco ilegível: arquivo guardado, dados baixados de novo, aviso ao usuário (perde só o não sincronizado — D9).
- PIN de 6 dígitos (PBKDF2-HMAC-SHA256), biometria como atalho, espera crescente após 5 erros; pedido só ao abrir o app do zero; removido no logout.
- Logout com operações pendentes é bloqueado com aviso. Exclusão de conta: fila vazia, dupla confirmação, RPC `delete_my_account`, registro mínimo em `deleted_accounts`.
- Sem segredos no repositório; `service_role` só no servidor. Logs sem valores financeiros.

## 6. Datas e dinheiro
- Centavos: `BigInt` no Dart, texto decimal no SQLite e no protocolo, `BIGINT` no PostgreSQL (somas em `NUMERIC`). Limite técnico 19 dígitos. Nunca ponto flutuante.
- Datas de competência/vencimento/pagamento são datas civis (`YYYY-MM-DD`), nunca convertidas por fuso; instantes técnicos em UTC.
- Geração de recorrências ao abrir o app e ao sincronizar (sem segundo plano).

## 7. Ambientes e distribuição (APROVADO)
- Dev e testes: Supabase local. Hospedados: homologação `norte-homologacao` (gratuito) e produção (pago, a criar). Config por `--dart-define-from-file` (`env/*.example.json` versionados; reais ignorados).
- Web: Cloudflare Pages (`*.pages.dev`; domínio próprio depois). Android: Google Play, chave de upload do responsável + Play App Signing. Build: `tooling/build_release.ps1`.
- Backup: dump diário cifrado por GitHub Actions em repositório privado, 30 dias; restauração reaplica exclusões de conta.
- Monitoramento sem nova dependência: Android Vitals, painel Supabase, verificação de disponibilidade, `FlutterError.onError` sem valores.

## 8. Testes
Ferramentas: `flutter test`; suíte PostgreSQL (`tooling/test_postgres_schema.ps1`, cluster temporário com Auth simulado); integração com Supabase local (`tooling/test_integration_local.ps1`) e homologação (`tooling/test_integration_homolog.ps1`). Paridade app × servidor: totais Drift = `get_range_report` (somas por intervalo de datas). Períodos calculados: tabela única de casos `test/fixtures/period_cases.json`; data mensal de recorrência: `test/fixtures/monthly_recurrence_cases.json` = `supabase/tests/recurrence_monthly_date_cases_test.sql`.
