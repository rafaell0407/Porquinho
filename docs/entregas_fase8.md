# Fase 8 — Sincronização completa, qualidade e publicação

**Status:** EM EXECUÇÃO. Entregas 69–74 e 75 (parcial) implementadas em 11/11/2026 e validadas pelo responsável em 12/11/2026 (§8). 76–81 dependem de decisões/serviços externos; 82 fecha a fase.
**Estado vigente:** `docs/estado_atual.md`. Regras permanentes: `docs/arquitetura.md` §4, §5 e §7. Escopo: `docs/requisitos.md` (RF022, RF027, §8).

## 1. Objetivo
Provar a sincronização de ponta a ponta, fechar falhas de robustez, implementar exclusão de conta, CSV e backup (requisitos aprovados ainda ausentes), provisionar o Supabase hospedado e publicar Android e Web.

## 2. Diagnóstico (11/11/2026)
Já implementado e testado (não refazer): estados da fila, chave idempotente, espera crescente, dependência entre operações, conflitos e resolução (a/b/c), adoção da versão do servidor, download incremental sem sobrescrever pendência, paridade de períodos, RLS/grants na suíte local, sessão/logout/troca de usuário, banco cifrado e PIN.

| # | Lacuna | Evidência | Entrega |
|---|---|---|---|
| L1 | Status "sincronizado" mesmo com download incompleto | `sync_providers.dart` ignora `DownloadResult.completed` | 69 |
| L2 | Faixa "sem conexão" demora até 1 min | `sync_scheduler.dart` (intervalo fixo) | 69 |
| L3 | Restauração do backup do Android pode impedir abrir o banco (chave nova gerada sem tratamento) | `allowBackup` ausente no `AndroidManifest.xml`; `stored_database_key_provider.dart:67` | 72 |
| L4 | Permissões testadas só em cluster temporário com Auth simulado; teste A×B pela API só na Fase 2 | `supabase/tests/bootstrap_local.sql` | 72, 76 |
| L5 | Sem exclusão de conta (exigida pela Google Play) | FKs `ON DELETE RESTRICT` | 73 |
| L6 | Sem backup | — | 77 |
| L7 | Dados não sincronizados se perdem ao desinstalar | regra da Fase 2 (logout bloqueado) | aceita |
| L8 | Conflito aberto no servidor não é baixado pelo celular | download sem `sync_conflicts` | aceita (D7) |
| L9 | Release assinado com chave de debug; `applicationId`, nome e ícone provisórios | `android/app/build.gradle.kts` | 75 |
| L10 | E-mail padrão do Supabase não serve para produção | `config.toml` (`enable_confirmations`) | 76 (D5) |
| L11 | Senha mínima 6 | `config.toml:183` | 76, 79 (D6) |
| L12 | Listas Web limitadas a 1.000 linhas | `remote_table_reader.dart` | aceita (D13) |
| L13 | Chave secreta do Google exposta | `estado_atual.md` | 76 (gerar nova) |
| — | Paridade de somas só testada separadamente (SQL e Dart) | nenhum teste Dart chama `get_period_report` | 71 |
| — | Sem tratamento global de erros | nenhum `FlutterError.onError` em `lib/` | 79 |

## 3. Entregas
⚠️ = exige autorização explícita (serviço externo).

