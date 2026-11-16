# Calculadora à vista ou parcelado — especificação

**Status:** APROVADO pelo responsável em 14/11/2026 (planejamento e decisões); desenvolvimento autorizado em 14/11/2026 (entregas AP0–AP8, validação no fim). Textos de apresentação e avisos (§9) estão em **rascunho** até a validação. Requisito: RF028. Pontos a confirmar: §15 e `pendencias.md` F5.

## 1. Para que serve
Comparar, para uma compra no **cartão de crédito**, duas formas de pagar: **à vista** (normalmente com desconto) ou **parcelado** (deixando o dinheiro investido e resgatando a cada fatura). O resultado é quanto a pessoa terá em caixa no fim, nos dois caminhos, e qual é melhor.

## 2. Escopo e exceção aprovada
- É só uma **simulação em memória**, aberta pela aba Ferramentas. Não cria lançamentos, não grava a simulação, não muda o dinheiro livre e não registra compra, parcela ou fatura.
- **Exceção aprovada (14/11/2026)** a `regras_negocio.md` RN007 e a `requisitos.md` §3.2 (parcelamentos e estimativa de rendimento por taxa ou % do CDI fora do MVP): a exceção vale **somente** para este simulador em Ferramentas. Continua proibido criar compras de cartão, parcelas, faturas automáticas ou rendimento automático nos lançamentos.
- Fora desta ferramenta: entrada (sinal), parcelas de valores diferentes, juros do rotativo, outros meios de pagamento (boleto, Pix parcelado, crediário), outros investimentos.
- O motor de cálculo recebe uma lista de parcelas (data, valor), para não fechar a porta a entrada ou valores diferentes no futuro (exigiria aprovação).

## 3. Entradas
Valores em BRL, em centavos inteiros. Limite de cada campo de dinheiro: R$ 1.000.000,00.

| Campo | Regra |
|---|---|
| Preço à vista — modo | "Valor à vista" (padrão) ou "Preço + desconto" |
| Valor à vista | maior que zero |
| Preço original + desconto | preço maior que zero; desconto em % de 0 a 99,99 (até 2 casas). Valor à vista = preço × (1 − desconto), arredondado para centavos **meio para cima**; tem que dar pelo menos R$ 0,01. A tela mostra o valor calculado e pede para conferir com a loja |
| Parcelamento — modo | "Total parcelado" (padrão) ou "Valor da parcela" |
| Total parcelado | maior que zero; no modo "Preço + desconto" vem preenchido com o preço original enquanto o usuário não mexer no campo |
| Valor da parcela | maior que zero; total = parcela × número de parcelas (dentro do limite) |
| Número de parcelas | inteiro de 1 a 24 |
| Divisão do total | parcela = total ÷ n (parte inteira, em centavos); o resto da divisão vai para a **1ª parcela**. O total precisa dar pelo menos R$ 0,01 por parcela |
| Data da compra | sempre **hoje** (fuso `America/Sao_Paulo`); não há campo |
| Dia de vencimento do cartão | inteiro de 1 a 31 |
| Fatura da 1ª parcela | "Próxima fatura (vence dd/mm/aaaa)" (padrão) ou "Fatura seguinte (vence dd/mm/aaaa)" |
| Investimento | "CDB liquidez diária" (padrão) ou "Tesouro Selic" |
| % do CDI (só CDB) | de 0 a 120, até 2 casas; padrão 100 |
| Taxa anual | CDI (CDB) ou Selic (Tesouro), buscada no Banco Central (§10); o usuário pode editar de 0 a 100% ao ano, até 2 casas, só nesta simulação (não grava) |

## 4. Datas
### 4.1 Vencimentos
- D = dia de vencimento. "Dia D do mês" em mês sem esse dia = **último dia do mês** (31 → 30/04, 28 ou 29/02).
- **Próxima fatura:** primeiro "dia D" **depois de hoje** (se hoje é o dia D, é o do mês seguinte).
- **Fatura seguinte:** o "dia D" do mês seguinte ao da próxima.
- Parcela k (k = 1…n): "dia D" do mês da 1ª fatura + (k − 1) meses; sempre a partir de D, nunca do dia já ajustado.

