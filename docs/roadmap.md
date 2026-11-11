# Roadmap — Porquinho

**Versão:** 0.5  
**Data:** 08/11/2026  
**Status geral:** Planejamento do MVP simplificado

## 1. Visão geral

O desenvolvimento será incremental. O MVP concentra-se em receitas, despesas, recorrências mensais ou por período, destinações simples para investimentos e cálculo da sobra. A navegação principal possui Dashboard, Lançamentos e Mais.

O aplicativo será individual e multiplataforma (Android e Web; iOS fora do MVP — decisão de 10/11/2026). O offline é essencial no celular e deve ser construído desde as primeiras fases financeiras; a Web funciona somente online (decisão de 10/11/2026).

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
**Status:** CONCLUÍDA em 10/11/2026 (Entregas 1 a 21; Entrega 21 validada pelo responsável). Antecipou da Fase 3: login, sessão, recuperação de senha, PIN/biometria, banco local criptografado, fila de envio e logout com pendências. Pendências que dependem do responsável seguem em `docs/estado_atual.md`; detalhe: `docs/entregas_fase2.md`.

### Fase 3 — Estrutura Flutter, autenticação e base offline

**Objetivo:** iniciar o aplicativo multiplataforma, autenticação e persistência local necessária às primeiras funcionalidades.

**Entregáveis:**
- Projeto Flutter para Android e Web.
- Estrutura modular aprovada.
- Ambiente de desenvolvimento e teste: Supabase local (ambientes hospedados ficam para a Fase 8 — decisão de 10/11/2026).
- ~~Login Google e e-mail/senha; confirmação de e-mail e recuperação de senha; bloqueio por PIN/biometria~~ — antecipados na Fase 2.
- Persistência local inicial e indicação do estado de conexão/sincronização.
- Base de testes automatizados.

**Plano aprovado em 10/11/2026 (detalhe em `docs/entregas_fase3.md`):**
23. Composição pelo Riverpod.
24. Navegação principal (Dashboard, Lançamentos, Mais).
25. Banco local ligado ao usuário (outra conta bloqueada se houver pendências da anterior).
26. Gravação local única e versão local após o envio.
27A/27B. Download dos dados do servidor (proposta e implementação).
28. Indicador de conexão e sincronização.
29. Web somente online.
31. Fechamento e regressão.
(A Entrega 30, iOS, saiu do plano: iOS fora do MVP.)

**Dependências:** Fase 2.

**Testes:** autenticação, sessão, autorização, persistência local, download idempotente e isolamento entre usuários.

**Prioridade:** Essencial.  
**Status:** CONCLUÍDA em 10/11/2026 — Entregas 23–29 e 31 validadas pelo responsável.

### Fase 4 — Categorias e lançamentos avulsos

**Objetivo:** implementar os registros financeiros básicos e personalização de categorias.

**Entregáveis:**
- Primeiro acesso: o usuário escolhe mês-calendário ou ciclo personalizado (e o dia inicial) antes do primeiro lançamento (decisão de 10/11/2026); criação do período vigente e cálculo local dos períodos (RN001, RN036, RN037).
- Categorias de receita e despesa personalizáveis.
- Entrega 22 — tela de resolução de conflitos, logo após a sincronização de categorias (decisão de 10/11/2026).
- Subcategorias opcionais.
- Receita avulsa com data de recebimento passada ou futura (decisão de 10/11/2026).
- Despesa avulsa com status pendente/paga.
- Registro de data de recebimento e data de pagamento.
- Edição e cancelamento de qualquer lançamento, preservando auditoria.
- Cálculo local inicial da sobra.
- Persistência offline para os fluxos implementados.