| # | Objetivo | Escopo resumido | Depende | Banco |
|---|---|---|---|---|
| 69 | Status verdadeiro e reenvio seguro | L1, L2 (repetição a cada 15 s offline); integração no Supabase local: resposta perdida, reenvio com a mesma chave, app fechado em `sending`, queda no download, duas edições seguidas | — | — |
| 70 | Dois aparelhos convergem | Dois bancos Drift + mesmo usuário no Supabase local: edição×edição, cancelamento×edição, criação duplicada, período concorrente, tema, recorrência gerada nos dois; resoluções a/b/c e download nos dois; roteiro manual emulador + Web | 69 | nova migration só se houver defeito |
| 71 | Mesmos resultados app × servidor (RF027) | Cenários de referência (arquitetura §12) gravados pelo app; totais Drift × `get_period_report`; > 1.000 linhas; valores grandes | — | — |
| 72 | Segurança e isolamento | Teste de catálogo (RLS em todas as tabelas, sem DML direto, nenhuma função para `anon`, `SECURITY DEFINER` com `search_path` vazio); teste A×B pela API em todas as tabelas/RPCs; `allowBackup=false`; recuperação de banco ilegível (D9); revisão de logs; sessão expirada; troca de usuário; checklist de Auth de produção | — | migration só se teste falhar |
| 73 | Exclusão definitiva da conta (D3) | RPC transacional do próprio usuário (dados na ordem segura + `auth.users`); registro mínimo de contas excluídas (id + data) para não ressuscitar na restauração; tela em Mais com dupla confirmação e aviso de irreversibilidade; celular exige fila vazia; página web de solicitação | 72 | nova migration |
| 74 | Exportação CSV (D4: só Web) | Um CSV por tipo (receitas, despesas, investimentos, categorias), centavos exatos; celular orienta a usar a Web | — | — |
| 75 | Build de produção (local) | `--dart-define-from-file` por ambiente (modelo versionado, reais ignorados); assinatura por `key.properties`; `applicationId`/nome/ícone (D1); versionamento; script de build APK/AAB e Web | D1 | — |
| 76 ⚠️ | Supabase de homologação | Projeto criado pelo responsável; `supabase link`/`db push` autorizados; Auth (URLs, Google com chave nova, SMTP – D5, senha 8 – D6); suítes 69–72 contra homologação | 72, 75; D5 | aplica as existentes |
| 76 (12/11/2026) | — | FEITA exceto SMTP (D5, Entrega 79); aguarda validação. Segredo antigo do Google desativado/substituído pelo responsável. Detalhe: projeto `norte-homologacao` (`fxjkulkyzpwgaeeiwbbl`) criado; 19 migrations aplicadas (`link` + `db push` autorizados e conferidos com `migration list`); 33 testes de integração passando na homologação (`tooling/test_integration_homolog.ps1`, chave secreta pedida no terminal). Painel configurado pelo responsável em 12/11/2026: senha mínima 8 (D6) e URLs de retorno (`localhost:3000`, só homologação); confirmação de e-mail ligada, cadastro anônimo desligado. Google ativado com credenciais novas (segredo antigo a ser apagado no Google Cloud; login Google a validar no emulador). **Falta (responsável, painel):** SMTP (D5, exige domínio, Entrega 79) | — | — |
| 77 | Backup e recuperação (D8) | GitHub Actions em repositório privado: dump diário cifrado (dados + auth), retenção 30 dias; roteiro de restauração reaplicando exclusões; restauração real no Supabase local; verificação mensal e antes de cada versão | 73, 76 | — |
| 78 | Regressão Android e Web | Roteiro manual contra homologação: emulador e, se possível, aparelho físico (biometria, alertas); modo avião, rede lenta, app fechado na sincronização; Chrome, Edge, Firefox; medição RN043 | 69–77 | — |
| 79 ⚠️ | Produção e monitoramento | Projeto de produção, migrations, Auth, backup ativo; monitoramento (D10): Play Vitals, painel Supabase, verificação de disponibilidade, `FlutterError.onError` sem valores | 78 | aplica as existentes |
| 80 ⚠️ | Publicação Web (D11) | Cloudflare Pages (`*.pages.dev`), HTTPS, cabeçalhos de segurança, recursos do Flutter servidos pelo próprio site, URLs de retorno do login, política de privacidade (D12) | 79 | — |
| 81 ⚠️ | Publicação Android | Play Console, ficha, segurança dos dados, privacidade, link de exclusão; teste interno → fechado (prazo exigido pela Google para contas pessoais novas, confirmar) → produção | 79, 80 | — |
| 82 | Fechamento da Fase 8 | Critérios da seção 6; documentos atualizados; pendências aceitas registradas | todas | — |

Paralelas: 69/71/72/74/75 não usam serviço externo e podem ser feitas em qualquer ordem respeitando as dependências.

## 4. Matriz de testes
A = automatizado (unitário/SQL); I = integração (Supabase local/homologação); M = manual. B = bloqueia publicação.

