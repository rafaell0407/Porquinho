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
  final Map<String, dynamic> Function(List<PeriodRange> ranges) json;
  final calls = <List<PeriodRange>>[];

  @override
  Future<Map<String, dynamic>> fetch(List<PeriodRange> ranges) async {
    calls.add(ranges);
    return json(ranges);
  }
}

PeriodRange month(int y, int m) => PeriodRange(
  CalendarDate(y, m, 1),
  m == 12 ? CalendarDate(y + 1, 1, 1) : CalendarDate(y, m + 1, 1),
);

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
    );
    final catRepo = LocalCategoryRepository(db, 'u1', recorder, clock: clock);
    categories = CategoryService(catRepo, newId: () => 'c${++ids}');
    entries = EntryService(
      LocalEntryRepository(db, 'u1', recorder, clock: clock),
      catRepo,
      newId: () => 'e${++ids}',
    );
    investments = InvestmentService(
      LocalInvestmentRepository(db, 'u1', recorder, clock: clock),
      newId: () => 'i${++ids}',
    );
    reports = LocalReportsRepository(db, 'u1');
    totals = LocalTotalsRepository(db, 'u1');
    await periods.setup(PeriodConfig.calendarMonth());
  });
  tearDown(() => db.close());

  Future<PeriodRange> pid(CalendarDate date) async =>
      (await periods.periodFor(date));

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
      // Período sem registro gravado: soma pelas datas do mesmo jeito.
      final none = month(2030, 1);
      final r = await reports.report([oct, nov, none]);

      expect(r.periods.map((p) => p.range), [oct, nov, none]);
      final novTotals = r.totalsOf(nov);
      expect(novTotals, await totals.totalsFor(nov));
      expect(novTotals.income, c(512000));
      expect(novTotals.expense, c(124000));
      expect(novTotals.investment, c(30000));
      expect(novTotals.surplus, c(358000));
      expect(r.totalsOf(oct).income, c(1000));
      expect(r.totalsOf(none).surplus, BigInt.zero);

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
        // Doze períodos calculados: dezembro/2025 a novembro/2026.
        final all = PeriodCalendar.between(
          PeriodConfig.calendarMonth(),
          d(2025, 12, 1),
          d(2026, 11, 1),
        );
        expect(all, hasLength(12));
        await db.transaction(() async {
          for (var i = 0; i < 5000; i++) {
            final period = all[i % all.length];
            await db.customStatement(
              'INSERT INTO income_entries (id, owner_id, version, created_at, '
              'updated_at, amount_centavos, status, received_on) '
              'VALUES (?, ?, 1, ?, ?, ?, ?, ?)',
              [
                'perf$i',
                'u1',
                '2026-11-10T00:00:00Z',
                '2026-11-10T00:00:00Z',
                '9007199254740993',
                'received',
                period.start.toIso(),
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
        // Cada período recebe a sua parte (5.000 / 12 = 416 ou 417).
        for (final p in r.periods) {
          final n = p.totals.income ~/ BigInt.parse('9007199254740993');
          expect(n.toInt(), anyOf(416, 417), reason: '${p.range}');
        }
        expect(sw.elapsedMilliseconds, lessThan(1000));
      },
    );
  });

  group('Web (leitura agregada do servidor)', () {
    test(
      'lê os totais e as categorias em texto, sem perder precisão',
      () async {
        final source = _Source(
          (ranges) => {
            'ranges': [
              {
                'index': 1,
                'income': '9007199254740993',
                'expense': '500',
                'investment': '0',
              },
            ],
            'income_by_category': [
              {'index': 1, 'category_id': 'a', 'amount': '9007199254740000'},
              {'index': 1, 'category_id': null, 'amount': '993'},
            ],
            'expense_by_category': [
              {'index': 1, 'category_id': 'b', 'amount': '500'},
            ],
          },
        );
        final p1 = month(2026, 11);
        final p2 = month(2026, 12);
        final r = await RemoteReportsRepository(source).report([p1, p2]);
        expect(source.calls.single, [p1, p2]);
        expect(r.totalsOf(p1).income, BigInt.parse('9007199254740993'));
        expect(r.totalsOf(p1).surplus, BigInt.parse('9007199254740493'));
        expect(r.totalsOf(p2).surplus, BigInt.zero);
        expect(r.incomeOf(p1).total, r.totalsOf(p1).income);
        expect(r.incomeOf(p1).items.map((i) => i.categoryId), ['a', null]);
        expect(r.expenseOf(p1).total, c(500));
      },
    );

    test('mais de 60 períodos viram várias chamadas, sem truncar', () async {
      final source = _Source(
        (ranges) => {
          'ranges': [
            for (var i = 0; i < ranges.length; i++)
              {
                'index': i + 1,
                'income': '${100 + i}',
                'expense': '0',
                'investment': '0',
              },
          ],
          'income_by_category': [],
          'expense_by_category': [],
        },
      );
      final wanted = [
        for (var i = 0; i < 130; i++) month(2020 + i ~/ 12, i % 12 + 1),
      ];
      final r = await RemoteReportsRepository(source).report(wanted);
      expect(source.calls.map((x) => x.length), [60, 60, 10]);
      expect(r.periods.length, 130);
      // A posição devolvida pelo servidor é relativa a cada chamada.
      expect(r.totalsOf(wanted[0]).income, c(100));
      expect(r.totalsOf(wanted[61]).income, c(101));
      expect(r.totalsOf(wanted[129]).income, c(109));
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
          (ranges) => {
            'ranges': [
              {
                'index': 1,
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
  final date =
      (await db
              .customSelect(
                'SELECT ${kind.dateColumn} AS d FROM ${kind.table} WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .read<String>('d');
  final rows = await service.entriesInPeriod(
    PeriodCalendar.containing(
      PeriodConfig.calendarMonth(),
      CalendarDate.parse(date),
    ),
  );
  return rows.firstWhere((e) => e.id == id);
}
