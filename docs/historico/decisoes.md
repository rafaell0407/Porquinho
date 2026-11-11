# Histórico de decisões e entregas — Porquinho

**Finalidade:** arquivo de consulta. Reúne, sem alteração de conteúdo, os registros de entregas, as revisões de versão, as linhas **SUPERADA** e os textos/status antigos retirados dos documentos de referência durante a reorganização de 09/11/2026. Nada aqui é regra vigente: a regra vigente está em `docs/regras_negocio.md`, `docs/requisitos.md`, `docs/arquitetura.md`, `docs/banco_de_dados.md` e `docs/roadmap.md`; o estado de execução está em `docs/estado_atual.md`.

Os trechos abaixo estão transcritos literalmente. Referências de seção dentro deles (por exemplo, "seção 16.9") seguem a numeração anterior à reorganização.

## 1. Revisões de versão e progresso (origem: roadmap.md §8)

_Inclui as linhas SUPERADA e INCORPORADA das revisões 0.2 a 0.4._
## 8. Histórico de progresso

| Data | Atualização | Status |
|---|---|---|
| 08/11/2026 | Baseline documental inicial | CONCLUÍDO |
| 08/11/2026 | Revisão 0.2: fotografia mensal de contas e simplificação de fatura | SUPERADA |
| 08/11/2026 | Revisão 0.3: ciclos personalizados e paridade de cálculos offline/backend | INCORPORADO COM REVISÕES |
| 08/11/2026 | Revisão 0.4: removidos módulos de contas e Porquinho virtual; sobra como único indicador; lançamentos, recorrências, categorias e investimento simples | INCORPORADA NA v0.5 |
| 08/11/2026 | Fase 1 validada pelo responsável; início da Fase 2 | FASE 1 CONCLUÍDA; FASE 2 EM EXECUÇÃO |
| 08/11/2026 | Entrega 1 da Fase 2 validada pelo responsável | ORGANIZAÇÃO DOS MÓDULOS E ESTRATÉGIA DE TESTES VALIDADAS |
| 09/11/2026 | Entrega 2 da Fase 2: esquema físico detalhado validado pelo responsável | APROVADO como base do schema |
| 09/11/2026 | Entrega 3 da Fase 2: migration PostgreSQL inicial e RLS de leitura | TESTES AUTOMATIZADOS PASSARAM EM POSTGRESQL 18.6 LOCAL; integração Supabase pendente |
| 09/11/2026 | Entrega 4 da Fase 2: RPC transacional para criar, renomear e desativar categorias | TESTES AUTOMATIZADOS PASSARAM EM POSTGRESQL 18.6 LOCAL; integração Supabase e outras RPCs pendentes |
| 09/11/2026 | Entrega 5 da Fase 2: RPC de períodos com trava por usuário e auditoria | TESTES FUNCIONAIS E DUAS SESSÕES CONCORRENTES PASSARAM EM POSTGRESQL 18.6 LOCAL; AGUARDA VALIDAÇÃO DO RESPONSÁVEL E SUPABASE GERENCIADO |
| 09/11/2026 | Entrega 5 da Fase 2 validada pelo responsável | APROVADA PARA SEGUIR; integração Supabase gerenciado pendente; proposta de fronteira após mudança de configuração continua PROPOSTA |
| 09/11/2026 | Entrega 6 da Fase 2: RPC transacional de subcategorias com versionamento, idempotência, auditoria e conflitos | TESTES AUTOMATIZADOS PASSARAM EM POSTGRESQL 18.6 LOCAL; AGUARDA VALIDAÇÃO DO RESPONSÁVEL; RPCs de lançamentos/recorrências e integração Supabase pendentes |
| 09/11/2026 | Entrega 6 validada pelo responsável; Entrega 7A: RPC transacional de destinações a investimentos | IMPLEMENTADA; suíte PostgreSQL local passou, incluindo valor exato acima de 2^53, replay, conflito, auditoria e isolamento |
| 09/11/2026 | Entrega 7B: RPCs transacionais para receitas e despesas avulsas | IMPLEMENTADAS; suíte PostgreSQL local passou com atribuição de período, pagamento sem troca de competência, edição, cancelamento, conflitos, auditoria e isolamento |
| 09/11/2026 | Entrega 7C: RPCs transacionais de modelos de recorrência de receita e despesa | IMPLEMENTADAS; suíte PostgreSQL local passou com frequências, valores fixos/variáveis, idempotência, edição, desativação, conflitos, auditoria e isolamento |
| 09/11/2026 | Entrega 8: geração idempotente e ciclo de vida de ocorrências recorrentes | IMPLEMENTADA; suíte PostgreSQL local passou com datas mensais, meses curtos, recuperação por período, edição, confirmação, pagamento, cancelamento, auditoria e isolamento |
| 09/11/2026 | Supabase local iniciado após recuperação do Docker Desktop | `porquinho-dev` ativo; banco/Auth/REST saudáveis e migrations 00100–00900 aplicadas; Vector reiniciando |
| 10/11/2026 | Entrega 10: Drift validado em SQLite/WASM (`tooling/web_check`); Entrega 10 validada pelo responsável | PASSOU (5 testes); ver `estado_atual.md` |
| 10/11/2026 | Entrega 11: prova técnica de criptografia local (`tooling/crypto_check`, SQLite3MultipleCiphers nativo e Web, KEK WebCrypto) e correção da divergência de §17.8 (Entrega 6 validada em 09/11/2026) | PASSOU (10 testes); Android/iOS e multiabas NÃO testados; aguarda validação do responsável |

## 2. Histórico de versões do planejamento (origem: roadmap.md §10.7)

_Inclui as linhas "Superada pela v0.5" e os status históricos._
### 10.7 Histórico

