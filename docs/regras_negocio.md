# Regras de Negócio — Porquinho

**Versão:** 0.5  
**Data:** 08/11/2026  
**Status:** Baseline funcional v0.5 consolidada; detalhamentos técnicos remanescentes identificados na seção 14

## 1. Princípios gerais

1. O MVP é um controle de receitas, despesas e valores destinados a investimentos por período.
2. O único indicador de resultado financeiro é a sobra do período.
3. O sistema não controla saldos bancários nem contas financeiras.
4. O sistema não possui o antigo Porquinho virtual, reservas ou cálculo de dinheiro livre.
5. Receitas são contabilizadas após efetivo recebimento.
6. Despesas são contabilizadas no cadastro ou geração da ocorrência, não no pagamento.
7. O pagamento de despesa não cria uma segunda dedução.
8. Investimentos são lançamentos simples de valor total destinado e reduzem a sobra no momento do lançamento.
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

### RN003 — Dias inexistentes em meses curtos

Esta regra foi resolvida na baseline v0.5: preservar o dia original configurado e, quando ele não existir no mês, usar o último dia disponível. No mês seguinte, retornar ao dia original quando possível. Ver RN037.

**Status:** APROVADO; regra detalhada na RN037.

### RN004 — Associação de lançamento ao período

A associação do lançamento ao período segue sua data de competência:

- Receita: data efetiva de recebimento.
- Despesa avulsa: data de cadastro/lançamento.
- Despesa recorrente: data de geração da ocorrência.
- Investimento: data do lançamento da destinação.

A data de pagamento da despesa é armazenada como histórico e não altera o período em que foi contabilizada. Alertas são determinados pela data de vencimento conforme RN017–RN018.

**Status:** APROVADO.

## 3. Cálculo da sobra

### RN005 — Fórmula única de resultado

A sobra do período é calculada por:

`Sobra = receitas contabilizadas no período - despesas contabilizadas no período - investimentos lançados no período`.

Somente a sobra do período será apresentada como indicador de resultado. O MVP não calcula saldo disponível, saldo atual, dinheiro livre ou saldo bancário.

**Status:** APROVADO.

### RN006 — Não existe saldo inicial especial

O MVP não possui campo próprio, fotografia bancária, entidade ou lançamento automático de saldo inicial. O usuário pode criar uma categoria de receita denominada “Saldo inicial” e lançar um valor como receita comum. Nesse caso:

- o lançamento segue as regras normais de receita;
- sua data efetiva determina o período;
- entra na sobra como qualquer receita;
- o sistema não identifica a categoria como especial e não detecta duplicidade.

O usuário é responsável por não registrar duas vezes o mesmo recurso.

**Status:** APROVADO.

### RN007 — Receitas fora da categoria de saldo inicial

Qualquer valor efetivamente recebido que o usuário decida registrar pode ser lançado como receita, inclusive rendimentos. Rendimentos recebidos manualmente são receitas comuns. Não existe cálculo automático de rendimento por taxa fixa, CDI ou projeção.

**Status:** APROVADO.

## 4. Receitas

### RN008 — Receita avulsa

Receita avulsa é registrada depois de efetivamente recebida. Sua data de recebimento determina o período em que será somada à sobra.

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

O sistema gera ocorrência pendente. Uma receita recorrente só entra no cálculo da sobra depois que o usuário confirma que recebeu o valor. Para valor fixo, o modelo fornece um valor padrão; para valor variável, o usuário informa o valor da ocorrência.

O usuário pode editar o valor de uma ocorrência, mesmo quando a recorrência é fixa. A edição da ocorrência não altera o modelo nem outras ocorrências.

**Status:** APROVADO.

### RN012 — Data de recebimento

A data efetiva de recebimento informada na confirmação determina o período da receita. O valor é somado uma única vez.

**Status:** APROVADO.

## 5. Despesas

### RN013 — Despesas avulsas

Ao cadastrar uma despesa avulsa, ela entra imediatamente no cálculo da sobra do período de cadastro e recebe status Pendente. Não é necessário aguardar pagamento para contabilizá-la.

**Status:** APROVADO.

### RN014 — Despesas recorrentes

As únicas frequências permitidas no MVP são mensal e por período. O usuário escolhe valor fixo ou variável.

- Valor fixo: a ocorrência utiliza o valor padrão.
- Valor variável: o sistema gera a ocorrência e solicita ao usuário o valor daquela ocorrência.
- A ocorrência entra na sobra quando gerada e com valor definido.
- Editar uma ocorrência não altera o modelo nem outras ocorrências.

**Status:** APROVADO.

### RN015 — Status e pagamento

Despesas começam como Pendente. Ao confirmar pagamento, o usuário informa a data efetiva e o status muda para Pago. O pagamento não cria uma segunda dedução na sobra. O MVP considera apenas pagamento integral. Pagamentos parciais estão FORA DO MVP e não possuem saldo parcial.

**Status:** APROVADO. Pagamentos parciais: FORA DO MVP.

### RN016 — Despesas pendentes na virada do período

