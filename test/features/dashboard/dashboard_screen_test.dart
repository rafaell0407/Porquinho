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
import 'package:porquinho/features/investments/investment_models.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/local_investment_repository.dart';
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
  late InvestmentService investments;
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
    investments = InvestmentService(
      LocalInvestmentRepository(db, 'u1', recorder),
      periods,
      newId: () => 'i${++ids}',
    );
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

  String shown(WidgetTester tester, String key) {
    final w = tester.widget<Text>(find.byKey(Key(key)));
    return w.data ?? w.textSpan!.toPlainText();
  }

  Future<void> add(EntryKind kind, int cents, CalendarDate date) => service
      .create(EntryDraft(kind: kind, amount: BigInt.from(cents), date: date));

  testWidgets('mostra o dinheiro livre, sem saldo', (tester) async {
    await add(EntryKind.income, 500000, d(2026, 11, 5));
    await add(EntryKind.expense, 120000, d(2026, 11, 6));
    await pump(tester);
    expect(find.text('Dinheiro livre do período'), findsOneWidget);
    expect(find.text('R\$ 3.800,00'), findsOneWidget);
    expect(find.textContaining('Saldo'), findsNothing);
    expect(find.textContaining('saldo'), findsNothing);
  });

  testWidgets('dinheiro livre negativo e sem lançamentos', (tester) async {
    await pump(tester);
    expect(shown(tester, 'valor-sobra'), 'R\$ 0,00');
    expect(shown(tester, 'valor-receitas'), 'R\$ 0,00');
    expect(shown(tester, 'valor-despesas'), 'R\$ 0,00');
    expect(shown(tester, 'valor-investimentos'), 'R\$ 0,00');
    await add(EntryKind.expense, 10000, d(2026, 11, 6));
    final container = await pump(tester);
    expect(shown(tester, 'valor-sobra'), '-R\$ 100,00');
    expect(container, isNotNull);
  });

  testWidgets('editar um período antigo recalcula aquele período', (
    tester,
  ) async {
    await periods.createCovering(d(2026, 10, 1));
    await add(EntryKind.income, 100000, d(2026, 10, 5));
    await add(EntryKind.income, 40000, d(2026, 11, 5));
    final container = await pump(tester);
    expect(shown(tester, 'valor-sobra'), 'R\$ 400,00');

    // Vai para outubro.
    await tester.tap(find.byKey(const Key('periodo-anterior')));
    await tester.pumpAndSettle();
    expect(find.text('Outubro 2026'), findsOneWidget);
    expect(shown(tester, 'valor-sobra'), 'R\$ 1.000,00');

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
    expect(shown(tester, 'valor-sobra'), 'R\$ 1.500,00');

    await tester.tap(find.byKey(const Key('periodo-hoje')));
    await tester.pumpAndSettle();
    expect(shown(tester, 'valor-sobra'), 'R\$ 400,00');
  });

  group('composição do dinheiro livre (D1)', () {
    // Receitas − despesas − investimentos exibidos = dinheiro livre exibido.
    BigInt cents(WidgetTester tester, String key) {
      final text = shown(tester, key)
          .replaceAll('R\$', '')
          .replaceAll('.', '')
          .replaceAll(',', '')
          .replaceAll(' ', '');
      return BigInt.parse(text);
    }

    void expectConsistent(WidgetTester tester) {
      expect(
        cents(tester, 'valor-receitas') -
            cents(tester, 'valor-despesas') -
            cents(tester, 'valor-investimentos'),
        cents(tester, 'valor-sobra'),
      );
    }

    testWidgets('mostra receitas, despesas e investimentos', (tester) async {
      await add(EntryKind.income, 500000, d(2026, 11, 5));
      await add(EntryKind.expense, 120000, d(2026, 11, 6));
      await investments.create(
        InvestmentDraft(amount: BigInt.from(30000), date: d(2026, 11, 7)),
      );
      await pump(tester);
      expect(find.text('Receitas'), findsOneWidget);
      expect(find.text('Despesas'), findsOneWidget);
      expect(find.text('Investimentos'), findsOneWidget);
      expect(shown(tester, 'valor-receitas'), 'R\$ 5.000,00');
      expect(shown(tester, 'valor-despesas'), 'R\$ 1.200,00');
      expect(shown(tester, 'valor-investimentos'), 'R\$ 300,00');
      expect(shown(tester, 'valor-sobra'), 'R\$ 3.500,00');
      expectConsistent(tester);
    });

    testWidgets('pagar não muda; cancelar tira; mudar a data move', (
      tester,
    ) async {
      final expenseId = await service.create(
        EntryDraft(
          kind: EntryKind.expense,
          amount: BigInt.from(40000),
          date: d(2026, 11, 6),
        ),
      );
      await add(EntryKind.income, 100000, d(2026, 11, 5));
      final investmentId = await investments.create(
        InvestmentDraft(amount: BigInt.from(10000), date: d(2026, 11, 7)),
      );
      final container = await pump(tester);
      final period = (await periods.periodFor(d(2026, 11, 6)))!;
      expect(shown(tester, 'valor-sobra'), 'R\$ 500,00');

      void refresh() {
        container
          ..invalidate(selectedPeriodProvider)
          ..invalidate(periodTotalsProvider);
      }

      // Pagar: status muda, valores iguais (sem segunda dedução).
      final expense = (await repo.entriesInPeriod(
        period.id,
      )).firstWhere((e) => e.id == expenseId);
      await service.pay(expense, d(2026, 11, 8));
      refresh();
      await tester.pumpAndSettle();
      expect(shown(tester, 'valor-despesas'), 'R\$ 400,00');
      expect(shown(tester, 'valor-sobra'), 'R\$ 500,00');
      expectConsistent(tester);

      // Mudar a data do investimento para outubro tira do mês atual.
      await periods.createCovering(d(2026, 10, 1));
      final investment = (await investments.investmentsInPeriod(
        period.id,
      )).firstWhere((i) => i.id == investmentId);
      await investments.update(
        investment,
        InvestmentDraft(amount: BigInt.from(10000), date: d(2026, 10, 7)),
      );
      refresh();
      await tester.pumpAndSettle();
      expect(shown(tester, 'valor-investimentos'), 'R\$ 0,00');
      expect(shown(tester, 'valor-sobra'), 'R\$ 600,00');
      expectConsistent(tester);

      // Cancelar a despesa tira do cálculo.
      final paid = (await repo.entriesInPeriod(
        period.id,
      )).firstWhere((e) => e.id == expenseId);
      await service.cancel(paid);
      refresh();
      await tester.pumpAndSettle();
      expect(shown(tester, 'valor-despesas'), 'R\$ 0,00');
      expect(shown(tester, 'valor-sobra'), 'R\$ 1.000,00');
      expectConsistent(tester);
    });

    testWidgets('período anterior mostra a composição daquele período', (
      tester,
    ) async {
      await periods.createCovering(d(2026, 10, 1));
      await investments.create(
        InvestmentDraft(amount: BigInt.from(25000), date: d(2026, 10, 7)),
      );
      await add(EntryKind.income, 100000, d(2026, 11, 5));
      await pump(tester);
      expect(shown(tester, 'valor-investimentos'), 'R\$ 0,00');
      await tester.tap(find.byKey(const Key('periodo-anterior')));
      await tester.pumpAndSettle();
      expect(shown(tester, 'valor-investimentos'), 'R\$ 250,00');
      expect(shown(tester, 'valor-receitas'), 'R\$ 0,00');
      expect(shown(tester, 'valor-sobra'), '-R\$ 250,00');
      expectConsistent(tester);
    });
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