| Data | Versão | Alteração | Status |
|---|---|---|---|
| 08/11/2026 | 0.4 | Escopo simplificado e sobra como único indicador | Superada pela v0.5 |
| 08/11/2026 | 0.5 | Correções da auditoria aplicadas; categoria opcional aprovada; propostas técnicas ainda pendentes de aprovação/detalhamento | STATUS HISTÓRICO — validação concluída posteriormente em 08/11/2026 |
| 08/11/2026 | Fase 1 validada; Fase 2, Entrega 1: propostas de módulos, esquema, RLS, sincronização e testes registradas | PROPOSTAS — aguardam revisão do esquema e decisões técnicas pendentes |
| 08/11/2026 | Fase 2, Entrega 1: organização de módulos e estratégia de testes revisadas e validadas pelo responsável | CONCLUÍDA |
| 09/11/2026 | Fase 2, Entrega 2: esquema físico detalhado, constraints, RLS e índices registrados | VALIDADA PELO RESPONSÁVEL; schema-base aprovado |
| 09/11/2026 | Fase 2, Entrega 3: migration inicial, grants read-only, RLS e testes de constraints/isolamento | PASSOU EM POSTGRESQL 18.6 LOCAL; RPCs e Supabase gerenciado pendentes |
| 09/11/2026 | Fase 2, Entrega 4: RPC de categorias com versionamento, idempotência, auditoria e conflitos | PASSOU EM POSTGRESQL 18.6 LOCAL; demais RPCs e Supabase gerenciado pendentes |
| 09/11/2026 | Fase 2, Entrega 5: RPC de criação de períodos e teste de duas sessões simultâneas | PASSOU EM POSTGRESQL 18.6 LOCAL; AGUARDA VALIDAÇÃO DO RESPONSÁVEL; fronteira após mudança PROPOSTA e Supabase gerenciado pendente |
| 09/11/2026 | Fase 2, Entrega 5 validada pelo responsável | APROVADA; primeira fronteira após mudança permanece PROPOSTA; Supabase gerenciado pendente |
| 09/11/2026 | Fase 2, Entrega 6: RPC de subcategorias e testes de permissões, isolamento, idempotência, conflitos e auditoria | PASSOU EM POSTGRESQL 18.6 LOCAL; AGUARDA VALIDAÇÃO DO RESPONSÁVEL; lançamentos, recorrências e Supabase gerenciado pendentes |
| 09/11/2026 | Supabase local iniciado com Docker Desktop; migrations 00100–00900 conferidas no banco local | CONCLUÍDA; validação gerenciada e RLS/grants remotos permanecem pendentes |
| 09/11/2026 | Responsável aprovou a regra de primeira fronteira após mudança de modalidade/dia | APROVADA; implementada e coberta pela RPC/teste local da Entrega 5 |
| 09/11/2026 | Entrega 9: schema Drift local v1 e teste de precisão monetária em SQLite nativo | PASSOU; validação Web, conexão persistente criptografada e integração remota pendentes |

## 3. Histórico de decisões incorporadas na versão 0.4 (origem: AGENTS.md §9)

_Decisões já consolidadas em requisitos e regras de negócio._
## 9. Histórico de decisões incorporadas na versão 0.4

- Removidos do MVP o módulo de contas bancárias e o Porquinho virtual, incluindo reservas e dinheiro livre.
- Removido o campo especial de saldo inicial. O usuário pode criar uma categoria de receita com esse nome; ela é tratada como receita comum.
- Mantida somente a sobra do período como indicador de resultado.
- Mantidas receitas, despesas, recorrências e investimento simples por valor total.
- Investimentos não possuem categorias por ativo; cada lançamento deduz a sobra imediatamente.
- Rendimentos recebidos manualmente são receitas comuns; estimativas automáticas por taxa fixa/CDI foram removidas.
- Cartão representado por despesa recorrente variável.
- Navegação reduzida a Dashboard, Lançamentos e Mais.
- Usuário pode editar ou cancelar qualquer lançamento em qualquer status, preservando auditoria.
- Recorrências somente mensais ou por período; renda recorrente só contabiliza após confirmação de recebimento.
- Offline permanece essencial, com implementação incremental.



## 4. Baseline de planejamento v0.5 e pendências anteriores (origem: roadmap.md §9 e §10.1–10.6)

_Decisões repetidas aqui permanecem vigentes em regras_negocio.md, requisitos.md e arquitetura.md; pendências e próximas etapas foram para docs/estado_atual.md._
## 9. Pendências para planejamento detalhado

1. Detalhar ambientes de desenvolvimento, teste e produção; a organização dos módulos está definida e a Entrega 1 foi validada.
3. Implementar e testar ciclos personalizados para dias 29, 30 e 31, inclusive anos bissextos.
4. Detalhar protocolo, retentativas e persistência de versões conflitantes conforme a política aprovada.
5. Implementar e testar alertas de despesas pendentes após o fim do período.
6. Detalhar consultas e apresentação dos cinco relatórios aprovados.
7. Especificar retenção, backup, restauração, exportação CSV e exclusão definitiva, respeitando a política aprovada.
8. Implementar o fluxo transacional de exclusão definitiva e validar que backups não reintroduzam dados removidos.


## 10. Baseline de planejamento v0.5

**Data:** 08/11/2026. As decisões de produto e stack aprovadas nesta seção substituem os bloqueios correspondentes registrados nas versões anteriores.

### 10.1 Fase 1 — documentação

**Status:** CONCLUÍDA — documentação consolidada e validada pelo responsável em 08/11/2026.

Entregáveis: seis documentos sincronizados; regras de períodos, recorrências, pagamentos, categorias, alertas e encerramento definidas; stack principal aprovada; modelo conceitual revisado; metas e relatórios básicos registrados. A documentação foi validada pelo responsável em 08/11/2026. Permanecem os detalhamentos técnicos da seção 10.5, tratados na Fase 2.

### 10.2 Decisões de produto resolvidas

