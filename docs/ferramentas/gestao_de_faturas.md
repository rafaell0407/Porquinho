# Gestão de Faturas de Cartões — especificação

**Status:** decisões de produto APROVADAS pelo responsável na discussão de 16/11/2026. **Desenvolvimento NÃO autorizado** (aguarda autorização própria). Requisito: RF029. Pontos a confirmar: §15 e `pendencias.md` F6.

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

- "Dia D do mês" em mês sem esse dia = **último dia do mês** (mesma regra da calculadora à vista ou parcelado; a confirmar, §15).
- O vencimento cai no **mesmo mês do fechamento** se o dia de vencimento for maior que o de fechamento; senão, no **mês seguinte** (ex.: fecha 28, vence 5 → vence no mês seguinte).
- Mudar o dia de fechamento ou vencimento no cartão só altera as **faturas pendentes que ainda não fecharam** (exceto as que tiveram as datas corrigidas à mão, §5.1). Faturas fechadas e pagas não mudam.
- **Apagar o cartão:** apaga compras, assinaturas e faturas pendentes dele, com aviso do valor que deixa de contar. Faturas pagas ficam no histórico (§10).

## 5. Faturas
### 5.1 Datas e ciclo
- Cada fatura pertence a um cartão e guarda o **próprio fechamento (F) e vencimento**, copiados do cartão ao ser criada; o usuário pode corrigir as datas de uma fatura específica (o banco muda o fechamento por fim de semana ou feriado).
- Ciclo da fatura: **[fechamento anterior, F)**. Compra feita **antes** do dia de fechamento entra na fatura atual; **no dia do fechamento ou depois**, na seguinte.
- **Fatura atual** de um cartão: aquela cujo ciclo contém hoje (fuso `America/Sao_Paulo`).
- **Fatura fechada:** hoje ≥ F. **Vencida:** pendente e hoje > vencimento.

### 5.2 Quais aparecem
- Sempre a **fatura atual e a seguinte** de cada cartão, mesmo vazias (para permitir informar o valor sem cadastrar compras). Vazia vale R$ 0,00.
- Faturas mais distantes, **só quando tiverem parcelas ou valor informado**.
- Faturas **fechadas e não pagas** continuam aparecendo; vencidas com destaque ("venceu em dd/mm").
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
| Data da compra | padrão hoje, editável |
| Valor | "Valor total" (padrão) ou "Valor da parcela"; maior que zero |
| Número de parcelas | inteiro de 1 a 24 (a confirmar, §15); 1 = compra à vista no cartão |
| Fatura da 1ª parcela | automática pela regra §5.1; a tela mostra "1ª parcela na fatura que vence em dd/mm/aaaa" e permite trocar para a anterior ou a seguinte |

- **Divisão:** parcela = total ÷ n (parte inteira, em centavos); o resto vai para a **1ª parcela**. Modo "Valor da parcela": total = parcela × n.
- Parcela k entra na fatura do mês da 1ª + (k − 1) meses, no mesmo cartão.
- **Total da compra = soma das parcelas** (não há total guardado à parte).
- **Editar uma parcela:** muda só ela. **Editar "esta e as próximas":** muda as parcelas pendentes dali em diante.
- **Editar a compra inteira** (valor, nº de parcelas, cartão, data, 1ª fatura): recalcula **só as parcelas de faturas pendentes**; as de faturas pagas ficam. Se houver parcelas editadas à mão, avisar que esses ajustes serão refeitos.
- **Mudar o nº de parcelas com algumas já pagas** (ex.: 3 de 10 pagas → 8): as pagas ficam; o valor restante (novo total − soma das pagas) é dividido nas parcelas restantes (8 − 3 = 5), resto na primeira delas. Não aceita nº de parcelas menor ou igual ao de pagas.
- **Cancelar/apagar a compra:** apaga a compra e as parcelas pendentes. As de faturas pagas permanecem só como texto no histórico da fatura (§10).

## 7. Assinaturas (cobranças recorrentes no cartão)
| Campo | Regra |
|---|---|
| Descrição | obrigatória |
| Cartão | obrigatório |
| Valor mensal | maior que zero |
| Início | fatura da primeira cobrança (padrão: a atual) |

- Uma assinatura ativa gera **uma cobrança por fatura**, mas só entra na **fatura atual** de cada cartão (nunca projetada nas faturas seguintes). Quando a fatura fecha sem ser paga, a cobrança continua nela; a nova fatura atual recebe a sua.
- A cobrança, uma vez gerada, é um **item próprio da fatura**: pode ter o valor editado ou ser removida só naquela fatura.
- **Mudança de preço:** vale para a fatura atual pendente e as próximas. Faturas pagas mantêm o valor antigo (congeladas).
- **Cancelamento:** apaga a assinatura e vale **a partir da fatura seguinte**; a cobrança já gerada na fatura atual continua (o usuário a remove à mão se não houver cobrança). (A confirmar, §15.)
- Identificador da cobrança determinístico (assinatura + fatura), para nunca gerar duas no mesmo ciclo, inclusive em dois aparelhos.

## 8. Pagamento
- Só se paga a **fatura inteira** ("Pagar fatura"). Não há pagamento parcial nem por item. Estados: **pendente** ou **paga**.
- O usuário confirma:
  - **Valor pago:** preenchido com o valor da fatura, editável, maior que zero.
  - **Data:** hoje, editável.
  - **Origem:** "Dinheiro reservado" ou "Outras fontes".
- Ao confirmar:
  - O valor pago passa a ser o **valor definitivo** da fatura e o compromisso dela vai a zero.
  - **Dinheiro reservado:** a reserva diminui o valor pago.
  - **Outras fontes:** a reserva não muda.
  - A previsão fica registrada ao lado: "previsto R$ 1.200,00 · pago R$ 1.237,50".
