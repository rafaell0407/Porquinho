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
- Navegação principal: barra inferior fixa com Home, Ferramentas, Adicionar (+), Lançamentos e Mais (abas: Home, Ferramentas, Lançamentos, Mais).
- Ferramentas (`features/tools/`): catálogo por registro. Cada ferramenta é uma `ToolDefinition` (ID estável, nome, descrição, ícone, categoria, rota, posição no padrão, destaque, modalidade de explicação, textos e aviso) em `registry/tool_registry.dart`; a tela não conhece ferramentas pelo nome. Lógica pura do catálogo (`domain/tool_catalog.dart`: Suas/Outras, adicionar, remover, reordenar, busca, categorias), testável sem widget. Toda abertura passa por `tool_launcher.dart` (explicação antes do primeiro uso quando a ferramenta pede). Escolhas do usuário em `user_preferences.tools`, pelo mesmo repositório das preferências (sem armazenamento paralelo). Ferramenta nova entra fora do padrão (`defaultPosition` nulo) para não mudar a lista de ninguém.
- Relatórios (`features/reports/`): central modular no mesmo molde. Cada relatório é uma `ReportDefinition` (ID estável, nome, benefício, ícone, grupo, tipo de visualização, posição na lista sugerida e o desenho de cada nível: compacto, expandido, tela completa e prévia do catálogo) em `registry/report_registry.dart`; as telas percorrem o registro, sem `switch` por relatório. Catálogo puro em `domain/report_catalog.dart`. Os módulos leem os mesmos providers (`selectedPeriodReportProvider` e `periodSeriesProvider`: 2 leituras para todos os cartões) e não recalculam nada; o único número novo (diferença do relatório 4) fica em `domain/free_money_change.dart`. Escolhas em `user_preferences.reports` (coluna própria, separada de `tools`). Relatório novo entra fora da lista sugerida. Spec: `docs/ferramentas/relatorios.md`.
- Ferramentas de simulação não gravam nada nem criam lançamentos. Única chamada de rede fora do Supabase: a Calculadora à vista ou parcelado lê a taxa pública do Banco Central (API SGS, séries 4389 e 1178), sem dados do usuário; a última taxa fica no armazenamento seguro do celular (`SecureValueStore`) e, na Web, só em memória. Ela também tem calendário próprio de dias úteis com feriados nacionais (o resto do app segue RN038). Spec: `docs/ferramentas/a_vista_ou_parcelado.md`.
- Gestão de Faturas de Cartões (`features/card_bills/`, RF029, spec `docs/ferramentas/gestao_de_faturas.md`): primeira ferramenta que grava dados, em tabelas próprias (`card_bill_*`), sem lançamentos nem efeito no dinheiro livre. Cálculos só no domínio em Dart (o mesmo código no Android e na Web); o servidor guarda e valida (dono, centavos e limites, fatura paga uma só vez, unicidade). Cada ação vira uma alteração comum (`CardBillsChange`: linhas a gravar/apagar) aplicada com a mesma regra no Drift e na RPC `card_bills_apply`; pagar/desfazer têm RPCs próprias. Celular: banco local + `sync_outbox` (sem `audit_events`), cadastros numa fila única e pagamentos por fatura; ao fim de cada sincronização a lista completa da ferramenta é baixada e substitui a local (exclusões por comparação, sem marca de exclusão), exceto enquanto houver envio pendente da ferramenta. Web: RPCs direto.

