@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/dashboard/dashboard_screen.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_providers.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_navigation.dart';
import 'package:porquinho/features/periods/period_providers.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);

void main() {
  late PorquinhoDatabase db;
  late PeriodService periods;
  late EntryService service;
  late LocalEntryRepository repo;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    final recorder = LocalChangeRecorder(db, newId: () => 'a${++ids}');
    periods = PeriodService(
      LocalPeriodRepository(db, 'u1', recorder),
      newId: () => 'p${++ids}',
    );
    final cats = LocalCategoryRepository(db, 'u1', recorder);
    repo = LocalEntryRepository(db, 'u1', recorder);
    service = EntryService(repo, cats, periods, newId: () => 'e${++ids}');
    await periods.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
    CategoryService(cats); // garante o mesmo conjunto de dependências
  });
  tearDown(() => db.close());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userClockProvider.overrideWithValue(
            UserClock(now: () => DateTime.utc(2026, 11, 10, 15)),
          ),
          periodServiceProvider.overrideWith((ref) async => periods),
          entryServiceProvider.overrideWith((ref) async => service),
          totalsRepositoryProvider.overrideWith(
            (ref) async => LocalTotalsRepository(db, 'u1'),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
  }

  Future<void> add(EntryKind kind, int cents, CalendarDate date) => service
      .create(EntryDraft(kind: kind, amount: BigInt.from(cents), date: date));

  testWidgets('mostra só a sobra, sem saldo', (tester) async {
    await add(EntryKind.income, 500000, d(2026, 11, 5));
    await add(EntryKind.expense, 120000, d(2026, 11, 6));
    await pump(tester);
    expect(find.text('Sobra do período'), findsOneWidget);
    expect(find.text('R\$ 3.800,00'), findsOneWidget);
    expect(find.textContaining('Saldo'), findsNothing);
    expect(find.textContaining('saldo'), findsNothing);
  });

  testWidgets('sobra negativa e sem lançamentos', (tester) async {
    await pump(tester);
    expect(find.text('R\$ 0,00'), findsOneWidget);
    await add(EntryKind.expense, 10000, d(2026, 11, 6));
    final container = await pump(tester);
    expect(find.text('-R\$ 100,00'), findsOneWidget);
    expect(container, isNotNull);
  });

  testWidgets('editar um período antigo recalcula aquele período', (
    tester,
  ) async {
    await periods.createCovering(d(2026, 10, 1));
    await add(EntryKind.income, 100000, d(2026, 10, 5));
    await add(EntryKind.income, 40000, d(2026, 11, 5));
    final container = await pump(tester);
    expect(find.text('R\$ 400,00'), findsOneWidget);

    // Vai para outubro.
    await tester.tap(find.byKey(const Key('periodo-anterior')));
    await tester.pumpAndSettle();
    expect(find.text('01/10/2026 a 31/10/2026'), findsOneWidget);
    expect(find.text('R\$ 1.000,00'), findsOneWidget);

    // Edita a receita de outubro para 1.500,00 e recalcula só outubro.
    final october = (await periods.periodFor(d(2026, 10, 5)))!;
    final entry = (await repo.entriesInPeriod(october.id)).single;
    await service.update(
      entry,
      EntryDraft(
        kind: EntryKind.income,
        amount: BigInt.from(150000),
        date: d(2026, 10, 5),
      ),
    );
    container
      ..invalidate(selectedPeriodProvider)
      ..invalidate(periodTotalsProvider);
    await tester.pumpAndSettle();
    expect(find.text('R\$ 1.500,00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('periodo-hoje')));
    await tester.pumpAndSettle();
    expect(find.text('R\$ 400,00'), findsOneWidget);
  });

  testWidgets('período futuro inexistente: pergunta antes de criar', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('periodo-proximo')));
    await tester.pumpAndSettle();
    expect(
      find.text('Criar o período de 01/12/2026 a 31/12/2026?'),
      findsOneWidget,
    );
    expect(await periods.periodFor(d(2026, 12, 5)), isNull);
  });
}
