# Requisitos do Produto — Norte

**Versão:** 0.5  
**Data:** 08/11/2026  
**Status:** Baseline funcional revisada do MVP  
**Responsável pelo produto:** usuário do projeto

## 1. Visão geral

O Norte é um aplicativo de controle financeiro pessoal por períodos. O MVP registra receitas pela data de recebimento, despesas cadastradas/geradas e valores totais destinados a investimentos. O principal e único indicador de resultado é a **dinheiro livre do período**.

O produto não fará controle de saldos bancários, não manterá módulo de contas e não terá o antigo Porquinho virtual de reservas e compromissos separados. "Dinheiro livre do período" passa a ser apenas o nome do indicador `receitas − despesas − investimentos` do período (decisão de 11/11/2026). O aplicativo chama-se Norte (decisão de 12/11/2026; antes Porquinho).

## 2. Objetivos do produto

- Registrar receitas avulsas e recorrentes.
- Registrar despesas avulsas e recorrentes, com valores fixos ou variáveis.
- Permitir editar e cancelar lançamentos a qualquer momento, preservando histórico.
- Registrar o valor total destinado a investimentos, sem acompanhar ativos.
- Calcular o dinheiro livre por mês-calendário ou ciclo personalizado.
- Permitir categorias de receitas e despesas personalizadas pelo usuário.
- Disponibilizar Dashboard, Lançamentos e Mais.
- Operar offline nas funcionalidades financeiras do MVP e sincronizar com segurança (offline somente no aplicativo de celular; a Web exige conexão — decisão de 10/11/2026).
- Oferecer relatórios básicos, autenticação e configurações.

## 3. Escopo

### 3.1 Incluído no MVP — APROVADO

1. Aplicativo Flutter para Android e Web (iOS fora do MVP — decisão de 10/11/2026).
2. Uso individual, com dados isolados por usuário.
3. Autenticação por Google e por e-mail/senha.
4. Confirmação de e-mail para cadastro tradicional e recuperação de senha.
5. Bloqueio opcional por PIN ou biometria no aplicativo móvel, solicitado ao abrir o app quando ativado.
6. Navegação principal com quatro áreas (Home, Ferramentas, Lançamentos e Mais) e o botão Adicionar (+) no centro da barra inferior.
7. Cadastro de receitas avulsas, com data de recebimento informada pelo usuário (passada ou futura — decisão de 10/11/2026).
8. Cadastro de receitas recorrentes mensais, com valores fixos ou variáveis; ocorrência pendente até confirmação do recebimento.
9. Cadastro de despesas avulsas e recorrentes mensais, com valores fixos ou variáveis.
10. Status de despesa pendente/paga e registro da data de pagamento.
11. Fatura de cartão representada por despesa recorrente variável, sem módulo próprio de cartão.
12. Categorias personalizáveis de receitas e despesas, com subcategorias opcionais.
13. Registro simplificado de valores destinados a investimentos, sem categoria de ativo ou controle de carteira.
14. Registro manual de rendimentos efetivamente recebidos como receitas comuns.
15. Controle por mês-calendário ou ciclo personalizado recorrente, com dia inicial configurável.
16. Cálculo e apresentação do dinheiro livre do período.
17. Edição e cancelamento de qualquer lançamento, independentemente do status, com histórico de auditoria.
18. Alertas móveis de vencimentos: três dias antes, no dia e diariamente após o vencimento enquanto a despesa estiver pendente, respeitadas as permissões do dispositivo.
19. Operação offline das funcionalidades financeiras do MVP, no aplicativo de celular (Android). A Web funciona somente online, sem banco local nem fila de envio (decisão de 10/11/2026).
20. Sincronização de operações pendentes, com idempotência e detecção de conflitos.
21. Assistente de configuração inicial, com etapas que podem ser puladas e concluídas posteriormente.
22. Tema claro ou escuro selecionável manualmente.
23. Cinco relatórios básicos aprovados, conforme seção 13.7; detalhamentos de apresentação e filtros podem ser definidos no planejamento técnico.

### 3.2 Fora do escopo do MVP — APROVADO

- Aplicativo iOS (decisão de 10/11/2026; pode voltar em versão futura).
- Cadastro ou manutenção de contas bancárias.
- Saldos individuais por conta, saldo bancário consolidado automático, conciliação ou integração bancária.
- Campo ou entidade especial de saldo inicial por período.
- Porquinho virtual, reservas, compromissos separados e cálculo de saldo disponível (com reservas ou compromissos separados).
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

