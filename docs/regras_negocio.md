# Regras de Negócio — Norte

**Versão:** 0.5  
**Data:** 08/11/2026  
**Status:** Baseline funcional v0.5 consolidada; detalhamentos técnicos remanescentes identificados na seção 13

## 1. Princípios gerais

1. O MVP é um controle de receitas, despesas e valores destinados a investimentos por período.
2. O único indicador de resultado financeiro é o dinheiro livre do período.
3. O sistema não controla saldos bancários nem contas financeiras.
4. O sistema não possui o antigo Porquinho virtual, reservas ou cálculo de saldo disponível. "Dinheiro livre do período" é só o nome do indicador `receitas − despesas − investimentos` (decisão de 11/11/2026).
5. Receitas são contabilizadas pela data de recebimento: a avulsa aceita data passada ou futura (RN008); a recorrente só após confirmação (RN011).
6. Despesas são contabilizadas no cadastro ou geração da ocorrência, não no pagamento.
7. O pagamento de despesa não cria uma segunda dedução.
8. Investimentos são lançamentos simples de valor total destinado e reduzem o dinheiro livre no momento do lançamento.
9. Cancelamentos e correções preservam histórico suficiente para auditoria.

## 2. Períodos de apuração

### RN001 — Modalidades de período

O usuário poderá escolher entre:

- **Mês-calendário:** do primeiro ao último dia do mês.
- **Ciclo personalizado:** intervalo recorrente definido por um dia inicial. Exemplo: dia 20 de um mês até dia 19 do mês seguinte.

**Status:** APROVADO.

### RN002 — Alteração da configuração de período

Alteração de modalidade ou dia inicial passa a valer somente a partir do próximo período. Períodos históricos preservam a configuração usada na sua criação. Períodos consecutivos não devem ter lacunas nem sobreposição.

**Status:** APROVADO.

**Detalhamento (decisões D2 e D3 da Fase 7, 11/11/2026):** a nova configuração começa quando termina o último período existente (o aplicativo avisa a data antes de confirmar). Enquanto nenhum período a usar, a mudança pode ser trocada ou cancelada. Períodos já criados nunca são alterados.

**Exceção de conflito para o tema (D5, 11/11/2026):** na preferência de tema vale a última gravação enviada, sem tela de conflito; a regra de conflitos por versão continua valendo para todos os dados financeiros.

**Detalhamento de transição — APROVADO pelo responsável em 09/11/2026:** quando a configuração muda, o primeiro período com a nova configuração começa no fim do período anterior e termina na próxima fronteira da nova modalidade/dia inicial que seja posterior ao início. Os períodos seguintes seguem a agenda regular aprovada. Essa regra mantém a continuidade, inclusive quando a nova fronteira mensal não coincide com a fronteira anterior.

**Períodos anteriores e futuros — APROVADO pelo responsável em 10/11/2026:** quando a data de um lançamento cair antes do primeiro período ou depois do último existente, o aplicativo pergunta se o usuário quer criar os períodos necessários (ex.: "Criar os períodos de julho a outubro?"). Períodos anteriores ao primeiro usam a mesma configuração do primeiro período; períodos futuros seguem a configuração vigente. A sequência continua sem lacunas nem sobreposição (RN036).

### RN003 — Dias inexistentes em meses curtos

Preservar o dia original configurado e, quando ele não existir no mês, usar o último dia disponível. No mês seguinte, retornar ao dia original quando possível. Ver RN037.

**Status:** APROVADO; regra detalhada na RN037.

### RN004 — Associação de lançamento ao período

A associação do lançamento ao período segue sua data de competência:

- Receita: data efetiva de recebimento.
- Despesa avulsa: data do lançamento, informada pelo usuário (padrão: hoje).
- Despesa recorrente: data de geração da ocorrência, isto é, a data programada (decisão D5, 11/11/2026): a despesa recuperada com atraso fica no período da data programada, não no do dia em que o app foi aberto.
- Investimento: data do lançamento da destinação.

A data de pagamento da despesa é armazenada como histórico e não altera o período em que foi contabilizada. Alertas são determinados pela data de vencimento conforme RN017–RN018.

**Datas passadas e futuras — APROVADO pelo responsável em 10/11/2026:** receitas e despesas avulsas aceitam data diferente de hoje, inclusive passada ou futura. A data informada define o período, conforme acima. Períodos inexistentes: RN002.

**Status:** APROVADO.

## 3. Cálculo do dinheiro livre

