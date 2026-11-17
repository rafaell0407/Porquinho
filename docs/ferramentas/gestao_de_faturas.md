# Gestão de Faturas de Cartões — especificação

**Status:** decisões de produto APROVADAS pelo responsável na discussão de 16/11/2026, incluindo os pontos abertos (§15). Momento definido: **antes da publicação da Fase 8**. GF0.1 validada e GF0.2–GF6.2 autorizadas em sequência (16/11/2026), com validação de tudo no fim: **implementadas em 16/11/2026, aguardando validação** (decisões técnicas do agente para confirmar em `pendencias.md` F7). GF6.3 (homologação) só com autorização. Requisito: RF029. Acompanhamento: `pendencias.md` F6.

## 1. Para que serve
Responder: **"do dinheiro que separei para pagar os cartões, quanto já está comprometido com faturas e quanto sobra?"**. O usuário informa quanto tem reservado e cadastra só o que quiser (cartões, compras parceladas, assinaturas ou apenas o total de uma fatura). A ferramenta não burocratiza: ninguém é obrigado a lançar cada compra.

## 2. Escopo e exceções aprovadas
- Ferramenta **totalmente separada e opcional**, aberta pela aba Ferramentas. **Não cria lançamentos, não muda o dinheiro livre, os relatórios nem as recorrências.** A fatura continua sendo lançada nos Lançamentos como despesa recorrente variável (RN019), se o usuário quiser; a ferramenta não conversa com ela.
- **Exceções aprovadas em 16/11/2026, válidas somente dentro desta ferramenta:**
  - `requisitos.md` §3.2 e `regras_negocio.md` princípio 4 — reserva, compromissos e um indicador de "saldo" próprio da ferramenta.
  - RN020 — cadastro de cartões, compras, parcelas, fechamento e fatura calculada a partir de compras.
  - RN029/RN030 — compras, assinaturas e cartões são **apagados de verdade**; edição não guarda versões antigas (histórico simples, §10).
  - RN033 — "última gravação vence" nos cadastros (cartão, compra, assinatura, valor informado, datas da fatura); pagamentos e ajustes da reserva são eventos que se somam (§12).
  - `arquitetura.md` — primeira ferramenta que grava dados (banco do servidor, banco local e sincronização próprios).
- Fora desta ferramenta: limite do cartão, bandeira, banco, juros do rotativo, pagamento parcial ou por item, origem mista escolhida pelo usuário, crédito/estorno levado para a fatura seguinte, alertas de vencimento, integração com Lançamentos.

## 3. Indicador
- **Dinheiro reservado:** valor informado pelo usuário (§9). Nunca negativo.
- **Comprometido:** soma do valor de todas as faturas **pendentes** de todos os cartões (§5.3).
- **Saldo não comprometido = Dinheiro reservado − Comprometido.**
- Negativo: em vez do número, a tela mostra **"Faltam R$ X para cobrir as faturas"** (X = Comprometido − Reservado).
- Informativo, fora do cálculo: **"Assinaturas ativas: R$ X por mês"** (soma do preço atual das assinaturas ativas).
- O nome usa "saldo" por decisão do responsável (16/11/2026), como exceção só desta ferramenta; não é saldo bancário nem se relaciona com o dinheiro livre.

## 4. Cartões
| Campo | Regra |
|---|---|
| Nome | obrigatório, texto livre |
| Dia de fechamento | inteiro de 1 a 31 |
| Dia de vencimento | inteiro de 1 a 31 |

- "Dia D do mês" em mês sem esse dia = **último dia do mês**, sem considerar dia útil (mesma regra da calculadora à vista ou parcelado; **não** é a regra RN038 dos lançamentos). Ex.: fecha 31 → 30/04; 28/02/2027.
- O vencimento cai no **mesmo mês do fechamento** se o dia de vencimento for maior que o de fechamento; senão, no **mês seguinte** (ex.: fecha 28, vence 5 → vence no mês seguinte). Fechamento e vencimento no mesmo dia: **aceito**, vence no mês seguinte.
- Mudar o dia de fechamento ou vencimento no cartão só altera as **datas** das **faturas pendentes que ainda não fecharam**, preservando as que tiveram as datas corrigidas à mão (§5.1). Faturas fechadas e pagas não mudam. **Parcelas e cobranças já distribuídas não mudam de fatura** (continuam nos mesmos meses).
- **Apagar o cartão:** apaga compras, assinaturas e faturas pendentes dele, com aviso do valor que deixa de contar. Faturas pagas ficam no histórico (§10).