A navegação principal terá somente (barra inferior: Home, Ferramentas, Adicionar +, Lançamentos e Mais — 13/11/2026):

- **Home (Dashboard):** período selecionado, dinheiro livre do período e visão resumida de receitas, despesas e investimentos.
- **Ferramentas:** catálogo personalizável de ferramentas financeiras (o usuário escolhe, ordena e restaura "Suas ferramentas"; as demais ficam em "Outras ferramentas"). Os cinco relatórios (RF025, §13.7) são uma ferramenta deste catálogo. Ferramentas futuras são simulações independentes, sem criar lançamentos, e cada uma precisa de aprovação própria.
- **Adicionar (+):** abre o novo lançamento (despesa, receita ou investimento).
- **Lançamentos:** inclusão, consulta, edição e cancelamento de receitas, despesas e destinações para investimentos; filtros por período, tipo, categoria e status quando aplicável.
- **Mais:** categorias, configurações, preferências de período, tema, segurança e onboarding.

Não haverá abas próprias para Contas ou Porquinho.

## 6. Requisitos funcionais

Prioridades: **Essencial** = necessário ao funcionamento central; **Alta** = parte aprovada do MVP; **Média** = incluído no MVP, podendo vir após os fluxos centrais.

| ID | Requisito | Prioridade | Status |
|---|---|---|---|
| RF001 | Autenticação com Google e e-mail/senha | Essencial | APROVADO |
| RF002 | Verificação de e-mail e recuperação de senha | Essencial | APROVADO |
| RF003 | Bloqueio móvel opcional por PIN ou biometria ao abrir o app | Alta | APROVADO |
| RF004 | Navegação principal: Home, Ferramentas, Adicionar, Lançamentos e Mais (Ferramentas substituiu Relatórios em 13/11/2026; os relatórios ficam dentro de Ferramentas) | Essencial | APROVADO |
| RF005 | Registrar receitas avulsas com data de recebimento informada (passada ou futura) | Essencial | APROVADO (revisado em 10/11/2026) |
| RF006 | Criar receitas recorrentes mensais ("Todo mês"; por período retirado em 13/11/2026), fixas ou variáveis, ativando "Repetir" no formulário do lançamento (o lançamento é a primeira ocorrência); consultar em Mais → Recorrências | Alta | APROVADO (D8, 11/11/2026) |
| RF007 | Gerar ocorrência pendente de receita recorrente e contabilizar somente após confirmação de recebimento | Essencial | APROVADO |
| RF008 | Permitir editar o valor de uma ocorrência de receita sem alterar recorrência ou outras ocorrências | Alta | APROVADO |
| RF009 | Registrar despesas avulsas, contabilizando-as no momento do cadastro | Essencial | APROVADO |
| RF010 | Criar despesas recorrentes mensais ("Todo mês"; por período retirado em 13/11/2026), fixas ou variáveis, ativando "Repetir" no formulário; editar "só esta" ocorrência ou "a recorrência" e parar de repetir | Essencial | APROVADO (D8, 11/11/2026) |
| RF011 | Contabilizar despesa recorrente ao gerar a ocorrência e, se variável, após informar seu valor | Essencial | APROVADO |
| RF012 | Confirmar pagamento de despesa, alterando status e registrando data sem nova dedução | Essencial | APROVADO |
| RF013 | Representar fatura de cartão como despesa recorrente variável | Alta | APROVADO |
| RF014 | Criar, renomear e desativar categorias de receitas e despesas | Alta | APROVADO |
| RF015 | Suportar subcategorias opcionais | Média | APROVADO |
| RF016 | Registrar valor total destinado a investimentos, com dedução imediata do dinheiro livre | Alta | APROVADO |
| RF017 | Registrar rendimento efetivamente recebido como receita comum | Média | APROVADO |
| RF018 | Editar ou cancelar qualquer lançamento, qualquer que seja seu status, preservando auditoria | Alta | APROVADO |
| RF019 | Permitir controle por mês-calendário ou ciclo personalizado, com troca a qualquer momento valendo para todos os períodos | Essencial | APROVADO (revisado em 13/11/2026) |
| RF020 | Calcular e apresentar somente o dinheiro livre do período como indicador de resultado | Essencial | APROVADO |
| RF021 | Realizar operações financeiras previstas mesmo sem conexão | Essencial | APROVADO |
| RF022 | Sincronizar operações pendentes com idempotência e detecção de conflitos | Essencial | APROVADO |
| RF023 | Alertas móveis de vencimento de despesas | Alta | APROVADO |
| RF024 | Assistente de configuração inicial com etapas opcionais | Média | APROVADO |
| RF025 | Disponibilizar cinco relatórios básicos (acesso pela aba Ferramentas → Relatórios) | Média | APROVADO; conteúdo definido na seção 13.7 |
| RF026 | Seleção manual de tema claro ou escuro | Média | APROVADO |
| RF027 | Cálculos locais e validação remota segundo as mesmas regras, com resultados equivalentes | Essencial | APROVADO |