### RN005 — Fórmula única de resultado

O dinheiro livre do período é calculado por:

`Dinheiro livre = receitas contabilizadas no período - despesas contabilizadas no período - investimentos lançados no período`.

Somente o dinheiro livre do período será apresentado como indicador de resultado. O MVP não calcula saldo disponível, saldo atual ou saldo bancário; o dinheiro livre do período não considera sobras de períodos anteriores, reservas, compromissos separados nem saldo bancário.

**Status:** APROVADO.

### RN006 — Não existe saldo inicial especial

O MVP não possui campo próprio, fotografia bancária, entidade ou lançamento automático de saldo inicial. O usuário pode criar uma categoria de receita denominada “Saldo inicial” e lançar um valor como receita comum. Nesse caso:

- o lançamento segue as regras normais de receita;
- sua data efetiva determina o período;
- entra no dinheiro livre como qualquer receita;
- o sistema não identifica a categoria como especial e não detecta duplicidade.

O usuário é responsável por não registrar duas vezes o mesmo recurso.

**Status:** APROVADO.

### RN007 — Receitas fora da categoria de saldo inicial

Qualquer valor efetivamente recebido que o usuário decida registrar pode ser lançado como receita, inclusive rendimentos. Rendimentos recebidos manualmente são receitas comuns. Não existe cálculo automático de rendimento por taxa fixa, CDI ou projeção.

**Status:** APROVADO.

## 4. Receitas

### RN008 — Receita avulsa

Receita avulsa é registrada com a data de recebimento informada pelo usuário, que pode ser passada ou futura (decisão de 10/11/2026). O aplicativo não verifica se o valor foi de fato recebido. A data de recebimento determina o período em que será somada ao dinheiro livre.

**Status:** APROVADO.

### RN009 — Tipos e categorias de receita

Receitas podem ser avulsas ou recorrentes. Categorias são personalizáveis pelo usuário. O tipo da categoria permanece Receita.

**Status:** APROVADO.

### RN010 — Recorrência de receita

As únicas frequências permitidas no MVP são:

- Mensal.
- Por período de controle configurado pelo usuário.

Valores podem ser fixos ou variáveis. Não há frequência semanal, quinzenal, anual ou diária.

**Status:** APROVADO.

### RN011 — Ocorrência de receita recorrente

O sistema gera ocorrência pendente. Uma receita recorrente só entra no cálculo do dinheiro livre depois que o usuário confirma que recebeu o valor. Para valor fixo, o modelo fornece um valor padrão; para valor variável, o usuário informa o valor da ocorrência.

O usuário pode editar o valor de uma ocorrência, mesmo quando a recorrência é fixa. A edição da ocorrência não altera o modelo nem outras ocorrências.

**Status:** APROVADO.

### RN012 — Data de recebimento

A data efetiva de recebimento informada na confirmação determina o período da receita. O valor é somado uma única vez.

**Status:** APROVADO.

## 5. Despesas

### RN013 — Despesas avulsas

Ao cadastrar uma despesa avulsa, ela entra imediatamente no cálculo do dinheiro livre do período de cadastro e recebe status Pendente. Não é necessário aguardar pagamento para contabilizá-la.

**Status:** APROVADO.

### RN014 — Despesas recorrentes

As únicas frequências permitidas no MVP são mensal e por período. O usuário escolhe valor fixo ou variável.

- Valor fixo: a ocorrência utiliza o valor padrão.
- Valor variável: o sistema gera a ocorrência e solicita ao usuário o valor daquela ocorrência.
- A ocorrência entra no dinheiro livre quando gerada e com valor definido.
- Editar uma ocorrência não altera o modelo nem outras ocorrências.

**Status:** APROVADO.

### RN015 — Status e pagamento

Despesas começam como Pendente. Ao confirmar pagamento, o usuário informa a data efetiva e o status muda para Pago. Pagamento integral, sem segunda dedução e sem pagamento parcial: RN039.

**Status:** APROVADO. Pagamentos parciais: FORA DO MVP.

### RN016 — Despesas pendentes na virada do período

Uma despesa não paga permanece pendente no período em que foi cadastrada ou gerada. Ela não é transportada para o cálculo do período seguinte e não é lançada novamente no novo período. O novo período começa com seus próprios lançamentos.

O lançamento original continua disponível no histórico do período anterior e pode ter seu status atualizado posteriormente. Essa atualização de status não cria uma nova despesa no período atual.