## 5. Faturas
### 5.1 Datas e ciclo
- Cada fatura pertence a um cartão e guarda o **próprio fechamento (F) e vencimento**, copiados do cartão ao ser criada; o usuário pode corrigir as datas de uma fatura específica (o banco muda o fechamento por fim de semana ou feriado). Vencimento antes do fechamento ou no mesmo dia é **recusado** ("O vencimento precisa ser depois do fechamento"). Corrigir as datas **não move compras já cadastradas**; vale para compras novas (o usuário troca a fatura de uma compra ao editá-la).
- Ciclo da fatura: **[fechamento anterior, F)**. Compra feita **antes** do dia de fechamento entra na fatura atual; **no dia do fechamento ou depois**, na seguinte.
- **Fatura atual** de um cartão (decisão do responsável, 16/11/2026): a mais antiga **fechada e não paga** que tenha itens ou valor informado; sem nenhuma, aquela cujo ciclo contém hoje (fuso `America/Sao_Paulo`). Vale para o painel e para o "Primeira cobrança" da assinatura. A geração das cobranças continua por ciclo (uma por fatura até a do ciclo de hoje) e a compra nova continua indo para a fatura do ciclo (§5.1).
- **Fatura fechada:** hoje ≥ F. **Vencida:** pendente e hoje > vencimento.

### 5.2 Quais aparecem
- Sempre a **fatura atual e a seguinte** de cada cartão, mesmo vazias (para permitir informar o valor sem cadastrar compras). Vazia vale R$ 0,00.
- Faturas mais distantes, **só quando tiverem parcelas ou valor informado**.
- Faturas **fechadas e não pagas** continuam aparecendo; vencidas com destaque ("venceu em dd/mm"). Fatura de R$ 0,00 sem itens nem valor informado não fica marcada como vencida e sai da lista quando deixa de ser a atual ou a seguinte.
- Faturas **pagas** ficam recolhidas na seção "Pagas".

### 5.3 Valor da fatura (modelo único, sem modos)
- **Itens:** parcelas (§6) e cobranças de assinaturas (§7), gerados automaticamente.
- **Valor informado:** opcional, digitado pelo usuário.
- **Valor da fatura** = valor informado, se existir; senão, a soma dos itens. **Nunca soma os dois** (sem duplicidade).
- Com valor informado, os itens viram detalhe: "R$ 1.200,00 informados, dos quais R$ 450,00 em parcelas e assinaturas e R$ 750,00 em outros gastos".
- Valor informado **menor** que a soma dos itens: aviso; prevalece o valor do usuário.
- "Trocar de modo" = preencher ou apagar o valor informado. Nada é perdido.
- Compromisso da fatura: pendente → valor da fatura; paga → 0.

## 6. Compras parceladas
| Campo | Regra |
|---|---|
| Descrição | obrigatória |
| Cartão | obrigatório |
| Data da compra | padrão hoje, editável; **data futura recusada** |
| Valor | "Valor total" (padrão) ou "Valor da parcela"; maior que zero; até R$ 1.000.000,00 |
| Número de parcelas | inteiro de 1 a 24; 1 = compra à vista no cartão |
| Fatura da 1ª parcela | automática pela regra §5.1; a tela mostra "1ª parcela na fatura que vence em dd/mm/aaaa" e permite trocar para a anterior ou a seguinte |

- **Divisão:** parcela = total ÷ n (parte inteira, em centavos); o resto vai para a **1ª parcela**. Modo "Valor da parcela": total = parcela × n.
- Parcela k entra na fatura do mês da 1ª + (k − 1) meses, no mesmo cartão.
- **Total da compra = soma das parcelas** (não há total guardado à parte).
- **Editar uma parcela:** muda só ela. **Editar "esta e as próximas":** muda as parcelas pendentes dali em diante.
- **Editar a compra inteira** (valor, nº de parcelas, cartão, data, 1ª fatura): recalcula **só as parcelas de faturas pendentes**; as de faturas pagas ficam. Se houver parcelas editadas à mão, avisar que esses ajustes serão refeitos.
- **Mudar o nº de parcelas com algumas já pagas** (ex.: 3 de 10 pagas → 8): as pagas ficam; o valor restante (novo total − soma das pagas) é dividido nas parcelas restantes (8 − 3 = 5), resto na primeira delas. Não aceita nº de parcelas menor ou igual ao de pagas.
- **Cancelar/apagar a compra:** apaga a compra e as parcelas pendentes. As de faturas pagas permanecem só como texto no histórico da fatura (§10).
- **Compra antiga** (parcelas que cairiam em faturas **já vencidas**): essas parcelas são tratadas como "pagas fora da ferramenta" — não criam faturas vencidas nem mexem na reserva; o aviso mostra quantas foram consideradas pagas. Fatura **fechada e ainda não vencida** recebe a parcela normalmente.
- **Fatura já paga:** se a 1ª parcela cairia numa fatura já paga, o app avisa e a lança na **próxima fatura pendente**; as parcelas seguintes andam junto.