| Cenário | Tipo | B |
|---|---|---|
| Offline prolongado e volta da conexão | I+M | Sim |
| Interrupção no envio e no download | I+M | Sim |
| Reenvio da mesma operação / resposta perdida | A+I | Sim |
| Identificador duplicado | A+I | Sim |
| Duas edições seguidas offline | I | Sim |
| Conflito entre aparelhos (inclui cancelamento×edição) e resoluções | I+M | Sim |
| Alteração local e remota simultânea | A+I | Sim |
| Sessão expirada offline e renovação | I+M | Sim |
| Logout com pendências bloqueado | A+M | Sim |
| Troca de usuário no aparelho | A+M | Sim |
| Banco local ilegível / chave perdida | A+M | Sim |
| Isolamento A×B e anônimo em tabelas e RPCs | A+I (local e hospedado) | Sim |
| Catálogo de permissões e RLS | A (local e hospedado) | Sim |
| Restauração de backup verificada | I+M | Sim |
| Exclusão de conta sem afetar outro usuário | A+I | Sim |
| Paridade app × servidor (dinheiro livre e relatórios) | I | Sim |
| Regressão financeira (suítes Flutter, PostgreSQL, Drift) | A | Sim |
| Android: rede lenta, modo avião, app fechado à força, reinício (alertas) | M | Sim |
| Web: Chrome e Edge / Firefox | M | Sim / Não |
| Biometria em aparelho real | M | Não |
| Metas RN043 | M | Não (registrar) |
| CSV | A+M | Não |

## 5. Decisões da Fase 8 (11/11/2026)
| # | Decisão | Status |
|---|---|---|
| D1 | Nome do produto: **Norte** (aprovado 12/11/2026; slogan "Suas finanças na direção certa. Organize. Equilibre. Evolua."). `applicationId` provisório `br.com.norte.app` aprovado em 12/11/2026 (Play Store não exige domínio próprio; deve ser confirmado como definitivo antes da primeira publicação, pois não pode ser trocado depois) | APROVADO (provisório) |
| D2 | Ambientes: local para dev/teste; homologação (gratuita) e produção (paga) hospedadas | APROVADO |
| D3 | Exclusão de conta: fila vazia, dupla confirmação, imediata, aviso claro de irreversibilidade | APROVADO |
| D4 | CSV só na Web no MVP | APROVADO |
| D5 | Provedor de e-mail: **Resend** (SMTP no Supabase) em homologação e produção — APROVADO em 12/11/2026. Remetente próprio exige domínio verificado (SPF/DKIM) → depende do domínio da D1 | APROVADO (domínio PENDENTE) |
| D6 | Senha mínima de 8 caracteres em produção | APROVADO |
| D7 | Conflito antigo após reinstalar aparece só na Web | APROVADO (pendência aceita) |
| D8 | Backup por GitHub Actions em repositório privado; push e segredos feitos pelo responsável (CLAUDE.md segue proibindo push pelo agente); solução mais robusta no futuro | APROVADO |
| D9 | Banco local ilegível: guardar arquivo, baixar do servidor, avisar; perde-se só o não sincronizado (exceção à regra de não descartar pendências) | APROVADO |
| D10 | Monitoramento sem nova dependência | APROVADO |
| D11 | Web no Cloudflare Pages; domínio próprio depois | APROVADO |
| D12 | Política de privacidade e página de exclusão: rascunho do agente, revisão do responsável | APROVADO |
| D13 | Listas Web com limite de 1.000 linhas: pendência aceita | APROVADO |
| — | Entrega 67 (onboarding) feita depois da Fase 8, antes do fechamento do MVP | APROVADO |

## 6. Critérios de conclusão
1. Testes bloqueadores da seção 4 passando, com resultado registrado.
2. `flutter analyze` limpo; suítes Flutter, PostgreSQL e Drift passando.
3. Testes de segurança passando em homologação e produção.
4. Backup diário ativo e restauração real verificada.
5. Exclusão de conta (Android e Web) e CSV (Web) funcionando.
6. Web publicada com HTTPS; Android ao menos em teste fechado.
7. Documentos atualizados e pendências aceitas registradas em `estado_atual.md`.