### 4.2 Dias úteis (só nesta ferramenta)
- Dia útil = segunda a sexta, menos os **feriados nacionais**: 1º/1, Carnaval (segunda e terça, Páscoa − 48 e − 47), Sexta-feira Santa (Páscoa − 2), 21/4, 1º/5, Corpus Christi (Páscoa + 60), 7/9, 12/10, 2/11, 15/11, 20/11 (a partir de 2024, Lei 14.759/2023) e 25/12. Mesmo calendário usado pelo mercado (ANBIMA) para o CDI.
- Feriados estaduais e municipais não entram.
- Esta regra vale **só** aqui. O resto do app continua com RN038 (dia útil = segunda a sexta, sem feriados).

### 4.3 Aplicação, resgates e fim
- **Aplicação (A):** hoje, se for dia útil; senão, o próximo dia útil. O dinheiro é aplicado de uma vez só.
- **Resgate da parcela k (Rₖ):** no vencimento, se for dia útil; senão, no **dia útil anterior**.
- Parcela com resgate **no dia da aplicação ou antes** é paga **direto da reserva** (não chega a ser aplicada).
- **Fim (F):** dia do resgate da última parcela. Nesse dia o que sobrou é resgatado (com impostos) e vira "em caixa".

## 5. Investimentos
| Produto | Rende | Premissas exibidas |
|---|---|---|
| CDB liquidez diária | % do CDI informado (0–120%) | resgate a qualquer dia útil pelo valor da curva; texto do FGC (§9.3) |
| Tesouro Selic | 100% da Selic | sem taxa de custódia, sem ágio/deságio, venda pelo valor exato no dia |

- Taxa anual a (CDI ou Selic, base 252) **constante** até o fim.
- Taxa diária: r = (1 + a)^(1/252) − 1. Fator do dia útil: 1 + p·r, com p = % do CDI ÷ 100 (Tesouro: p = 1). O percentual incide sobre a **taxa diária** (padrão de mercado).
- Rende em cada dia útil d com A ≤ d < resgate (da aplicação até o dia útil anterior ao resgate). Fim de semana e feriado não rendem.

## 6. Os dois caminhos
**Reserva (Res):** o maior valor entre o total parcelado e o valor à vista. Premissa mostrada: "você já tem Res reservados para pagar todas as parcelas, sem depender do rendimento".

- **À vista:** paga o valor à vista hoje; a sobra (Res − valor à vista) é aplicada em A no mesmo investimento e resgatada inteira em F. Se F ≤ A, não rende.
- **Parcelado:** a reserva é aplicada em A (menos as parcelas pagas direto da reserva). Em cada Rₖ resgata-se o necessário para pagar a parcela **já líquida de impostos**; em F, resgata-se o que sobrou.

**Resultado:** "em caixa no fim" de cada caminho = o que sobra em F depois de todas as parcelas e impostos.

## 7. Impostos (por resgate)
- Dias corridos (dc) = data do resgate − data da aplicação.
- **IOF** sobre o rendimento resgatado: dc ≥ 30 → 0. dc de 1 a 29: 96, 93, 90, 86, 83, 80, 76, 73, 70, 66, 63, 60, 56, 53, 50, 46, 43, 40, 36, 33, 30, 26, 23, 20, 16, 13, 10, 6, 3 (%). (dc = 0 não tem rendimento.)
- **IR** sobre (rendimento − IOF): até 180 dias 22,5%; 181 a 360: 20%; 361 a 720: 17,5%; acima de 720: 15%. Tabela regressiva vigente (a MP 1.303/2025, que mudaria as alíquotas, perdeu a validade em outubro/2025).
- **Proporcional:** todo o dinheiro tem a mesma data de aplicação. Num resgate bruto G de uma posição de valor V com custo C, o rendimento resgatado é G·(V − C)/V; o custo restante cai na mesma proporção.
- **Por dentro:** para receber a parcela P líquida, resgata-se G = P ÷ (1 − y·τ), com y = (V − C)/V e τ = IOF + IR·(1 − IOF). Impostos do resgate = G − P.
- No fim (F), o resgate do que sobrou paga IOF/IR sobre todo o rendimento restante.

