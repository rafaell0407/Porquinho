# Requisitos do Produto — Porquinho

**Versão:** 0.5  
**Data:** 08/11/2026  
**Status:** Baseline funcional revisada do MVP  
**Responsável pelo produto:** usuário do projeto

## 1. Visão geral

O Porquinho é um aplicativo de controle financeiro pessoal por períodos. O MVP registra receitas efetivamente recebidas, despesas cadastradas/geradas e valores totais destinados a investimentos. O principal e único indicador de resultado é a **sobra do período**.

O produto não fará controle de saldos bancários, não manterá módulo de contas e não terá o antigo Porquinho virtual de reservas e dinheiro livre. O nome do aplicativo permanece Porquinho.

## 2. Objetivos do produto

- Registrar receitas avulsas e recorrentes.
- Registrar despesas avulsas e recorrentes, com valores fixos ou variáveis.
- Permitir editar e cancelar lançamentos a qualquer momento, preservando histórico.
- Registrar o valor total destinado a investimentos, sem acompanhar ativos.
- Calcular a sobra por mês-calendário ou ciclo personalizado.
- Permitir categorias de receitas e despesas personalizadas pelo usuário.
- Disponibilizar Dashboard, Lançamentos e Mais.
- Operar offline nas funcionalidades financeiras do MVP e sincronizar com segurança.
- Oferecer relatórios básicos, autenticação e configurações.

## 3. Escopo

### 3.1 Incluído no MVP — APROVADO

1. Aplicativo Flutter para Android, iOS e Web.
2. Uso individual, com dados isolados por usuário.
3. Autenticação por Google e por e-mail/senha.
4. Confirmação de e-mail para cadastro tradicional e recuperação de senha.
5. Bloqueio opcional por PIN ou biometria no aplicativo móvel, solicitado ao abrir o app quando ativado.
6. Navegação principal com três áreas: Dashboard, Lançamentos e Mais.
7. Cadastro de receitas avulsas, registradas após recebimento.
8. Cadastro de receitas recorrentes mensais ou por período, com valores fixos ou variáveis; ocorrência pendente até confirmação do recebimento.
9. Cadastro de despesas avulsas e recorrentes mensais ou por período, com valores fixos ou variáveis.
10. Status de despesa pendente/paga e registro da data de pagamento.
11. Fatura de cartão representada por despesa recorrente variável, sem módulo próprio de cartão.
12. Categorias personalizáveis de receitas e despesas, com subcategorias opcionais.
13. Registro simplificado de valores destinados a investimentos, sem categoria de ativo ou controle de carteira.
14. Registro manual de rendimentos efetivamente recebidos como receitas comuns.
15. Controle por mês-calendário ou ciclo personalizado recorrente, com dia inicial configurável.
16. Cálculo e apresentação da sobra do período.
17. Edição e cancelamento de qualquer lançamento, independentemente do status, com histórico de auditoria.
18. Alertas móveis de vencimentos: três dias antes, no dia e diariamente após o vencimento enquanto a despesa estiver pendente, respeitadas as permissões do dispositivo.
19. Operação offline das funcionalidades financeiras do MVP.
20. Sincronização de operações pendentes, com idempotência e detecção de conflitos.
21. Assistente de configuração inicial, com etapas que podem ser puladas e concluídas posteriormente.
22. Tema claro ou escuro selecionável manualmente.
23. Cinco relatórios básicos aprovados, conforme seção 13.7; detalhamentos de apresentação e filtros podem ser definidos no planejamento técnico.

### 3.2 Fora do escopo do MVP — APROVADO

- Cadastro ou manutenção de contas bancárias.
- Saldos individuais por conta, saldo bancário consolidado automático, conciliação ou integração bancária.
- Campo ou entidade especial de saldo inicial por período.
- Porquinho virtual, reservas, compromissos separados e cálculo de dinheiro livre/disponível.
- Compras individuais no cartão, parcelamentos, fechamento automático, faturas calculadas a partir de compras e controle de limites.
- Categorias ou detalhamento de investimentos por ativo, classe, instituição ou carteira.
- Acompanhamento de ativos, posições, cotações, rentabilidade ou dividendos.
- Estimativas automáticas de rendimentos por taxa fixa ou percentual do CDI.
- Compartilhamento familiar ou entre usuários.
- Importação de dados de planilhas ou outros arquivos.
- Parcelamentos diretos em lojas, boletos ou financiamentos.
- Notificações por e-mail ou navegador.
- Aplicativo desktop nativo.
- Relatórios avançados e exportação PDF/Excel.