## 7. Autorizações explícitas necessárias
Criar projetos/assinar planos; `supabase link` e `supabase db push`; configurar Auth/Google/SMTP hospedados; restaurar ambiente hospedado; publicar Web e configurar domínio; conta e envios na Play Console; push para o GitHub; commits; excluir conta real.

## 8. Execução (11/11/2026)
Resultados dos testes automáticos: `flutter analyze` limpo; `flutter test` 419 passando; integração com o Supabase local (`tooling/test_integration_local.ps1`) 33 passando; suíte PostgreSQL (`tooling/test_postgres_schema.ps1`) passando; build Web compila.

| # | Situação | O que foi feito | O que ainda é manual / pendente |
|---|---|---|---|
| 69 | FEITA | L1: "sincronizado" só se o download terminou (`fullSyncProvider` devolve se completou); L2: com a faixa "sem conexão", nova tentativa a cada 15 s (antes até 1 min). Testes de integração: resposta perdida com reenvio da mesma chave, app fechado em `sending`, queda no download, duas edições seguidas | Modo avião e rede lenta no aparelho (Entrega 78) |
| 70 | FEITA (parte automática) | Dois bancos Drift com a mesma conta: criação em um aparelho chega ao outro; edição×edição com as 3 resoluções (manter do aparelho, do servidor, editar) convergindo nos dois aparelhos e no servidor; desativação×edição; mesma operação vinda de dois aparelhos não duplica. Recorrência nos dois aparelhos já coberta por `phase5_flow_test.dart` | Roteiro manual emulador + Web; período concorrente e tema não receberam teste novo (tema: última gravação vence, D5 da Fase 7; período: coberto por SQL na Fase 2) |
| 71 | FEITA | Cenário de referência (recebimento, despesa avulsa e paga, cancelamento, edição, investimento) + valor de 19 dígitos + 1.000+ lançamentos: totais e categorias do app = `get_period_report`. Limite de valor: 19 dígitos (banco local e servidor) | — |
| 72 | FEITA (sem hospedado) | Teste de catálogo SQL (`security_catalog_test.sql`: RLS em todas as tabelas, sem DML direto, `anon` sem funções, `SECURITY DEFINER` com `search_path` vazio). **Defeito achado e corrigido** em nova migration `20261113000100`: duas funções de gatilho ficavam executáveis por `anon` no Supabase (privilégio padrão do Supabase). Teste A×B pela API em 14 tabelas e 20 RPCs. `allowBackup=false`. Banco local ilegível (D9): arquivo guardado, banco recomeça vazio, aviso na faixa do app, download repovoa. Logs revisados: só mensagens de erro de alertas, sem valores | Rodar o catálogo e a suíte A×B no hospedado (Entrega 76); sessão expirada/troca de usuário seguem cobertas pelos testes da Fase 3; conferir o checklist abaixo |
| 73 | FEITA | Migration `20261113000200`: RPC `delete_my_account` (apaga tudo na ordem segura e o usuário do Auth; guarda só id+data em `deleted_accounts`). Tela "Excluir conta" em Mais: exige fila vazia, 2 confirmações (digitar EXCLUIR), mensagem de irreversibilidade; volta ao login e apaga o banco local. Página `web/excluir-conta.html` (rascunho, D12) | Teste manual no emulador e na Web com conta de teste; revisar o texto da página; restaurar backup reaplicando exclusões (Entrega 77) |
| 74 | FEITA | Mais → Exportar dados (CSV): 4 arquivos (receitas, despesas, investimentos, categorias/subcategorias), valores em centavos exatos, coluna de status (desde 19/11/2026 os apagados não saem, X-D), UTF-8 com BOM, aspas e proteção contra fórmula de planilha; leitura paginada (sem o limite de 1.000). No celular a tela orienta usar a Web | Baixar e abrir os arquivos no navegador (Excel/Planilhas) |
| 75 | PARCIAL | `env/*.example.json` + `--dart-define-from-file`; assinatura por `android/key.properties` (modelo versionado); `tooling/build_release.ps1` valida o ambiente (recusa chave secreta, local fora do ambiente local, sem HTTPS, sem keystore) e gera apk/aab/web | `applicationId`, nome e ícone definitivos (D1) e a chave de upload (responsável); primeiro build real de loja |