- Períodos semiabertos `[início, fim)`, início inclusivo e fim exclusivo.
- Ciclo personalizado preserva dia original e usa último dia disponível em mês curto, retornando ao dia original quando possível; inclui anos bissextos.
- Recorrências mensais e por período; primeira mensal na primeira referência não anterior ao início; recorrência criada durante o período inclui sua ocorrência; recuperação na abertura e sincronização; idempotência por modelo + referência programada.
- Pagamentos parciais fora do MVP; pagamento integral.
- Categorias são desativadas, nunca excluídas fisicamente.
- Categorias são opcionais em receitas e despesas; lançamentos sem categoria aparecem como “Sem categoria” nos relatórios por categoria e permanecem nos totais gerais.
- Alertas continuam após o término do período enquanto a despesa estiver pendente.
- Sem encerramento/arquivamento manual de período.
- Conflitos preservam versões, são apresentados ao usuário e resolvidos por nova versão consolidada; sem “última gravação vence” silencioso.
- Banco local criptografado, tokens/chaves em armazenamento seguro, backup diário com retenção de 30 dias, recuperação, exclusão definitiva e exportação CSV.
- Cinco relatórios: receitas por categoria, despesas por categoria, total de investimentos, evolução da sobra e comparativo receitas/despesas/investimentos.
- Valores do MVP em BRL/centavos: zero permitido; negativos e precisão acima de duas casas rejeitados sem arredondamento. Decisão do responsável em 08/11/2026.
- Zona IANA `America/Sao_Paulo` por usuário; recuperação de ocorrências na abertura e sincronização. Decisão do responsável em 08/11/2026 e complementada em 09/11/2026.

### 10.3 Stack aprovada

Flutter/Dart, Supabase, PostgreSQL, SQLite com Drift, Riverpod, GoRouter, Supabase Auth, serviço próprio de sincronização em Dart e Git.

### 10.4 Metas iniciais

Dashboard local até 1 s; lista até 1 s; salvamento local até 500 ms; atualização da sobra até 300 ms; sincronização de lote pequeno em conexão normal até 5 s. Validar em testes e dispositivos representativos.

### 10.5 Dependências técnicas remanescentes

1. Validar migrations, grants e RLS no projeto Supabase gerenciado; a suíte atual usa PostgreSQL local e `auth.uid()` simulado.
2. Validar Drift no Flutter Web e sua paridade com PostgreSQL; o schema v1 e a persistência SQLite nativa passaram localmente.
3. Detalhar ambientes de desenvolvimento, teste e produção; a organização dos módulos foi definida na Entrega 1.
4. Validar criptografia e armazenamento seguro em Android, iOS e Web.
5. Detalhar sessão, logout com operações offline pendentes e autorização.
6. Especificar backup/restauração, retenção, exclusão definitiva, observabilidade e proteção contra reaparecimento de dados.

Esses itens são detalhamentos técnicos e não reabrem as decisões funcionais aprovadas.

### 10.6 Próximas etapas

1. Supabase local iniciado e migrations 20261109000100–20261109000900 conferidas em 09/11/2026; provisionar projetos hospedados dev/teste/produção após definir organização e referências.
2. Testar migrations, grants, RLS e ownership das funções no Supabase gerenciado.
3. Validar paridade local/Web de BRL e datas, e preparar armazenamento persistente criptografado antes da Fase 3.
4. Validar criptografia e armazenamento local em Android, iOS e Web.


**Status anterior da Fase 2 (roadmap.md, seção 3):**

**Status:** EM EXECUÇÃO — Entregas 1 e 2 validadas; migrations PostgreSQL e RPCs passaram em PostgreSQL local nas Entregas 3 a 8, incluindo concorrência. O schema Drift v1 e os testes de SQLite nativo passaram na Entrega 9. A regra da primeira fronteira após mudança de configuração foi aprovada em 09/11/2026. Permanecem pendentes validação do Drift Web, abertura persistente criptografada, validação do Vector e integração com Supabase gerenciado.

## 5. Textos superados da arquitetura (origem: arquitetura.md)

_Pendências anteriores à Entrega 2, listas de pendências repetidas e status de entregas._
**§2.2 e §2.3**

### 2.2 Tecnologias aprovadas e detalhamento pendente

A stack foi aprovada conforme a tabela da seção 2.1. A organização concreta dos módulos foi aprovada tecnicamente na Entrega 1 da Fase 2 e está registrada na seção 17.1. A zona `America/Sao_Paulo` por usuário foi definida na Entrega 2. Permanecem pendentes configurações e decisões de implementação: ambientes, políticas RLS, observabilidade, chaves e compatibilidade multiplataforma.

### 2.3 Detalhamentos técnicos pendentes

- Protocolo de sincronização, retentativas e implementação técnica da política de conflitos aprovada.
- Configuração de OAuth, sessão e armazenamento de credenciais.
- Estratégia multiplataforma para notificações móveis.
- Ambientes de desenvolvimento, teste e produção.
- Implementação de backup, recuperação, retenção, exportação e exclusão de dados.

Backend, banco, estado, roteamento, persistência local e política funcional de conflitos estão aprovados; organização concreta de módulos está definida na seção 17.1. Os demais detalhes de implementação não alteram essas decisões.

**§15 (pendências antes da reorganização)**

## 15. Detalhamentos técnicos pendentes

1. Ambientes e configuração operacional.
2. Migrations, políticas e testes RLS, constraints e modelo físico.
3. Configuração OAuth, gestão de sessão e armazenamento seguro por plataforma.
5. Protocolo de sincronização, retentativas e mecanismo técnico para preservar/resolver conflitos segundo a política aprovada.
6. Estratégia de notificações móveis e validação multiplataforma.
7. Mecanismo e procedimento de backup, restauração, retenção, exportação CSV e exclusão definitiva.
8. Observabilidade, publicação e compatibilidade dos mecanismos em Android, iOS e Web.

Backend, banco, autenticação, estado, roteamento, persistência local e política funcional de conflitos estão aprovados na seção 16; não são decisões pendentes.

**§16.6 (pendências técnicas remanescentes)**

### 16.6 Pendências técnicas remanescentes

Não são decisões de produto pendentes; são detalhamentos necessários antes da implementação correspondente: ambientes; migrations; políticas e testes RLS; estratégia de chaves; sessão e autorização; estratégia de observabilidade; mecanismo de backup e restauração; validação de armazenamento seguro e criptografia em Android, iOS e Web; política de logout com fila offline. A organização de módulos está definida na seção 17.1 e a zona IANA por usuário foi aprovada na seção 17.8.

**§17, linha de status inicial**