## 7. Assinaturas (cobranças recorrentes no cartão)
| Campo | Regra |
|---|---|
| Descrição | obrigatória |
| Cartão | obrigatório |
| Valor mensal | maior que zero |
| Início | fatura da primeira cobrança (padrão: a atual) |

- Uma assinatura ativa gera **uma cobrança por fatura**, mas só entra na **fatura mais antiga que ainda não venceu** (hoje ≤ vencimento), nunca projetada nas seguintes (decisão do responsável, 16/11/2026). Fatura fechada e ainda não vencida continua recebendo; só depois do vencimento a cobrança entra na fatura seguinte. A cobrança já gerada fica na fatura anterior, como histórico.
- A cobrança, uma vez gerada, é um **item próprio da fatura**: pode ter o valor editado ou ser removida só naquela fatura.
- **Mudança de preço:** vale para a fatura atual pendente e as próximas. Faturas fechadas ou pagas mantêm o valor antigo; a cobrança pode ser editada à mão.
- **Cancelamento:** apaga a assinatura e vale **a partir da fatura seguinte**; a cobrança já gerada na fatura atual continua, e o app pergunta "Remover também a cobrança da fatura atual?".
- **Início futuro:** a cobrança aparece quando a fatura de início passa a ser a que recebe cobranças (regra acima); a assinatura só entra em "Assinaturas ativas" a partir daí.
- **App fechado por um ou mais ciclos:** ao abrir, o app inclui a cobrança nas faturas **não pagas** que ficaram sem ela desde o início da assinatura. Cobrança **removida à mão não reaparece** (a cobrança fica marcada como removida naquela fatura — é o estado atual do item, não histórico).
- Identificador da cobrança determinístico (assinatura + fatura), para nunca gerar duas no mesmo ciclo, inclusive em dois aparelhos.

## 8. Pagamento
- Só se paga a **fatura inteira** ("Pagar fatura"). Não há pagamento parcial nem por item. Estados: **pendente** ou **paga**.
- O usuário confirma:
  - **Valor pago:** preenchido com o valor da fatura, editável, zero ou mais (R$ 0,00 = "sem valor a pagar", tira a fatura da lista), até R$ 1.000.000,00. Menor que o previsto: aviso "R$ X deixarão de contar. Se ficarem para a próxima fatura, informe lá."
  - **Data:** hoje, editável.
  - **Origem:** "Dinheiro reservado" ou "Outras fontes".
- Ao confirmar:
  - O valor pago passa a ser o **valor definitivo** da fatura e o compromisso dela vai a zero.
  - **Dinheiro reservado:** a reserva diminui o valor pago.
  - **Outras fontes:** a reserva não muda.
  - A previsão fica registrada ao lado: "previsto R$ 1.200,00 · pago R$ 1.237,50".
- **Valor pago maior que a reserva** (origem reserva): aviso "a reserva tem R$ X; o pagamento vai deixá-la em R$ 0,00"; ao confirmar, a reserva vai a zero e o restante é tratado como vindo de outras fontes.
- **Fatura paga fica congelada:** editar compras, assinaturas ou o cartão depois não a altera.
- **Desfazer pagamento:** permitido. A fatura volta a pendente e a reserva recebe de volta **só o que saiu dela** (ex.: pagou R$ 1.237,50 com a reserva tendo R$ 1.000,00 → voltam R$ 1.000,00).

