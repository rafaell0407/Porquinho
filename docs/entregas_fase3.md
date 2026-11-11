# Entregas da Fase 3 — plano e detalhe

Plano aprovado pelo responsável em 10/11/2026. Cada entrega é implementada, testada e validada antes da próxima. Estado vigente: `docs/estado_atual.md`.

## Decisões do planejamento (10/11/2026)
- D1: Entrega 21 (A–D) validada no emulador; Fase 2 concluída.
- D2: outra conta tentando entrar com pendências da conta anterior no aparelho → entrada bloqueada até a anterior sincronizar.
- D3: configuração de período perguntada no primeiro acesso (primeira entrega da Fase 4).
- D4: iOS fora do MVP.
- D5: Fase 3 concluída com o Supabase local; ambientes hospedados na Fase 8.
- D6: Entrega 22 (tela de conflitos) no início da Fase 4, após categorias.
- D7: `test/` mantém a estrutura que espelha `lib/`; `arquitetura.md` §17.1 corrigida.
- D8: gravação de `user_preferences` (tema) por nova função na Fase 7.

## Lacunas encontradas no diagnóstico
- Após envio aplicado, o app só remove a operação da fila e não grava a nova versão local (`sync_service.dart`, `_send`) → conflito falso na próxima edição. Entrega 26.
- Sessão expirada não limpa nem vincula o banco local ao dono (`session_controller.dart`, `_setUser`); arquivo único (`local_database_manager.dart`). Entrega 25.
- Não há download de dados do servidor. Entrega 27.
- Não existe `web/`; a Web nunca rodou como app. Entrega 29.
- Peças montadas à mão em `main.dart`; `ownerIdProvider` sem uso. Entrega 23.

## Entregas

| # | Objetivo | Depende de | Critério de aceitação |
|---|---|---|---|
| 23 | Composição pelo Riverpod: banco, sincronização, sessão e bloqueio como providers; limpar comentários da opção B | — | Comportamento idêntico; testes atuais passam; analyze limpo; login/PIN/logout iguais no emulador |
| 24 | Navegação: abas Dashboard, Lançamentos, Mais (`StatefulShellRoute`); Segurança e Sair em Mais; `lib/shared/` | 23 | Só três destinos; Segurança ausente na Web; redirecionamentos de login/bloqueio/nova senha preservados |
| 25 | Banco local ligado ao usuário (dono no armazenamento seguro); outra conta bloqueada se houver pendências da anterior (D2); sessão expirada preserva dados | 23 | Testes com 2 usuários: mesma conta reabre; outra sem pendências apaga; outra com pendências bloqueada |
| 26 | Gravação local única (registro + auditoria + fila em uma transação) e versão local após envio aplicado | 23 | Falha no meio não grava nada; versão local = servidor; duas edições seguidas sem conflito falso |
| 27A | Proposta do download (docs): leitura incremental por tabela, ordem de dependência, pendência local nunca sobrescrita (vira conflito), necessidade de nova migration | 26 | Proposta aprovada |
| 27B | Download: mecanismo genérico + preferências, configurações de período, períodos e categorias | 27A | Supabase local: aparelho novo baixa tudo; repetição não duplica; pendência local × mudança remota vira conflito; isolamento por usuário |
| 28 | Indicador de conexão/sincronização (sem dependência nova) e "Sincronizar agora" em Mais; contagem de itens que precisam de atenção | 24, 26 | Emulador em modo avião: sem conexão → volta → sincronizado; contagem de conflitos/recusas visível |
| 29 | Web somente online: criar `web/`; contrato de acesso a dados com implementação local (celular) e remota (Web); aviso sem conexão bloqueia gravação; retirar `_NoLocalDataYet` | 24, 28 | Login e navegação no Chrome; nada gravado localmente na Web |
| 31 | Fechamento: regressão no emulador e Chrome; documentos atualizados | todas | Critérios de conclusão abaixo |

A Entrega 30 (iOS) saiu do plano (D4).

## Matriz de testes
| Área | Unidade | Widget | Supabase local | Emulador | Chrome |
|---|---|---|---|---|---|
| 23 | ✓ | ✓ | — | ✓ | — |
| 24 | — | ✓ | — | ✓ | ✓ (em 29) |
| 25 | ✓ | — | — | ✓ | — |
| 26 | ✓ | — | ✓ | — | — |
| 27B | ✓ | — | ✓ | ✓ | — |
| 28 | ✓ | ✓ | — | ✓ | — |
| 29 | ✓ | — | — | — | ✓ manual |
| 31 | todos | todos | ✓ | ✓ | ✓ |