**Status:** Entrega 1 registrada em 08/11/2026. Organização de módulos e estratégia de testes aprovadas tecnicamente para orientar a implementação. O esquema físico, a configuração operacional de produção, as dependências Flutter e as migrations continuam sem aprovação nesta seção.

**§17.4, parágrafo de RPCs e entregas 4 a 8**

Escritas remotas são restringidas a funções autenticadas que façam validações e mantenham auditoria na mesma transação. RLS protege leitura própria e grants SQL bloqueiam DML direto. As Entregas 4 a 6 implementam RPCs de categoria, período e subcategoria; as Entregas 7A e 7B adicionam destinações a investimentos e lançamentos avulsos de receitas/despesas; a Entrega 7C adiciona modelos recorrentes; a Entrega 8 adiciona geração e ciclo de vida de ocorrências. Essas funções usam `SECURITY DEFINER`, proprietária `postgres`, `search_path` vazio, referências qualificadas, execução concedida somente a `authenticated` e proprietário derivado de `auth.uid()`. Como `postgres` ignora RLS, toda consulta e escrita das funções filtra explicitamente por esse usuário. A RPC de período serializa chamadas do mesmo proprietário com trava advisory e valida as fronteiras; os testes locais cobrem isolamento e duas chamadas simultâneas. A validação no Supabase gerenciado permanece pendente. A Entrega 5 e a regra de transição foram validadas pelo responsável em 09/11/2026.

**§17.6, status de migrations e de testes**

**Status:** Migrations PostgreSQL/RPCs passaram localmente nas Entregas 3 a 8; schema Drift v1 e testes nativos passaram na Entrega 9. Adapter persistente criptografado, validação Web e integração Supabase gerenciada permanecem pendentes.

**Status:** A estratégia de testes foi aprovada na Entrega 1. Na Entrega 3 passou a suíte da migration PostgreSQL com autenticação simulada; nenhum teste de aplicação Flutter foi executado ainda.

**§17.8, parágrafos finais**

Na Entrega 7A foi implementada a RPC `public.apply_investment_allocation_change` com gravação autenticada, associação por data ao período, idempotência, versionamento, auditoria e conflitos. Na Entrega 7B foram implementadas as RPCs de receitas e despesas avulsas. Na Entrega 7C foram implementadas as RPCs de modelos; na Entrega 8, geração e ciclo de vida das ocorrências. Os testes PostgreSQL locais passaram. A validação remota continua pendente.

## 6. Textos superados do banco de dados (origem: banco_de_dados.md)

_Texto anterior à aprovação do schema físico (09/11/2026) e registros de entregas._
**§4, ressalva sobre entidades**

As entidades abaixo são conceitos aprovados para o modelo lógico; não são tabelas aprovadas e não autorizam esquema físico ou migrations.

**§8, último parágrafo**

A seção 16.8 propõe `BIGINT` assinado de 64 bits por valor individual no PostgreSQL; essa faixa técnica depende da aprovação do esquema físico e não constitui limite de produto aprovado. Nenhum limite de produto foi definido.

**§12 e §13**

Índices, chaves e tipos SQL só serão definidos após escolha do banco e validação do modelo lógico. Consultas esperadas incluem lançamentos por usuário/período, receitas e despesas por categoria, ocorrências de recorrência e fila de sincronização.

Backend, banco, modelo lógico conceitual e política funcional de sincronização estão aprovados. Criar tabelas físicas ou migrations somente após concluir o esquema físico, constraints, RLS e detalhes técnicos de sincronização. Mudanças futuras devem ser versionadas, revisáveis e acompanhadas de estratégia de evolução/reversão quando aplicável.

**§14 (pendências de modelagem anteriores)**

1. Definir esquema físico, tipos, índices e constraints após validar o modelo lógico.
2. A geração usa data corrente na zona do usuário e ocorre ao abrir o app e durante a sincronização; não há agendador em segundo plano.
3. Especificar fila offline, versionamento e persistência das versões conflitantes.
4. Detalhar retenção, restauração, exclusão definitiva e exportação.
5. Validar tecnicamente a integridade das referências polimórficas de auditoria e sincronização.

**§15, cabeçalho**

**Data:** 08/11/2026. Esta seção prevalece sobre trechos anteriores que indiquem como pendentes decisões aqui aprovadas. O esquema físico continua sujeito a detalhamento; esta baseline não autoriza migrations.

**§15.2, semântica canônica da referência (resolvida na §16.8.3)**

A semântica canônica da referência usada na chave de unicidade deve ser definida no esquema físico, preservando a regra funcional aprovada de uma ocorrência por modelo e referência programada/competência.

**§16.1 a §16.7 — Proposta de esquema físico inicial, pendências e classificação da Entrega 1 (substituídas pela §16.8)**

## 16. Proposta de esquema físico inicial

**Status:** PROPOSTA — aguarda revisão e aprovação. Este desenho detalha o modelo conceitual v0.5; não autoriza migrations nem cria novas regras funcionais.

### 16.1 Convenções e propriedade

O Supabase Auth (`auth.users`) é a fonte da identidade; não se propõe duplicar a tabela de usuários. Entidades do aplicativo usam UUID gerado no cliente, `owner_id` UUID obrigatório, `version` inteira crescente e timestamps de criação/atualização. A chave lógica principal é `(owner_id, id)` para permitir referências compostas que impeçam relações entre proprietários diferentes.

Proposta de mapeamento:

| Conceito | Tabela candidata | Campos físicos principais |
|---|---|---|
| Preferência | `user_preferences` | `owner_id` (único), tema opcional e `time_zone_id` IANA com padrão `America/Sao_Paulo` |
| Configuração de período | `period_configurations` | `id`, `owner_id`, modalidade, dia inicial quando aplicável, início de vigência |
| Período | `accounting_periods` | `id`, `owner_id`, configuração de origem, `start_date`, `end_date` |
| Categoria | `categories` | `id`, `owner_id`, tipo imutável, nome, ativo/inativo |
| Subcategoria | `subcategories` | `id`, `owner_id`, `category_id`, nome, ativo/inativo |
| Modelo de receita recorrente | `income_recurrence_templates` | proprietário, frequência, parâmetros de agenda, valor fixo/variável, categoria opcional, ativo/inativo |
| Modelo de despesa recorrente | `expense_recurrence_templates` | proprietário, frequência, parâmetros de agenda, valor fixo/variável, categoria opcional, ativo/inativo |
| Receita | `income_entries` | proprietário, descrição, centavos, recebimento, status, categoria/período opcionais enquanto pendente, modelo e referência programada opcionais |
| Despesa | `expense_entries` | proprietário, descrição, centavos, competência, vencimento/pagamento, status, categoria opcional, período e modelo opcionais conforme origem |
| Destinação para investimento | `investment_allocations` | proprietário, centavos, data do lançamento e período; sem categoria ou status de pagamento |
| Auditoria | `audit_events` | proprietário, entidade/tipo, operação, instante, snapshots anteriores/novos |
| Idempotência remota | `applied_sync_operations` | proprietário, chave idempotente, resultado e instante de aplicação |
| Conflito remoto | `sync_conflicts` | proprietário, entidade, versão-base, snapshots concorrentes, estado e resolução |
| Fila local | `sync_outbox` | chave idempotente, entidade, versão esperada, payload, tentativas, estado e próximo retry |

`sync_outbox` é local. As tabelas remotas de operações aplicadas e conflitos apoiam idempotência e resolução; não substituem os registros de domínio. Campos opcionais e suas combinações devem ser fechados contra o fluxo funcional de cada entidade antes da migration.

### 16.2 Tipos e constraints propostas

No PostgreSQL, propõem-se `uuid`, `date`, `timestamptz`, `bigint`, `boolean` e `text` com `CHECK` para valores enumerados. No SQLite/Drift, IDs, enums e centavos são `TEXT` canônico; o mapeamento Dart converte centavos para `BigInt`. Isso evita perda de precisão no Flutter Web, cujo `int` JavaScript não representa todos os inteiros de 64 bits. Datas são ISO `YYYY-MM-DD` e instantes ISO UTC; datas não são convertidas por timezone.

Valores são BRL em centavos. Armazenar `amount_centavos` em `BIGINT` no PostgreSQL e como texto decimal canônico no SQLite/Drift; o domínio Dart usa `BigInt`, e o protocolo de sincronização transmite centavos como string decimal. Não converter valores monetários para `double` nem para `int` no Flutter Web. Zero é permitido; negativos e entradas com mais de duas casas decimais são rejeitados, sem arredondamento. O limite superior técnico por lançamento é o máximo do inteiro assinado de 64 bits; não há limite de produto menor aprovado. Agregações locais usam `BigInt`; as remotas usam `NUMERIC` para soma exata sem overflow intermediário.

Constraints propostas:

- `start_date < end_date` para períodos, com intervalos semiabertos;
- unicidade do período por proprietário e início, além de prevenção de sobreposição;
- chaves estrangeiras compostas por proprietário para categoria, subcategoria, período e modelo de recorrência;
- unicidade de ocorrência recorrente por proprietário, modelo e referência programada, aplicável somente às ocorrências com modelo;
- unicidade da chave idempotente por proprietário;
- ausência de `period_id` em receita recorrente ainda pendente e associação a período após recebimento;
- categoria opcional, sempre compatível com o tipo e proprietário do lançamento;
- investimento sem categoria, sem pagamento e sem descrição obrigatória.

O mecanismo físico de prevenção de sobreposição de períodos (por exemplo, constraint de exclusão ou validação transacional equivalente) depende da validação de extensões disponíveis no PostgreSQL gerenciado. A data de competência e o período associado também precisam ser validados na mesma transação; uma `CHECK` simples não valida outra linha/tabela.

### Índices candidatos

Além das chaves e índices únicos das constraints, propõem-se índices iniciados por `owner_id` para refletir as consultas aprovadas: lançamentos por período/data; receitas e despesas por período/categoria; períodos por início; eventos de auditoria por entidade e instante; e modelos/ocorrências por referência programada. A fila local pode indexar estado e próximo retry. O plano de consulta deve validar esses candidatos com dados representativos antes de fixá-los; índices redundantes às constraints não devem ser criados.

### 16.3 RLS e autorização

RLS será habilitada em todas as tabelas remotas que contenham dados de usuário. A política-base exige `auth.uid() = owner_id` em leitura e escrita, além de validação da identidade nas funções de sincronização. Tabelas filhas precisam validar o mesmo proprietário por referência composta. Acesso anônimo é negado. A proposta é não conceder escrita direta às tabelas financeiras: operações passam por funções autenticadas e transacionais que validam regras, versão esperada, auditoria e idempotência.

O conjunto de testes deve criar dois usuários e demonstrar que cada um lê e altera apenas suas linhas; referências a categoria, período ou recorrência de outro usuário falham; usuário anônimo não acessa dados; e repetir uma operação idempotente não duplica alteração nem auditoria.

### 16.4 Auditoria e sincronização

`audit_events` é append-only para o fluxo normal. Como a referência ao registro afetado é polimórfica, a proposta exige que a função transacional valide tipo, ID e proprietário antes de gravar os snapshots. Valores sensíveis não necessários não devem ser incluídos nos snapshots.

Cada linha sincronizável tem versão. A aplicação remota compara a versão esperada, registra a nova versão e o evento de auditoria atomicamente, ou preserva os snapshots concorrentes em `sync_conflicts`. `applied_sync_operations` possui chave única por proprietário e operação, guardando resposta suficiente para reenvio idempotente. Resolução de conflito cria uma nova versão; não atualiza silenciosamente um estado concorrente.

### 16.5 Migrations e evolução

Migrations PostgreSQL seriam mantidas em `supabase/migrations/`, ordenadas e revisáveis. A aplicação local de teste deve começar de banco vazio, aplicar toda a sequência e executar testes de constraints/RLS. Produção recebe migrations já aplicadas e verificadas em ambiente de teste, com estratégia documentada de evolução e recuperação.

Drift mantém `schemaVersion`, snapshots gerados e migrações locais independentes. Cada migração local deve ser testada da versão anterior para a nova, preservando dados. O contrato lógico e casos de paridade são comuns aos dois armazenamentos; tipos e scripts de migration não precisam ser idênticos.

