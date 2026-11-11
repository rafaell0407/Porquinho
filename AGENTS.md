# AGENTS.md — Manual de trabalho dos agentes do Porquinho

**Projeto:** Porquinho  
**Versão da documentação:** 0.5  
**Data de referência:** 08/11/2026  
**Idioma:** Português brasileiro

## Eficiência e consumo de tokens

1. Leia somente os arquivos necessários para cada tarefa.
2. Não releia documentações já analisadas, salvo necessidade.
3. Não faça análises gerais do projeto em tarefas pontuais.
4. Não repita verificações já aprovadas sem justificativa.
5. Faça alterações incrementais, evitando reescrever arquivos.
6. Execute apenas testes relacionados às alterações.
7. Não apresente explicações extensas durante a implementação.
8. Não gere relatórios intermediários desnecessários.
9. Não utilize subagentes sem benefício concreto.
10. Preserve as decisões arquiteturais já aprovadas.
11. Se encontrar um problema fora do escopo, registre-o
    sem tentar resolvê-lo automaticamente.
12. Ao concluir, apresente um resumo objetivo:
    - Arquivos modificados.
    - Funcionalidades implementadas.
    - Testes executados.
    - Problemas encontrados.

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

## 1.1 Comunicação das entregas

As comunicações devem utilizar português brasileiro, linguagem simples e foco no comportamento do aplicativo, permitindo que o responsável pelo produto compreenda e valide as implementações sem precisar conhecer programação.

Regras:

1. Explique o que mudou e como isso afeta o usuário, evitando detalhes técnicos desnecessários.
2. Utilize `docs/requisitos.md` e `docs/regras_negocio.md` como referência para descrever os resultados.
3. Identifique os RFs e RNs atendidos quando aplicável.
4. Diferencie claramente o que foi implementado, testado e o que ainda está pendente.
5. Apresente problemas indicando seu impacto e se exigem alguma decisão do responsável.
6. Só apresente detalhes de código, arquitetura, comandos ou logs quando forem necessários ou solicitados.
7. Não repita informações já registradas na documentação ou em mensagens anteriores, salvo quando necessário para compreensão.
8. Seja objetivo: prefira frases curtas e informações essenciais. Não gere relatórios extensos ou explicações repetitivas.

### Formato de conclusão

Apresente somente os itens pertinentes à entrega:

- **Implementado:** o que foi feito e seu resultado no aplicativo.
- **Requisitos:** RFs/RNs atendidos.
- **Testes:** resultado das verificações executadas.
- **Pendências:** o que falta ou precisa de validação.

Não inclua itens sem informação relevante. A comunicação deve ser suficiente para permitir a validação da entrega com o menor consumo possível de tokens.

## 2. Documentação obrigatória

| Documento | Responsabilidade | Pergunta que responde |
|---|---|---|
| `AGENTS.md` | Processo e padrões de trabalho | Como trabalhar? |
| `docs/requisitos.md` | Escopo e comportamento funcional | O que o aplicativo deve fazer? |
| `docs/arquitetura.md` | Organização técnica e integração | Como o sistema será construído? |
| `docs/banco_de_dados.md` | Entidades, persistência e integridade | Como os dados serão organizados? |
| `docs/regras_negocio.md` | Regras financeiras | Como cada operação afeta o dinheiro livre do período? |
| `docs/roadmap.md` | Fases, prioridades e dependências | Em qual ordem desenvolver? |
| `docs/estado_atual.md` | Fase, última entrega, pendências e decisões abertas | Onde o projeto está agora? |
| `docs/historico/decisoes.md` | Arquivo de entregas, revisões e textos superados (somente consulta) | O que já foi feito ou substituído? |

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
- Reservas virtuais, compromissos separados ou qualquer cálculo de "dinheiro livre" além da fórmula do §4.2 (o nome "dinheiro livre do período" é o do indicador `receitas − despesas − investimentos`, decisão de 11/11/2026).
- Carteira de investimentos, ativos, posições, rentabilidade ou categorias por classe de ativo.
- Compras individuais de cartão, parcelamentos, fechamento ou fatura calculada automaticamente.
- Cálculos automáticos de rendimento por taxa fixa ou CDI.

O nome do produto permanece Porquinho; isso não autoriza reintroduzir o antigo módulo Porquinho virtual.

### 4.2 Resultado financeiro

O único indicador de resultado financeiro do MVP é a **dinheiro livre do período**:

`Dinheiro livre do período = receitas contabilizadas - despesas contabilizadas - valores destinados a investimentos`.

Não criar indicador de saldo disponível, saldo atual ou saldo bancário. "Dinheiro livre do período" é somente o nome do indicador único acima: não considera sobras de períodos anteriores, reservas, compromissos separados nem saldo bancário.

Não existe campo especial de saldo inicial. O usuário pode criar uma categoria de receita chamada, por exemplo, **Saldo inicial**, e registrar um lançamento comum. O sistema não dá tratamento especial a essa categoria, não a reconhece automaticamente e não detecta eventual duplicidade.

### 4.3 Receitas