### 6.1 Critérios de aceitação

**RF005–RF008 — Receitas**
- Receita avulsa aceita data de recebimento passada ou futura; o aplicativo não verifica se foi de fato recebida (decisão de 10/11/2026).
- A data de recebimento determina o período da receita.
- Uma recorrência mensal gera uma ocorrência pendente.
- Uma ocorrência recorrente só entra no dinheiro livre quando o usuário confirma o recebimento.
- Se fixa, o valor padrão é preenchido automaticamente; se variável, o usuário informa o valor.
- O usuário pode alterar o valor da ocorrência, inclusive quando fixa, sem alterar o modelo da recorrência nem ocorrências futuras.
- O valor confirmado é contabilizado uma única vez.

**RF009–RF013 — Despesas**
- Despesa avulsa entra no cálculo do dinheiro livre no momento do cadastro, no período da data informada (passada ou futura; padrão hoje).
- Despesa recorrente gera uma ocorrência por mês, no dia do lançamento original; dia inexistente (29–31) vai para o dia útil anterior mais próximo (RN038), com o vencimento na mesma data.
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
- Cada categoria tem ícone e cor, escolhidos de um conjunto fixo (APROVADO em 12/11/2026); subcategorias herdam o visual da categoria. O visual não altera nenhuma regra financeira.
- Categorias não são aplicadas ao lançamento simples de investimento.
- No primeiro acesso, o aplicativo sugere categorias desmarcáveis (lista na RN024); o usuário pode criar as suas.

**RF016–RF017 — Investimentos e rendimentos**
- O usuário registra somente o valor destinado a investimentos e a data (padrão hoje; passada ou futura — decisão de 11/11/2026). O total de investimentos por período aparece no relatório da Fase 7 e, desde 11/11/2026 (D1 da Fase 7, revisa a D3 da Fase 6), também no Dashboard como parte da composição do dinheiro livre; sem discriminação por ativo ou categoria.
- O valor é deduzido imediatamente do dinheiro livre do período da data do investimento.
- O investimento pode se repetir todo mês (por período retirado em 13/11/2026), com valor fixo e valor alterável por ocorrência; cada ocorrência gerada entra no dinheiro livre sem confirmação (decisão de 11/11/2026).
- O sistema não solicita classe de ativo, instituição, quantidade, posição, status de pagamento ou rentabilidade.
- Rendimentos efetivamente recebidos podem ser lançados como receitas comuns.
- Nenhuma estimativa de rendimento é calculada automaticamente.

**RF018 — Edição e cancelamento**
- Todo lançamento pode ser editado ou cancelado a qualquer momento, independentemente de estar pendente, pago ou recebido.
- Edição atualiza o resultado do período correspondente; alteração de data pode alterar o período ao qual o lançamento pertence.
- Cancelamento exclui o lançamento dos cálculos, mas preserva o registro histórico e o evento de auditoria.
- O sistema não apaga fisicamente o histórico financeiro.

**RF019–RF020 — Períodos e dinheiro livre**
- O usuário escolhe mês-calendário ou ciclo personalizado.
- O ciclo personalizado usa um dia inicial configurável; exemplo: 20/11 a 19/12.
- Há uma única configuração; o usuário pode alterá-la a qualquer momento e a alteração recalcula imediatamente todos os períodos, passados e futuros (RN002, 13/11/2026). Totais de períodos antigos podem mudar.
- O período é um intervalo de datas calculado, nunca criado: todo lançamento, de qualquer data, pertence a um período. Não existe pergunta para criar períodos.
- O dinheiro livre de um período soma os lançamentos cuja data está entre o início e o fim do período: receitas pela data de recebimento, despesas pela data do lançamento e investimentos pela data do investimento.
- Não há indicador de saldo atual ou saldo disponível; o dinheiro livre do período é somente o indicador único do §5.
- Para ciclos personalizados, preservar o dia original e usar o último dia disponível em meses curtos; retornar ao dia original quando possível no mês seguinte.