### 16.6 Pendências antes da aprovação do esquema

**Registro histórico da Entrega 1:** o texto abaixo registra as pendências existentes antes da validação do schema na Entrega 2. O estado atual e as pendências remanescentes estão nas seções 16.8 e 16.9.

1. Aprovar campos e nullability de receita/despesa recorrente pendente, especialmente valor variável e período.
2. Aprovar a representação canônica da referência mensal e por período e a respectiva constraint.
3. Validar mecanismo de não sobreposição e continuidade de períodos no PostgreSQL de destino.
4. Aprovar tipos, índices, política de exclusão definitiva/tombstones e retenção de auditoria.
5. Testar compatibilidade de criptografia e armazenamento local em Android, iOS e Web antes da implementação correspondente.

Naquele momento, até a resolução dessas pendências e aprovação explícita do esquema físico, o documento permanecia PROPOSTA e nenhuma migration definitiva deveria ser criada.

### 16.7 Resultado da revisão da Entrega 1 — classificação para validação

Esta tabela registra o estado ao final da Entrega 1. Moeda/escala e zona IANA foram decididas pelo responsável na Entrega 2; ver a seção 16.8.

| Tema | Status | Registro |
|---|---|---|
| Modelo conceitual v0.5 | APROVADO | Permanece a fonte do escopo das entidades; não se criam entidades fora do MVP. |
| Esquema físico da seção 16 | PROPOSTA | A aprovação do planejamento da Fase 2 não substitui a aprovação explícita do esquema. |
| Inteiros de 64 bits em unidade mínima | PROPOSTA | Estratégia recomendada; moeda, escala, limites e rejeição de casas excedentes precisam de decisão. |
| Propriedade, chaves compostas e RLS | PROPOSTA | Princípio de isolamento aprovado; constraints e políticas concretas aguardam validação e testes. |
| Unicidade de recorrências e associação a períodos | PENDENTE | Referência mensal versus identificador do período e nullability precisam ser fechadas antes da migration. |
| Não sobreposição e continuidade dos períodos | PENDENTE | Validar constraint disponível ou mecanismo transacional equivalente no PostgreSQL de destino. |
| Auditoria, idempotência e conflitos | APROVADO como requisitos; desenho físico PROPOSTA | As entidades e constraints finais continuam sujeitas à aprovação do esquema. |
| Migrations PostgreSQL e Drift | APROVADO como estratégia; execução PENDENTE | Não foram criadas migrations nesta entrega. |

Os valores e registros usados nos futuros testes de banco serão fixtures sintéticas, isoladas dos ambientes com dados reais.

**§16.8.7 — Execuções registradas nas Entregas 3, 4 e 5**

**Executado na Entrega 3:** migration aplicada em banco PostgreSQL 18.6 vazio; constraints de sinal, período não vazio, modelo de recorrência, referência composta entre proprietários, chave única de ocorrência e tipo imutável de categoria; zero e ocorrência variável sem valor; leitura isolada entre dois usuários; acesso anônimo e escrita direta negados; valor acima de `2^53 - 1` preservado exatamente no PostgreSQL; remoção de usuário com dados bloqueada por `RESTRICT`. Fixtures são sintéticas.

**Executado na Entrega 4:** RPC de categorias testada para create/rename/deactivate, replay idempotente, reutilização de chave com payload diferente, controle de versão, conflito com snapshots, auditoria anterior/nova, ausência de sessão, isolamento entre usuários e grants de execução.

**Executado na Entrega 5:** datas mensais; início/fim semiabertos; criação inicial e continuação; rejeição de gaps e overlaps; alteração de configuração no período seguinte; transição para ciclo personalizado; dias 20 e 31, fevereiro bissexto, retorno ao dia original; idempotência, conflitos, auditoria, rollback, isolamento e DML direto bloqueado. Duas sessões simultâneas confirmaram espera na trava advisory e criaram períodos consecutivos sem gap.

**§16.9 a §16.17 — Registro por entrega (texto integral anterior à consolidação)**

### 16.9 Entrega 3 — migration PostgreSQL inicial

**Implementado na Entrega 3:** `supabase/migrations/20261109000100_initial_schema.sql` cria as tabelas remotas aprovadas, constraints, chaves compostas por proprietário, índices, triggers para tipo imutável de categoria e compatibilidade do tipo de categoria. Todas as FKs para `auth.users` e referências históricas usam `ON DELETE RESTRICT`; a limpeza definitiva de conta ficará em uma operação transacional explícita futura. O migration aplica RLS, concede somente leitura própria a `authenticated` e bloqueia DML direto. Naquele ponto, as RPCs de escrita ainda não existiam.

**Testes automatizados:** `tooling/test_postgres_schema.ps1` cria PostgreSQL 18.6 temporário em loopback, inicializa banco vazio, simula `auth.users`, roles `anon`/`authenticated` e `auth.uid()`, aplica todas as migrations, executa `supabase/tests/*_test.sql` e roda um teste concorrente em duas sessões. Para repetir, deixe `initdb.exe`, `pg_ctl.exe` e `psql.exe` no `PATH` e rode `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tooling/test_postgres_schema.ps1`. A suíte passou em 09/11/2026. A autenticação foi simulada; a suíte não substitui integração com Supabase gerenciado.

### 16.10 Entrega 4 — RPC transacional de categorias

`supabase/migrations/20261109000200_category_write_rpc.sql` cria `public.apply_category_change(operation_id, action, category_id, expected_version, kind, name)`. A RPC implementa somente `create`, `rename` e `deactivate`, ações previstas para categorias. O usuário é obtido por `auth.uid()`; não existe parâmetro de proprietário. Criação exige versão esperada zero; alteração exige versão positiva e, em caso de divergência, preserva os snapshots local/remoto em `sync_conflicts` e retorna o conflito sem sobrescrever a categoria.