Uma despesa não paga permanece pendente no período em que foi cadastrada ou gerada. Ela não é transportada para o cálculo do período seguinte e não é lançada novamente no novo período. O novo período começa com seus próprios lançamentos.

O lançamento original continua disponível no histórico do período anterior e pode ter seu status atualizado posteriormente. Essa atualização de status não cria uma nova despesa no período atual.

**Status:** APROVADO.

### RN017 — Data de vencimento

A despesa pode ter data de vencimento. Essa data serve para exibição e alertas; não determina a competência financeira da despesa, que é a data de cadastro/geração.

**Status:** APROVADO.

### RN018 — Alertas de vencimento

Alertas móveis previstos:

- Três dias antes do vencimento.
- No dia do vencimento.
- Diariamente após o vencimento enquanto a despesa estiver pendente.

Os alertas continuam após o fim do período enquanto a despesa estiver pendente e cessam quando paga ou cancelada.

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

O usuário poderá registrar valores destinados a investimentos por lançamentos simples que registram somente valor e data. O aplicativo apresenta um único total destinado a investimentos no período, sem descrição, categoria por ativo, classe, instituição ou tipo de investimento.

**Status:** APROVADO.

### RN022 — Efeito imediato na sobra

O valor destinado a investimento é deduzido da sobra do período no momento em que o lançamento é registrado. Não existe status pendente/pago nem confirmação posterior.

**Status:** APROVADO.

### RN023 — Limites do controle de investimentos

O aplicativo não acompanha carteira, ativos, posições, saldo acumulado, rentabilidade, dividendos ou cotações. O total exibido para o período é a soma dos lançamentos de destinação não cancelados daquele período.

**Status:** APROVADO.

## 8. Categorias e subcategorias

### RN024 — Categorias personalizáveis

O usuário pode criar e renomear categorias de Receita e Despesa. O tipo é definido na criação e não pode ser alterado posteriormente.

**Status:** APROVADO.

### RN025 — Subcategorias opcionais

O usuário poderá criar subcategorias vinculadas a categorias, sem obrigatoriedade de uso.

**Status:** APROVADO.

### RN026 — Desativação de categorias

Categorias usadas ou não podem ser desativadas, mas nunca excluídas fisicamente. A desativação preserva a classificação histórica e impede o uso em novos lançamentos, conforme RN040.

**Status:** APROVADO; exclusão física de categorias: FORA DO MVP.

### RN027 — Investimentos sem categorias

Destinações para investimento não usam categorias personalizáveis; cada registro contém somente valor e data, e o Dashboard apresenta o total agregado do período.

**Status:** APROVADO.

## 9. Edição, cancelamento e auditoria

### RN028 — Edição de qualquer lançamento

O usuário pode editar qualquer lançamento a qualquer momento, independentemente do status (Pendente, Pago ou Recebido). Pode alterar valor, descrição, categoria e data, conforme os campos aplicáveis. Alterar a data pode mudar o período ao qual o lançamento pertence.

**Status:** APROVADO.

### RN029 — Cancelamento de qualquer lançamento

O usuário pode cancelar qualquer lançamento a qualquer momento, independentemente do status. Lançamentos cancelados deixam de participar da sobra, mas permanecem no histórico como cancelados. Não apagar fisicamente o registro.

**Status:** APROVADO.

### RN030 — Recalcular períodos afetados

Após editar ou cancelar um lançamento, o sistema recalcula a sobra dos períodos afetados. Alterações não devem gerar uma segunda contabilização. O histórico deve registrar os valores anteriores e novos, operação, usuário e data/hora.

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

Alertas do MVP serão enviados a dispositivos móveis Android e iOS, mediante permissão. Não haverá notificações por e-mail ou navegador.

**Status:** APROVADO.

## 12. Matriz resumida

| ID | Regra | Status |
|---|---|---|
| RN001–RN004 | Modalidades, configuração e competência dos períodos | APROVADO |
| RN005–RN007 | Fórmula da sobra, ausência de saldo inicial especial e receitas | APROVADO |
| RN008–RN012 | Receitas avulsas e recorrentes | APROVADO |
| RN013–RN018 | Despesas, pagamento, virada de período e alertas | APROVADO |
| RN019–RN020 | Fatura variável e exclusões de cartão | APROVADO/FORA DO ESCOPO |
| RN021–RN023 | Investimentos simplificados e rendimentos | APROVADO |
| RN024–RN027, RN040, RN044 | Categorias e subcategorias; associação opcional e grupo “Sem categoria” | APROVADO |
| RN028–RN030 | Edição, cancelamento, auditoria e recálculo | APROVADO |
| RN031–RN033 | Offline, paridade, idempotência e conflitos | APROVADO; detalhes de protocolo e retentativa são técnicos |
| RN034–RN035 | Segurança e notificações | APROVADO |

## 13. Detalhamentos pendentes

As regras funcionais consolidadas não estão pendentes. Antes das implementações correspondentes, definir tecnicamente: timezone, horário e calendário operacional de geração de recorrências; protocolo e retentativas de sincronização; mecanismo de backup, restauração, retenção, exportação e exclusão; e método/dispositivos representativos para validar as metas iniciais de desempenho. A continuidade dos alertas, os relatórios básicos e a regra de meses curtos estão aprovados.