**RF021–RF022–RF027 — Offline e sincronização** (offline somente no celular; Web somente online — decisão de 10/11/2026)
- O usuário consegue consultar dados sincronizados localmente e registrar/editar/cancelar operações sem conexão.
- As operações são persistidas localmente antes de serem apresentadas como salvas no dispositivo.
- Cada operação possui identificador idempotente.
- O backend valida as operações usando regras equivalentes às locais.
- Divergências são identificadas e apresentadas, sem sobrescrita silenciosa.
- A política aprovada detecta conflitos por versão, preserva as versões concorrentes, apresenta o conflito ao usuário e registra a resolução em nova versão consolidada.

**RF023 — Alertas**
- Alertas móveis previstos: três dias antes do vencimento, no dia e diariamente após o vencimento enquanto a despesa estiver pendente.
- Os alertas continuam após o fim do período enquanto a despesa estiver pendente e cessam quando paga ou cancelada.
- Às 9h (zona do usuário), uma única notificação por dia resume as despesas, sem valores; só no Android; reagendada ao abrir, sincronizar e salvar; apagada ao sair da conta (D9, 11/11/2026).

## 7. Requisitos não funcionais

- Interface responsiva para Android e Web.
- Operações financeiras locais disponíveis sem conexão no celular, conforme escopo offline; a Web não oferece uso offline (decisão de 10/11/2026).
- Valores monetários em BRL, com escala de até duas casas decimais; rejeitar valores negativos e entradas com casas excedentes, sem arredondamento. Zero é permitido. Persistir sem ponto flutuante binário.
- Cálculos determinísticos, testáveis e equivalentes entre cliente e backend.
- Metas iniciais de desempenho aprovadas constam na RN043 (`docs/regras_negocio.md`); são objetivos a medir e validar, não garantias.
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

Os cinco relatórios aprovados estão especificados na seção 13.7. Esta seção não define uma lista alternativa. Não incluir relatório de saldo bancário, saldo disponível, Porquinho virtual ou carteira de investimentos.

## 11. Detalhamentos pendentes

As regras funcionais desta baseline estão aprovadas. Não há decisão pendente sobre meses curtos, conflitos, relatórios aprovados ou encerramento manual de períodos. Detalhamentos técnicos pendentes: `docs/pendencias.md` §T; critérios de medição das metas de desempenho: RN043.

## 12. Funcionalidades para versões futuras

- Gestão de contas bancárias e conciliação.
- Porquinho virtual, reservas e saldo disponível.
- Compras individuais, parcelas e gestão avançada de cartões.
- Gestão de carteira e acompanhamento de ativos.
- Estimativas automáticas de rendimentos.
- Compartilhamento familiar.
- Importação de planilhas, exportação avançada e relatórios avançados.


## 13. Complementos aprovados (v0.5)

**Versão:** 0.5 — 08/11/2026. As regras financeiras complementares estão em `docs/regras_negocio.md`; esta seção apenas as localiza.

| Tema | Regra vigente |
|---|---|
| Períodos calculados `[início, fim)`, ciclo personalizado, meses curtos e troca de configuração | RN001–RN004, RN036–RN037 |
| Recorrências: só mensal, dia útil anterior em dia inexistente, primeira ocorrência, idempotência, zona `America/Sao_Paulo`, geração ao abrir e sincronizar | RN010–RN011, RN014, RN038 |
| Pagamento integral (pagamento parcial FORA DO MVP) | RN015, RN039 |
| Categorias: desativação, categoria opcional e grupo "Sem categoria" | RN024–RN027, RN040, RN044 |
| Alertas e períodos históricos (sem encerramento manual) | RN016, RN018, RN041, RN042 |
| Segurança, sincronização, backup e portabilidade | `docs/arquitetura.md` §4–§5 e §7 |
| Metas iniciais de desempenho | RN043 |
| Moeda e precisão monetária | RN045 |

### 13.7 Relatórios básicos do MVP

1. Receitas por categoria e período.
2. Despesas por categoria e período.
3. Total destinado a investimentos por período.
4. Evolução do dinheiro livre entre períodos.
5. Comparativo de receitas, despesas e investimentos por período.

Todos respeitam a configuração de período do usuário. Nos relatórios de receitas e despesas por categoria, lançamentos sem categoria aparecem agrupados em **Sem categoria** e também permanecem nos totais gerais. Não incluem rentabilidade, projeções, saldos bancários, saldo disponível ou gestão de carteira.
