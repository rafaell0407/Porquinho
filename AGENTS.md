# AGENTS.md — Manual de trabalho dos agentes do Porquinho

**Projeto:** Porquinho  
**Versão da documentação:** 0.5  
**Data de referência:** 08/11/2026  
**Idioma:** Português brasileiro

## 1. Identidade e responsabilidades

Atue como engenheiro de software responsável por apoiar o planejamento, desenvolvimento, manutenção, testes e documentação do Porquinho.

Suas responsabilidades incluem:

- Compreender a solicitação antes de alterar o projeto.
- Preservar as decisões aprovadas pelo responsável pelo produto.
- Identificar impactos funcionais, financeiros, arquiteturais e de dados.
- Propor soluções simples, seguras, testáveis e evolutivas.
- Implementar somente o escopo autorizado.
- Testar as alterações e comunicar limitações ou pendências.
- Manter código, testes e documentação consistentes.

O agente não tem autoridade para decidir regras financeiras em nome do responsável pelo produto.

## 2. Documentação obrigatória

Antes de iniciar uma tarefa, consulte os documentos aplicáveis. Em alterações que atravessem várias áreas, consulte os seis documentos:

| Documento | Responsabilidade | Pergunta que responde |
|---|---|---|
| `AGENTS.md` | Processo e padrões de trabalho | Como trabalhar? |
| `docs/requisitos.md` | Escopo e comportamento funcional | O que o aplicativo deve fazer? |
| `docs/arquitetura.md` | Organização técnica e integração | Como o sistema será construído? |
| `docs/banco_de_dados.md` | Entidades, persistência e integridade | Como os dados serão organizados? |
| `docs/regras_negocio.md` | Regras financeiras | Como cada operação afeta a sobra do período? |
| `docs/roadmap.md` | Fases, prioridades e dependências | Em qual ordem desenvolver? |

### 2.1 Fonte de verdade e conflitos

- `requisitos.md` é a referência do escopo funcional aprovado.
- `regras_negocio.md` é a referência do comportamento financeiro aprovado.
- `arquitetura.md` e `banco_de_dados.md` registram decisões técnicas aprovadas e propostas ainda não aprovadas.
- `roadmap.md` organiza a execução, mas não autoriza funcionalidades que não estejam aprovadas nos requisitos.
- Este arquivo orienta o processo de trabalho e não substitui os documentos de produto.

Se houver contradição entre documentos, código e nova solicitação:

1. Não escolha silenciosamente uma interpretação.
2. Identifique a divergência e os arquivos afetados.
3. Considere decisões explícitas mais recentes do responsável como candidatas a atualização da documentação.
4. Peça confirmação quando a mudança alterar uma regra financeira, o escopo ou uma decisão técnica aprovada.
5. Atualize os documentos antes ou junto da implementação autorizada.

Use os status **APROVADO**, **PROPOSTA**, **PENDENTE** e **FORA DO ESCOPO**. Nunca apresente uma proposta como decisão definitiva.

## 3. Fluxo obrigatório de desenvolvimento

Para cada solicitação:

1. **Analisar:** reformule o objetivo e identifique o resultado esperado.
2. **Consultar:** leia os documentos pertinentes e examine o código existente.
3. **Classificar:** identifique se a tarefa é correção, melhoria, funcionalidade, refatoração ou documentação.
4. **Avaliar impactos:** liste módulos, telas, regras, entidades, integrações, testes e documentos afetados.
5. **Planejar:** para tarefas relevantes, apresente plano conciso, riscos e critérios de aceitação.
6. **Aguardar autorização:** não implemente mudanças de escopo, decisões pendentes ou operações destrutivas sem aprovação.
7. **Implementar:** faça alterações pequenas e compatíveis com a arquitetura aprovada.
8. **Testar:** execute verificações adequadas ao tipo de alteração.
9. **Revisar:** examine diferenças, regressões, erros e efeitos sobre dados existentes.
10. **Documentar:** atualize os documentos impactados.
11. **Comunicar:** informe alterações, testes, resultados e pendências.

Não implemente regra financeira que esteja marcada como **PENDENTE**. Primeiro apresente a lacuna e solicite decisão.

## 4. Regras de produto que devem ser preservadas

### 4.1 Escopo simplificado do MVP

A navegação principal possui somente três áreas: **Dashboard**, **Lançamentos** e **Mais**.

O MVP não possui módulo de contas bancárias nem módulo de Porquinho virtual. Não implementar:

- Cadastro ou manutenção de contas bancárias.
- Saldos individuais, consolidação automática de saldos ou conciliação bancária.
- Campo ou entidade especial de saldo inicial por período.
- Reservas virtuais, compromissos separados ou cálculo de dinheiro livre.
- Carteira de investimentos, ativos, posições, rentabilidade ou categorias por classe de ativo.
- Compras individuais de cartão, parcelamentos, fechamento ou fatura calculada automaticamente.
- Cálculos automáticos de rendimento por taxa fixa ou CDI.

O nome do produto permanece Porquinho; isso não autoriza reintroduzir o antigo módulo Porquinho virtual.

### 4.2 Resultado financeiro

O único indicador de resultado financeiro do MVP é a **sobra do período**:

`Sobra do período = receitas contabilizadas - despesas contabilizadas - valores destinados a investimentos`.

Não criar indicador de saldo disponível, saldo atual, dinheiro livre ou saldo bancário.

Não existe campo especial de saldo inicial. O usuário pode criar uma categoria de receita chamada, por exemplo, **Saldo inicial**, e registrar um lançamento comum. O sistema não dá tratamento especial a essa categoria, não a reconhece automaticamente e não detecta eventual duplicidade.

### 4.3 Receitas

- Receitas avulsas são registradas depois de efetivamente recebidas.
- A data efetiva de recebimento determina o período da receita.
- Receitas recorrentes geram ocorrências pendentes; só entram no cálculo após confirmação do recebimento.
- O usuário pode editar o valor da ocorrência recorrente antes ou depois da confirmação, sem alterar o modelo da recorrência nem outras ocorrências.
- Qualquer lançamento pode ser editado ou cancelado a qualquer momento, independentemente do status. Preservar histórico e recalcular períodos afetados.

### 4.4 Despesas

- Despesas avulsas entram no cálculo da sobra quando cadastradas.
- Despesas recorrentes entram no cálculo quando a ocorrência é gerada e, quando variável, depois de informado o valor.
- O pagamento altera o status e registra a data, mas não gera uma segunda dedução.
- Despesas não pagas permanecem no período original como pendentes e não são transportadas financeiramente para o período seguinte.
- Qualquer lançamento pode ser editado ou cancelado a qualquer momento, independentemente do status. Preservar histórico e recalcular o período correspondente.

### 4.5 Investimentos

- O MVP permite apenas registrar valores totais destinados a investimentos.
- Cada lançamento registra somente o valor e a data. O aplicativo apresenta um único total destinado a investimentos no período, sem descrição obrigatória, categorias por ativo, classe ou instituição.
- O valor é deduzido da sobra no momento do lançamento.
- Não existe status pendente/pago para destinação de investimento.
- O aplicativo não acompanha ativos, posições, saldo investido acumulado ou rentabilidade.
- Rendimentos efetivamente recebidos, quando informados, são receitas comuns. Não há cálculo automático.

### 4.6 Cartão de crédito

A fatura pode ser registrada como uma despesa recorrente variável, por exemplo, “Fatura do cartão”. Não existe módulo próprio de cartão nem registro de compras ou parcelas.

### 4.7 Períodos

- O usuário escolhe mês-calendário ou ciclo personalizado.
- No ciclo personalizado, o usuário define o dia inicial; exemplo: dia 20 até dia 19 do mês seguinte.
- Alterações de modalidade ou dia inicial passam a valer somente no próximo período.
- Períodos históricos preservam a configuração usada na sua criação.
- Não pode haver sobreposição nem lacuna entre períodos consecutivos.
- O ciclo personalizado preserva o dia originalmente configurado; em meses curtos usa o último dia disponível e retorna ao dia original no mês seguinte quando possível. Aplicar intervalos [início, fim).

### 4.8 Categorias

- O usuário pode criar, renomear e desativar categorias de receitas e despesas.
- O tipo da categoria (receita ou despesa) não muda após sua criação.
- Subcategorias são opcionais.
- Categorias nunca são apagadas fisicamente; usadas ou não podem ser desativadas. Categorias inativas não aparecem em novos lançamentos e permanecem no histórico.
- Investimentos não usam categorias de ativos; são registrados como valor total destinado.

### 4.9 Edição, cancelamento e auditoria

O usuário pode editar ou cancelar qualquer lançamento, mesmo pago ou recebido. Lançamentos cancelados deixam de participar dos cálculos, mas não são apagados fisicamente. Registrar valores anteriores e novos, operação, data/hora e usuário. Após edição, cancelamento ou alteração de data, recalcular os períodos afetados.

## 5. Padrões de programação

### 5.1 Organização e nomenclatura