**Status:** APROVADO.

### RN017 — Data de vencimento

A despesa pode ter data de vencimento. Essa data serve para exibição e alertas; não determina a competência financeira da despesa, que é a data de cadastro/geração. Na despesa recorrente, o vencimento é preenchido automaticamente com a data da ocorrência (mensal: data programada; por período: início do período) e o usuário pode alterá-lo em cada ocorrência (decisão D3, 11/11/2026).

**Status:** APROVADO.

### RN018 — Alertas de vencimento

Alertas móveis previstos:

- Três dias antes do vencimento.
- No dia do vencimento.
- Diariamente após o vencimento enquanto a despesa estiver pendente.

Os alertas continuam após o fim do período enquanto a despesa estiver pendente e cessam quando paga ou cancelada, respeitadas as permissões do dispositivo. Regra consolidada também na RN041.

**Detalhes aprovados em 11/11/2026 (D9):** o alerta é enviado às 9h (zona `America/Sao_Paulo`); há uma única notificação por dia resumindo as despesas, sem valores nem nomes na tela bloqueada; vale para toda despesa pendente com vencimento, avulsa ou recorrente; os alertas dos próximos 30 dias são reagendados ao abrir, sincronizar e salvar; o logout apaga todos; só Android. Se a despesa for paga em outro aparelho, o alerta pode ficar desatualizado até a próxima sincronização.

**Status:** APROVADO.

## 6. Cartão de crédito

### RN019 — Fatura como despesa recorrente variável

A fatura de cartão é representada por uma despesa recorrente variável, por exemplo “Fatura do cartão”. O usuário informa o valor da ocorrência e a data de vencimento. Ela segue as mesmas regras de qualquer despesa recorrente variável.

**Status:** APROVADO.

### RN020 — Funcionalidades de cartão fora do MVP

Não haverá cadastro técnico de cartões, compras individuais, parcelas, fechamento, geração automática de fatura, controle de limite ou módulo próprio de cartões.

**Status:** FORA DO ESCOPO.

## 7. Investimentos

### RN021 — Destinação simples para investimentos

O usuário poderá registrar valores destinados a investimentos por lançamentos simples que registram somente valor e data. A data é informada pelo usuário (padrão hoje; passada ou futura) e define o período (decisão de 11/11/2026). Não há descrição, categoria por ativo, classe, instituição ou tipo de investimento. O total destinado no período consta do relatório da Fase 7; o Dashboard do MVP não o exibe.

**Status:** APROVADO.

### RN022 — Efeito imediato no dinheiro livre

O valor destinado a investimento é deduzido do dinheiro livre do período no momento em que o lançamento é registrado. Não existe status pendente/pago nem confirmação posterior. A ocorrência de um investimento recorrente também entra no dinheiro livre assim que é gerada, no período da data programada, sem confirmação.

**Status:** APROVADO.

### RN023 — Limites do controle de investimentos

O aplicativo não acompanha carteira, ativos, posições, saldo acumulado, rentabilidade, dividendos ou cotações. O total do período é a soma dos lançamentos de destinação não cancelados daquele período. Não existe resgate: o valor investido não volta para o dinheiro livre e o aplicativo não orienta lançar resgate como receita. Desfazer um investimento é cancelá-lo, o que devolve o valor ao dinheiro livre do período original do investimento, não do período atual (decisão de 11/11/2026).

**Status:** APROVADO.

## 8. Categorias e subcategorias

### RN024 — Categorias personalizáveis

O usuário pode criar e renomear categorias de Receita e Despesa. O tipo é definido na criação e não pode ser alterado posteriormente.

**Visual — APROVADO pelo responsável em 12/11/2026:** cada categoria guarda uma chave de ícone e uma de cor (conjunto fixo no aplicativo; a cor se adapta ao tema claro/escuro). Padrão: ícone `category` e cor `gray`. Subcategorias herdam o visual. Alterar o visual é uma edição comum (versão, auditoria e sincronização, como renomear).

**Sugestões no primeiro acesso — APROVADO pelo responsável em 10/11/2026:** o aplicativo sugere categorias, todas marcadas e desmarcáveis; as escolhidas viram categorias comuns, sem tratamento especial. Receitas: Salário, Renda extra (alterado em 13/11/2026: "Rendimentos" deixou de ser sugerida; o usuário pode criá-la como categoria comum). Despesas: Moradia, Alimentação, Mercado, Transporte, Saúde, Educação, Lazer, Contas da casa, Assinaturas, Fatura do cartão. Sem subcategorias prontas. "Saldo inicial" não é sugerida (RN006).