## 9. Dinheiro reservado e calculadora
- Começa em R$ 0,00. O usuário só digita o novo valor; o app grava a **diferença** como ajuste (§12). Nenhum lançamento é criado.
- Embaixo do campo: a última mudança automática, ex.: "−R$ 1.237,50 pela fatura Nubank de 10/12" (reduz o risco de descontar o mesmo pagamento à mão).
- **Calculadora ao editar:**
  - O visor começa com o valor atual da reserva.
  - Teclas: números, vírgula, `+ − × ÷`, apagar, limpar, `=`.
  - A conta fica visível (`28.207,43 + 1.500 − 320 = 29.387,43`), com o resumo "Atual R$ X → Novo R$ Y (+R$ Z)" e o botão Confirmar.
  - Conta exata (sem ponto flutuante); o resultado final é arredondado para o centavo mais próximo, **meio para cima** (1.000 ÷ 3 = 333,33).
  - Ordem da matemática: × e ÷ antes de + e − (`100 + 50 × 2 = 200`).
  - Resultado negativo não é aceito; divisão por zero mostra erro; teto da reserva R$ 10.000.000,00.
  - Vale só no campo da reserva desta ferramenta.

## 10. Histórico (simples)
- Guardado: **faturas pagas**, com datas, valor previsto, valor pago, origem (quanto saiu da reserva) e a lista de itens copiada como texto (descrição e valor) no momento do pagamento.
- Guardados também os eventos da reserva (§12), necessários ao cálculo; a tela mostra só a última mudança automática.
- Não guardado: versões de edição e cancelamentos de compras, assinaturas, cartões e previsões (decisão de 16/11/2026). Apagar remove de verdade, sem marca de exclusão; a ferramenta não grava no histórico de auditoria do app (`audit_events`).

## 11. Telas (rota proposta `/gestao-de-faturas`, fora do shell, barra com Ferramentas selecionada)
- Título "Gestão de Faturas de Cartões"; ⓘ no topo.
- **Topo:** Saldo não comprometido em destaque (ou "Faltam R$ X…"), linhas **Reservado** (toque abre a calculadora; última mudança automática) e **Comprometido**; linha "Assinaturas ativas: R$ X por mês".
- **Faturas:** lista por vencimento, a mais próxima primeiro: "Cartão · vence dd/mm · R$ valor · pendente/vencida", botão **Pagar**. Ao tocar: itens, valor informado (editar/apagar), datas (corrigir), aviso de valor informado menor que os itens. Seção recolhida **Pagas**.
- **Botão +:** Compra parcelada, Assinatura, Cartão. Listas de cartões, compras e assinaturas para editar/apagar.
- Sem nenhum cartão: estado vazio convidando a cadastrar o primeiro.
- Visual do Norte (Menta + Inter, claro e escuro, cartões).

## 12. Dados e sincronização
- Android: funciona sem conexão e sincroniza depois; Web: somente online. Dados isolados por usuário (RLS no servidor).
- **Cadastros** (cartão, compra, parcelas editadas, assinatura, valor informado e datas da fatura): última gravação vence.
- **Reserva = soma de eventos**, nunca sobrescrita: ajuste (diferença digitada), pagamento (− parte da reserva). Eventos com identificador idempotente; os dois aparelhos sempre chegam ao mesmo valor.
- **Pagamento duplicado** (mesma fatura paga em dois aparelhos sem conexão): ao sincronizar, o segundo **não é aplicado** e aparece como aviso para o usuário escolher qual manter. Qualquer um pode ser escolhido; o outro é desfeito como em §8 (a reserva é descontada uma vez só). É o único conflito apresentado.
- **Exclusões entre aparelhos:** como nada é guardado ao apagar (§10), a cada sincronização o aparelho compara a lista de registros da ferramenta com a do servidor e apaga localmente o que não existe mais lá (exceto o que tiver envio pendente).
- Fatura identificada de forma determinística (cartão + mês do fechamento); cobrança de assinatura idem (§7).
- O servidor valida dono, valores (centavos inteiros, limites) e fatura paga uma só vez.

## 13. Arquitetura (proposta técnica)
- Módulo próprio `lib/features/card_bills/` (domínio, aplicação, dados, telas); usa só o núcleo (`money.dart`, `calendar_date.dart`, `user_clock.dart`, tema, barra). Regras no domínio, testáveis, fora dos widgets.
- **Cálculos só no domínio em Dart** (o mesmo código no Android e na Web). O servidor guarda e valida (dono, centavos inteiros, limites, fatura paga uma só vez, unicidade de parcelas e cobranças), sem recalcular datas nem saldo (decisão de 16/11/2026).
- ID de catálogo `card_bills`, nome no catálogo **"Gestão de faturas"**, categoria "Compras e crédito", explicação antes do primeiro uso, **fora de "Suas ferramentas"** por padrão (em Outras ferramentas). Textos da explicação e do ⓘ: rascunho do agente direto na ferramenta, ajustados depois pelo responsável.
- Servidor: migration nova com tabelas de cartões, compras, parcelas, assinaturas, faturas, pagamentos e eventos da reserva; RLS; RPCs próprias. Drift: nova `schemaVersion` com snapshot e migração testada. Sem mudança nas tabelas, RPCs e sincronização existentes.