- Utilize Dart e Flutter para o aplicativo.
- Separe apresentação, aplicação, domínio e infraestrutura conforme arquitetura aprovada.
- Mantenha regras financeiras fora dos widgets e componentes visuais.
- Evite abstrações prematuras, duplicação e dependências sem necessidade demonstrada.
- Use português brasileiro na interface e documentação para usuários; nomes técnicos podem seguir convenções do ecossistema.

### 5.2 Valores financeiros e datas

- Nunca utilize ponto flutuante binário como representação persistente de dinheiro.
- Não invente critérios de arredondamento, juros, impostos ou convenções de datas.
- Centralize a fórmula da sobra e as regras de competência em componentes de domínio testáveis.
- Receita é atribuída pela data efetiva de recebimento; despesa, pela data de cadastro/geração; investimento, pela data do lançamento.
- A data do pagamento da despesa não altera o período em que ela foi contabilizada.
- A implementação local e a validação remota devem produzir resultados equivalentes para os mesmos dados e condições. Não é obrigatório compartilhar o mesmo código.
- Divergências entre cliente e servidor devem ser identificadas, sem sobrescrita ou correção silenciosa.
- Consulte `docs/regras_negocio.md` antes de alterar cálculos.

## 6. Arquitetura, segurança e dependências

- Flutter, Dart, Git, Supabase, PostgreSQL, SQLite com Drift, Riverpod, GoRouter, Supabase Auth e serviço próprio de sincronização em Dart estão aprovados conforme a baseline v0.5 da seção 10.4.
- Plataformas do MVP: Android, iOS e Web.
- Ambientes, organização concreta de módulos, migrations, RLS, armazenamento seguro, observabilidade, timezone e compatibilidade multiplataforma são detalhamentos técnicos pendentes; não reabrem a stack aprovada.
- Dados financeiros devem ser isolados por usuário e protegidos local e remotamente.
- Não armazene senhas, tokens ou segredos no repositório.
- Antes de adicionar dependência, avalie manutenção, compatibilidade, licença, segurança, custo e impacto operacional.

## 7. Banco de dados e sincronização

- O modelo conceitual deve refletir somente as funcionalidades do MVP simplificado.
- Não criar entidades de conta bancária, saldo inicial especial, Porquinho virtual, reserva, cartão/compra/parcela, carteira de ativos ou cálculo automático de rendimento.
- Utilize migrations versionadas somente depois de backend e banco aprovados.
- Use transações para operações relacionadas e identificadores idempotentes para sincronização.
- O uso offline é essencial e deve ser construído incrementalmente desde os primeiros módulos financeiros.
- Armazene localmente antes de informar que um lançamento foi salvo no dispositivo.
- Sincronização repetida não pode duplicar operações.
- Conflitos são detectados por controle de versão; preservar versões conflitantes, informar o usuário e registrar resolução em nova versão consolidada. Não adotar silenciosamente “última gravação vence”.

## 8. Testes e qualidade

Antes de considerar uma tarefa concluída, execute conforme aplicável:

- Formatação e análise estática.
- Testes unitários das regras da sobra e da competência.
- Testes de edição, cancelamento, recorrências e mudanças de período.
- Testes de equivalência dos cálculos locais e remotos.
- Testes de sincronização idempotente, falhas e conflitos.
- Testes de autorização e isolamento por usuário.
- Testes de interface e regressão nas plataformas suportadas.

Não declarar testes executados se não foram executados. Informe limitações e pendências.

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


## 10. Baseline documental 0.5 — decisões consolidadas

**Versão:** 0.5  
**Data:** 08/11/2026  
**Status:** decisões funcionais e stack principal aprovadas.

Esta seção prevalece sobre qualquer trecho anterior deste arquivo que ainda classifique as decisões abaixo como pendentes ou propostas. Os seis documentos devem ser interpretados em conjunto; em caso de divergência residual, prevalece a regra mais específica de `regras_negocio.md` para comportamento financeiro e `requisitos.md` para escopo.

### 10.1 Períodos e datas

- Todos os períodos usam intervalo semiaberto `[data_inicio, data_fim)`: início inclusivo e fim exclusivo.
- A data exatamente igual ao fim exclusivo pertence ao período seguinte. Períodos consecutivos não podem ter lacunas nem sobreposições.
- Para ciclo personalizado, preservar o dia inicial originalmente configurado. Se esse dia não existir no mês, usar o último dia daquele mês; no mês seguinte, voltar ao dia originalmente configurado quando existir.
- Exemplo de ciclo iniciado no dia 31: `[31/01, 28/02)`, `[28/02, 31/03)`, `[31/03, 30/04)`. As datas finais são exclusivas. Em ano bissexto, fevereiro termina em 29/02; a mesma regra se aplica.
- Mudanças na configuração passam a valer no próximo período. Períodos históricos preservam a configuração que os originou.

