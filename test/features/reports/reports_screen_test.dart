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
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_providers.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_providers.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/investments/investment_models.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/local_investment_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_navigation.dart';
import 'package:porquinho/features/periods/period_providers.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/reports/reports_providers.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/reports/reports_screen.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

void main() {
  late PorquinhoDatabase db;
  late PeriodService periods;
  late EntryService entries;
  late InvestmentService investments;
  late CategoryService categories;
  late LocalEntryRepository entryRepo;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    final recorder = LocalChangeRecorder(db, newId: () => 'a${++ids}');
    periods = PeriodService(
      LocalPeriodRepository(db, 'u1', recorder),
      newId: () => 'p${++ids}',
    );
    final catRepo = LocalCategoryRepository(db, 'u1', recorder);
    categories = CategoryService(catRepo, newId: () => 'c${++ids}');
    entryRepo = LocalEntryRepository(db, 'u1', recorder);
    entries = EntryService(
      entryRepo,
      catRepo,
      periods,
      newId: () => 'e${++ids}',
    );
    investments = InvestmentService(
      LocalInvestmentRepository(db, 'u1', recorder),
      periods,
      newId: () => 'i${++ids}',
    );
    await periods.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
  });
  tearDown(() => db.close());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userClockProvider.overrideWithValue(
            UserClock(now: () => DateTime.utc(2026, 11, 10, 15)),
          ),
          periodServiceProvider.overrideWith((ref) async => periods),
          categoryServiceProvider.overrideWith((ref) async => categories),
          reportsRepositoryProvider.overrideWith(
            (ref) async => LocalReportsRepository(db, 'u1'),
          ),
          totalsRepositoryProvider.overrideWith(
            (ref) async => LocalTotalsRepository(db, 'u1'),
          ),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(ReportsScreen)),
    );
  }

  Future<void> choose(WidgetTester tester, ReportKind kind) async {
    await tester.tap(find.byKey(const Key('seletor-relatorio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kind.title).last);
    await tester.pumpAndSettle();
  }

  Future<String> category(CategoryKind kind, String name) async {
    await categories.createCategory(kind, name);
    return (await categories.load()).categories
        .firstWhere((x) => x.name == name)
        .id;
  }

  Future<String> add(
    EntryKind kind,
    int cents,
    CalendarDate date, [
    String? cat,
  ]) => entries.create(
    EntryDraft(kind: kind, amount: c(cents), date: date, categoryId: cat),
  );

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  void refresh(ProviderContainer container) {
    container
      ..invalidate(selectedPeriodProvider)
      ..invalidate(categoryDataProvider);
  }

  group('relatórios por categoria e investimentos (1, 2 e 3)', () {
    testWidgets('receitas: categorias, "Sem categoria", total e participação', (
      tester,
    ) async {
      final salary = await category(CategoryKind.income, 'Salário');
      final yields = await category(CategoryKind.income, 'Rendimentos');
      await add(EntryKind.income, 300000, d(2026, 11, 1), salary);
      await add(EntryKind.income, 50000, d(2026, 11, 2), yields);
      await add(EntryKind.income, 50000, d(2026, 11, 3));
      await pump(tester);
      expect(text(tester, 'total-relatorio'), 'R\$ 4.000,00');
      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('Rendimentos'), findsOneWidget);
      expect(find.text('Sem categoria'), findsOneWidget);
      expect(find.text('75,0%'), findsOneWidget);
      expect(find.text('12,5%'), findsNWidgets(2));
    });

    testWidgets('receita recorrente pendente e cancelada ficam fora', (
      tester,
    ) async {
      final id = await add(EntryKind.income, 10000, d(2026, 11, 1));
      final other = await add(EntryKind.income, 5000, d(2026, 11, 2));
      final period = (await periods.periodFor(d(2026, 11, 1)))!;
      final record = (await entryRepo.entriesInPeriod(
        period.id,
      )).firstWhere((e) => e.id == other);
      await entries.cancel(record);
      await pump(tester);
      expect(id, isNotEmpty);
      expect(text(tester, 'total-relatorio'), 'R\$ 100,00');
    });

    testWidgets('despesas: paga e pendente contam uma vez', (tester) async {
      final home = await category(CategoryKind.expense, 'Moradia');
      final paid = await add(EntryKind.expense, 120000, d(2026, 11, 2), home);
      await add(EntryKind.expense, 30000, d(2026, 11, 3), home);
      await add(EntryKind.expense, 10000, d(2026, 11, 4));
      final period = (await periods.periodFor(d(2026, 11, 2)))!;
      await entries.pay(
        (await entryRepo.entriesInPeriod(
          period.id,
        )).firstWhere((e) => e.id == paid),
        d(2026, 11, 9),
      );
      await pump(tester);
      await choose(tester, ReportKind.expenseByCategory);
      expect(text(tester, 'total-relatorio'), 'R\$ 1.600,00');
      expect(find.text('Moradia'), findsOneWidget);
      expect(find.text('R\$ 1.500,00'), findsOneWidget);
      expect(find.text('Sem categoria'), findsOneWidget);
    });

    testWidgets('categoria desativada aparece; renomear muda o nome', (
      tester,
    ) async {
      final cat = await category(CategoryKind.expense, 'Lazer');
      await add(EntryKind.expense, 5000, d(2026, 11, 2), cat);
      var data = await categories.load();
      await categories.deactivateCategory(
        data.categories.firstWhere((x) => x.id == cat),
      );
      await pump(tester);
      await choose(tester, ReportKind.expenseByCategory);
      expect(find.text('Lazer'), findsOneWidget);
      data = await categories.load();
      await categories.renameCategory(
        data.categories.firstWhere((x) => x.id == cat),
        'Diversão',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReportsScreen)),
      );
      refresh(container);
      await tester.pumpAndSettle();
      expect(find.text('Lazer'), findsNothing);
      expect(find.text('Diversão'), findsOneWidget);
    });

    testWidgets('investimentos: total do período; cancelado fica fora', (
      tester,
    ) async {
      await investments.create(
        InvestmentDraft(amount: c(30000), date: d(2026, 11, 3)),
      );
      final second = await investments.create(
        InvestmentDraft(amount: c(1000), date: d(2026, 11, 4)),
      );
      final period = (await periods.periodFor(d(2026, 11, 3)))!;
      await investments.cancel(
        (await investments.investmentsInPeriod(
          period.id,
        )).firstWhere((i) => i.id == second),
      );
      await pump(tester);
      await choose(tester, ReportKind.investments);
      expect(text(tester, 'total-investimentos'), 'R\$ 300,00');
    });

    testWidgets('período sem dados', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('relatorio-vazio')), findsOneWidget);
      expect(text(tester, 'total-relatorio'), 'R\$ 0,00');
      await choose(tester, ReportKind.investments);
      expect(text(tester, 'total-investimentos'), 'R\$ 0,00');
    });

    testWidgets('edição e cancelamento aparecem na leitura seguinte', (
      tester,
    ) async {
      final id = await add(EntryKind.income, 10000, d(2026, 11, 1));
      final container = await pump(tester);
      expect(text(tester, 'total-relatorio'), 'R\$ 100,00');
      final period = (await periods.periodFor(d(2026, 11, 1)))!;
      final record = (await entryRepo.entriesInPeriod(
        period.id,
      )).firstWhere((e) => e.id == id);
      await entries.update(
        record,
        EntryDraft(
          kind: EntryKind.income,
          amount: c(25000),
          date: d(2026, 11, 1),
        ),
      );
      refresh(container);
      await tester.pumpAndSettle();
      expect(text(tester, 'total-relatorio'), 'R\$ 250,00');
      final edited = (await entryRepo.entriesInPeriod(
        period.id,
      )).firstWhere((e) => e.id == id);
      await entries.cancel(edited);
      refresh(container);
      await tester.pumpAndSettle();
      expect(text(tester, 'total-relatorio'), 'R\$ 0,00');
    });

    testWidgets('totais batem com o dinheiro livre do mesmo período', (
      tester,
    ) async {
      final cat = await category(CategoryKind.income, 'Salário');
      await add(EntryKind.income, 500000, d(2026, 11, 1), cat);
      await add(EntryKind.expense, 120000, d(2026, 11, 2));
      await investments.create(
        InvestmentDraft(amount: c(30000), date: d(2026, 11, 3)),
      );
      final container = await pump(tester);
      final period = (await periods.periodFor(d(2026, 11, 1)))!;
      final totals = await LocalTotalsRepository(db, 'u1').totalsFor(period.id);
      expect(text(tester, 'total-relatorio'), 'R\$ ${_money(totals.income)}');
      await choose(tester, ReportKind.expenseByCategory);
      expect(text(tester, 'total-relatorio'), 'R\$ ${_money(totals.expense)}');
      await choose(tester, ReportKind.investments);
      expect(
        text(tester, 'total-investimentos'),
        'R\$ ${_money(totals.investment)}',
      );
      expect(container, isNotNull);
    });

    testWidgets('período futuro inexistente pergunta antes de criar', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('periodo-proximo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pergunta-periodos')), findsOneWidget);
    });
  });

  group('evolução e comparativo (4 e 5)', () {
    testWidgets('evolução: cada linha bate com o dinheiro livre do período', (
      tester,
    ) async {
      await periods.createCovering(d(2026, 9, 1));
      await add(EntryKind.income, 100000, d(2026, 9, 5));
      await add(EntryKind.income, 200000, d(2026, 10, 5));
      await add(EntryKind.expense, 50000, d(2026, 10, 6));
      await add(EntryKind.expense, 30000, d(2026, 11, 6)); // negativo
      await pump(tester);
      await choose(tester, ReportKind.evolution);
      for (final start in ['2026-09-01', '2026-10-01', '2026-11-01']) {
        expect(find.byKey(Key('evolucao-$start')), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('evolucao-2026-09-01')),
          matching: find.text('R\$ 1.000,00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('evolucao-2026-10-01')),
          matching: find.text('R\$ 1.500,00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('evolucao-2026-11-01')),
          matching: find.text('-R\$ 300,00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('mostra no máximo 12 períodos e navega para trás', (
      tester,
    ) async {
      await periods.createCovering(d(2025, 9, 1)); // 15 períodos até nov/2026
      await pump(tester);
      await choose(tester, ReportKind.evolution);
      expect(find.textContaining('Últimos 12 períodos'), findsOneWidget);
      expect(find.byKey(const Key('evolucao-2025-12-01')), findsOneWidget);
      expect(find.byKey(const Key('evolucao-2025-11-01')), findsNothing);
      // Voltando um período, a janela termina em outubro e inclui novembro/25.
      await tester.tap(find.byKey(const Key('periodo-anterior')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('evolucao-2026-11-01')), findsNothing);
      expect(find.byKey(const Key('evolucao-2025-11-01')), findsOneWidget);
    });

    testWidgets('sequência atravessa mudança de configuração', (tester) async {
      await periods.scheduleChange(
        PeriodConfig.customCycle(20),
        d(2026, 11, 10),
      );
      await periods.ensureUpTo(d(2027, 1, 25));
      await add(EntryKind.income, 10000, d(2026, 12, 10)); // transição
      await add(EntryKind.income, 20000, d(2026, 12, 25));
      await pump(tester);
      // Período atual do app é o de novembro; vai até o mais recente.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('periodo-proximo')));
        await tester.pumpAndSettle();
      }
      await choose(tester, ReportKind.comparison);
      expect(find.text('01/12/2026 a 19/12/2026'), findsOneWidget);
      expect(find.text('20/12/2026 a 19/01/2027'), findsOneWidget);
      expect(text(tester, 'comp-receitas-2026-12-01'), 'R\$ 100,00');
      expect(text(tester, 'comp-receitas-2026-12-20'), 'R\$ 200,00');
    });

    testWidgets('comparativo: receitas, despesas, investimentos e livre', (
      tester,
    ) async {
      await add(EntryKind.income, 500000, d(2026, 11, 1));
      await add(EntryKind.expense, 120000, d(2026, 11, 2));
      await investments.create(
        InvestmentDraft(amount: c(30000), date: d(2026, 11, 3)),
      );
      await pump(tester);
      await choose(tester, ReportKind.comparison);
      expect(text(tester, 'comp-receitas-2026-11-01'), 'R\$ 5.000,00');
      expect(text(tester, 'comp-despesas-2026-11-01'), 'R\$ 1.200,00');
      expect(text(tester, 'comp-invest-2026-11-01'), 'R\$ 300,00');
      expect(text(tester, 'comp-livre-2026-11-01'), 'R\$ 3.500,00');
    });

    testWidgets('período futuro vazio fica com zeros', (tester) async {
      await periods.createCovering(d(2026, 12, 5));
      await pump(tester);
      await tester.tap(find.byKey(const Key('periodo-proximo')));
      await tester.pumpAndSettle();
      await choose(tester, ReportKind.comparison);
      expect(text(tester, 'comp-livre-2026-12-01'), 'R\$ 0,00');
      expect(text(tester, 'comp-receitas-2026-12-01'), 'R\$ 0,00');
    });
  });
}

String _money(BigInt cents) {
  final s = cents.toString().padLeft(3, '0');
  final reais = s.substring(0, s.length - 2);
  final grouped = reais.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '$grouped,${s.substring(s.length - 2)}';
}