## 8. Comparação e veredito
- Diferença = em caixa à vista − em caixa parcelado (valores **mostrados**, já em centavos).
- |diferença| < R$ 1,00 → **"DÁ NO MESMO"**. Sem faixa de "vantagem pequena".
- Senão: **"O MELHOR É PAGAR À VISTA"** ou **"O MELHOR É PAGAR A PRAZO"**, com "R$ X a mais no seu bolso".
- Texto dos dois caminhos: "Pagando À VISTA, até a última parcela (dd/mm/aaaa), você terá o que comprou e mais R$ X em caixa." (idem A PRAZO; a data é o vencimento da última parcela).
- Rodapé fixo do cartão: "Primeiro, organização financeira. Depois, otimização financeira."

**Propriedade de controle (teste):** a diferença não depende do tamanho da reserva. Com reserva = total parcelado ou reserva maior, a diferença exata é a mesma (cada real a mais rende igual nos dois caminhos).

## 9. Avisos (textos em rascunho)
### 9.1 Faixa permanente (topo da tela; não fecha)
"**Investir enquanto parcela exige disciplina financeira.** Não é recomendado para quem tem dívidas ou não paga a fatura inteira." + link "Ler mais" (abre §9.2).
O mesmo texto é o **alerta inicial** do catálogo: aparece no topo da apresentação antes do primeiro uso e do ícone ⓘ.

### 9.2 Ler mais
- Só faz sentido para quem paga a fatura inteira todo mês. Os juros do rotativo e do parcelamento da fatura são muito maiores que qualquer rendimento.
- Quem tem dívidas ganha mais quitando a dívida do que investindo.
- Parcelar compromete a renda dos próximos meses; várias compras parceladas juntas podem apertar o orçamento.
- O dinheiro reservado precisa ficar guardado até a última parcela. Se for usado para outra coisa, a vantagem some e as parcelas continuam.
- Taxas mudam. A simulação usa a taxa de hoje como se fosse a mesma até o fim.
- Confira o valor à vista com a loja e a data de vencimento no app do banco.
- É uma simulação: não cria lançamentos e não é recomendação de investimento.

### 9.3 Texto do CDB (abaixo do % do CDI)
"Limite de 120% do CDI. Taxas maiores costumam vir de bancos de maior risco. Se o banco quebrar, a garantia do FGC pode levar semanas para devolver o dinheiro, e as faturas continuam vencendo."

### 9.4 Premissas (ícone ⓘ e resultado)
Taxa constante até o fim; rende só em dia útil (feriados nacionais); resgate no dia útil anterior ao vencimento; IR regressivo e IOF descontados em cada resgate; Tesouro sem custódia e sem ágio/deságio; compra feita hoje; só cartão de crédito, parcelas iguais (resto na 1ª).

## 10. Fonte da taxa (Banco Central — SGS)
- Séries: **CDI 4389** e **Selic 1178** (ambas "% ao ano, base 252"). Endereço: `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{série}/dados/ultimos/{n}?formato=json` (resposta `[{"data":"dd/mm/aaaa","valor":"14.90"}]`; acesso público, CORS liberado).
- A resposta pode vir fora de ordem: usar sempre a **maior data**.
- Busca ao abrir a ferramenta. Celular: guarda a última taxa no armazenamento seguro do aparelho (`SecureValueStore`); Web: só em memória.
- Aviso quando a busca falha (usa a guardada, se houver) ou quando a taxa tem mais de 30 dias. Sem taxa nenhuma, o usuário precisa informar.
- Edição manual: 0 a 100% ao ano, até 2 casas, só para a simulação atual; não grava.