### 3.3 Observação sobre saldo inicial

Não existe campo próprio de saldo inicial. Como as categorias de receitas são personalizáveis, o usuário pode criar uma categoria chamada “Saldo inicial” ou equivalente e registrar um valor como receita comum. O aplicativo não atribui tratamento especial a essa categoria, não a cria obrigatoriamente e não detecta se o valor já foi considerado em outro registro. O usuário é responsável por evitar lançamentos duplicados.

## 4. Usuários e perfis

### 4.1 Usuário individual — MVP

Cada usuário administra seus próprios lançamentos, categorias, recorrências, períodos, configurações e relatórios. Seus dados devem ser privados e isolados dos dados de outros usuários.

### 4.2 Ambiente compartilhado — futuro

Casais ou famílias poderão compartilhar um planejamento financeiro em versão futura. Convites, papéis e permissões não fazem parte do MVP.

## 5. Navegação e módulos funcionais

A navegação principal terá somente:

- **Dashboard:** período selecionado, sobra do período e visão resumida de receitas, despesas e investimentos.
- **Lançamentos:** inclusão, consulta, edição e cancelamento de receitas, despesas e destinações para investimentos; filtros por período, tipo, categoria e status quando aplicável.
- **Mais:** categorias, relatórios, configurações, preferências de período, tema, segurança e onboarding.

Não haverá abas próprias para Contas ou Porquinho.

## 6. Requisitos funcionais

Prioridades: **Essencial** = necessário ao funcionamento central; **Alta** = parte aprovada do MVP; **Média** = incluído no MVP, podendo vir após os fluxos centrais.

| ID | Requisito | Prioridade | Status |
|---|---|---|---|
| RF001 | Autenticação com Google e e-mail/senha | Essencial | APROVADO |
| RF002 | Verificação de e-mail e recuperação de senha | Essencial | APROVADO |
| RF003 | Bloqueio móvel opcional por PIN ou biometria ao abrir o app | Alta | APROVADO |
| RF004 | Navegação principal Dashboard, Lançamentos e Mais | Essencial | APROVADO |
| RF005 | Registrar receitas avulsas somente após recebimento | Essencial | APROVADO |
| RF006 | Criar receitas recorrentes mensais ou por período, fixas ou variáveis | Alta | APROVADO |
| RF007 | Gerar ocorrência pendente de receita recorrente e contabilizar somente após confirmação de recebimento | Essencial | APROVADO |
| RF008 | Permitir editar o valor de uma ocorrência de receita sem alterar recorrência ou outras ocorrências | Alta | APROVADO |
| RF009 | Registrar despesas avulsas, contabilizando-as no momento do cadastro | Essencial | APROVADO |
| RF010 | Criar despesas recorrentes mensais ou por período, fixas ou variáveis | Essencial | APROVADO |
| RF011 | Contabilizar despesa recorrente ao gerar a ocorrência e, se variável, após informar seu valor | Essencial | APROVADO |
| RF012 | Confirmar pagamento de despesa, alterando status e registrando data sem nova dedução | Essencial | APROVADO |
| RF013 | Representar fatura de cartão como despesa recorrente variável | Alta | APROVADO |
| RF014 | Criar, renomear e desativar categorias de receitas e despesas | Alta | APROVADO |
| RF015 | Suportar subcategorias opcionais | Média | APROVADO |
| RF016 | Registrar valor total destinado a investimentos, com dedução imediata da sobra | Alta | APROVADO |
| RF017 | Registrar rendimento efetivamente recebido como receita comum | Média | APROVADO |
| RF018 | Editar ou cancelar qualquer lançamento, qualquer que seja seu status, preservando auditoria | Alta | APROVADO |
| RF019 | Permitir controle por mês-calendário ou ciclo personalizado | Essencial | APROVADO |
| RF020 | Calcular e apresentar somente a sobra do período como indicador de resultado | Essencial | APROVADO |
| RF021 | Realizar operações financeiras previstas mesmo sem conexão | Essencial | APROVADO |
| RF022 | Sincronizar operações pendentes com idempotência e detecção de conflitos | Essencial | APROVADO |
| RF023 | Alertas móveis de vencimento de despesas | Alta | APROVADO |
| RF024 | Assistente de configuração inicial com etapas opcionais | Média | APROVADO |
| RF025 | Disponibilizar cinco relatórios básicos | Média | APROVADO; conteúdo definido na seção 13.7 |
| RF026 | Seleção manual de tema claro ou escuro | Média | APROVADO |
| RF027 | Cálculos locais e validação remota segundo as mesmas regras, com resultados equivalentes | Essencial | APROVADO |