**Status:** APROVADO.

### RN025 — Subcategorias opcionais

O usuário poderá criar subcategorias vinculadas a categorias, sem obrigatoriedade de uso.

**Status:** APROVADO.

### RN026 — Desativação de categorias

Categorias usadas ou não podem ser desativadas, mas nunca excluídas fisicamente. Regras de desativação e renomeação: RN040.

**Status:** APROVADO; exclusão física de categorias: FORA DO MVP.

### RN027 — Investimentos sem categorias

Destinações para investimento não usam categorias personalizáveis; cada registro contém somente valor e data (o total agregado do período consta do relatório da Fase 7).

**Status:** APROVADO.

## 9. Edição, cancelamento e auditoria

### RN028 — Edição de qualquer lançamento

O usuário pode editar qualquer lançamento a qualquer momento, independentemente do status (Pendente, Pago ou Recebido). Pode alterar valor, descrição, categoria e data, conforme os campos aplicáveis. Alterar a data pode mudar o período ao qual o lançamento pertence.

**Status:** APROVADO.

### RN029 — Cancelamento de qualquer lançamento

O usuário pode cancelar qualquer lançamento a qualquer momento, independentemente do status. Lançamentos cancelados deixam de participar do dinheiro livre, mas permanecem no histórico como cancelados. Não apagar fisicamente o registro.

**Status:** APROVADO.

### RN030 — Recalcular períodos afetados

Após editar ou cancelar um lançamento, o sistema recalcula o dinheiro livre dos períodos afetados. Alterações não devem gerar uma segunda contabilização. O histórico deve registrar os valores anteriores e novos, operação, usuário e data/hora.

**Status:** APROVADO.

## 10. Operação offline e integridade

### RN031 — Operação offline

O usuário poderá consultar dados locais e criar, editar, cancelar e consultar lançamentos e ocorrências recorrentes sem conexão. A capacidade offline é essencial e será implementada incrementalmente desde os primeiros módulos financeiros.

**Status:** APROVADO.

### RN032 — Paridade de cálculo

O cliente executa os cálculos localmente. O backend valida operações sincronizadas segundo as mesmas regras. Para os mesmos dados e condições, os resultados devem ser equivalentes. Não é obrigatório compartilhar o mesmo código.

**Status:** APROVADO.

### RN033 — Conflitos e idempotência

A sincronização usa identificadores idempotentes e controle de versão. Conflitos preservam versões concorrentes, são apresentados ao usuário e resolvidos por nova versão consolidada. Não há sobrescrita silenciosa.

**Status:** APROVADO.

## 11. Segurança e notificações

### RN034 — Uso individual

Cada usuário acessa somente os próprios dados. A autorização deve ser verificada no backend.

**Status:** APROVADO.

### RN035 — Canal de notificação

Alertas do MVP serão enviados a dispositivos móveis Android (iOS fora do MVP — decisão de 10/11/2026), mediante permissão. Não haverá notificações por e-mail ou navegador.

**Status:** APROVADO.

## 12. Matriz resumida

| ID | Regra | Status |
|---|---|---|
| RN001–RN004 | Modalidades, configuração e competência dos períodos | APROVADO |
| RN005–RN007 | Fórmula do dinheiro livre, ausência de saldo inicial especial e receitas | APROVADO |
| RN008–RN012 | Receitas avulsas e recorrentes | APROVADO |
| RN013–RN018 | Despesas, pagamento, virada de período e alertas | APROVADO |
| RN019–RN020 | Fatura variável e exclusões de cartão | APROVADO/FORA DO ESCOPO |
| RN021–RN023 | Investimentos simplificados e rendimentos | APROVADO |
| RN024–RN027, RN040, RN044 | Categorias e subcategorias; associação opcional e grupo “Sem categoria” | APROVADO |
| RN028–RN030 | Edição, cancelamento, auditoria e recálculo | APROVADO |
| RN031–RN033 | Offline, paridade, idempotência e conflitos | APROVADO; detalhes de protocolo e retentativa são técnicos |
| RN034–RN035 | Segurança e notificações | APROVADO |
| RN036–RN039, RN041–RN043, RN045 | Intervalos semiabertos, meses curtos, recorrências idempotentes, pagamento integral, alertas, períodos sem encerramento manual, metas e moeda | APROVADO; pagamento parcial e encerramento manual: FORA DO MVP |