## 11. Telas (rota `/a-vista-ou-parcelado`, fora do shell, barra com Ferramentas selecionada)
- Título "Calculadora à vista ou parcelado"; ⓘ no topo; faixa §9.1.
- Seções: **A compra** (modo + valores; mostra o valor à vista calculado) · **No cartão** (modo, total ou parcela, nº de parcelas, "n x de R$ p", dia de vencimento, escolha da fatura com as duas datas, vencimentos da 1ª à última com "ver todos") · **Onde o dinheiro fica** (produto, % do CDI com texto §9.3, taxa com data e "Editar") · Calcular / Limpar.
- **Resultado:** cartão do veredito (§8, faixa em Menta); premissas (reserva; chips: data da simulação, data da aplicação, produto, taxa e data, "Taxa constante até o fim"); **Lado a lado** (valor pago, fica investido no início, rendimento, Imposto de Renda, IOF, em caixa no fim); gráfico do saldo investido nos dois caminhos (um ponto por fatura, toque mostra data e valor); tabela **A prazo, fatura a fatura**: Data · Saldo inicial · Rendimento · Impostos · Parcela paga · Saldo final, com nota quando o resgate é antes do vencimento ou a parcela sai direto da reserva, e a linha final "Resgate do que sobrou".

## 12. Precisão e arredondamento
- Conta exata em inteiros grandes (`BigInt`), sem ponto flutuante; centavos só na exibição.
- Valores **acumulados** (rendimento, IR, IOF) são arredondados para centavos **meio para cima**; as linhas da tabela são diferenças dos acumulados, para que tabela, lado a lado e veredito batam ao centavo.
- Saldo final da linha = reserva + rendimento acumulado − impostos acumulados − parcelas pagas. Em caixa no fim = mesma conta após o resgate final.
- Impostos acumulados = IR acumulado arredondado + IOF acumulado arredondado.
- Veredito usa os números mostrados.

## 13. Testes de veracidade
1. **Referência independente** em Python (`tooling/a_vista_ou_parcelado_referencia.py`, só biblioteca padrão): feriados por tabela de datas da Páscoa (não por fórmula), cálculo por cotas (não por posição), `Decimal` com 50 dígitos. Gera `test/fixtures/cash_or_installments_cases.json` (calendário, impostos e simulações completas), escrita **antes** do código Dart; o Dart tem de bater ao centavo.
2. **Fórmulas fechadas:** 252 dias úteis a 100% do CDI rendem exatamente a taxa anual; taxa 0 → nenhum rendimento; sem IOF a partir de 30 dias; alíquota do IR em 180/181, 360/361, 720/721 dias.
3. **Propriedade de controle** (§8).
4. **Conferência manual (Calculadora do Cidadão, Banco Central):** "Correção de valor pelo CDI", R$ 1.000,00, de 01/09/2022 a 01/08/2023, 100% do CDI. Nesse intervalo o CDI ficou constante em 13,65% a.a.; o valor corrigido deve ficar a poucos centavos do resultado bruto da ferramenta com a mesma taxa e as mesmas datas (a B3 arredonda o fator diário em 8 casas). Valor esperado registrado em `pendencias.md` F5.

## 14. Arquitetura
- Módulo independente `lib/features/cash_or_installments/` (não compartilha código com `compound_interest/`; usa só o núcleo: `money.dart`, `calendar_date.dart`, `user_clock.dart`, `SecureValueStore`, tema e barra).
- ID `cash_or_installments`, rota `/a-vista-ou-parcelado`, categoria "Compras e crédito", nome no catálogo "À vista ou parcelado" (o nome longo corta nos cartões), explicação antes do primeiro uso, fora de "Suas ferramentas" por padrão.
- Campo opcional novo no catálogo: `ToolDefinition.initialAlert` (alerta inicial), mostrado no topo da apresentação e do ⓘ.
- Sem banco, Drift, migration, sincronização ou preferência nova. Rede: só a leitura pública do SGS.

## 15. Pontos a confirmar na validação
(a) limite de R$ 1.000.000,00 por campo; (b) textos §9 e da apresentação; (c) "Total parcelado" pré-preenchido só no modo "Preço + desconto"; (d) parcela com vencimento em fim de semana/feriado resgatada no dia útil anterior (algumas faturas aceitam pagar no dia útil seguinte); (e) conferência da Calculadora do Cidadão (§13.4).