| 79 | PARCIAL (12/11/2026) | Só o tratamento global de erros: `lib/core/error_reporting.dart` (`FlutterError.onError` e `PlatformDispatcher.onError`), instalado no `main.dart`; registra apenas o tipo da exceção, sem mensagem, pilha ou valores. 2 testes passando, analyze limpo | Projeto de produção, migrations, Auth, SMTP (D5, exige domínio), backup ativo, Play Vitals, painel e verificação de disponibilidade (D10). Depende das Entregas 77 e 78 e de autorização |

### Checklist de Auth para produção (Entregas 72/76)
- Confirmação de e-mail ligada (`enable_confirmations`) com SMTP próprio (D5); limites de envio ajustados.
- Senha mínima 8 (D6) e proteção contra senhas vazadas, se o plano permitir.
- Cadastro anônimo desligado (já está); `enable_signup` conforme o plano de lançamento.
- URLs de retorno: apenas o domínio da Web e o esquema do app; remover `localhost`.
- Google: chave secreta nova (a antiga foi exposta); redirect do Supabase como único autorizado.
- Rotação de refresh token ligada (já está); duração do JWT padrão.
- Nenhuma chave `service_role`/secreta em app, Web ou repositório.

### Roteiro manual de validação (responsável)
1. Emulador: criar lançamentos em modo avião; religar a rede e ver a faixa sumir em até ~15 s e o status voltar a "sincronizado".
2. Dois aparelhos (emulador + Web): editar o mesmo lançamento nos dois; resolver o conflito em Mais → Itens que precisam de atenção; conferir que os dois mostram o mesmo valor.
3. Mais → Excluir conta com uma conta de teste: tentar com pendências (deve recusar), cancelar nos dois diálogos, concluir; confirmar volta ao login e que a conta não entra mais.
4. Web: Mais → Exportar dados (CSV); abrir os quatro arquivos.
5. Simular banco ilegível (apagar a chave guardada é difícil sem root): coberto por teste automático; validar só a leitura da mensagem.

## 9. Planos extras concluídos durante a Fase 8
Registro saído de `pendencias.md` na limpeza de 19/11/2026. Detalhe de cada plano nas specs citadas e no histórico do Git.

