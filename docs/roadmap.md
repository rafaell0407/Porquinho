# Roadmap — Porquinho

**Versão:** 0.5  
**Data:** 08/11/2026  
**Status geral:** Planejamento do MVP simplificado

## 1. Visão geral

O desenvolvimento será incremental. O MVP concentra-se em receitas, despesas, recorrências mensais ou por período, destinações simples para investimentos e cálculo da sobra. A navegação principal possui Dashboard, Lançamentos e Mais.

O aplicativo será individual e multiplataforma (Android, iOS e Web). O offline é essencial e deve ser construído desde as primeiras fases financeiras.

## 2. Princípios de priorização

1. Não implementar regras financeiras ainda pendentes.
2. Priorizar integridade de lançamentos, competência e cálculo da sobra.
3. Implementar testes de domínio antes de depender da interface para validar cálculos.
4. Planejar persistência offline e sincronização desde a arquitetura inicial.
5. Manter o MVP enxuto; funcionalidades fora do escopo só entram mediante aprovação.
6. Não reintroduzir módulos de contas bancárias ou Porquinho virtual.

## 3. Fases do projeto

### Fase 1 — Documentação e alinhamento do produto

**Objetivo:** consolidar escopo, regras financeiras e decisões pendentes.

**Entregáveis:**
- `AGENTS.md`.
- `docs/requisitos.md`.
- `docs/arquitetura.md`.
- `docs/banco_de_dados.md`.
- `docs/regras_negocio.md`.
- `docs/roadmap.md`.

**Critérios de aceitação:** decisões aprovadas e pendentes claramente identificadas; documentação consistente; nenhuma proposta apresentada como decisão.

**Status:** CONCLUÍDA — documentação consolidada e validada pelo responsável em 08/11/2026.

### Fase 2 — Detalhamento arquitetural e modelagem física

**Objetivo:** detalhar a implementação da stack e das políticas já aprovadas, fechar o modelo lógico/físico e preparar a base técnica.

**Entregáveis:**
- Ambientes e configuração do backend e banco aprovados.
- Organização dos módulos e camadas.
- Estratégia de estado e navegação.
- Modelo lógico e físico inicial do banco.
- Segurança, isolamento por usuário e migrations.
- Persistência local, fila e política de conflitos.

**Dependências:** Fase 1 e resolução dos detalhamentos técnicos necessários ao cálculo, persistência e sincronização.

**Critérios de aceitação:** detalhamentos registrados em arquitetura e banco; modelo lógico revisado; schema e políticas de segurança preparados; cálculos e eventos cobertos por casos de teste.

**Prioridade:** Essencial.  
**Status:** EM EXECUÇÃO — Entregas 1 e 2 validadas; migrations PostgreSQL e RPCs passaram em PostgreSQL local nas Entregas 3 a 8, incluindo concorrência. O schema Drift v1 e os testes de SQLite nativo passaram na Entrega 9. A regra da primeira fronteira após mudança de configuração foi aprovada em 09/11/2026. Permanecem pendentes validação do Drift Web, abertura persistente criptografada, validação do Vector e integração com Supabase gerenciado.

### Fase 3 — Estrutura Flutter, autenticação e base offline

**Objetivo:** iniciar o aplicativo multiplataforma, autenticação e persistência local necessária às primeiras funcionalidades.

**Entregáveis:**
- Projeto Flutter para Android, iOS e Web.
- Estrutura modular aprovada.
- Ambientes de desenvolvimento e teste.
- Login Google e e-mail/senha.
- Confirmação de e-mail e recuperação de senha.
- Persistência local inicial e indicação do estado de conexão/sincronização.
- Base de testes automatizados.
- Bloqueio móvel opcional por PIN/biometria, se viável na arquitetura aprovada.

**Dependências:** Fase 2.

**Testes:** autenticação, sessão, autorização, persistência local e isolamento entre usuários.

**Prioridade:** Essencial.  
**Status:** NÃO INICIADO.

### Fase 4 — Categorias e lançamentos avulsos

**Objetivo:** implementar os registros financeiros básicos e personalização de categorias.

**Entregáveis:**
- Categorias de receita e despesa personalizáveis.
- Subcategorias opcionais.
- Receita avulsa após recebimento.
- Despesa avulsa com status pendente/paga.
- Registro de data de recebimento e data de pagamento.
- Edição e cancelamento de qualquer lançamento, preservando auditoria.
- Cálculo local inicial da sobra.
- Persistência offline para os fluxos implementados.

**Dependências:** Fases 2 e 3; regras de competência e auditoria aprovadas na baseline v0.5.

**Testes:** inclusão, edição, cancelamento, alteração de data, categoria, pagamento sem segunda dedução e cálculo da sobra.

**Prioridade:** Essencial.  
**Status:** NÃO INICIADO.

### Fase 5 — Recorrências

**Objetivo:** implementar receitas e despesas recorrentes mensais ou por período.

**Entregáveis:**
- Modelos recorrentes de receita e despesa.
- Frequências permitidas: mensal e por período de controle.
- Valores fixos e variáveis.
- Geração de ocorrências.
- Receitas recorrentes pendentes até confirmação do recebimento.
- Edição individual de ocorrência sem alterar modelo/futuras ocorrências.
- Despesas recorrentes contabilizadas quando geradas e com valor definido.
- Fatura de cartão como despesa recorrente variável comum.
- Vencimentos e alertas móveis.

**Dependências:** Fase 4. A zona por usuário `America/Sao_Paulo`, a geração na abertura/sincronização e as regras para primeira ocorrência estão aprovadas.