- Receitas avulsas aceitam data de recebimento passada ou futura, informada pelo usuário (RN008, decisão de 10/11/2026).
- A data de recebimento determina o período da receita.
- Receitas recorrentes geram ocorrências pendentes; só entram no cálculo após confirmação do recebimento.
- O usuário pode editar o valor da ocorrência recorrente antes ou depois da confirmação, sem alterar o modelo da recorrência nem outras ocorrências.
- Qualquer lançamento pode ser editado ou cancelado a qualquer momento, independentemente do status. Preservar histórico e recalcular períodos afetados.

### 4.4 Despesas

- Despesas avulsas entram no cálculo do dinheiro livre quando cadastradas.
- Despesas recorrentes entram no cálculo quando a ocorrência é gerada e, quando variável, depois de informado o valor.
- O pagamento altera o status e registra a data, mas não gera uma segunda dedução.
- Despesas não pagas permanecem no período original como pendentes e não são transportadas financeiramente para o período seguinte.
- Qualquer lançamento pode ser editado ou cancelado a qualquer momento, independentemente do status. Preservar histórico e recalcular o período correspondente.

### 4.5 Investimentos

- O MVP permite apenas registrar valores totais destinados a investimentos.
- Cada lançamento registra somente o valor e a data (informada pelo usuário, passada ou futura), sem descrição, categorias por ativo, classe ou instituição. O total por período vem no relatório da Fase 7; o Dashboard não o exibe no MVP.
- Investimento pode ser recorrente (todo mês ou todo período), com valor fixo e valor alterável por ocorrência; a ocorrência gerada entra no dinheiro livre sem confirmação. Não existe resgate: desfazer é cancelar o lançamento.
- O valor é deduzido do dinheiro livre no momento do lançamento.
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
- Centralize a fórmula do dinheiro livre e as regras de competência em componentes de domínio testáveis.
- Receita é atribuída pela data efetiva de recebimento; despesa, pela data de cadastro/geração; investimento, pela data do lançamento.
- A data do pagamento da despesa não altera o período em que ela foi contabilizada.
- A implementação local e a validação remota devem produzir resultados equivalentes para os mesmos dados e condições. Não é obrigatório compartilhar o mesmo código.
- Divergências entre cliente e servidor devem ser identificadas, sem sobrescrita ou correção silenciosa.
- Consulte `docs/regras_negocio.md` antes de alterar cálculos.

## 6. Arquitetura, segurança e dependências

- Flutter, Dart, Git, Supabase, PostgreSQL, SQLite com Drift, Riverpod, GoRouter, Supabase Auth e serviço próprio de sincronização em Dart estão aprovados conforme a baseline v0.5 (`docs/arquitetura.md` §2.1).
- Plataformas do MVP: Android e Web (iOS fora do MVP — decisão de 10/11/2026).
- Ambientes, RLS, armazenamento seguro, observabilidade e compatibilidade multiplataforma são detalhamentos técnicos pendentes; organização dos módulos e zona IANA por usuário estão definidas na Fase 2.
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
- Testes unitários das regras do dinheiro livre e da competência.
- Testes de edição, cancelamento, recorrências e mudanças de período.
- Testes de equivalência dos cálculos locais e remotos.
- Testes de sincronização idempotente, falhas e conflitos.
- Testes de autorização e isolamento por usuário.
- Testes de interface e regressão nas plataformas suportadas.

Não declarar testes executados se não foram executados. Informe limitações e pendências.

## 9. Histórico de decisões

O histórico de decisões e revisões (incluindo a versão 0.4) está em `docs/historico/decisoes.md`. O estado de execução está em `docs/estado_atual.md`.

## 10. Baseline documental 0.5 — onde está cada decisão

**Versão:** 0.5
**Data:** 08/11/2026
**Status:** decisões funcionais e stack principal aprovadas.

Esta seção prevalece sobre qualquer trecho anterior deste arquivo que ainda classifique as decisões abaixo como pendentes ou propostas. Os documentos devem ser interpretados em conjunto; em caso de divergência residual, prevalece a regra mais específica de `regras_negocio.md` para comportamento financeiro e `requisitos.md` para escopo. Cada decisão tem um único local canônico:

| Tema | Local canônico |
|---|---|
| Períodos, datas, ciclo personalizado e mudança de configuração (aprovada em 09/11/2026) | `regras_negocio.md` RN001–RN004, RN036–RN037, RN042 |
| Recorrências, zona `America/Sao_Paulo` (08/11/2026) e geração ao abrir/sincronizar | RN010–RN011, RN014, RN038 |
| Pagamento integral, alertas, categorias, moeda BRL em centavos (08/11/2026) | RN015/RN039, RN018/RN041, RN040/RN044, RN045 |
| Metas iniciais de desempenho | RN043 |
| Relatórios básicos | `requisitos.md` §13.7 |
| Stack aprovada | `arquitetura.md` §2.1 |
| Sincronização, proteção local, logout, backup, CSV e portabilidade | `arquitetura.md` §16 |

### 10.8 Critério de atualização

Quando uma regra desta baseline for alterada, atualizar simultaneamente todos os documentos afetados, registrar a decisão e sua data e solicitar validação antes de implementar mudança financeira ou de escopo.