## 13. Detalhamentos pendentes

As regras funcionais consolidadas não estão pendentes. Permanecem detalhamentos técnicos (`docs/pendencias.md` §T) e o método/dispositivos representativos para validar as metas iniciais de desempenho (RN043). A zona IANA `America/Sao_Paulo` por usuário foi definida em 08/11/2026; a continuidade dos alertas, os relatórios básicos e a regra de meses curtos estão aprovados.

## 14. Regras complementares (RN036–RN045)

**Data:** 08/11/2026. As regras abaixo resolvem as pendências da auditoria v0.4 e prevalecem sobre status anteriores incompatíveis.

### RN036 — Intervalos de período

Todo período utiliza intervalo semiaberto `[data_inicio, data_fim)`: início inclusivo e fim exclusivo. A data igual ao fim exclusivo pertence ao próximo período. Períodos consecutivos não podem apresentar lacuna ou sobreposição.

**Status:** APROVADO.

### RN037 — Ciclos personalizados em meses curtos

O dia originalmente configurado deve ser preservado. Quando não existir no mês, usar o último dia disponível; no mês seguinte, retornar ao dia originalmente configurado quando existir. Exemplo para dia 31: `[31/01,28/02)`, `[28/02,31/03)`, `[31/03,30/04)`. Em ano bissexto, fevereiro usa 29 dias. As datas finais são exclusivas. Alteração de configuração: RN002.

**Status:** APROVADO.

### RN038 — Geração idempotente de recorrências

Recorrências mensais mantêm o dia de referência original; se a data não existir, usar o último dia do mês sem alterar a referência dos meses seguintes. A primeira ocorrência mensal é a primeira data de referência igual ou posterior ao início da recorrência (por exemplo, criada em 10 de maio com referência no dia 31, começa em 31 de maio). Recorrências por período geram uma ocorrência no início de cada período; se criadas durante um período, também geram a ocorrência desse período, mesmo que sua data seja anterior à criação. Na abertura do aplicativo e durante a sincronização, verificar ocorrências faltantes e recuperar as atrasadas até a data corrente na zona do usuário, sem depender de agendador em segundo plano. A combinação modelo de recorrência + referência programada/competência identifica unicamente uma ocorrência e deve possuir garantia de unicidade no armazenamento. Edição individual não altera modelo nem ocorrências futuras; desativação impede novas ocorrências e preserva o histórico.

Receitas recorrentes são criadas pendentes e só entram no dinheiro livre após confirmação do recebimento (data padrão: hoje; o usuário pode informar outra). Despesas recorrentes entram no dinheiro livre quando geradas e com valor definido; pagamento não gera segunda dedução. A zona de calendário por usuário é `America/Sao_Paulo`, decisão de 08/11/2026. A geração ocorre ao abrir o aplicativo e sincronizar, usando a data corrente nessa zona.

**Decisões de 11/11/2026 (Fase 5):**

- **D1 — identificador:** a ocorrência tem identificador determinístico calculado de modelo + data programada, igual no aplicativo e no servidor; dois aparelhos que geram offline produzem a mesma ocorrência.
- **D2 — mudar a agenda:** todos os campos do modelo podem mudar (dia, frequência, início, fixo/variável), mas só valem para ocorrências ainda não geradas: nunca há duas ocorrências do mesmo modelo no mesmo mês/período e a mudança não cria ocorrências passadas (ex.: dia 5 já gerado em 05/11 → muda para dia 20 → próxima em 20/12). Descrição, valor padrão e categoria valem para as próximas.
- **D4:** início anterior ao primeiro período: o app pergunta se cria os períodos (RN002); sem confirmação não salva. O servidor recusa em vez de ignorar.
- **D6:** o lançamento avulso só se repete se o usuário marcar a recorrência. A confirmação de recebimento usa hoje como padrão e aceita outra data.
- **D7:** ao parar de repetir, as ocorrências já geradas ficam como estão.
- **D8:** a recorrência é ativada no formulário do lançamento (“Repetir”: todo mês ou todo período). O próprio lançamento é a primeira ocorrência; as seguintes seguem o dia dele; data passada gera também as atrasadas até hoje. Em “todo período”, a data da ocorrência é o início do período que contém a data informada. Ao editar uma ocorrência, o usuário escolhe “só esta” ou “a recorrência”. Lista de consulta em Mais → Recorrências.

