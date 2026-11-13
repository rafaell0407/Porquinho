@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/recurrence_schedule.dart';
import 'package:porquinho/core/domain/surplus.dart';
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
import 'package:porquinho/features/recurrence/local_recurrence_repository.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

/// Entrega 58 (D4, D5, RN007, RN008, RN044): rendimento é receita comum,
/// lançada pelo usuário; investimento desconta a sobra; nada automático.
void main() {
  late PorquinhoDatabase db;
  late PeriodService periods;
  late EntryService entries;
  late InvestmentService investments;
  late CategoryService categories;
  late LocalRecurrenceRepository generator;
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
    generator = LocalRecurrenceRepository(db, 'u1', null, clock: clock);
    totals = LocalTotalsRepository(db, 'u1');
    await periods.setup(PeriodConfig.calendarMonth());
  });
  tearDown(() => db.close());

  Future<PeriodTotals> totalsOf(CalendarDate date) async =>
      totals.totalsFor((await periods.periodFor(date)));

  test('sem lançamento nenhum, não existe rendimento nem sobra', () async {
    final t = await totalsOf(d(2026, 11, 10));
    expect(t.surplus, BigInt.zero);
    expect(t.income, BigInt.zero);
    // Investir não gera rendimento: só desconta.
    await investments.create(
      InvestmentDraft(amount: c(100000), date: d(2026, 11, 5)),
    );
    final after = await totalsOf(d(2026, 11, 10));
    expect(after.income, BigInt.zero, reason: 'nenhum rendimento automático');
    expect(after.surplus, c(-100000));
  });

  test(
    'rendimento é receita comum, pela data de recebimento (RN007/RN008)',
    () async {
      await categories.createCategory(CategoryKind.income, 'Rendimentos');
      final category = (await categories.load()).categories.single;
      await investments.create(
        InvestmentDraft(amount: c(100000), date: d(2026, 10, 5)),
      );
      // Rendimento informado pelo usuário, em outro mês: soma no mês dele.
      await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: c(2500),
          date: d(2026, 11, 3),
          categoryId: category.id,
        ),
      );
      final october = await totalsOf(d(2026, 10, 10));
      final november = await totalsOf(d(2026, 11, 10));
      expect(october.income, BigInt.zero);
      expect(october.surplus, c(-100000), reason: 'investimento de outubro');
      expect(november.income, c(2500));
      expect(november.surplus, c(2500), reason: 'rendimento de novembro');
    },
  );

  test(
    'sobra desconta investimentos avulsos e recorrentes uma única vez',
    () async {
      await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: c(500000),
          date: d(2026, 11, 1),
        ),
      );
      await entries.create(
        EntryDraft(
          kind: EntryKind.expense,
          amount: c(120000),
          date: d(2026, 11, 2),
        ),
      );
      await investments.create(
        InvestmentDraft(amount: c(30000), date: d(2026, 11, 4)),
      );
      await investments.create(
        InvestmentDraft(amount: c(50000), date: d(2026, 9, 5)),
        repeat: RecurrenceFrequency.monthly,
      );
      await generator.generateDue(d(2026, 11, 10));
      // Gerar de novo não desconta de novo.
      await generator.generateDue(d(2026, 11, 10));

      final november = await totalsOf(d(2026, 11, 10));
      // 5.000 - 1.200 - 300 (avulso) - 500 (recorrente de novembro) = 3.000
      expect(november.surplus, c(300000));
      final september = await totalsOf(d(2026, 9, 10));
      expect(september.surplus, c(-50000));
      final october = await totalsOf(d(2026, 10, 10));
      expect(october.surplus, c(-50000));
    },
  );

  test(
    'não existe resgate: cancelar devolve ao período original (D5)',
    () async {
      await investments.create(
        InvestmentDraft(amount: c(80000), date: d(2026, 9, 12)),
      );
      expect((await totalsOf(d(2026, 9, 12))).surplus, c(-80000));
      final september = await periods.periodFor(d(2026, 9, 12));
      final record = (await investments.investmentsInPeriod(september)).single;
      await investments.cancel(record);
      expect((await totalsOf(d(2026, 9, 12))).surplus, BigInt.zero);
      expect((await totalsOf(d(2026, 11, 10))).surplus, BigInt.zero);
    },
  );
}
