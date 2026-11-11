@TestOn('vm')
library;

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/investments/investment_models.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/local_investment_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

class _Source implements RemoteReportSource {
  _Source(this.json);
  final Map<String, dynamic> Function(List<String> ids) json;
  final calls = <List<String>>[];

  @override
  Future<Map<String, dynamic>> fetch(List<String> periodIds) async {
    calls.add(periodIds);
    return json(periodIds);
  }
}

void main() {
  late PorquinhoDatabase db;
  late PeriodService periods;
  late EntryService entries;
  late InvestmentService investments;
  late CategoryService categories;
  late LocalReportsRepository reports;
  late LocalTotalsRepository totals;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    DateTime clock() => DateTime.utc(2026, 11, 10);
    final recorder = LocalChangeRecorder(
      db,
      clock: clock,
      newId: () => 'a${++ids}',
    );
    periods = PeriodService(
      LocalPeriodRepository(db, 'u1', recorder, clock: clock),
      newId: () => 'p${++ids}',
    );
    final catRepo = LocalCategoryRepository(db, 'u1', recorder, clock: clock);
    categories = CategoryService(catRepo, newId: () => 'c${++ids}');
    entries = EntryService(
      LocalEntryRepository(db, 'u1', recorder, clock: clock),
      catRepo,
      periods,
      newId: () => 'e${++ids}',
    );
    investments = InvestmentService(
      LocalInvestmentRepository(db, 'u1', recorder, clock: clock),
      periods,
      newId: () => 'i${++ids}',
    );
    reports = LocalReportsRepository(db, 'u1');
    totals = LocalTotalsRepository(db, 'u1');
    await periods.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
    await periods.createCovering(d(2025, 12, 1));
  });
  tearDown(() => db.close());

  Future<String> pid(CalendarDate date) async =>
      (await periods.periodFor(date))!.id;

  Future<String> category(CategoryKind kind, String name) async {
    await categories.createCategory(kind, name);
    return (await categories.load()).categories
        .firstWhere((x) => x.name == name)
        .id;
  }

  group('celular (banco local)', () {
    test('totais e categorias batem com o cálculo do dinheiro livre', () async {
      final salary = await category(CategoryKind.income, 'Salário');
      final home = await category(CategoryKind.expense, 'Moradia');
      Future<String> add(
        EntryKind kind,
        int cents,
        CalendarDate date, [
        String? cat,
      ]) => entries.create(
        EntryDraft(kind: kind, amount: c(cents), date: date, categoryId: cat),
      );

      await add(EntryKind.income, 500000, d(2026, 11, 1), salary);
      await add(EntryKind.income, 12000, d(2026, 11, 2)); // sem categoria
      await add(EntryKind.expense, 120000, d(2026, 11, 3), home);
      final cancelled = await add(EntryKind.expense, 999, d(2026, 11, 4), home);
      await add(EntryKind.expense, 4000, d(2026, 11, 5)); // sem categoria
      await investments.create(
        InvestmentDraft(amount: c(30000), date: d(2026, 11, 6)),
      );
      final inv2 = await investments.create(
        InvestmentDraft(amount: c(777), date: d(2026, 11, 7)),
      );
      await entries.cancel(
        (await _record(db, entries, EntryKind.expense, cancelled)),
      );
      final invs = await investments.investmentsInPeriod(
        await pid(d(2026, 11, 10)),
      );
      await investments.cancel(invs.firstWhere((i) => i.id == inv2));
      // Outubro: só uma receita.
      await add(EntryKind.income, 1000, d(2026, 10, 9), salary);

      final nov = await pid(d(2026, 11, 10));
      final oct = await pid(d(2026, 10, 10));
      final r = await reports.report([oct, nov, 'inexistente']);

      expect(r.periods.map((p) => p.periodId), [oct, nov, 'inexistente']);
      final novTotals = r.totalsOf(nov);
      expect(novTotals, await totals.totalsFor(nov));
      expect(novTotals.income, c(512000));
      expect(novTotals.expense, c(124000));
      expect(novTotals.investment, c(30000));
      expect(novTotals.surplus, c(358000));
      expect(r.totalsOf(oct).income, c(1000));
      expect(r.totalsOf('inexistente').surplus, BigInt.zero);

      final income = r.incomeOf(nov);
      expect(income.total, novTotals.income);
      expect(income.items.map((i) => i.categoryId), [salary, null]);
      final expense = r.expenseOf(nov);
      expect(expense.total, novTotals.expense);
      expect(expense.items.map((i) => i.categoryId), [home, null]);
      expect(expense.items.map((i) => i.amount), [c(120000), c(4000)]);
      // Período sem lançamentos de despesa: relatório vazio.
      expect(r.expenseOf(oct).items, isEmpty);
    });

    test('mudar a data move o valor para o período da nova data', () async {
      final id = await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: c(5000),
          date: d(2026, 11, 3),
        ),
      );
      final nov = await pid(d(2026, 11, 10));
      final oct = await pid(d(2026, 10, 10));
      expect((await reports.report([nov])).totalsOf(nov).income, c(5000));
      final record = await _record(db, entries, EntryKind.income, id);
      await entries.update(
        record,
        EntryDraft(
          kind: EntryKind.income,
          amount: c(5000),
          date: d(2026, 10, 20),
        ),
      );
      final r = await reports.report([oct, nov]);
      expect(r.totalsOf(nov).income, BigInt.zero);
      expect(r.totalsOf(oct).income, c(5000));
    });

    test('dados de outro usuário não entram', () async {
      await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: c(5000),
          date: d(2026, 11, 3),
        ),
      );
      final nov = await pid(d(2026, 11, 10));
      final other = LocalReportsRepository(db, 'u2');
      expect((await other.report([nov])).totalsOf(nov).income, BigInt.zero);
    });

    test('lista vazia de períodos', () async {
      final r = await reports.report([]);
      expect(r.periods, isEmpty);
    });

    test(
      '12 períodos com ~5.000 lançamentos somam exato e rápido (RN043)',
      () async {
        final all = <String>[];
        final list = await periods.history();
        // Doze períodos criados no setup (dezembro/2025 a novembro/2026).
        for (final item in list) {
          all.add(await pid(item.range.start));
        }
        await db.transaction(() async {
          for (var i = 0; i < 5000; i++) {
            final period = all[i % all.length];
            await db.customStatement(
              'INSERT INTO income_entries (id, owner_id, version, created_at, '
              'updated_at, amount_centavos, status, received_on, '
              'accounting_period_id) VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?)',
              [
                'perf$i',
                'u1',
                '2026-11-10T00:00:00Z',
                '2026-11-10T00:00:00Z',
                '9007199254740993',
                'received',
                '2026-11-05',
                period,
              ],
            );
          }
        });
        final sw = Stopwatch()..start();
        final r = await reports.report(all);
        sw.stop();
        // 5.000 lançamentos de 2^53 + 1 centavos, divididos entre os períodos.
        final sum = r.periods.fold(BigInt.zero, (s, p) => s + p.totals.income);
        expect(sum, BigInt.parse('9007199254740993') * BigInt.from(5000));
        expect(sw.elapsedMilliseconds, lessThan(1000));
      },
    );
  });

  group('Web (leitura agregada do servidor)', () {
    test(
      'lê os totais e as categorias em texto, sem perder precisão',
      () async {
        final source = _Source(
          (ids) => {
            'periods': [
              {
                'period_id': 'p1',
                'income': '9007199254740993',
                'expense': '500',
                'investment': '0',
              },
            ],
            'income_by_category': [
              {
                'period_id': 'p1',
                'category_id': 'a',
                'amount': '9007199254740000',
              },
              {'period_id': 'p1', 'category_id': null, 'amount': '993'},
            ],
            'expense_by_category': [
              {'period_id': 'p1', 'category_id': 'b', 'amount': '500'},
            ],
          },
        );
        final r = await RemoteReportsRepository(source).report(['p1', 'p2']);
        expect(r.totalsOf('p1').income, BigInt.parse('9007199254740993'));
        expect(r.totalsOf('p1').surplus, BigInt.parse('9007199254740493'));
        expect(r.totalsOf('p2').surplus, BigInt.zero);
        expect(r.incomeOf('p1').total, r.totalsOf('p1').income);
        expect(r.incomeOf('p1').items.map((i) => i.categoryId), ['a', null]);
        expect(r.expenseOf('p1').total, c(500));
      },
    );

    test('mais de 60 períodos viram várias chamadas, sem truncar', () async {
      final source = _Source(
        (ids) => {
          'periods': [
            for (final id in ids)
              {
                'period_id': id,
                'income': '100',
                'expense': '0',
                'investment': '0',
              },
          ],
          'income_by_category': [],
          'expense_by_category': [],
        },
      );
      final wanted = [for (var i = 0; i < 130; i++) 'p$i'];
      final r = await RemoteReportsRepository(source).report(wanted);
      expect(source.calls.map((x) => x.length), [60, 60, 10]);
      expect(r.periods.length, 130);
      expect(r.periods.every((p) => p.totals.income == c(100)), isTrue);
    });

    test('mesmos dados, mesmo resultado no celular e na Web', () async {
      final salary = await category(CategoryKind.income, 'Salário');
      await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: c(250000),
          date: d(2026, 11, 3),
          categoryId: salary,
        ),
      );
      await entries.create(
        EntryDraft(
          kind: EntryKind.expense,
          amount: c(80000),
          date: d(2026, 11, 4),
        ),
      );
      await investments.create(
        InvestmentDraft(amount: c(10000), date: d(2026, 11, 5)),
      );
      final nov = await pid(d(2026, 11, 10));
      final local = (await reports.report([nov])).totalsOf(nov);
      // O que o servidor devolveria para os mesmos dados.
      final web = RemoteReportsRepository(
        _Source(
          (ids) => {
            'periods': [
              {
                'period_id': nov,
                'income': local.income.toString(),
                'expense': local.expense.toString(),
                'investment': local.investment.toString(),
              },
            ],
            'income_by_category': [],
            'expense_by_category': [],
          },
        ),
      );
      expect((await web.report([nov])).totalsOf(nov), local);
    });
  });
}

Future<EntryRecord> _record(
  PorquinhoDatabase db,
  EntryService service,
  EntryKind kind,
  String id,
) async {
  final rows = await service.entriesInPeriod(
    (await db
            .customSelect(
              'SELECT accounting_period_id AS p FROM '
              '${kind == EntryKind.income ? 'income_entries' : 'expense_entries'} '
              'WHERE id = ?',
              variables: [Variable.withString(id)],
            )
            .getSingle())
        .read<String>('p'),
  );
  return rows.firstWhere((e) => e.id == id);
}