Cada chamada grava a categoria ou conflito, o resultado idempotente e, quando aplicada, o evento de auditoria na mesma transação PostgreSQL. Repetir a mesma chave e conteúdo retorna a resposta registrada; a mesma chave com conteúdo diferente é rejeitada. A hash é apenas um filtro e a igualdade exata do JSONB da solicitação também é verificada. O tipo da categoria não pode ser alterado. A função é `SECURITY DEFINER`, pertence a `postgres`, usa `search_path` vazio, qualifica objetos e concede `EXECUTE` somente a `authenticated`; o acesso explícito por usuário continua obrigatório porque a função proprietária ignora RLS.

**Testado localmente:** sessão autenticada e ausente, grants, isolamento de proprietário, create/rename/deactivate, avanço da versão, auditoria, repetição idempotente, chave reutilizada com outro conteúdo, conflito persistido e repetido sem duplicação.

**Pendente após a Entrega 4:** teste no Supabase gerenciado, resolução do conflito como nova versão e RPCs de lançamentos/recorrências. A RPC de subcategorias foi implementada e testada localmente na Entrega 6. O PostgreSQL local usado na suíte simula `auth.uid()` e não comprova configuração ou privilégios do projeto remoto.

### 16.11 Entrega 5 — RPC transacional de períodos

`supabase/migrations/20261109000300_accounting_period_rpc.sql` cria `public.create_accounting_period(operation_id, period_id, configuration_id, start_date, mode, custom_start_day)`. A chamada deriva o usuário de `auth.uid()`, cria a configuração inicial ou uma nova configuração efetiva no início do período e grava o período e a auditoria atomicamente. Repetição da mesma chave e conteúdo retorna o resultado anterior; conflito com período/configuração existente preserva snapshots em `sync_conflicts`.

A RPC serializa operações do mesmo proprietário com `pg_advisory_xact_lock`, calcula o fim exclusivo a partir da configuração e valida a adjacência com o período anterior e seguinte. Mês-calendário começa no dia 1. Ciclo personalizado preserva o dia configurado, ajusta meses curtos e retorna ao dia original quando possível. **A primeira fronteira após mudança de modalidade/dia foi aprovada em 09/11/2026:** o novo período começa no fim do anterior e termina na próxima fronteira da nova agenda posterior a esse início.

**Testado localmente:** meses e ciclos personalizados, fevereiro de 2028, dias 20/31, gaps/overlaps, replay, colisão de versão/ID, mudança efetiva de configuração, auditoria, rollback, isolamento, bloqueio de escrita direta e duas sessões concorrentes observadas esperando na mesma trava por usuário. Todo o teste usa PostgreSQL 18.6 temporário e identidade Auth simulada.

**Validada pelo responsável em 09/11/2026** para prosseguimento da Fase 2, incluindo a regra da primeira fronteira após mudança de configuração. Permanecem pendentes a validação no Supabase gerenciado e o deploy remoto da migration.

### 16.12 Entrega 6 — RPC transacional de subcategorias

**Status:** IMPLEMENTADA E TESTADA LOCALMENTE; aguarda validação do responsável e teste no Supabase gerenciado.

`supabase/migrations/20261109000400_subcategory_write_rpc.sql` cria `public.apply_subcategory_change(operation_id, action, subcategory_id, category_id, expected_version, name)`. A RPC implementa `create`, `rename` e `deactivate`; deriva o proprietário de `auth.uid()` e, na criação, exige que a categoria pertença ao usuário e esteja ativa. Alterações com versão esperada desatualizada preservam snapshots em `sync_conflicts` e não sobrescrevem a subcategoria.

A operação bem-sucedida, o resultado idempotente e o evento de auditoria são gravados na mesma transação. Repetir a mesma chave e solicitação retorna a resposta anterior; reutilizar a chave com conteúdo diferente é rejeitado. A função é `SECURITY DEFINER`, pertence a `postgres`, usa `search_path` vazio e concede execução somente a `authenticated`.

**Testado localmente em PostgreSQL 18.6:** criação, renomeação, desativação, categoria inativa, autenticação ausente, privilégios, isolamento entre dois usuários, replay idempotente, chave reutilizada com outro conteúdo, conflito de versão com snapshots, auditoria de valores anteriores/novos e bloqueio de DML direto.

**Pendente:** validação no Supabase gerenciado, RPCs de lançamentos/recorrências, migration Drift e resolução de conflitos como nova versão. Os testes locais usam Auth simulado e não comprovam configuração ou privilégios do projeto remoto.

### 16.13 Entrega 7A — RPC transacional de destinações a investimentos

`supabase/migrations/20261109000500_investment_allocation_rpc.sql` cria `public.apply_investment_allocation_change(operation_id, action, allocation_id, expected_version, amount_centavos, allocated_on)`. A função autenticada deriva o proprietário de `auth.uid()` e implementa criação, edição e cancelamento lógico. Criação/edição localizam o período pela data com intervalo `[start_date, end_date)`. Edição preserva o estado de cancelamento existente; o cancelamento registra `cancelled_at`. Valores são `BIGINT` não negativo, e zero permanece válido.

A RPC usa `SECURITY DEFINER`, proprietária `postgres`, `search_path` vazio, grants somente para `authenticated`, idempotência por operação, controle otimista de versão, snapshots de conflito e auditoria na mesma transação. O teste automatizado está em `supabase/tests/rpc_investment_allocation_test.sql` e cobre permissões, associação ao período, valor acima de `2^53`, replay, edição, conflito, cancelamento, auditoria e isolamento entre usuários.

**Status:** implementação e teste local concluídos. A suíte PostgreSQL isolada passou, incluindo execução concorrente da RPC de períodos. Validação no Supabase gerenciado permanece pendente.

### 16.14 Entrega 7B — RPCs de receitas e despesas avulsas

`supabase/migrations/20261109000600_cash_entry_write_rpcs.sql` cria `public.apply_income_entry_change` e `public.apply_expense_entry_change`. Ambas derivam `owner_id` de `auth.uid()`, recebem UUID estável do registro e operação idempotente, payload JSONB, ação e versão esperada; aplicam `SECURITY DEFINER`, proprietária `postgres`, `search_path` vazio e grants somente a `authenticated`.

