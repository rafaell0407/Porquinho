@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/surplus.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

BigInt c(int v) => BigInt.from(v);

void main() {
  group('fórmula da sobra', () {
    test('receita recebida entra; pendente e cancelada não', () {
      final t = computePeriodTotals(
        incomes: [
          IncomeLine(status: 'received', amount: c(100000)),
          IncomeLine(status: 'pending', amount: c(50000)),
          IncomeLine(status: 'cancelled', amount: c(70000)),
        ],
      );
      expect(t.income, c(100000));
      expect(t.surplus, c(100000));
    });

    test('despesa pendente entra e pagar não deduz de novo', () {
      final pending = computePeriodTotals(
        expenses: [ExpenseLine(status: 'pending', amount: c(30000))],
      );
      final paid = computePeriodTotals(
        expenses: [ExpenseLine(status: 'paid', amount: c(30000))],
      );
      expect(pending.expense, c(30000));
      expect(paid, pending, reason: 'pagar não altera a sobra');
    });

    test('despesa cancelada sai; variável sem valor não entra; zero entra', () {
      final t = computePeriodTotals(
        expenses: [
          ExpenseLine(status: 'cancelled', amount: c(30000)),
          const ExpenseLine(status: 'pending', amount: null),
          ExpenseLine(status: 'pending', amount: BigInt.zero),
        ],
      );
      expect(t.expense, BigInt.zero);
    });

    test('investimento deduz; cancelado não', () {
      final t = computePeriodTotals(
        incomes: [IncomeLine(status: 'received', amount: c(100000))],
        expenses: [ExpenseLine(status: 'pending', amount: c(40000))],
        investments: [
          InvestmentLine(amount: c(20000)),
          InvestmentLine(amount: c(99999), cancelled: true),
        ],
      );
      expect(t.surplus, c(40000));
    });

    test('sobra negativa e valores acima de 2^53 são exatos', () {
      final big = BigInt.parse('9007199254740993');
      final t = computePeriodTotals(
        incomes: [IncomeLine(status: 'received', amount: c(1))],
        expenses: [ExpenseLine(status: 'pending', amount: big)],
      );
      expect(t.surplus, c(1) - big);
      expect(t.surplus.isNegative, isTrue);
    });
  });

  group('consulta por período', () {
    late PorquinhoDatabase db;
    setUp(() => db = PorquinhoDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    // A data de cada lançamento fica dentro do período a que ele pertence.
    String dateOf(String period) =>
        period == 'p12' ? '2026-12-05' : '2026-11-05';
    final nov = PeriodRange(
      CalendarDate(2026, 11, 1),
      CalendarDate(2026, 12, 1),
    );
    final dec = PeriodRange(
      CalendarDate(2026, 12, 1),
      CalendarDate(2027, 1, 1),
    );

    Future<void> income(
      String id,
      String status,
      String? amount,
      String? period,
    ) => db.customStatement(
      'INSERT INTO income_entries (id, owner_id, version, created_at, '
      'updated_at, status, amount_centavos, received_on) '
      "VALUES (?, 'u1', 1, 'x', 'x', ?, ?, ?)",
      [id, status, amount, period == null ? null : dateOf(period)],
    );

    Future<void> expense(
      String id,
      String status,
      String? amount,
      String period,
    ) => db.customStatement(
      'INSERT INTO expense_entries (id, owner_id, version, created_at, '
      'updated_at, status, amount_centavos, competence_on, paid_on) '
      "VALUES (?, 'u1', 1, 'x', 'x', ?, ?, ?, ?)",
      [
        id,
        status,
        amount,
        dateOf(period),
        status == 'paid' ? '2026-11-06' : null,
      ],
    );

    test('só entra o que pertence ao período; outro não interfere', () async {
      await income('i1', 'received', '500000', 'p11');
      await income('i2', 'received', '100000', 'p12');
      await expense('e1', 'pending', '120000', 'p11');
      await expense('e2', 'paid', '30000', 'p11');
      await expense('e3', 'cancelled', '99999', 'p11');
      await db.customStatement(
        'INSERT INTO investment_allocations (id, owner_id, version, '
        'created_at, updated_at, amount_centavos, allocated_on) '
        "VALUES ('v1', 'u1', 1, 'x', 'x', '50000', '2026-11-07')",
      );

      final repo = LocalTotalsRepository(db, 'u1');
      final t = await repo.totalsFor(nov);
      expect(t.income, c(500000));
      expect(t.expense, c(150000));
      expect(t.investment, c(50000));
      expect(t.surplus, c(300000));
      expect((await repo.totalsFor(dec)).surplus, c(100000));
    });

    test('isolamento por usuário', () async {
      await income('i1', 'received', '500000', 'p11');
      final other = LocalTotalsRepository(db, 'outro');
      expect((await other.totalsFor(nov)).surplus, BigInt.zero);
    });

    test('recálculo com 5.000 lançamentos em até 300 ms (RN043)', () async {
      await db.transaction(() async {
        for (var i = 0; i < 2500; i++) {
          await income('i$i', 'received', '${1000 + i}', 'p11');
          await expense(
            'e$i',
            i.isEven ? 'pending' : 'paid',
            '${500 + i}',
            'p11',
          );
        }
      });
      final repo = LocalTotalsRepository(db, 'u1');
      final sw = Stopwatch()..start();
      final t = await repo.totalsFor(nov);
      sw.stop();
      expect(t.income > BigInt.zero, isTrue);
      expect(
        sw.elapsedMilliseconds,
        lessThan(300),
        reason: '${sw.elapsedMilliseconds} ms',
      );
    });
  });

  test('Web usa o total somado pelo servidor (texto exato)', () async {
    final source = _Source({
      'ranges': [
        {
          'index': 1,
          'income': '100000',
          'expense': '25000',
          'investment': '10000',
        },
      ],
      'income_by_category': [],
      'expense_by_category': [],
    });
    final repo = RemoteTotalsRepository(RemoteReportsRepository(source));
    final nov = PeriodRange(
      CalendarDate(2026, 11, 1),
      CalendarDate(2026, 12, 1),
    );
    final t = await repo.totalsFor(nov);
    expect(t.surplus, c(65000));
  });
}

class _Source implements RemoteReportSource {
  _Source(this.json);
  final Map<String, dynamic> json;

  @override
  Future<Map<String, dynamic>> fetch(List<PeriodRange> ranges) async => json;
}
