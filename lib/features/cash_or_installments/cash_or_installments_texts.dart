/// Textos da Calculadora à vista ou parcelado (spec §9; **rascunho** até a
/// validação do responsável). Ficam juntos para revisar num lugar só.
abstract final class CashOrInstallmentsTexts {
  static const title = 'Calculadora à vista ou parcelado';

  /// Faixa permanente (§9.1) e alerta inicial do catálogo.
  static const alertTitle =
      'Investir enquanto parcela exige disciplina financeira.';
  static const alertBody =
      'Não é recomendado para quem tem dívidas ou não paga a fatura inteira.';
  static const initialAlert = '$alertTitle $alertBody';

  /// "Ler mais" (§9.2).
  static const readMore = [
    'Só faz sentido para quem paga a fatura inteira todo mês. Os juros do '
        'rotativo e do parcelamento da fatura são muito maiores que qualquer '
        'rendimento.',
    'Quem tem dívidas ganha mais quitando a dívida do que investindo.',
    'Parcelar compromete a renda dos próximos meses; várias compras '
        'parceladas juntas podem apertar o orçamento.',
    'O dinheiro reservado precisa ficar guardado até a última parcela. Se '
        'for usado para outra coisa, a vantagem some e as parcelas continuam.',
    'Taxas mudam. A simulação usa a taxa de hoje como se fosse a mesma até '
        'o fim.',
    'Confira o valor à vista com a loja e a data de vencimento no app do '
        'banco.',
    'É uma simulação: não cria lançamentos e não é recomendação de '
        'investimento.',
  ];

  /// Abaixo do % do CDI (§9.3).
  static const cdbRisk =
      'Limite de 120% do CDI. Taxas maiores costumam vir de bancos de maior '
      'risco. Se o banco quebrar, a garantia do FGC pode levar semanas para '
      'devolver o dinheiro, e as faturas continuam vencendo.';

  static const treasuryNote =
      '100% da Selic. A simulação considera sem taxa de custódia, sem '
      'ágio/deságio e venda pelo valor exato no dia.';

  static const billHint =
      'Comprou depois do fechamento da fatura? Então a 1ª parcela vem na '
      'fatura seguinte. Na dúvida, confira no app do banco.';

  static const footer =
      'Primeiro, organização financeira. Depois, otimização financeira.';

  /// Premissas (§9.4) para o ícone de informação.
  static const assumptions = [
    'Você já tem o dinheiro reservado para pagar todas as parcelas, sem '
        'depender do rendimento. À vista, a sobra fica no mesmo investimento.',
    'Taxa (CDI ou Selic) constante até a última parcela.',
    'Rende só em dia útil (segunda a sexta, menos feriados nacionais).',
    'Cada parcela é resgatada no vencimento ou, se cair em fim de semana ou '
        'feriado, no dia útil anterior.',
    'IR regressivo e IOF descontados em cada resgate.',
    'Tesouro Selic sem taxa de custódia e sem ágio/deságio.',
    'Compra feita hoje, no cartão de crédito, em parcelas iguais (o resto '
        'dos centavos fica na 1ª).',
  ];
}
