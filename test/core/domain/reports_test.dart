import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/reports.dart';
import 'package:porquinho/core/domain/surplus.dart';

BigInt c(int v) => BigInt.from(v);

IncomeLine inc(String status, int? cents, [String? cat]) => IncomeLine(
  status: status,
  amount: cents == null ? null : c(cents),
  categoryId: cat,
);

ExpenseLine exp(String status, int? cents, [String? cat]) => ExpenseLine(
  status: status,
  amount: cents == null ? null : c(cents),
  categoryId: cat,
);

void main() {
  group('receitas por categoria (relatório 1)', () {
    test('soma por categoria, "Sem categoria" e ordem do maior ao menor', () {
      final r = incomeByCategory([
        inc('received', 300000, 'salario'),
        inc('received', 50000, 'rendimentos'),
        inc('received', 20000, 'salario'),
        inc('received', 10000), // sem categoria
      ]);
      expect(r.items.map((i) => i.categoryId), [
        'salario',
        'rendimentos',
        null,
      ]);
      expect(r.items.map((i) => i.amount), [c(320000), c(50000), c(10000)]);
      expect(r.total, c(380000));
    });

    test('pendentes, canceladas e sem valor ficam fora', () {
      final r = incomeByCategory([
        inc('received', 100000, 'a'),
        inc('pending', 90000, 'a'),
        inc('cancelled', 80000, 'a'),
        inc('received', null, 'a'),
      ]);
      expect(r.total, c(100000));
      expect(r.items.single.amount, c(100000));
    });

    test('rendimento é receita comum, na categoria escolhida', () {
      final r = incomeByCategory([inc('received', 1234, 'rendimentos')]);
      expect(r.items.single.categoryId, 'rendimentos');
    });
  });

  group('despesas por categoria (relatório 2)', () {
    test('paga e pendente contam uma única vez; cancelada e sem valor não', () {
      final r = expenseByCategory([
        exp('pending', 30000, 'mercado'),
        exp('paid', 20000, 'mercado'),
        exp('cancelled', 99999, 'mercado'),
        exp('pending', null, 'cartao'), // variável sem valor
        exp('paid', 5000),
      ]);
      expect(r.items.map((i) => i.categoryId), ['mercado', null]);
      expect(r.total, c(55000));
    });

    test('pagar não muda o total (sem segunda dedução)', () {
      final pending = expenseByCategory([exp('pending', 30000, 'a')]);
      final paid = expenseByCategory([exp('paid', 30000, 'a')]);
      expect(paid.total, pending.total);
    });

    test('empate de valor: ordem estável, "Sem categoria" por último', () {
      final r = expenseByCategory([
        exp('paid', 100),
        exp('paid', 100, 'b'),
        exp('paid', 100, 'a'),
      ]);
      expect(r.items.map((i) => i.categoryId), ['a', 'b', null]);
    });

    test('participação em pontos-base e total zero', () {
      final r = expenseByCategory([
        exp('paid', 7500, 'a'),
        exp('paid', 2500, 'b'),
      ]);
      expect(r.basisPoints(r.items[0]), 7500);
      expect(r.basisPoints(r.items[1]), 2500);
      final empty = expenseByCategory([]);
      expect(empty.total, BigInt.zero);
      expect(empty.items, isEmpty);
    });
  });

  group('os relatórios batem com o dinheiro livre', () {
    final incomes = [
      inc('received', 500000, 'salario'),
      inc('received', 12345),
      inc('pending', 99999, 'salario'),
    ];
    final expenses = [
      exp('pending', 120000, 'moradia'),
      exp('paid', 45000, 'mercado'),
      exp('pending', null, 'cartao'),
      exp('cancelled', 777, 'mercado'),
    ];
    final investments = [
      InvestmentLine(amount: c(80000)),
      InvestmentLine(amount: c(1000), cancelled: true),
    ];

    test('soma dos grupos = receitas e despesas do dinheiro livre', () {
      final totals = computePeriodTotals(
        incomes: incomes,
        expenses: expenses,
        investments: investments,
      );
      expect(incomeByCategory(incomes).total, totals.income);
      expect(expenseByCategory(expenses).total, totals.expense);
      expect(totals.investment, c(80000));
      expect(
        totals.surplus,
        incomeByCategory(incomes).total -
            expenseByCategory(expenses).total -
            totals.investment,
      );
    });
  });

  group('vários períodos (relatórios 3, 4 e 5)', () {
    final p1 = PeriodRange(CalendarDate(2026, 9, 1), CalendarDate(2026, 10, 1));
    final p2 = PeriodRange(
      CalendarDate(2026, 10, 1),
      CalendarDate(2026, 11, 1),
    );
    final p3 = PeriodRange(
      CalendarDate(2026, 11, 1),
      CalendarDate(2026, 12, 1),
    );

    test('totais por período na ordem recebida; período vazio = zero', () {
      final s = summarizePeriods([
        PeriodLines(
          range: p1,
          incomes: [inc('received', 100000)],
          expenses: [exp('paid', 30000)],
          investments: [InvestmentLine(amount: c(20000))],
        ),
        PeriodLines(range: p2),
        PeriodLines(
          range: p3,
          expenses: [exp('pending', 50000)],
          investments: [InvestmentLine(amount: c(1), cancelled: true)],
        ),
      ]);
      expect(s.map((e) => e.range), [p1, p2, p3]);
      expect(s[0].totals.surplus, c(50000));
      expect(s[1].totals, PeriodTotals.zero);
      expect(s[1].totals.surplus, BigInt.zero);
      // Dinheiro livre negativo.
      expect(s[2].totals.surplus, c(-50000));
      expect(s[2].totals.investment, BigInt.zero);
    });

    test('valores acima de 2^53 ficam exatos', () {
      final big = BigInt.parse('9007199254740993'); // 2^53 + 1
      final s = summarizePeriods([
        PeriodLines(
          range: p1,
          incomes: [IncomeLine(status: 'received', amount: big)],
          expenses: [ExpenseLine(status: 'paid', amount: BigInt.one)],
        ),
      ]);
      expect(s.single.totals.income, big);
      expect(s.single.totals.surplus, big - BigInt.one);
      final byCat = incomeByCategory([
        IncomeLine(status: 'received', amount: big, categoryId: 'x'),
        IncomeLine(status: 'received', amount: BigInt.one, categoryId: 'x'),
      ]);
      expect(byCat.total, big + BigInt.one);
    });
  });
}