**Decisões de 11/11/2026 (Fase 6 — investimento recorrente):** o investimento também pode ser recorrente, com as mesmas regras de agenda, identificador determinístico, geração ao abrir e sincronizar, mudança de agenda só para as próximas e "parar de repetir" da despesa recorrente (D1, D2, D4, D7, D8 acima). Diferenças: o valor é sempre fixo (valor padrão do modelo, alterável por ocorrência com "só esta" ou nas próximas com "a recorrência"); não há valor variável, pendente/pago, vencimento nem alertas; a ocorrência entra no dinheiro livre quando gerada. Cancelar uma ocorrência não a recria.

**Status:** APROVADO. Primeira data mensal e inclusão do período atual na recorrência por período foram decididas em 09/11/2026.

### RN039 — Pagamento integral

No MVP, despesa só pode ser paga integralmente. Não existe pagamento parcial, saldo remanescente ou histórico de parcelas de pagamento. Ao pagar, alterar status e registrar data efetiva; não deduzir novamente do dinheiro livre.

**Status:** APROVADO. Pagamentos parciais: FORA DO MVP.

### RN040 — Desativação de categorias

Categorias nunca são excluídas fisicamente. Categorias usadas ou não podem ser desativadas. Categorias desativadas não são oferecidas em novos lançamentos, mas continuam disponíveis para consulta histórica. Renomear uma categoria não altera retroativamente os lançamentos vinculados: eles continuam ligados à mesma categoria e passam a exibir o nome atual (interpretação aprovada em 10/11/2026).

**Status:** APROVADO.

### RN041 — Continuidade de alertas

Consolidada na RN018: os alertas continuam válidos mesmo após o fim do período de competência, cessam quando a despesa é paga ou cancelada e respeitam as permissões do dispositivo.

**Status:** APROVADO.

### RN042 — Períodos sem encerramento manual

Não existe fechamento ou arquivamento manual de períodos no MVP. Períodos são determinados pelo calendário e configuração do usuário e permanecem consultáveis após seu término. Despesas pendentes permanecem no período original, sem transporte financeiro para períodos seguintes. O término do período não bloqueia edição ou cancelamento de lançamentos.

**Status:** APROVADO.

### RN043 — Metas iniciais de desempenho

Metas de engenharia: Dashboard com dados locais até 1 s; lista de lançamentos até 1 s; salvar localmente até 500 ms; atualizar cálculo do dinheiro livre até 300 ms; sincronizar lote pequeno em conexão normal até 5 s. São metas a validar por testes e medições, não garantias.

**Status:** APROVADO como metas iniciais, sujeito à validação.

### RN044 — Categoria opcional em receitas e despesas

O usuário pode registrar receitas e despesas sem categoria. Nos relatórios por categoria, esses lançamentos aparecem agrupados em **Sem categoria** e continuam incluídos nos totais gerais. Destinações para investimento não usam categorias.

**Status:** APROVADO — decisão do responsável pelo produto em 08/11/2026.

### RN045 — Moeda, escala e sinal dos valores

Todos os valores financeiros do MVP são denominados em BRL e representados em centavos. Entradas aceitam até duas casas decimais; casas excedentes e valores negativos são rejeitados, sem arredondamento implícito. Valor zero é permitido. Nenhum limite de produto foi definido. Em 09/11/2026 o responsável validou o schema físico PostgreSQL `BIGINT` assinado de 64 bits por valor individual e a estratégia local/Web de exatidão (`BigInt`, texto decimal e protocolo em string). Drift grava e lê valores exatos no SQLite nativo; a validação Web continua pendente.

**Status:** APROVADO — decisão do responsável pelo produto em 08/11/2026.

### 14.1 Outros temas (sem RN própria)

| Tema | Status |
|---|---|
| Zona IANA por usuário | APROVADO: `America/Sao_Paulo` |
| Geração ao abrir e sincronizar, usando a zona IANA | APROVADO; implementado localmente |
| Pagamentos parciais | FORA DO MVP |
| Encerramento manual de período | FORA DO MVP |
| Desfazer pagamento, reativar categoria e desfazer cancelamento | FORA DO MVP por ora (decisão de 10/11/2026); correção da data de pagamento é feita pagando novamente |
| Segurança, backup, recuperação e CSV | APROVADO como requisito; desenho técnico detalhado |

O quadro-resumo anterior, que repetia os status das RN036–RN045, está em `docs/historico/decisoes.md`.