### 6.1 Critérios de aceitação

**RF005–RF008 — Receitas**
- Receita avulsa somente é registrada quando efetivamente recebida.
- A data efetiva de recebimento determina o período da receita.
- Uma recorrência mensal ou por período gera uma ocorrência pendente.
- Uma ocorrência recorrente só entra na sobra quando o usuário confirma o recebimento.
- Se fixa, o valor padrão é preenchido automaticamente; se variável, o usuário informa o valor.
- O usuário pode alterar o valor da ocorrência, inclusive quando fixa, sem alterar o modelo da recorrência nem ocorrências futuras.
- O valor confirmado é contabilizado uma única vez.

**RF009–RF013 — Despesas**
- Despesa avulsa entra no cálculo da sobra no momento do cadastro.
- Despesa recorrente gera uma ocorrência no calendário escolhido (mensal ou por período).
- Despesa fixa utiliza o valor padrão; despesa variável solicita o valor da ocorrência.
- O valor da despesa recorrente é contabilizado quando a ocorrência é gerada e o valor está definido.
- A despesa fica pendente até a confirmação do pagamento.
- Ao confirmar, o sistema registra status Pago e data efetiva, sem deduzir novamente.
- Fatura de cartão pode ser cadastrada como despesa recorrente variável, por exemplo “Fatura do cartão”. Não existem compras ou parcelas individuais.

**RF014–RF015 — Categorias**
- Usuário cria, renomeia e desativa categorias próprias de receita ou despesa.
- O tipo da categoria (receita ou despesa) é definido na criação e não pode ser alterado.
- Subcategorias são opcionais e vinculadas a uma categoria.
- Categoria já utilizada não é apagada fisicamente; pode ser desativada, preservando lançamentos históricos.
- Categorias não são aplicadas ao lançamento simples de investimento.

**RF016–RF017 — Investimentos e rendimentos**
- O usuário registra somente o valor destinado a investimentos; a data do lançamento é registrada pelo sistema. O Dashboard apresenta um único total de investimentos do período, sem discriminação por ativo ou categoria.
- O valor é deduzido imediatamente da sobra do período.
- O sistema não solicita classe de ativo, instituição, quantidade, posição, status de pagamento ou rentabilidade.
- Rendimentos efetivamente recebidos podem ser lançados como receitas comuns.
- Nenhuma estimativa de rendimento é calculada automaticamente.

**RF018 — Edição e cancelamento**
- Todo lançamento pode ser editado ou cancelado a qualquer momento, independentemente de estar pendente, pago ou recebido.
- Edição atualiza o resultado do período correspondente; alteração de data pode alterar o período ao qual o lançamento pertence.
- Cancelamento exclui o lançamento dos cálculos, mas preserva o registro histórico e o evento de auditoria.
- O sistema não apaga fisicamente o histórico financeiro.

**RF019–RF020 — Períodos e sobra**
- O usuário escolhe mês-calendário ou ciclo personalizado.
- O ciclo personalizado usa um dia inicial configurável; exemplo: 20/11 a 19/12.
- Alterações de modalidade ou dia inicial só passam a valer no próximo período.
- Períodos anteriores mantêm a configuração usada na criação.
- A sobra é calculada com receitas recebidas no período, despesas cadastradas/geradas no período e investimentos lançados no período.
- Não há indicador de saldo atual, saldo disponível ou dinheiro livre.
- Para ciclos personalizados, preservar o dia original e usar o último dia disponível em meses curtos; retornar ao dia original quando possível no mês seguinte.

