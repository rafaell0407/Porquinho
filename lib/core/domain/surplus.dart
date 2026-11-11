/// Cálculo da sobra do período (RN005–RN007, RN022, `AGENTS.md` §4.2).
///
/// `Sobra = receitas contabilizadas − despesas contabilizadas − investimentos`.
/// Funções puras sobre valores em centavos ([BigInt]); sem acesso a dados.
library;

/// Receita como entra no cálculo. Só a receita **recebida** conta; recorrente
/// pendente e cancelada ficam de fora.
class IncomeLine {
  const IncomeLine({required this.status, required this.amount});

  /// `pending`, `received` ou `cancelled`.
  final String status;
  final BigInt? amount;
}

/// Despesa como entra no cálculo. Pendente e paga contam uma única vez
/// (pagar não deduz de novo); cancelada e variável sem valor não contam.
class ExpenseLine {
  const ExpenseLine({required this.status, required this.amount});

  /// `pending`, `paid` ou `cancelled`.
  final String status;
  final BigInt? amount;
}

/// Destinação a investimento; cancelada (com data) não conta.
class InvestmentLine {
  const InvestmentLine({required this.amount, this.cancelled = false});

  final BigInt amount;
  final bool cancelled;
}

class PeriodTotals {
  const PeriodTotals({
    required this.income,
    required this.expense,
    required this.investment,
  });

  static final zero = PeriodTotals(
    income: BigInt.zero,
    expense: BigInt.zero,
    investment: BigInt.zero,
  );

  final BigInt income;
  final BigInt expense;
  final BigInt investment;

  /// Sobra do período. Pode ser negativa.
  BigInt get surplus => income - expense - investment;

  @override
  bool operator ==(Object other) =>
      other is PeriodTotals &&
      other.income == income &&
      other.expense == expense &&
      other.investment == investment;

  @override
  int get hashCode => Object.hash(income, expense, investment);

  @override
  String toString() =>
      'PeriodTotals(receitas: $income, despesas: $expense, '
      'investimentos: $investment, sobra: $surplus)';
}

bool countsAsIncome(IncomeLine l) => l.status == 'received' && l.amount != null;

bool countsAsExpense(ExpenseLine l) =>
    (l.status == 'pending' || l.status == 'paid') && l.amount != null;

/// Soma as linhas **já filtradas pelo período** (cada lançamento pertence a um
/// único período, definido pela sua data de competência).
PeriodTotals computePeriodTotals({
  Iterable<IncomeLine> incomes = const [],
  Iterable<ExpenseLine> expenses = const [],
  Iterable<InvestmentLine> investments = const [],
}) {
  var income = BigInt.zero;
  for (final l in incomes) {
    if (countsAsIncome(l)) income += l.amount!;
  }
  var expense = BigInt.zero;
  for (final l in expenses) {
    if (countsAsExpense(l)) expense += l.amount!;
  }
  var investment = BigInt.zero;
  for (final l in investments) {
    if (!l.cancelled) investment += l.amount;
  }
  return PeriodTotals(income: income, expense: expense, investment: investment);
}