- **Valor pago maior que a reserva** (origem reserva): aviso "a reserva tem R$ X; o pagamento vai deixá-la em R$ 0,00"; ao confirmar, a reserva vai a zero e o restante é tratado como vindo de outras fontes.
- **Fatura paga fica congelada:** editar compras, assinaturas ou o cartão depois não a altera.

## 9. Dinheiro reservado e calculadora
- Começa em R$ 0,00. O usuário só digita o novo valor; o app grava a **diferença** como ajuste (§12). Nenhum lançamento é criado.
- Embaixo do campo: a última mudança automática, ex.: "−R$ 1.237,50 pela fatura Nubank de 10/12" (reduz o risco de descontar o mesmo pagamento à mão).
- **Calculadora ao editar:**
  - O visor começa com o valor atual da reserva.
  - Teclas: números, vírgula, `+ − × ÷`, apagar, limpar, `=`.
  - A conta fica visível (`28.207,43 + 1.500 − 320 = 29.387,43`), com o resumo "Atual R$ X → Novo R$ Y (+R$ Z)" e o botão Confirmar.
  - Conta exata (sem ponto flutuante); o resultado final é arredondado para o centavo mais próximo, **meio para cima** (1.000 ÷ 3 = 333,33).
  - Resultado negativo não é aceito; divisão por zero mostra erro; teto do campo em §15.
  - Vale só no campo da reserva desta ferramenta.

## 10. Histórico (simples)
- Guardado: **faturas pagas**, com datas, valor previsto, valor pago, origem (quanto saiu da reserva) e a lista de itens copiada como texto (descrição e valor) no momento do pagamento.
- Guardados também os eventos da reserva (§12), necessários ao cálculo; a tela mostra só a última mudança automática.
- Não guardado: versões de edição de compras, assinaturas, cartões e previsões. Apagar remove de verdade.

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
- **Pagamento duplicado** (mesma fatura paga em dois aparelhos sem conexão): ao sincronizar, o segundo **não é aplicado** e aparece como aviso para o usuário escolher qual manter. É o único conflito apresentado.
- Fatura identificada de forma determinística (cartão + mês do fechamento); cobrança de assinatura idem (§7).
- O servidor valida dono, valores (centavos inteiros, limites) e fatura paga uma só vez.

## 13. Arquitetura (proposta técnica)
- Módulo próprio `lib/features/card_bills/` (domínio, aplicação, dados, telas); usa só o núcleo (`money.dart`, `calendar_date.dart`, `user_clock.dart`, tema, barra). Regras no domínio, testáveis, fora dos widgets.
- ID de catálogo `card_bills`, nome no catálogo **"Gestão de faturas"**, categoria "Compras e crédito", explicação antes do primeiro uso, fora de "Suas ferramentas" por padrão (a confirmar).
- Servidor: migration nova com tabelas de cartões, compras, parcelas, assinaturas, faturas, pagamentos e eventos da reserva; RLS; RPCs próprias. Drift: nova `schemaVersion` com snapshot e migração testada. Sem mudança nas tabelas, RPCs e sincronização existentes.

## 14. Testes previstos
- Saldo não comprometido e "Faltam R$ X"; valor da fatura (informado × itens, sem soma dupla).
- Distribuição por fechamento (antes/no dia/depois), dias 29–31, ano bissexto, vencimento no mês seguinte, datas corrigidas à mão.
- Divisão com resto na 1ª; edição de uma, "esta e as próximas" e compra inteira só em faturas pendentes; mudança do nº de parcelas com pagas.
- Assinaturas só na fatura atual, mudança de preço, cancelamento, sem cobrança dupla.
- Pagamento: valor diferente do previsto, origem, reserva insuficiente, congelamento.
- Calculadora: precedência, arredondamento, divisão por zero, limites.
- Sincronização: eventos idempotentes, pagamento duplicado, isolamento por usuário; testes SQL e equivalência local × servidor.

## 15. Pontos a confirmar (antes ou durante o desenvolvimento)
(a) dias 29–31 de fechamento/vencimento em mês curto = último dia do mês; fechamento e vencimento no mesmo dia: aceitar (vence no mês seguinte) ou recusar;
(b) cancelamento de assinatura a partir da fatura seguinte;
(c) **compra antiga** cadastrada hoje com parcelas em faturas já vencidas (ex.: compra de 5 meses atrás em 10x) — proposta: o app avisa e trata essas parcelas como "já pagas fora da ferramenta", sem criar faturas vencidas nem mexer na reserva;
(d) **nova compra cuja fatura já foi paga antecipadamente** — proposta: avisar e lançar a parcela na próxima fatura pendente;
(e) **desfazer pagamento** (pagou a fatura errada) — proposta: permitir, devolvendo à reserva o que saiu dela; não discutido ainda;
(f) limites: nº de parcelas (proposta 1–24), valor por compra/fatura (proposta R$ 1.000.000,00), reserva (proposta R$ 10.000.000,00);
(g) calculadora: ordem das operações — proposta: a da matemática (× e ÷ antes de + e −);
(h) mudança do dia no cartão preserva as datas corrigidas à mão numa fatura;
(i) textos da explicação antes do primeiro uso e do ⓘ;
(j) entrar ou não em "Suas ferramentas" por padrão.

## 16. Entregas propostas (só com autorização)
GF1 domínio (cálculo, datas, distribuição, calculadora) com tabela de casos · GF2 servidor (migration, RLS, RPCs, testes SQL) · GF3 banco local (Drift), repositórios e sincronização · GF4 cartões, compras e assinaturas (telas) · GF5 faturas e pagamento · GF6 reserva, calculadora e topo da tela · GF7 catálogo, textos e validação.