### 10.2 Recorrências

- Frequências do MVP: mensal e por período de apuração.
- Recorrência mensal preserva o dia de referência original; quando inexistente, agenda no último dia do mês, sem alterar a referência dos meses seguintes.
- Recorrência por período gera uma ocorrência por período, no início desse período.
- A geração deve ser idempotente. A chave lógica única é modelo de recorrência + referência programada/competência; a unicidade também deve ser garantida no armazenamento.
- Ao abrir o aplicativo e ao sincronizar, verificar e recuperar ocorrências vencidas que ainda não foram geradas, sem duplicá-las.
- Edição de ocorrência não altera modelo nem outras ocorrências. Desativação impede ocorrências futuras e preserva o histórico.
- Receitas recorrentes nascem pendentes e só entram na sobra após confirmação do recebimento. Despesas recorrentes entram na sobra quando geradas e com valor definido; pagamento posterior não deduz novamente.
- Horário, timezone e calendário operacional da geração são detalhamento técnico obrigatório antes da implementação da rotina; não presumir UTC ou horário local sem decisão registrada.

### 10.3 Outras regras aprovadas

- Pagamentos parciais estão **FORA DO MVP**. Despesas são pagas integralmente ou permanecem pendentes; não há saldo parcial.
- Categorias não são excluídas fisicamente. Categorias usadas ou não podem ser desativadas; categorias inativas não aparecem em novos lançamentos e permanecem nos históricos. Renomear não reclassifica retroativamente os lançamentos.
- Categorias são opcionais em receitas e despesas. Nos relatórios por categoria, lançamentos sem classificação aparecem agrupados em **Sem categoria** e continuam incluídos nos totais gerais. Investimentos permanecem sem categoria.
- Alertas de despesa: três dias antes, no vencimento e diariamente após o vencimento enquanto pendente, inclusive depois do fim do período. Cessam ao pagar ou cancelar, respeitadas as permissões do dispositivo.
- Não existe encerramento ou arquivamento manual de período no MVP. Períodos históricos permanecem consultáveis; despesas pendentes ficam no período de origem; não há transporte financeiro nem bloqueio de edição.

### 10.4 Stack aprovada

- Flutter/Dart; Supabase; PostgreSQL; SQLite com Drift; Riverpod; GoRouter; Supabase Auth; serviço próprio de sincronização em Dart; Git.
- A aprovação da stack não substitui o detalhamento de ambientes, RLS, migrations, módulos, armazenamento seguro, timezone, observabilidade e compatibilidade de cada mecanismo entre Android, iOS e Web.

### 10.5 Sincronização, proteção e portabilidade

- Cada registro/alteração sincronizável deve possuir versão. O servidor detecta escrita concorrente com base na versão esperada.
- Não usar “última gravação vence” silencioso. Preservar as versões conflitantes, informar o usuário e registrar a resolução como nova versão consolidada. Operações independentes continuam sincronizando. Reenvios são idempotentes.
- Proteger banco local com criptografia; armazenar chaves e tokens em armazenamento seguro apropriado à plataforma; nunca persistir senha em texto puro. Bloqueio por PIN/biometria é opcional em dispositivos móveis.
- Logout não pode descartar operações ainda não sincronizadas. Definir fluxo explícito para sincronização, exportação ou decisão do usuário antes de limpar dados locais.
- Backup remoto diário, retenção de 30 dias e procedimento documentado de recuperação. Prever exclusão definitiva e exportação CSV. Backups antigos devem respeitar a política de retenção e não podem reintroduzir dados após exclusão definitiva.

### 10.6 Metas iniciais de desempenho

| Operação | Meta inicial |
|---|---:|
| Dashboard com dados locais | até 1 s |
| Lista de lançamentos | até 1 s |
| Salvar lançamento local | até 500 ms |
| Atualizar cálculo da sobra | até 300 ms |
| Sincronizar lote pequeno em conexão normal | até 5 s |

São metas mensuráveis, não garantias; devem ser validadas em dispositivos e condições representativos.

### 10.7 Relatórios básicos aprovados

1. Receitas por categoria e período.
2. Despesas por categoria e período.
3. Total destinado a investimentos por período.
4. Evolução da sobra entre períodos.
5. Comparativo de receitas, despesas e investimentos por período.

Não incluir rentabilidade, projeções, saldos bancários, dinheiro livre ou gestão de carteira.

### 10.8 Critério de atualização

Quando uma regra desta baseline for alterada, atualizar simultaneamente todos os documentos afetados, registrar a decisão e sua data e solicitar validação antes de implementar mudança financeira ou de escopo.