**RF021–RF022–RF027 — Offline e sincronização**
- O usuário consegue consultar dados sincronizados localmente e registrar/editar/cancelar operações sem conexão.
- As operações são persistidas localmente antes de serem apresentadas como salvas no dispositivo.
- Cada operação possui identificador idempotente.
- O backend valida as operações usando regras equivalentes às locais.
- Divergências são identificadas e apresentadas, sem sobrescrita silenciosa.
- A política aprovada detecta conflitos por versão, preserva as versões concorrentes, apresenta o conflito ao usuário e registra a resolução em nova versão consolidada.

**RF023 — Alertas**
- Alertas móveis previstos: três dias antes do vencimento, no dia e diariamente após o vencimento enquanto a despesa estiver pendente.
- Os alertas continuam após o fim do período enquanto a despesa estiver pendente e cessam quando paga ou cancelada.

## 7. Requisitos não funcionais

- Interface responsiva para Android, iOS e Web.
- Operações financeiras locais disponíveis sem conexão, conforme escopo offline.
- Valores monetários em BRL, com escala de até duas casas decimais; rejeitar valores negativos e entradas com casas excedentes, sem arredondamento. Zero é permitido. Persistir sem ponto flutuante binário.
- Cálculos determinísticos, testáveis e equivalentes entre cliente e backend.
- Metas iniciais de desempenho aprovadas constam na seção 13.6; são objetivos a medir e validar, não garantias.
- Logs sem exposição desnecessária de dados financeiros ou pessoais.
- Ações de sincronização idempotentes e recuperáveis após falhas transitórias.

## 8. Segurança e privacidade

- Dados isolados por usuário no backend.
- Autorização validada no servidor, não apenas na interface.
- Credenciais e tokens protegidos e fora do repositório.
- Proteção dos dados financeiros armazenados localmente conforme a tecnologia aprovada.
- Bloqueio móvel por PIN/biometria é camada adicional, não substitui autenticação/autorização.
- Retenção, exportação e exclusão de dados devem ser detalhadas antes da produção.

## 9. Restrições e exclusões

O aplicativo não controla contas bancárias nem saldos bancários. Não há saldo inicial especial nem módulo de Porquinho virtual. Não há compras individuais/parcelas de cartão, carteiras de investimento ou cálculos automáticos de rendimentos. A categoria de receita “Saldo inicial” pode ser criada pelo usuário, mas é uma categoria comum, sem lógica especial.

## 10. Relatórios do MVP

Os cinco relatórios aprovados estão especificados na seção 13.7. Esta seção não define uma lista alternativa. Não incluir relatório de saldo bancário, dinheiro livre, Porquinho virtual ou carteira de investimentos.

## 11. Detalhamentos pendentes

As regras funcionais desta baseline estão aprovadas. A zona IANA `America/Sao_Paulo` por usuário foi definida em 08/11/2026. Permanecem detalhamentos técnicos antes das implementações correspondentes: horário e calendário operacional das recorrências; protocolo e retentativas de sincronização; implementação de alertas móveis; critérios de medição das metas de desempenho; e desenho de backup, restauração, retenção, exportação e exclusão. Não há decisão pendente sobre meses curtos, conflitos, relatórios aprovados ou encerramento manual de períodos.

## 12. Funcionalidades para versões futuras

- Gestão de contas bancárias e conciliação.
- Porquinho virtual, reservas e dinheiro livre.
- Compras individuais, parcelas e gestão avançada de cartões.
- Gestão de carteira e acompanhamento de ativos.
- Estimativas automáticas de rendimentos.
- Compartilhamento familiar.
- Importação de planilhas, exportação avançada e relatórios avançados.


## 13. Baseline v0.5 — complementos aprovados

**Versão:** 0.5 — 08/11/2026. Esta seção consolida e prevalece sobre qualquer indicação anterior de pendência incompatível com as decisões abaixo.

### 13.1 Períodos e competência

- Todo período é representado por `[data_inicio, data_fim)`, com início inclusivo e fim exclusivo. A data do limite final pertence ao próximo período.
- Períodos consecutivos não podem ter lacunas ou sobreposições.
- No ciclo personalizado, preservar o dia inicial configurado. Se não existir no mês, usar o último dia disponível; no mês seguinte, retornar ao dia originalmente configurado quando possível. Exemplo para dia 31: `[31/01, 28/02)`, `[28/02, 31/03)`, `[31/03, 30/04)`. Em ano bissexto, fevereiro pode terminar em 29/02.
- Mudanças de configuração valem a partir do próximo período; períodos históricos mantêm a configuração original.