**Testes:** geração mensal e por período, ocorrência fixa/variável, confirmação de receita, edição isolada, despesa recorrente e ausência de duplicidade.

**Prioridade:** Essencial.  
**Status:** NÃO INICIADO.

### Fase 6 — Investimentos simples e rendimentos manuais

**Objetivo:** registrar o valor total destinado a investimentos sem administrar ativos.

**Entregáveis:**
- Lançamento simples de valor destinado a investimentos, com data registrada pelo sistema e sem categoria ou detalhamento por ativo.
- Dedução imediata do valor no cálculo da sobra.
- Exibição do total destinado no período.
- Registro de rendimentos efetivamente recebidos como receitas comuns.
- Nenhuma projeção automática, taxa fixa ou cálculo CDI.

**Dependências:** Fases 2 e 4.

**Testes:** destinação deduz uma vez, edição/cancelamento recalculam sobra, rendimento manual é receita, ausência de cálculo automático.

**Prioridade:** Alta.  
**Status:** NÃO INICIADO.

### Fase 7 — Períodos, Dashboard e relatórios

**Objetivo:** apresentar a sobra por mês-calendário ou ciclo personalizado.

**Entregáveis:**
- Seleção mês-calendário/ciclo personalizado.
- Configuração do dia inicial e vigência da mudança a partir do próximo período.
- Preservação da configuração histórica.
- Dashboard com sobra e composição por receitas, despesas e investimentos.
- Navegação Dashboard, Lançamentos e Mais.
- Receitas por categoria e período.
- Despesas por categoria e período.
- Total destinado a investimentos por período.
- Evolução da sobra entre períodos.
- Comparativo de receitas, despesas e investimentos por período.
- Tema claro/escuro.
- Onboarding com etapas opcionais.

**Dependências:** Fases 4 a 6 e implementação/testes da regra aprovada de meses curtos.

**Testes:** cálculo em mês-calendário e ciclo personalizado, mudança de configuração, período histórico, edição/cancelamento entre períodos, dashboard e relatórios.

**Prioridade:** Alta.  
**Status:** NÃO INICIADO.

### Fase 8 — Sincronização completa, qualidade e publicação

**Objetivo:** completar sincronização offline, validar segurança e preparar o MVP para distribuição.

**Entregáveis:**
- Fila de operações pendentes completa.
- Identificadores idempotentes.
- Retentativas seguras.
- Detecção e apresentação de conflitos.
- Validação no backend com regras equivalentes às locais.
- Backup e recuperação.
- Revisão de segurança e isolamento de usuários.
- Testes Android, iOS e Web.
- Processo de publicação e hospedagem.

**Dependências:** Fases 2 a 7. A persistência e as operações offline básicas já devem existir desde as fases anteriores.

**Testes:** operação offline prolongada, reenvio, interrupção, duplicidade, divergência local/remota, conflito entre dispositivos, autenticação e recuperação.

**Prioridade:** Essencial.  
**Status:** NÃO INICIADO.

## 4. Prioridades do MVP

### P0 — núcleo financeiro

- Receitas avulsas e recorrentes.
- Despesas avulsas e recorrentes.
- Edição e cancelamento com auditoria.
- Cálculo da sobra do período.
- Recorrências mensal e por período.
- Investimento simples por valor total.
- Persistência local e cálculo offline desde o início.

### P1 — demais funcionalidades aprovadas para o MVP

- Autenticação completa e bloqueio móvel opcional.
- Categorias e subcategorias.
- Faturas como despesas recorrentes variáveis.
- Alertas móveis.
- Ciclo personalizado e Dashboard.
- Relatórios básicos.
- Onboarding e tema claro/escuro.
- Sincronização completa e tratamento de conflitos.

P1 representa ordem relativa de entrega, não significa que uma funcionalidade aprovada possa ser retirada do MVP. Offline continua requisito essencial.

## 5. Dependências e detalhamentos técnicos

- Implementar e testar os casos de meses curtos e anos bissextos conforme regra aprovada.
- Implementar e testar alertas após o fim do período enquanto a despesa continuar pendente.
- Detalhar protocolo, retentativas e persistência técnica dos conflitos conforme política aprovada.
- Detalhar as consultas dos cinco relatórios já aprovados.
- Stack, política funcional de conflitos, regras de período e escopo dos relatórios estão aprovados; não são bloqueios de decisão.
- O esquema físico depende do detalhamento técnico do modelo lógico aprovado e das constraints de integridade.

## 6. Fora do MVP

- Gestão de contas bancárias e conciliação.
- Porquinho virtual, reservas e dinheiro livre.
- Compras individuais, parcelamentos e gestão avançada de cartões.
- Gestão de carteira de investimentos, ativos e rentabilidade.
- Estimativas automáticas de rendimentos.
- Compartilhamento familiar.
- Importação de planilhas e relatórios avançados.

## 7. Critérios de conclusão do MVP

- Todos os requisitos aprovados do MVP implementados.
- Cálculo da sobra coberto por testes unitários e de integração.
- Receitas, despesas e investimentos atribuídos ao período correto.
- Pagamento de despesa não gera dedução adicional.
- Edições e cancelamentos recalculam os períodos afetados e preservam auditoria.
- Recorrências geram ocorrências conforme regras aprovadas.
- Operação offline idempotente; conflitos detectados e apresentados.
- Isolamento por usuário testado.
- Android, iOS e Web validados.
- Documentação corresponde ao comportamento entregue.
- Pendências bloqueadoras resolvidas ou formalmente excluídas do MVP.

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