`flutter test --platform chrome` não abre nesta máquina; a verificação Web do app é manual.

## Critérios de conclusão da Fase 3
1. Três abas no Android e na Web, sem outras áreas.
2. Login, PIN, logout com pendências e recuperação de senha sem regressão no emulador.
3. Banco local nunca compartilhado entre contas (teste com 2 usuários).
4. Gravação local única pronta; nenhum conflito falso após envio.
5. Download idempotente e isolado por usuário no Supabase local.
6. Indicador de estado validado em modo avião.
7. App Web rodando no Chrome, somente online.
8. `flutter analyze` limpo, suíte completa passando, documentos atualizados.
9. Pendências do responsável (Supabase gerenciado, chave do Google, biometria real) registradas, sem bloquear a fase (D5).

## Preparação para a Fase 4 (não antecipar)
A Fase 4 abre com: primeiro acesso com escolha do período (D3) e cálculo local de períodos; categorias com gravação local única e download; Entrega 22; depois receitas, despesas e cálculo da sobra.

## Entrega 27A — Download de dados do servidor (APROVADA em 11/11/2026, com escopo ampliado)

**Decisão do responsável (11/11/2026):** o download deve levar para o aparelho novo **todo o histórico, os lançamentos e as configurações**, e novas tabelas/migrations necessárias estão autorizadas (somente Supabase local). Por isso a 27B cobre todas as tabelas de dados (não só as cinco da proposta original) e o histórico de auditoria.

**Objetivo:** um aparelho novo (ou reinstalado) baixa os dados da conta; aparelhos já em uso recebem o que mudou em outro aparelho. Nunca sobrescreve trabalho local ainda não enviado.

**Escopo da 27B (ampliado):** preferências, configurações de período, períodos, categorias, subcategorias, recorrências de receita e despesa, receitas, despesas, investimentos e o histórico de auditoria.

**Regras propostas**
1. **Leitura incremental por tabela**, na ordem de dependência: preferências → configurações de período → períodos → categorias → subcategorias → recorrências → receitas → despesas → investimentos → auditoria. Cada tabela é lida em páginas de 500 linhas, ordenadas por (`updated_at`, `id`), a partir do último ponto guardado (cursor). A leitura usa a política de leitura própria (RLS) que já existe: nenhuma RPC nova e nenhuma permissão nova.
2. **Cursor local** por usuário e tabela, numa nova tabela local `sync_cursors` (exige schema Drift v3, snapshot em `drift_schemas/` e teste de migração, conforme as regras do projeto). O cursor só avança depois que a página inteira foi gravada (uma transação por página); falha no meio repete a página, o que é seguro porque a gravação é idempotente.
3. **Gravação idempotente:** a linha do servidor só é gravada se sua `version` for maior que a local (ou se não existir localmente). Repetir o download não duplica nem altera nada.
4. **Trabalho local pendente nunca é sobrescrito:** se existe operação na fila (`sync_outbox`) para o mesmo registro, a linha baixada é ignorada. Quando a operação for enviada, o servidor detecta a divergência de versão e gera o conflito pelo fluxo já existente (Entrega 21), que será mostrado ao usuário na Entrega 22. Não é criado conflito localmente pelo download.
5. **Sem auditoria local do download:** a auditoria dos registros vem do servidor; o download grava apenas o registro.
6. **Quando roda:** após o login (aparelho novo) e a cada rodada do agendador, depois do envio da fila (envia primeiro, baixa depois).
7. **Registros cancelados/inativos** chegam como linhas comuns (nada é apagado fisicamente no servidor), então não há "lápides" a tratar.
8. **Isolamento:** toda leitura filtra pelo `owner_id` do usuário logado e a RLS repete o filtro no servidor; o cursor e as linhas locais são sempre do dono vinculado (Entrega 25).

**Nova migration (somente índices de desempenho):** índice `(owner_id, updated_at, id)` nas cinco tabelas lidas. Não altera colunas nem regras. Fica em arquivo novo em `supabase/migrations/`, aplicada só no Supabase local (nada no gerenciado).

**Decisões:** A) escopo e regras — aprovado (ampliado). B) `sync_cursors` (Drift v3) e migration de índices — aprovados.

**Critério de aceitação da 27B:** aparelho novo baixa tudo; repetição não duplica; pendência local × mudança remota vira conflito no envio; isolamento por usuário no Supabase local.

## Registro das entregas 24–29 (11/11/2026)

