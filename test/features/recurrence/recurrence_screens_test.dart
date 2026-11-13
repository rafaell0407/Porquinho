@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/recurrence_schedule.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/category_providers.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_providers.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/investments/investment_models.dart';
import 'package:porquinho/features/investments/investment_providers.dart';
import 'package:porquinho/features/investments/investment_recurrence_service.dart';
import 'package:porquinho/features/investments/local_investment_recurrence_repository.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/local_investment_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_providers.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/recurrence/local_recurrence_repository.dart';
import 'package:porquinho/features/recurrence/recurrence_providers.dart';
import 'package:porquinho/features/recurrence/recurrence_service.dart';
import 'package:porquinho/features/recurrence/recurrences_screen.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/totals/totals_repository.dart';
import 'package:porquinho/features/transactions/transactions_screen.dart';

void main() {
  late PorquinhoDatabase db;
  late PeriodService periods;
  late EntryService service;
  late CategoryService categories;
  late RecurrenceService recurrences;
  late InvestmentService investments;
  late LocalInvestmentRecurrenceRepository investmentTemplates;
  late LocalRecurrenceRepository recurrenceRepo;
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
    recurrenceRepo = LocalRecurrenceRepository(db, 'u1', recorder);
    recurrences = RecurrenceService(recurrenceRepo, catRepo);
    service = EntryService(
      LocalEntryRepository(db, 'u1', recorder),
      catRepo,
      periods,
      recurrences: recurrenceRepo,
      newId: () => 'e${++ids}',
    );
    investmentTemplates = LocalInvestmentRecurrenceRepository(
      db,
      'u1',
      recorder,
    );
    investments = InvestmentService(
      LocalInvestmentRepository(db, 'u1', recorder),
      periods,
      newId: () => 'i${++ids}',
    );
    await periods.setup(
      PeriodConfig.calendarMonth(),
      CalendarDate(2026, 11, 10),
    );
  });

  tearDown(() => db.close());

  List<Override> overrides() => [
    userClockProvider.overrideWithValue(
      UserClock(now: () => DateTime.utc(2026, 11, 10, 15)),
    ),
    periodServiceProvider.overrideWith((ref) async => periods),
    entryServiceProvider.overrideWith((ref) async => service),
    investmentServiceProvider.overrideWith((ref) async => investments),
    investmentRecurrenceServiceProvider.overrideWith(
      (ref) async => InvestmentRecurrenceService(investmentTemplates),
    ),
    categoryServiceProvider.overrideWith((ref) async => categories),
    recurrenceServiceProvider.overrideWith((ref) async => recurrences),
    recurrenceRepositoryProvider.overrideWith((ref) async => recurrenceRepo),
    totalsRepositoryProvider.overrideWith(
      (ref) async => LocalTotalsRepository(db, 'u1'),
    ),
  ];

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Repetir: receita nasce pendente, confirma o recebimento e vira '
      'recorrência na lista', (tester) async {
    await pump(tester, const TransactionsScreen());

    await tester.tap(find.byKey(const Key('novo-lancamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nova-receita')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor')), '3000');
    await tester.enterText(find.byKey(const Key('campo-descricao')), 'Salário');
    await tester.tap(find.byKey(const Key('repetir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('repetir-monthly')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('frequencia')), findsOneWidget);
    expect(find.byKey(const Key('ja-recebi')), findsOneWidget);
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();

    // Pendente: aparece como "A receber" e a sobra continua zerada.
    expect(find.textContaining('A receber'), findsOneWidget);
    expect(find.textContaining('Recorrente'), findsOneWidget);
    final period = (await periods.periodFor(CalendarDate(2026, 11, 10)))!;
    var totals = await LocalTotalsRepository(db, 'u1').totalsFor(period.id);
    expect(totals.surplus, BigInt.zero);

    // Confirma o recebimento (data de hoje no seletor).
    await tester.tap(find.text('Salário'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acao-receber')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recebida'), findsOneWidget);
    totals = await LocalTotalsRepository(db, 'u1').totalsFor(period.id);
    expect(totals.surplus, BigInt.from(300000));
  });

  testWidgets('Despesa variável: informa o valor depois e ela entra na sobra', (
    tester,
  ) async {
    await pump(tester, const TransactionsScreen());
    await tester.tap(find.byKey(const Key('novo-lancamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nova-despesa')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-descricao')), 'Cartão');
    await tester.tap(find.byKey(const Key('repetir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('repetir-monthly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('valor-variavel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(find.text('Informar valor'), findsOneWidget);

    await tester.tap(find.text('Cartão'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acao-informar-valor')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-valor-ocorrencia')),
      '1500',
    );
    await tester.tap(find.byKey(const Key('confirmar-valor')));
    await tester.pumpAndSettle();
    expect(find.text('- R\$ 1.500,00'), findsOneWidget);
    final period = (await periods.periodFor(CalendarDate(2026, 11, 10)))!;
    final totals = await LocalTotalsRepository(db, 'u1').totalsFor(period.id);
    expect(totals.surplus, BigInt.from(-150000));
  });

  testWidgets('Mais → Recorrências lista, edita e para a recorrência', (
    tester,
  ) async {
    await service.create(
      _expense(1000, CalendarDate(2026, 11, 5)),
      repeat: _monthly,
    );
    await pump(tester, const RecurrencesScreen());
    expect(find.textContaining('Todo dia 5'), findsOneWidget);

    await tester.tap(find.textContaining('Todo dia 5'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acao-parar-recorrencia')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-parar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Interrompida'), findsOneWidget);
  });

  testWidgets('Repetir no investimento: sem pagar/vencimento, lista, edita o '
      'valor de um mês e das próximas, para de repetir', (tester) async {
    await pump(tester, const TransactionsScreen());

    await tester.tap(find.byKey(const Key('novo-lancamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('novo-investimento')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor')), '300');
    await tester.tap(find.byKey(const Key('repetir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('repetir-monthly')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('frequencia')), findsOneWidget);
    expect(find.byKey(const Key('valor-variavel')), findsNothing);
    expect(find.byKey(const Key('ja-recebi')), findsNothing);
    expect(find.byKey(const Key('ja-paga')), findsNothing);
    expect(find.byKey(const Key('campo-vencimento')), findsNothing);
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Recorrente'), findsOneWidget);
    expect(find.text('- R\$ 300,00'), findsOneWidget);
    final period = (await periods.periodFor(CalendarDate(2026, 11, 10)))!;
    final totals = LocalTotalsRepository(db, 'u1');
    expect((await totals.totalsFor(period.id)).surplus, BigInt.from(-30000));

    // "Editar só esta": muda o valor deste mês; o modelo não muda.
    await tester.tap(find.text('Investimento'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('acao-pagar')), findsNothing);
    expect(find.text('Editar só esta'), findsOneWidget);
    await tester.tap(find.byKey(const Key('acao-editar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('repetir')), findsNothing);
    await tester.enterText(find.byKey(const Key('campo-valor')), '450');
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(find.text('- R\$ 450,00'), findsOneWidget);
    expect((await totals.totalsFor(period.id)).surplus, BigInt.from(-45000));
    final template = (await investmentTemplates.templates()).single;
    expect(template.defaultAmount, BigInt.from(30000));

    // "Editar a recorrência": muda o valor das próximas, não o deste mês.
    await tester.tap(find.text('Investimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acao-editar-recorrencia')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor')), '600');
    await tester.tap(find.byKey(const Key('salvar-recorrencia')));
    await tester.pumpAndSettle();
    expect(
      (await investmentTemplates.templates()).single.defaultAmount,
      BigInt.from(60000),
    );
    expect((await totals.totalsFor(period.id)).surplus, BigInt.from(-45000));
  });

  testWidgets('Mais → Recorrências lista investimento recorrente e permite '
      'parar de repetir', (tester) async {
    await investments.create(
      InvestmentDraft(
        amount: BigInt.from(25000),
        date: CalendarDate(2026, 11, 5),
      ),
      repeat: RecurrenceFrequency.monthly,
    );
    await pump(tester, const RecurrencesScreen());
    expect(find.textContaining('Todo dia 5'), findsOneWidget);
    expect(find.textContaining('R\$ 250,00'), findsOneWidget);

    await tester.tap(find.textContaining('Todo dia 5'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('acao-editar-recorrencia')), findsOneWidget);
    await tester.tap(find.byKey(const Key('acao-parar-recorrencia')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-parar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Interrompida'), findsOneWidget);
    expect((await investmentTemplates.templates()).single.isActive, isFalse);
  });
}

const _monthly = RepeatChoice(frequency: RecurrenceFrequency.monthly);

EntryDraft _expense(int cents, CalendarDate date) => EntryDraft(
  kind: EntryKind.expense,
  amount: BigInt.from(cents),
  date: date,
  description: 'Academia',
);