**Plano aprovado em 10/11/2026 (detalhe e decisões D1–D13 em `docs/entregas_fase4.md`):**
32. Domínio: valores em reais (centavos exatos) e data corrente em `America/Sao_Paulo`.
33. Domínio de períodos (mês-calendário, ciclo, dias 29–31, bissexto, para frente e para trás).
35. Dependências na fila de envio (lançamento espera categoria/período).
34A. Primeiro acesso: escolha do período e criação do período vigente.
34B. Períodos anteriores e futuros sob demanda, com confirmação (nova migration).
36. Categorias, com sugestões no primeiro acesso.
37. Subcategorias.
22. Itens que precisam de atenção (conflitos e recusas), celular e Web.
38. Cálculo da sobra no domínio.
39. Receita avulsa.
40. Despesa avulsa (pendente/paga, vencimento, "já paga").
41. Sobra no Dashboard, navegação entre períodos e filtros período/tipo.
42. Fechamento e regressão.

**Dependências:** Fases 2 e 3 (concluídas); regras de competência e auditoria aprovadas na baseline v0.5.

**Testes:** inclusão, edição, cancelamento, alteração de data, categoria, pagamento sem segunda dedução e cálculo da sobra.

**Prioridade:** Essencial.  
**Status:** CONCLUÍDA em 11/11/2026 — Entregas 22 e 32–42 implementadas e validadas pelo responsável.

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
**Status:** CONCLUÍDA em 11/11/2026 — Entregas 43–50 (`docs/entregas_fase5.md`) implementadas e validadas pelo responsável.

### Fase 6 — Investimentos simples e rendimentos manuais

**Objetivo:** registrar o valor total destinado a investimentos sem administrar ativos.

**Entregáveis:**
- "Novo investimento" ao lado de receita e despesa em Lançamentos: só valor e data (informada pelo usuário, passada ou futura), sem categoria, descrição ou status de pagamento (D1, D2, D10).
- Dedução imediata do valor no cálculo da sobra; editar, mudar a data e cancelar recalculam os períodos afetados.
- Investimentos na lista de Lançamentos, com filtro "Investimentos". O total por período fica para o relatório da Fase 7 (D3: sem total no Dashboard na Fase 6).
- Investimento recorrente (todo mês ou todo período), com valor fixo e valor alterável por ocorrência; gerado ao abrir e sincronizar, sem pendente/pago (D7–D9).
- Rendimentos efetivamente recebidos continuam sendo receitas comuns; nenhuma tela de rendimento, resgate, projeção automática, taxa fixa ou cálculo CDI (D4, D5).

**Dependências:** Fases 2, 4 e 5.

**Testes:** destinação deduz uma vez, edição/cancelamento recalculam sobra, recorrência idempotente e igual no app e no servidor, rendimento manual é receita, ausência de cálculo automático.

**Prioridade:** Alta.  
**Status:** CONCLUÍDA e VALIDADA em 11/11/2026 — Entregas 51–58 (`docs/entregas_fase6.md`; a 54 foi removida por D3).

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
- Tema claro/escuro, salvo na conta por nova função no servidor (`user_preferences` ainda não tem RPC de gravação; nova migration — decisão de 10/11/2026).
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
- Testes Android e Web.
- Ambientes Supabase hospedados (dev/teste/produção), validação de RLS/grants no projeto gerenciado, publicação e hospedagem.

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

Ver `docs/requisitos.md` §3.2 e §12.

## 7. Critérios de conclusão do MVP

- Todos os requisitos aprovados do MVP implementados.
- Cálculo da sobra coberto por testes unitários e de integração.
- Receitas, despesas e investimentos atribuídos ao período correto.
- Pagamento de despesa não gera dedução adicional.
- Edições e cancelamentos recalculam os períodos afetados e preservam auditoria.
- Recorrências geram ocorrências conforme regras aprovadas.
- Operação offline idempotente; conflitos detectados e apresentados.
- Isolamento por usuário testado.
- Android e Web validados.
- Documentação corresponde ao comportamento entregue.
- Pendências bloqueadoras resolvidas ou formalmente excluídas do MVP.

## 8. Histórico de progresso

Movido para `docs/historico/decisoes.md`. Estado atual: `docs/estado_atual.md`.

## 9. Pendências para planejamento detalhado

Pendências técnicas: `docs/arquitetura.md` §15. Próximas etapas: `docs/estado_atual.md`.
