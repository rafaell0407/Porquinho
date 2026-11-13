/// Cálculos dos relatórios básicos (Entrega 61; `requisitos.md` §13.7).
///
/// Funções puras sobre valores em centavos ([BigInt]). Usam exatamente as
/// mesmas regras do dinheiro livre (`surplus.dart`): nenhuma fórmula nova.
library;

import 'period_calendar.dart';
import 'surplus.dart';

/// Uma linha de relatório por categoria. [categoryId] nulo = "Sem categoria".
class CategoryTotal {
  const CategoryTotal({required this.categoryId, required this.amount});

  final String? categoryId;
  final BigInt amount;
}

/// Relatório por categoria de um período: linhas do maior para o menor valor
/// (empate: categoria com nome/ID menor primeiro, "Sem categoria" por último)
/// e o total, que é igual ao total do dinheiro livre.
class CategoryBreakdown {
  const CategoryBreakdown(this.items, this.total);

  final List<CategoryTotal> items;
  final BigInt total;

  /// Participação de [item] no total, em pontos-base (1/100 de %), truncada.
  /// Total zero → 0. Só para exibição; os valores continuam em centavos.
  int basisPoints(CategoryTotal item) => total == BigInt.zero
      ? 0
      : (item.amount * BigInt.from(10000) ~/ total).toInt();
}

CategoryBreakdown _breakdown(Map<String?, BigInt> sums) {
  final items = [
    for (final e in sums.entries)
      CategoryTotal(categoryId: e.key, amount: e.value),
  ];
  items.sort((a, b) {
    final byAmount = b.amount.compareTo(a.amount);
    if (byAmount != 0) return byAmount;
    if (a.categoryId == null) return b.categoryId == null ? 0 : 1;
    if (b.categoryId == null) return -1;
    return a.categoryId!.compareTo(b.categoryId!);
  });
  final total = items.fold(BigInt.zero, (sum, i) => sum + i.amount);
  return CategoryBreakdown(items, total);
}

/// Monta o relatório por categoria a partir de somas já feitas (por exemplo,
/// as que o servidor devolve). Linhas da mesma categoria são somadas.
CategoryBreakdown breakdownFromTotals(Iterable<CategoryTotal> totals) {
  final sums = <String?, BigInt>{};
  for (final t in totals) {
    sums.update(t.categoryId, (v) => v + t.amount, ifAbsent: () => t.amount);
  }
  return _breakdown(sums);
}

/// Receitas recebidas do período, por categoria (relatório 1).
CategoryBreakdown incomeByCategory(Iterable<IncomeLine> lines) {
  final sums = <String?, BigInt>{};
  for (final l in lines) {
    if (!countsAsIncome(l)) continue;
    sums.update(l.categoryId, (v) => v + l.amount!, ifAbsent: () => l.amount!);
  }
  return _breakdown(sums);
}

/// Despesas pendentes ou pagas com valor do período, por categoria
/// (relatório 2). Pagas e pendentes contam uma única vez.
CategoryBreakdown expenseByCategory(Iterable<ExpenseLine> lines) {
  final sums = <String?, BigInt>{};
  for (final l in lines) {
    if (!countsAsExpense(l)) continue;
    sums.update(l.categoryId, (v) => v + l.amount!, ifAbsent: () => l.amount!);
  }
  return _breakdown(sums);
}

/// Lançamentos de um período, para os relatórios de vários períodos.
class PeriodLines {
  const PeriodLines({
    required this.range,
    this.incomes = const [],
    this.expenses = const [],
    this.investments = const [],
  });

  final PeriodRange range;
  final Iterable<IncomeLine> incomes;
  final Iterable<ExpenseLine> expenses;
  final Iterable<InvestmentLine> investments;
}

/// Totais de um período dentro de uma sequência (relatórios 3, 4 e 5).
class PeriodSummary {
  const PeriodSummary({required this.range, required this.totals});

  final PeriodRange range;
  final PeriodTotals totals;
}

/// Totais de cada período, na ordem recebida (cronológica). Período sem
/// lançamentos resulta em zero.
List<PeriodSummary> summarizePeriods(Iterable<PeriodLines> periods) => [
  for (final p in periods)
    PeriodSummary(
      range: p.range,
      totals: computePeriodTotals(
        incomes: p.incomes,
        expenses: p.expenses,
        investments: p.investments,
      ),
    ),
];