## 3. Celular × Web
- **Celular (Android):** offline primeiro. Lê do Drift; grava registro + auditoria + operação da fila na mesma transação; só então diz "salvo". PIN/biometria opcional.
- **Web:** somente online; sem banco local, fila ou PIN; lê e grava direto nas RPCs; sessão não persiste (novo login a cada sessão do navegador). Listas limitadas a 1.000 linhas por consulta (aceito, D13). CSV só na Web: exportação e importação (RF030; arquivo lido só no navegador, gravação em blocos atômicos pelas RPCs `import_*`, que chamam as RPCs de sempre; sem mudança no Drift nem na sincronização — o celular recebe o que foi importado pelo download normal).
- **Exceções online também no celular:** "Excluir conta" e "Apagar todos os lançamentos" (RF031, RN056). As duas exigem fila vazia e conexão e rodam no servidor; o apagar-tudo roda em partes repetíveis (`wipe_entries_run`) pelas RPCs de sempre, e o celular recebe o resultado na sincronização completa logo em seguida (nada de milhares de operações na fila).

## 4. Sincronização e conflitos
- Toda gravação remota passa por RPC autenticada, transacional, idempotente (chave por operação), versionada e auditada. DML direto bloqueado; RLS só de leitura própria.
- Fila local `sync_outbox`: `pending` → `sending` (volta a `pending` se o app fechar) → removida ao aplicar; `failed` (reenvio com espera crescente); `conflict` (para só a entidade; o resto segue); `rejected` (erro permanente; usuário decide). Operações declaram dependências (`depends_on`): lançamento espera a categoria.
- Rodada: envia configuração/modelos → `generate_due_recurrence_occurrences` no servidor → baixa (incremental, sem sobrescrever pendência) → gera localmente o que faltar. "Sincronizado" só se o download terminou. Offline: nova tentativa a cada 15 s.
- Conflito: versão esperada divergente → servidor guarda as duas versões em `sync_conflicts`. Usuário escolhe (a) aparelho, (b) servidor, (c) editar; (a)/(c) geram nova versão consolidada; sempre auditado (`conflict_resolved`). Criação duplicada só aceita (b); a configuração de período aceita (a) e (b). Cancelamento × edição = conflito. Web resolve conflitos no servidor na mesma tela "Itens que precisam de atenção". Conflito antigo após reinstalar aparece só na Web (D7). Gestão de Faturas: cadastros com última gravação vence, reserva = soma de eventos, e o único conflito é o pagamento duplicado (o servidor responde `conflict`; no celular vai para "Itens que precisam de atenção" e é resolvido no aparelho, mantendo qualquer um dos dois; na Web a pergunta aparece na hora). Tema, lista de Ferramentas e lista de Meus relatórios: última gravação vence (exceções aprovadas: D5 e decisões de 13/11/2026 e 17/11/2026); a configuração guiada de Relatórios, feita em qualquer aparelho, não volta; "Não mostrar novamente" das ferramentas e etapas do assistente se somam entre aparelhos.
- Ocorrência recorrente tem ID determinístico (modelo + data programada), igual no app e no servidor → gerar em dois lugares não duplica.
- **Retenção (D15, RN029/RN030):** a mesma regra roda nos dois lados, sem marcador de exclusão. Servidor: `purge_expired_records` (diária pelo `pg_cron` quando o banco tem a extensão). Celular: ao terminar cada sincronização. Apaga:
  - avulsos cancelados sem alteração há 12 meses, sem pendência na fila e sem conflito aberto; ocorrências de recorrência ficam enquanto o modelo existir;
  - auditoria e conflitos resolvidos com mais de 12 meses;
  - no servidor, o conteúdo das respostas guardadas das operações (a chave fica, e o reenvio antigo é recusado).

  O aparelho guarda o instante do último download completo. Se passou de 11 meses, ou na primeira vez após a atualização, refaz o download dos três tipos de lançamento desde o início. Assim, apaga localmente o que sumiu do servidor e não tem pendência nem alteração recente. Isso impede que um aparelho parado por mais de um ano mantenha vivo um lançamento que outro aparelho apagou. Uma alteração feita offline num lançamento que já sumiu do servidor é recusada e aparece em "Itens que precisam de atenção". Ao descartá-la, o registro sai do aparelho.

