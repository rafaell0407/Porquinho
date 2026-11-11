@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

    Future<void> seedPeriod(String id, String start, String end) async {
      await db.customStatement(
        'INSERT OR IGNORE INTO period_configurations (id, owner_id, version, '
        "created_at, updated_at, mode, effective_from) VALUES ('cfg', 'u1', 1, "
        "'x', 'x', 'calendar_month', '2026-01-01')",
      );
      await db.customStatement(
        'INSERT INTO accounting_periods (id, owner_id, version, created_at, '
        'updated_at, configuration_id, start_date, end_date) '
        "VALUES (?, 'u1', 1, 'x', 'x', 'cfg', ?, ?)",
        [id, start, end],
      );
    }

    Future<void> income(
      String id,
      String status,
      String? amount,
      String? period,
    ) => db.customStatement(
      'INSERT INTO income_entries (id, owner_id, version, created_at, '
      'updated_at, status, amount_centavos, received_on, accounting_period_id) '
      "VALUES (?, 'u1', 1, 'x', 'x', ?, ?, ?, ?)",
      [id, status, amount, period == null ? null : '2026-11-05', period],
    );

    Future<void> expense(
      String id,
      String status,
      String? amount,
      String period,
    ) => db.customStatement(
      'INSERT INTO expense_entries (id, owner_id, version, created_at, '
      'updated_at, status, amount_centavos, competence_on, '
      'accounting_period_id, paid_on) '
      "VALUES (?, 'u1', 1, 'x', 'x', ?, ?, '2026-11-05', ?, ?)",
      [id, status, amount, period, status == 'paid' ? '2026-11-06' : null],
    );

    test('só entra o que pertence ao período; outro não interfere', () async {
      await seedPeriod('p11', '2026-11-01', '2026-12-01');
      await seedPeriod('p12', '2026-12-01', '2027-01-01');
      await income('i1', 'received', '500000', 'p11');
      await income('i2', 'received', '100000', 'p12');
      await expense('e1', 'pending', '120000', 'p11');
      await expense('e2', 'paid', '30000', 'p11');
      await expense('e3', 'cancelled', '99999', 'p11');
      await db.customStatement(
        'INSERT INTO investment_allocations (id, owner_id, version, '
        'created_at, updated_at, amount_centavos, allocated_on, '
        "accounting_period_id) VALUES ('v1', 'u1', 1, 'x', 'x', '50000', "
        "'2026-11-07', 'p11')",
      );

      final repo = LocalTotalsRepository(db, 'u1');
      final t = await repo.totalsFor('p11');
      expect(t.income, c(500000));
      expect(t.expense, c(150000));
      expect(t.investment, c(50000));
      expect(t.surplus, c(300000));
      expect((await repo.totalsFor('p12')).surplus, c(100000));
    });

    test('isolamento por usuário', () async {
      await seedPeriod('p11', '2026-11-01', '2026-12-01');
      await income('i1', 'received', '500000', 'p11');
      final other = LocalTotalsRepository(db, 'outro');
      expect((await other.totalsFor('p11')).surplus, BigInt.zero);
    });

    test('recálculo com 5.000 lançamentos em até 300 ms (RN043)', () async {
      await seedPeriod('p11', '2026-11-01', '2026-12-01');
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
      final t = await repo.totalsFor('p11');
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
      'periods': [
        {
          'period_id': 'p11',
          'income': '100000',
          'expense': '25000',
          'investment': '10000',
        },
      ],
      'income_by_category': [],
      'expense_by_category': [],
    });
    final repo = RemoteTotalsRepository(RemoteReportsRepository(source));
    final t = await repo.totalsFor('p11');
    expect(t.surplus, c(65000));
    // Período sem linha no servidor = zero.
    expect((await repo.totalsFor('outro')).surplus, BigInt.zero);
  });
}

class _Source implements RemoteReportSource {
  _Source(this.json);
  final Map<String, dynamic> json;

  @override
  Future<Map<String, dynamic>> fetch(List<String> periodIds) async => json;
}