### 13.2 Recorrências

- Frequências do MVP: mensal e por período de apuração.
- Recorrência mensal mantém dia de referência; se inexistente, usa o último dia do mês sem alterar a referência original para os meses seguintes.
- Recorrência por período gera uma ocorrência no início de cada período.
- Geração idempotente, com unicidade por modelo + referência programada/competência.
- Na abertura do app e na sincronização, verificar e gerar ocorrências faltantes, inclusive atrasadas, sem duplicidade.
- Edição individual não altera modelo ou outras ocorrências; desativação impede futuras e preserva anteriores.
- Receitas recorrentes começam pendentes e só são contabilizadas após confirmação do recebimento. Despesas recorrentes são contabilizadas quando geradas e com valor definido.
- A zona de calendário é `America/Sao_Paulo` por usuário, conforme decisão de 08/11/2026. Horário e calendário operacional da geração ainda devem ser detalhados antes da implementação.

### 13.3 Pagamentos e categorias

- Pagamento parcial está **FORA DO MVP**. O pagamento de despesa é integral; não há saldo parcial.
- Categorias não são excluídas fisicamente. Podem ser desativadas mesmo sem uso; as desativadas não aparecem em novos lançamentos, mas permanecem no histórico. Renomear categoria não altera o histórico dos lançamentos.
- Categoria é opcional em receitas e despesas. Nos relatórios por categoria, lançamentos sem categoria aparecem agrupados em **Sem categoria** e permanecem nos totais gerais. Investimentos não usam categoria.

### 13.4 Alertas e períodos históricos

Alertas de despesas pendentes ocorrem três dias antes do vencimento, no dia e diariamente após o vencimento. Continuam após o fim do período original até a despesa ser paga ou cancelada, respeitadas as permissões do dispositivo.

Não existe encerramento ou arquivamento manual de período no MVP. Períodos anteriores permanecem consultáveis; despesas pendentes continuam no período original, não são transportadas nem bloqueiam edição.

### 13.5 Segurança, sincronização e portabilidade

- Criptografia do banco local e armazenamento seguro de chaves e tokens conforme a plataforma; senhas nunca são armazenadas em texto puro.
- Bloqueio opcional por PIN/biometria em dispositivos móveis.
- Isolamento dos dados por usuário e autorização validada no backend.
- Sincronização versionada: detectar concorrência, preservar versões conflitantes, apresentar conflito ao usuário e registrar resolução como nova versão; não usar sobrescrita silenciosa por última gravação. Operações idempotentes.
- Não descartar operações pendentes no logout.
- Backup remoto diário com retenção de 30 dias, procedimento de recuperação, exclusão definitiva e exportação CSV. A política de restauração deve impedir reaparecimento de dados definitivamente excluídos.

### 13.6 Metas iniciais de desempenho

| Operação | Meta |
|---|---:|
| Dashboard com dados locais | até 1 s |
| Lista de lançamentos | até 1 s |
| Salvamento local | até 500 ms |
| Cálculo/atualização da sobra | até 300 ms |
| Sincronização de lote pequeno em conexão normal | até 5 s |

Metas de engenharia sujeitas a medição e validação; não são garantias.

### 13.7 Relatórios básicos do MVP

1. Receitas por categoria e período.
2. Despesas por categoria e período.
3. Total destinado a investimentos por período.
4. Evolução da sobra entre períodos.
5. Comparativo de receitas, despesas e investimentos por período.

Todos respeitam a configuração de período do usuário. Nos relatórios de receitas e despesas por categoria, lançamentos sem categoria aparecem agrupados em **Sem categoria** e também permanecem nos totais gerais. Não incluem rentabilidade, projeções, saldos bancários, dinheiro livre ou gestão de carteira.

### 13.8 Moeda e precisão monetária

Decisão do responsável em 08/11/2026: todos os valores do MVP são BRL; aceitam até duas casas decimais, zero é válido, valores negativos e casas excedentes são rejeitados e não há arredondamento implícito. Nenhum limite de produto foi definido. O responsável validou em 09/11/2026 a representação PostgreSQL `BIGINT` e a estratégia exata local/Web (`BigInt`, texto decimal e protocolo em string). Os testes de Drift/Web permanecem pendentes.