- **24 Navegação:** três abas por `StatefulShellRoute`; Segurança (só celular) e Sair em Mais; `lib/shared/main_shell.dart`.
- **25 Banco local ligado ao usuário:** dono guardado no armazenamento seguro (`porquinho.database_owner`). Mesma conta: mantém dados. Outra conta sem pendências: apaga e vincula. Outra conta com pendências da anterior: entrada bloqueada (sessão remota encerrada, nada apagado) e aviso na tela de login. Sessão expirada não apaga nada; logout continua apagando banco, chave, PIN e dono.
- **26 Gravação única e versão após envio:** `LocalChangeRecorder` grava registro + auditoria + fila numa transação. Convenção: registro local fica em `versão anterior + 1` e a operação leva `expectedVersion = versão anterior`. Após envio aplicado o aparelho adota a versão do servidor (`MAX`, nunca recua). Ainda não há tela que use o gravador (Fase 4); o teste do gravador usa um servidor simulado, **não** o Supabase local.
- **27A:** proposta acima (aguarda aprovação).
- **28 Indicador:** faixa no topo (sem conexão / itens que precisam de atenção) e "Sincronizar agora" em Mais. A conexão é medida por uma chamada leve ao servidor (`/auth/v1/health`) usando `package:http` (adicionada como dependência direta; já fazia parte do projeto via Supabase). A contagem de atenção soma conflitos abertos e operações recusadas; a tela para resolvê-los é a Entrega 22 (Fase 4).
- **29 Web somente online:** pasta `web/` criada; `flutter build web` compila. Na Web não há banco local nem fila (`databasePath` nulo); o acompanhamento mede só a conexão. Contrato: `DataAccessMode` (local no celular, remoteOnly na Web) e `WriteGate` (bloqueia gravação sem conexão na Web). **Interpretação a confirmar:** como ainda não há telas de dados, o "contrato com implementação local e remota" ficou como esse modo + porta; cada repositório (categorias, lançamentos…) terá as duas implementações quando for criado.

## Roteiro de validação (você)
1. **Emulador, geral:** login, PIN, abas, Mais → Segurança, Sair com e sem pendências.
2. **25:** com pendências simuladas de uma conta (modo avião + edição, quando existir tela; até lá, só os testes automáticos cobrem), entrar com outra conta deve bloquear. Sem pendências, trocar de conta deve funcionar e abrir sem dados da anterior.
3. **28:** modo avião no emulador → faixa "Sem conexão" em até 1 minuto (ou "Sincronizar agora" em Mais); religar a rede → faixa some.
4. **27B (aparelho novo):** entre no emulador com uma conta que já tem dados no Supabase local (ex.: criada pelos testes ou pela Fase 4); depois de alguns segundos o banco local deve ter os dados (a tela de categorias só chega na Fase 4, então a conferência hoje é pelos testes de integração). 
5. **29 (Chrome):** `flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`: login, três abas, ausência de "Segurança" e de "Sincronizar agora" em Mais, faixa ao desligar a rede do navegador.

## Entrega 27B — Download implementado (11/11/2026)
- `lib/features/sync/download_service.dart` (motor), `supabase_sync_reader.dart` (leitura via RLS, sem RPC nova). Roda a cada rodada do agendador, depois do envio (`fullSyncProvider`).
- **Margem de segurança:** o cursor recua 2 minutos em cada rodada (linhas gravadas por transações lentas não se perdem); o excesso é ignorado pela guarda de versão.
- **Auditoria:** eventos já criados neste aparelho (mesma operação, registro e tipo) não são duplicados.
- **Drift v3** (`schemaVersion` 3, snapshot `drift_schemas/porquinho/drift_schema_v3.json`, migração testada v1→v3 e v2→v3): tabela `sync_cursors`; **correção de divergência com o servidor** encontrada no diagnóstico — o esquema local aceitava `per_period` e o servidor usa `by_period`; descrição passou a ser opcional nos lançamentos e foi adicionada às recorrências (o servidor já tinha). Dados existentes são convertidos na migração.
- **Migration** `20261111000100_download_read_indexes.sql` (somente índices), aplicada no Supabase local; suíte PostgreSQL passou.
- **Testes:** 8 unitários do motor (aparelho novo, repetição, versão, pendência local, isolamento, falha de rede, margem, auditoria) e 3 de integração com o **Supabase local** (`test/integration/supabase_local_sync_test.dart`, exige `--dart-define` das chaves; sem elas fica ignorado): download completo e isolado entre contas, pendência local × mudança remota vira conflito no envio, duas edições seguidas sem conflito falso (Entrega 26).
- **Limite:** receitas, despesas, recorrências e investimentos foram validados com dados simulados (tipos de campo conferidos com o esquema do servidor); o Supabase local ainda não tem esses registros reais de teste.