## 14. Testes previstos
- Saldo não comprometido e "Faltam R$ X"; valor da fatura (informado × itens, sem soma dupla).
- Distribuição por fechamento (antes/no dia/depois), dias 29–31, ano bissexto, vencimento no mês seguinte, datas corrigidas à mão.
- Divisão com resto na 1ª; edição de uma, "esta e as próximas" e compra inteira só em faturas pendentes; mudança do nº de parcelas com pagas.
- Assinaturas só na fatura atual, mudança de preço, cancelamento, sem cobrança dupla.
- Pagamento: valor diferente do previsto, origem, reserva insuficiente, congelamento.
- Calculadora: precedência, arredondamento, divisão por zero, limites.
- Sincronização: eventos idempotentes, pagamento duplicado, isolamento por usuário; testes SQL e equivalência local × servidor.

## 15. Decisões dos pontos abertos (16/11/2026, todas aprovadas pelo responsável)
Já incorporadas nas seções acima; resumo para consulta:
- **Pagamento:** só a fatura inteira, sem pagamento por item ou parcial; valor pago menor que o previsto mostra aviso (§8). Desfazer pagamento permitido (§8). Pagamento duplicado: o usuário escolhe qualquer um (§12). Fatura de R$ 0,00 pode ser paga como "sem valor a pagar" (§5.2, §8).
- **Valor da fatura:** modelo único confirmado — preencher ou apagar o valor informado faz o papel das "duas modalidades" (§5.3).
- **Assinaturas:** preço novo vale da fatura atual pendente; cancelamento a partir da seguinte, com pergunta sobre a cobrança atual; início futuro; cobranças faltantes após app fechado; cobrança removida não reaparece (§7).
- **Datas:** dias 29–31 = último dia do mês; fechamento e vencimento no mesmo dia aceito; vencimento corrigido antes ou no dia do fechamento recusado; correções à mão preservadas; corrigir datas ou mudar o dia do cartão não move compras já distribuídas (§4, §5.1).
- **Compras:** compra antiga com parcelas em faturas vencidas; fatura já paga → próxima pendente; data futura recusada (§6).
- **Limites:** 1–24 parcelas; R$ 1.000.000,00 por compra/fatura/pagamento; reserva até R$ 10.000.000,00 (§6, §8, §9).
- **Calculadora:** ordem da matemática (§9).
- **Histórico:** sem versões de edição nem cancelamentos; apagar some de verdade; exclusões propagadas por comparação com o servidor (§10, §12).
- **Técnica:** cálculos só em Dart; servidor guarda e valida (§13).
- **Catálogo:** fora de "Suas ferramentas"; textos em rascunho do agente (§13).

## 16. Entregas (uma por vez, cada uma com autorização e validação)
Protocolo: linha de base dos testes → só o escopo da entrega → testes da entrega + regressão (suíte completa; sync e integração nas Fases 3–4) → docs → resumo → parar para validação. Compilar ou tela bonita não basta.
- **Fase 0 — Preparação:** GF0.1 decisões consolidadas (esta revisão) · GF0.2 linha de base de todas as suítes.
- **Fase 1 — Domínio (Dart puro):** GF1.1 calendário do cartão · GF1.2 ciclo e fatura da compra · GF1.3 divisão de parcelas · GF1.4 valor da fatura e indicador · GF1.5 reserva por eventos · GF1.6 edição de compras · GF1.7 assinaturas · GF1.8 calculadora da reserva · GF1.9 faturas visíveis · GF1.10 tabela de casos revisada pelo responsável.
- **Fase 2 — Servidor (Supabase local):** GF2.1 tabelas e RLS · GF2.2 RPCs de cartão · GF2.3 compra e parcelas · GF2.4 assinaturas e cobranças · GF2.5 fatura (valor informado, datas) · GF2.6 pagamento, desfazer e reserva · GF2.7 excluir conta e catálogo de segurança.
- **Fase 3 — Banco local e sincronização:** GF3.1 Drift v10 · GF3.2 repositório de cartões · GF3.3 compras · GF3.4 assinaturas · GF3.5 faturas, pagamento e reserva · GF3.6 download e exclusões por comparação · GF3.7 pagamento duplicado na tela Atenção · GF3.8 integração (dois aparelhos, isolamento, paridade).
- **Fase 4 — Aplicação:** GF4.1 serviço do painel · GF4.2 geração de cobranças.
- **Fase 5 — Telas:** GF5.1 rota e estado vazio · GF5.2 cartão · GF5.3 apagar cartão · GF5.4 nova compra · GF5.5 editar/apagar compra · GF5.6 editar parcela · GF5.7 assinaturas · GF5.8 lista e detalhe da fatura · GF5.9 corrigir datas · GF5.10 pagar e desfazer · GF5.11 topo e reserva · GF5.12 calculadora · GF5.13 seção Pagas.
- **Fase 6 — Fechamento:** GF6.1 catálogo e textos · GF6.2 regressão e validação (emulador claro/escuro, Web) · GF6.3 homologação (só com autorização explícita).