| Plano | Entregas | Situação |
|---|---|---|
| P — Reestruturação de períodos (RN001–RN004, RN010, RN014, RN017, RN036–RN038, RN042; RF006, RF010, RF019) | P1 documentação; P2 período calculado por data (243 casos em `test/fixtures/period_cases.json`); P3 totais por intervalo (`get_range_report`); P4 rede de segurança (sem diferença; testes retirados na P6); P5 repetição só "Todo mês", dia inexistente → último dia útil (360 casos); P6 configuração única `period_settings` (Drift v7); P7 limpeza das tabelas/RPCs de período (Drift v8); P8 validação. Migrations `20261113000300`–`0800` em local e homologação | Validadas pelo responsável em 18/11/2026 |
| GF — Gestão de Faturas de Cartões (RF029, `docs/ferramentas/gestao_de_faturas.md`) | GF0.1–GF6.2 (domínio, servidor, Drift v10, sincronização, telas, catálogo); GF6.3 migration `20261116000100_card_bills.sql` em homologação | Validadas em 18/11/2026; homologação com 41 testes de integração passando em 19/11/2026 |
| RL — Reformulação de Relatórios (RF025, `docs/ferramentas/relatorios.md`) | RL0–RL7 (preferências, Drift v11, catálogo, Meus relatórios, relatórios 1–5, configuração guiada, Personalizar); RL8 migration `20261117000100_report_preferences.sql` em homologação | Validadas em 18/11/2026; homologação passou em 19/11/2026 |
| IM — Importação CSV (RF030, RN046–RN055, D16–D36, `docs/importacao.md`) | IM0–IM9 e IM-A1 (modelo e "Como importar"); IM10 migration `20261118000100_import_batches.sql` em homologação | Validadas em 19/11/2026 ("aprovado csv"); homologação passou em 19/11/2026 |
| X — Retenção de 12 meses (D15; RN029, RN030) | X0 documentação; X1 `retention.dart`; X2 `purge_expired_records` + `pg_cron` diário; X3 limpeza no aparelho, download desde o início após 11 meses, "Cancelar" → "Apagar"; X4 testes; X5 migration `20261118000200_retention_purge.sql` e job `norte-retencao-12-meses` (`17 6 * * *`) em homologação | Validadas em 19/11/2026; homologação com 42 testes passando |
| AT — Apagar todos os lançamentos (RF031, RN056) | AT0 documentação; AT1 `wipe_entries_preview`/`wipe_entries_run`; AT2 tela em Mais com duas confirmações; AT3 testes; AT4 migration `20261119000100_wipe_entries.sql` em homologação | Validadas em 19/11/2026 |
| T10 — Índice da auditoria e limpeza das contas de teste | Migration `20261119000200_audit_actor_index.sql` (local e homologação), `foreign_key_index_test.sql`, `tooling/cleanup_test_accounts.ps1` e plano B `.sql` | Concluída em 19/11/2026 |
| T6 — Desempenho com muitos dados (RN043) | `test/integration/performance_test.dart` (`PERF_ROWS`); Drift v12 com índice `audit_events_operation_idx` (primeira sincronização: 20 mil de 73 s para 8,5 s; 100 mil de 34 min para 36,5 s no local); 3 consultas da lista Web em paralelo (`remote_entry_repository.dart`); medições em `norte-homologacao` com 20 mil e 100 mil | Validada em 19/11/2026; a lista Web com 100 mil acima da meta seguiu como T13 |
| T12 — Apagar conta com muitos dados | Migration `20261119000300_delete_account_timeout.sql` (`statement_timeout = '120s'` em `delete_my_account`) no Supabase local; teste em `rpc_delete_my_account_test.sql`; plano B `tooling/cleanup_test_accounts.sql` | Validada em 19/11/2026; aplicação em homologação e nova medição seguiram como T14 |

Decisões aceitas pelo responsável nesses planos (valem hoje):
- **Faturas (aceitas em 18/11/2026):** (1) fecha 30 e vence 31 em mês curto → vence no dia 31 (ou último dia) do mês seguinte; (2) fechamento corrigido precisa ficar entre os das faturas vizinhas; (3) parcela que cairia em fatura já paga (não a 1ª) conta como paga fora; (4) regra da "compra antiga" na edição só se mudar cartão, data ou fatura da 1ª parcela; (5) mudança de preço da assinatura não sobrescreve cobrança editada à mão; (6) início da assinatura: fatura atual ou uma das 11 seguintes, sem editar depois; (7) parcela editada à mão > 0; (8) calculadora: até 10 dígitos inteiros e 6 decimais; (9) cobranças faltantes: no máximo 24 faturas para trás. Textos e ícone `receipt_long` aceitos.
- **Retenção (19/11/2026):** X-A ocorrência de recorrência apagada fica guardada enquanto o modelo existir (o gerador preenche todo mês vazio desde o início do modelo; mudar isso exige aprovação); X-B auditoria 12 meses; X-C conflitos resolvidos e respostas guardadas também 12 meses, respostas sem conteúdo e chave mantida (reenvio com mais de 12 meses é recusado); X-D exportação CSV sem os apagados; X-E desfazer importação de item já limpo mostra "preservado — Não encontrado"; X-F textos "Apagar lançamento"/"Apagar este lançamento?"; X-G cada aparelho baixa tudo de novo uma vez após a atualização.
- **Apagar todos (19/11/2026):** AT-A qualquer conflito aberto (e, no celular, fila ou conflito local) bloqueia; AT-B um celular parado com recorrência ativa pode manter uma ocorrência gerada só no aparelho até um download desde o início (mesmo caso de desativar recorrência em outro aparelho); AT-C textos "Apagar todos os lançamentos?", "Confirme para apagar", "Apagar tudo", "N lançamentos apagados.".
- **Importação:** cada linha gera auditoria e registro de repetição (50 mil linhas ≈ 100 mil registros técnicos), limpos após 12 meses pela D15.