## 14. Consolidação das regras — baseline v0.5

**Data:** 08/11/2026. As regras abaixo resolvem as pendências da auditoria v0.4 e prevalecem sobre status anteriores incompatíveis.

### RN036 — Intervalos de período

Todo período utiliza intervalo semiaberto `[data_inicio, data_fim)`: início inclusivo e fim exclusivo. A data igual ao fim exclusivo pertence ao próximo período. Períodos consecutivos não podem apresentar lacuna ou sobreposição.

**Status:** APROVADO.

### RN037 — Ciclos personalizados em meses curtos

O dia originalmente configurado deve ser preservado. Quando não existir no mês, usar o último dia disponível; no mês seguinte, retornar ao dia originalmente configurado quando existir. Exemplo para dia 31: `[31/01,28/02)`, `[28/02,31/03)`, `[31/03,30/04)`. Em ano bissexto, fevereiro usa 29 dias. As datas finais são exclusivas. Alteração da configuração só vale no próximo período; períodos históricos preservam sua configuração.

**Status:** APROVADO.

### RN038 — Geração idempotente de recorrências

Recorrências mensais mantêm o dia de referência original; se a data não existir, usar o último dia do mês sem alterar a referência dos meses seguintes. Recorrências por período geram uma ocorrência no início de cada período. Na abertura do aplicativo e durante a sincronização, verificar ocorrências faltantes e recuperar as atrasadas. A combinação modelo de recorrência + referência programada/competência identifica unicamente uma ocorrência e deve possuir garantia de unicidade no armazenamento. Edição individual não altera modelo nem ocorrências futuras; desativação impede novas ocorrências e preserva o histórico.

Receitas recorrentes são criadas pendentes e só entram na sobra após confirmação do recebimento. Despesas recorrentes entram na sobra quando geradas e com valor definido; pagamento não gera segunda dedução. Horário, timezone e calendário operacional da geração devem ser especificados tecnicamente antes da implementação.

**Status:** APROVADO quanto às regras funcionais; detalhamento de horário/timezone permanece técnico.

### RN039 — Pagamento integral

No MVP, despesa só pode ser paga integralmente. Não existe pagamento parcial, saldo remanescente ou histórico de parcelas de pagamento. Ao pagar, alterar status e registrar data efetiva; não deduzir novamente da sobra.

**Status:** APROVADO. Pagamentos parciais: FORA DO MVP.

### RN040 — Desativação de categorias

Categorias nunca são excluídas fisicamente. Categorias usadas ou não podem ser desativadas. Categorias desativadas não são oferecidas em novos lançamentos, mas continuam disponíveis para consulta histórica. Renomear uma categoria não altera retroativamente os lançamentos vinculados.

**Status:** APROVADO.

### RN041 — Continuidade de alertas

Emitir alerta três dias antes do vencimento, no dia do vencimento e diariamente após o vencimento enquanto a despesa estiver pendente. A regra continua válida mesmo após o fim do período de competência. Cessa quando a despesa é paga ou cancelada e respeita permissões do dispositivo.

**Status:** APROVADO.

### RN042 — Períodos sem encerramento manual

Não existe fechamento ou arquivamento manual de períodos no MVP. Períodos são determinados pelo calendário e configuração do usuário e permanecem consultáveis após seu término. Despesas pendentes permanecem no período original, sem transporte financeiro para períodos seguintes. O término do período não bloqueia edição ou cancelamento de lançamentos.

**Status:** APROVADO.

### RN043 — Metas iniciais de desempenho

Metas de engenharia: Dashboard com dados locais até 1 s; lista de lançamentos até 1 s; salvar localmente até 500 ms; atualizar cálculo da sobra até 300 ms; sincronizar lote pequeno em conexão normal até 5 s. São metas a validar por testes e medições, não garantias.

**Status:** APROVADO como metas iniciais, sujeito à validação.

### RN044 — Categoria opcional em receitas e despesas

O usuário pode registrar receitas e despesas sem categoria. Nos relatórios por categoria, esses lançamentos aparecem agrupados em **Sem categoria** e continuam incluídos nos totais gerais. Destinações para investimento não usam categorias.

**Status:** APROVADO — decisão do responsável pelo produto em 08/11/2026.

### 14.1 Resumo de status após v0.5

| Tema | Status |
|---|---|
| Limites de período | APROVADO |
| Meses curtos e anos bissextos | APROVADO |
| Geração e idempotência de recorrências | APROVADO funcionalmente |
| Horário/timezone de geração | DETALHAMENTO TÉCNICO PENDENTE |
| Pagamentos parciais | FORA DO MVP |
| Categorias | APROVADO |
| Alertas após fim do período | APROVADO |
| Encerramento manual de período | FORA DO MVP |
| Conflitos de sincronização | APROVADO: preservar versões, informar usuário e consolidar em nova versão |
| Segurança, backup, recuperação e CSV | APROVADO como requisito; desenho técnico detalhado |
| Obrigatoriedade de categoria | APROVADO: categoria opcional; sem classificação aparece em “Sem categoria” nos relatórios |