## 17. Tabela de casos (GF1.10) — para o responsável revisar
Cartão de referência: fecha dia 10, vence dia 17; hoje 16/11/2026. Todos cobertos por testes em `test/features/card_bills/domain/`.
| Caso | Resultado |
|---|---|
| Compra em 09/11 | fatura de novembro (fecha 10/11, vence 17/11); fechada e não vencida: recebe a parcela |
| Compra em 10/11 ou 16/11 | fatura de dezembro (fecha 10/12, vence 17/12) — a atual |
| Fecha 31 em abril / fevereiro de 2027 / 2028 | 30/04 · 28/02/2027 · 29/02/2028 (sem dia útil) |
| Fecha 28, vence 5 | vence no mês seguinte (fecha 28/11, vence 05/12) |
| Fecha e vence no mesmo dia (10 e 10) | aceito; vence 10 do mês seguinte |
| Fecha 30, vence 31, em novembro | 30/11 e 31→30/11 cairiam juntos → vence 31/12 (decisão F7-1) |
| R$ 1.000,00 em 3x | R$ 333,34 + R$ 333,33 + R$ 333,33 (dez, jan, fev) |
| 4 × R$ 125,50 ("valor da parcela") | total R$ 502,00 |
| Compra de 20/08 em 5x (hoje 16/11) | set e out vencidas → 2 parcelas "consideradas pagas"; nov, dez, jan contam |
| 1ª parcela em fatura já paga | vai para a próxima pendente, as seguintes andam junto (aviso) |
| 10x de R$ 1.000,00 com 3 pagas → 8x | as 3 ficam; R$ 7.000,00 em 5 de R$ 1.400,00; parcelas 9 e 10 somem |
| Mudar para 3x com 3 pagas | recusado |
| Fatura com itens R$ 450,00 e informado R$ 1.200,00 | vale R$ 1.200,00 ("R$ 750,00 em outros gastos"); informado R$ 300,00 → vale R$ 300,00 com aviso |
| Reserva R$ 1.000,00, paga R$ 1.237,50 pela reserva | reserva vai a R$ 0,00 (aviso); desfazer devolve R$ 1.000,00 |
| Paga R$ 1.000,00 de R$ 1.200,00 previstos | aviso "R$ 200,00 deixarão de contar" |
| Reservado R$ 1.000,00, comprometido R$ 1.500,00 | "Faltam R$ 500,00 para cobrir as faturas" |
| Assinatura R$ 39,90 desde dezembro | cobrança só na fatura atual; em 12/02/2027, com janeiro pago, entram fevereiro e março |
| Cobrança removida à mão | não volta, nem gerada por outro aparelho |
| Preço novo da assinatura | vale da fatura atual pendente; dezembro fechado mantém o antigo; cobrança ajustada à mão não muda |
| Calculadora: 100 + 50 × 2 · 1.000 ÷ 3 · 2 ÷ 3 · 0,1 + 0,2 · 10 ÷ 0 · 10 − 20 | 200,00 · 333,33 · 0,67 · 0,30 · erro · erro (negativo) |
| Pagamento duplicado (A pela reserva, B por outras fontes) | B não é aplicado e vai para atenção; manter B desfaz A (reserva volta) e aplica B |