## 5. Segurança
- Isolamento por usuário: RLS + filtro `auth.uid()` em toda RPC (`SECURITY DEFINER`, dono `postgres`, `search_path` vazio, `EXECUTE` só para `authenticated`; nada para `anon`). Teste de catálogo e teste A×B cobrem isso.
- Banco local cifrado; backup automático do Android desligado (`allowBackup=false`). Banco ilegível: arquivo guardado, dados baixados de novo, aviso ao usuário (perde só o não sincronizado — D9).
- PIN de 6 dígitos (PBKDF2-HMAC-SHA256), biometria como atalho, espera crescente após 5 erros; pedido só ao abrir o app do zero; removido no logout.
- Logout com operações pendentes é bloqueado com aviso. Exclusão de conta: fila vazia, dupla confirmação, RPC `delete_my_account`, registro mínimo em `deleted_accounts`.
- Sem segredos no repositório; `service_role` só no servidor. Logs sem valores financeiros.

## 6. Datas e dinheiro
- Centavos: `BigInt` no Dart, texto decimal no SQLite e no protocolo, `BIGINT` no PostgreSQL (somas em `NUMERIC`). Limite técnico 19 dígitos. Nunca ponto flutuante.
- Web: o navegador lê número JSON como ponto flutuante (inexato acima de 2^53). Toda leitura de dinheiro na Web vem em texto: RPCs de soma devolvem `::TEXT`; leituras diretas de tabela usam `lib/core/exact_money_columns.dart` (coluna também pedida como `::text`); colunas novas de dinheiro sem teto abaixo de 2^53 entram nessa lista.
- Datas de competência/vencimento/pagamento são datas civis (`YYYY-MM-DD`), nunca convertidas por fuso; instantes técnicos em UTC.
- Geração de recorrências ao abrir o app e ao sincronizar (sem segundo plano).

## 7. Ambientes e distribuição (APROVADO)
- Dev e testes: Supabase local. Hospedados: homologação `norte-homologacao` (gratuito) e produção (pago, a criar). Config por `--dart-define-from-file` (`env/*.example.json` versionados; reais ignorados).
- Web: Cloudflare Pages (`*.pages.dev`; domínio próprio depois). Android: Google Play, chave de upload do responsável + Play App Signing. Build: `tooling/build_release.ps1`.
- Backup: dump diário cifrado por GitHub Actions em repositório privado, 30 dias; restauração reaplica exclusões de conta.
- Monitoramento sem nova dependência: Android Vitals, painel Supabase, verificação de disponibilidade, `FlutterError.onError` sem valores.

## 8. Testes
Ferramentas: `flutter test`; Web: `tooling/test_web.ps1` (roda no Chrome só os arquivos sem `@TestOn('vm')`, porque a Web compila todos juntos e um teste nativo quebra a compilação; no Flutter 3.47.9/Windows exige o patch local `tooling/flutter_web_test_t9.patch`; tabelas de casos chegam ao navegador pela cópia embutida `test/fixtures/embedded_fixtures.g.dart` — regerar com `dart run tooling/embed_test_fixtures.dart` ao mudar um JSON); paridade Web × servidor no navegador: `tooling/test_web_parity.ps1` (Supabase local); suíte PostgreSQL (`tooling/test_postgres_schema.ps1`, cluster temporário com Auth simulado); integração com Supabase local (`tooling/test_integration_local.ps1`) e homologação (`tooling/test_integration_homolog.ps1`). Paridade app × servidor: totais Drift = `get_range_report` (somas por intervalo de datas). Períodos calculados: tabela única de casos `test/fixtures/period_cases.json`; data mensal de recorrência: `test/fixtures/monthly_recurrence_cases.json` = `supabase/tests/recurrence_monthly_date_cases_test.sql`. Calculadora à vista ou parcelado: referência independente `tooling/a_vista_ou_parcelado_referencia.py` gera `test/fixtures/cash_or_installments_cases.json` (rodar com `--check` para conferir se está em dia).