A RPC de receita cria lançamentos avulsos já recebidos e associa o período pela data efetiva; permite edição/cancelamento em qualquer status sem alterar o modelo de recorrência. A RPC de despesa cria lançamentos pendentes e associa pela competência/data de cadastro; pagamento registra `paid_on` sem mover o período nem criar nova despesa. Ambas preservam auditoria, retornam conflitos com snapshots em versão desatualizada e evitam reutilização indevida de chave idempotente. Edições de registros cancelados preservam o status cancelado. Novas associações exigem categorias/subcategorias ativas; referências históricas podem ser mantidas.

O teste `supabase/tests/rpc_cash_entry_test.sql` cobre permissões, atribuição de períodos, limite semiaberto, replay, edição entre períodos, conflito, pagamento, status após edição, cancelamento, auditoria e isolamento entre usuários. **Status:** implementação e suíte PostgreSQL local concluídas; integração Supabase gerenciado pendente.

### 16.15 Entrega 7C — RPCs de modelos de recorrência

`supabase/migrations/20261109000700_recurrence_template_write_rpcs.sql` cria `public.apply_income_recurrence_template_change` e `public.apply_expense_recurrence_template_change`. As funções autenticadas permitem criar, editar e desativar modelos, com versionamento otimista, idempotência, snapshots de conflito e auditoria transacional. Validam frequência mensal ou por período, dia de referência mensal, data inicial, modo fixo/variável, centavos não negativos e associações ativas compatíveis de categoria/subcategoria. Desativar mantém o modelo e seu histórico.

O teste `supabase/tests/rpc_recurrence_template_test.sql` verifica grants, configuração `SECURITY DEFINER`, modelos mensais e por período, valores fixos/variáveis, replay, edição, conflito, desativação, auditoria e isolamento entre usuários. **Status:** funções e suíte PostgreSQL local concluídas.

### 16.16 Entrega 8 — geração e ciclo de vida de ocorrências recorrentes

As migrations `20261109000800_recurrence_occurrence_rpcs.sql` e `20261109000900_allow_unpriced_variable_expense_occurrence_edits.sql` implementam geração idempotente de ocorrências mensais e por período, além de edição, recebimento, pagamento e cancelamento individual. A geração recupera ocorrências vencidas ao abrir o aplicativo e durante sincronização, usando a data corrente na zona IANA do usuário. A primeira ocorrência mensal ocorre na primeira data de referência igual ou posterior ao início do modelo; modelo por período criado durante o período atual também gera sua ocorrência no início desse período. Conflitos de versão preservam snapshots; gravações mantêm auditoria e idempotência. Despesas variáveis sem valor podem receber outras edições sem contabilização até informar o valor.

O teste `supabase/tests/rpc_recurrence_occurrence_test.sql` cobre grants, segurança, calendário mensal incluindo meses curtos, recuperação por período, modelos inativos, valor variável não informado, ciclo de vida das ocorrências, auditoria, idempotência e isolamento entre usuários. **Status:** migrations aplicadas no Supabase local e teste direcionado aprovado; validação no Supabase gerenciado permanece pendente.

### 16.17 Entrega 9 — schema local Drift v1

`lib/core/local_database/app_database.dart` define as 14 tabelas locais do schema aprovado, chaves compostas por proprietário, referências locais, índices únicos de agenda recorrente, constraints de status e ciclo, e centavos como texto decimal convertido para `BigInt`. A versão 1 está registrada em `drift_schemas/porquinho/drift_schema_v1.json`; o código tipado é gerado em `app_database.g.dart`. A conexão recebe um `QueryExecutor` injetado; esta entrega não configura armazenamento persistente sem criptografia.

O teste `test/core/local_database/app_database_test.dart` verifica criação do schema, chaves estrangeiras, versão, limites de `BigInt` e gravação/leitura exata de 9.007.199.254.740.993 centavos em SQLite nativo. **Status:** geração, análise estática e testes locais passaram. Teste Flutter Web, adapter de armazenamento persistente criptografado e sincronização com PostgreSQL permanecem pendentes.

## 7. Textos superados de regras de negócio e requisitos

_Pendências anteriores e quadro-resumo de status repetido._
**regras_negocio.md §13**

As regras funcionais consolidadas não estão pendentes. A zona IANA `America/Sao_Paulo` por usuário foi definida em 08/11/2026. Permanecem detalhamentos técnicos: protocolo e retentativas de sincronização; mecanismo de backup, restauração, retenção, exportação e exclusão; e método/dispositivos representativos para validar as metas iniciais de desempenho. A continuidade dos alertas, os relatórios básicos e a regra de meses curtos estão aprovados.

**regras_negocio.md §14.1 — Resumo de status após v0.5 (completo)**

### 14.1 Resumo de status após v0.5

| Tema | Status |
|---|---|
| Limites de período | APROVADO |
| Meses curtos e anos bissextos | APROVADO |
| Geração e idempotência de recorrências | APROVADO funcionalmente |
| Zona IANA por usuário | APROVADO: `America/Sao_Paulo` |
| Geração ao abrir e sincronizar, usando a zona IANA | APROVADO; implementado localmente |
| Pagamentos parciais | FORA DO MVP |
| Categorias | APROVADO |
| Alertas após fim do período | APROVADO |
| Encerramento manual de período | FORA DO MVP |
| Moeda BRL, escala em centavos, zero permitido e negativos/mais de duas casas rejeitados | APROVADO |
| Representação física PostgreSQL `BIGINT` e estratégia exata local/Web | APROVADO pelo responsável em 09/11/2026; round-trip Drift nativo testado; Web pendente |
| Conflitos de sincronização | APROVADO: preservar versões, informar usuário e consolidar em nova versão |
| Segurança, backup, recuperação e CSV | APROVADO como requisito; desenho técnico detalhado |

**requisitos.md §11**

As regras funcionais desta baseline estão aprovadas. A zona IANA `America/Sao_Paulo` por usuário foi definida em 08/11/2026. Permanecem detalhamentos técnicos antes das implementações correspondentes: protocolo e retentativas de sincronização; implementação de alertas móveis; critérios de medição das metas de desempenho; e desenho de backup, restauração, retenção, exportação e exclusão. Não há decisão pendente sobre meses curtos, conflitos, relatórios aprovados ou encerramento manual de períodos.
