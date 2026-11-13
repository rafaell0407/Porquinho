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
import 'package:porquinho/features/categories/category_providers.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_providers.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/investments/investment_providers.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/local_investment_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_providers.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/totals/totals_repository.dart';
import 'package:porquinho/features/transactions/transactions_screen.dart';

void main() {
  late PorquinhoDatabase db;
  late LocalEntryRepository entries;
  late PeriodService periods;
  late EntryService service;
  late CategoryService categories;
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
    final catRepo = LocalCategoryRepository(db, 'u1', recorder);
    categories = CategoryService(catRepo, newId: () => 'c${++ids}');
    entries = LocalEntryRepository(db, 'u1', recorder);
    investments = InvestmentService(
      LocalInvestmentRepository(db, 'u1', recorder),
      periods,
      newId: () => 'i${++ids}',
    );
    service = EntryService(entries, catRepo, periods, newId: () => 'e${++ids}');
    await periods.setup(
      PeriodConfig.calendarMonth(),
      CalendarDate(2026, 11, 10),
    );
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userClockProvider.overrideWithValue(
            UserClock(now: () => DateTime.utc(2026, 11, 10, 15)),
          ),
          periodServiceProvider.overrideWith((ref) async => periods),
          entryServiceProvider.overrideWith((ref) async => service),
          investmentServiceProvider.overrideWith((ref) async => investments),
          categoryServiceProvider.overrideWith((ref) async => categories),
          totalsRepositoryProvider.overrideWith(
            (ref) async => LocalTotalsRepository(db, 'u1'),
          ),
        ],
        child: const MaterialApp(home: TransactionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cadastra receita e despesa, filtra, paga e cancela', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Nenhum lançamento neste período.'), findsOneWidget);
    expect(find.text('01/11/2026 a 30/11/2026'), findsOneWidget);

    // Receita.
    await tester.tap(find.byKey(const Key('novo-lancamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nova-receita')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(
      find.text('Informe um valor.'),
      findsOneWidget,
      reason: 'valor obrigatório',
    );
    await tester.enterText(find.byKey(const Key('campo-valor')), '1,234');
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(find.text('Use no máximo duas casas decimais.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo-valor')), '1.234,56');
    await tester.enterText(find.byKey(const Key('campo-descricao')), 'Salário');
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(find.text('+ R\$ 1.234,56'), findsOneWidget);
    expect(find.textContaining('Recebida'), findsOneWidget);

    // Despesa já paga.
    await tester.tap(find.byKey(const Key('novo-lancamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nova-despesa')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor')), '200');
    await tester.enterText(find.byKey(const Key('campo-descricao')), 'Luz');
    await tester.tap(find.byKey(const Key('ja-paga')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(find.text('- R\$ 200,00'), findsOneWidget);
    expect(find.textContaining('Paga'), findsOneWidget);

    // Filtro por tipo.
    await tester.tap(find.byKey(const Key('filtro-expense')));
    await tester.pumpAndSettle();
    expect(find.text('Luz'), findsOneWidget);
    expect(find.text('Salário'), findsNothing);
    await tester.tap(find.byKey(const Key('filtro-income')));
    await tester.pumpAndSettle();
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Luz'), findsNothing);
    await tester.tap(find.byKey(const Key('filtro-all')));
    await tester.pumpAndSettle();

    // Cancelar a despesa: confirma e ela some da lista.
    await tester.tap(find.text('Luz'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acao-cancelar')));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar este lançamento?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar-cancelar')));
    await tester.pumpAndSettle();
    expect(find.text('Luz'), findsNothing);

    final periodId = (await periods.periodFor(CalendarDate(2026, 11, 10)))!.id;
    final t = await LocalTotalsRepository(db, 'u1').totalsFor(periodId);
    expect(t.surplus, BigInt.from(123456));
  });

  testWidgets('despesa pendente pode ser paga pela lista', (tester) async {
    await service.create(
      EntryDraft(
        kind: EntryKind.expense,
        amount: BigInt.from(5000),
        date: CalendarDate(2026, 11, 3),
        description: 'Água',
      ),
    );
    await pumpScreen(tester);
    expect(find.textContaining('Pendente'), findsOneWidget);
    await tester.tap(find.text('Água'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acao-pagar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paga'), findsOneWidget);
  });

  testWidgets('navegar para período inexistente pergunta antes de criar', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('periodo-anterior')));
    await tester.pumpAndSettle();
    expect(find.text('01/10/2026 a 31/10/2026'), findsOneWidget);
    expect(find.byKey(const Key('pergunta-periodos')), findsOneWidget);
    expect(
      find.text('Criar o período de 01/10/2026 a 31/10/2026?'),
      findsOneWidget,
    );
    expect((await periods.periodFor(CalendarDate(2026, 10, 5))), isNull);

    await tester.tap(find.byKey(const Key('criar-periodos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pergunta-periodos')), findsNothing);
    expect(await periods.periodFor(CalendarDate(2026, 10, 5)), isNotNull);

    await tester.tap(find.byKey(const Key('periodo-hoje')));
    await tester.pumpAndSettle();
    expect(find.text('01/11/2026 a 30/11/2026'), findsOneWidget);
  });

  testWidgets('data em período inexistente pede confirmação e só então salva', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('novo-lancamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nova-receita')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor')), '100');
    await tester.tap(find.byKey(const Key('campo-data')));
    await tester.pumpAndSettle();
    // Seletor de data: volta dois meses pelo calendário.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('15/09/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(find.text('Período ainda não existe'), findsOneWidget);
    expect(
      find.text('Criar os 2 períodos de setembro de 2026 a outubro de 2026?'),
      findsOneWidget,
    );
    expect(
      await db
          .customSelect('SELECT COUNT(*) AS n FROM income_entries')
          .getSingle()
          .then((r) => r.read<int>('n')),
      0,
    );

    await tester.tap(find.byKey(const Key('confirmar-periodos')));
    await tester.pumpAndSettle();
    final n = await db
        .customSelect('SELECT COUNT(*) AS n FROM income_entries')
        .getSingle();
    expect(n.read<int>('n'), 1);
    final p = await db
        .customSelect('SELECT COUNT(*) AS n FROM accounting_periods')
        .getSingle();
    expect(p.read<int>('n'), 3);
  });

  testWidgets('investimento: criar, filtrar, editar a data, cancelar (D10)', (
    tester,
  ) async {
    await pumpScreen(tester);
    Future<BigInt> surplusNow() async {
      final periodId = (await periods.periodFor(
        CalendarDate(2026, 11, 10),
      ))!.id;
      return (await LocalTotalsRepository(
        db,
        'u1',
      ).totalsFor(periodId)).surplus;
    }

    // Formulário só com valor e data.
    await tester.tap(find.byKey(const Key('novo-lancamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('novo-investimento')));
    await tester.pumpAndSettle();
    expect(find.text('Novo investimento'), findsOneWidget);
    expect(find.text('Valor investido'), findsOneWidget);
    expect(find.text('Data do investimento'), findsOneWidget);
    expect(find.byKey(const Key('campo-descricao')), findsNothing);
    expect(find.byKey(const Key('campo-categoria')), findsNothing);
    expect(find.byKey(const Key('campo-vencimento')), findsNothing);
    expect(find.byKey(const Key('ja-paga')), findsNothing);
    expect(find.byKey(const Key('repetir')), findsOneWidget);
    expect(find.byKey(const Key('valor-variavel')), findsNothing);

    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(find.text('Informe um valor.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo-valor')), '300,50');
    await tester.tap(find.text('Salvar investimento'));
    await tester.pumpAndSettle();
    expect(find.text('- R\$ 300,50'), findsOneWidget);
    expect(find.text('Investimento'), findsOneWidget);
    expect(await surplusNow(), BigInt.from(-30050));

    // Filtros.
    await tester.tap(find.byKey(const Key('filtro-expense')));
    await tester.pumpAndSettle();
    expect(find.text('- R\$ 300,50'), findsNothing);
    await tester.tap(find.byKey(const Key('filtro-investment')));
    await tester.pumpAndSettle();
    expect(find.text('- R\$ 300,50'), findsOneWidget);

    // Editar o valor.
    await tester.tap(find.text('Investimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acao-editar')));
    await tester.pumpAndSettle();
    expect(find.text('Editar investimento'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo-valor')), '500');
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(find.text('- R\$ 500,00'), findsOneWidget);
    expect(await surplusNow(), BigInt.from(-50000));

    // Cancelar: confirma, some da lista e sai da sobra.
    await tester.tap(find.text('Investimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acao-cancelar')));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar este investimento?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar-cancelar')));
    await tester.pumpAndSettle();
    expect(find.text('Investimento'), findsNothing);
    expect(await surplusNow(), BigInt.zero);
  });

  testWidgets('investimento: lista vazia e data em período inexistente', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('filtro-investment')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum investimento neste período.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('novo-lancamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('novo-investimento')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor')), '100');
    await tester.tap(find.byKey(const Key('campo-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();
    expect(find.text('Período ainda não existe'), findsOneWidget);
    expect(
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM investment_allocations')
              .getSingle())
          .read<int>('n'),
      0,
    );
    await tester.tap(find.byKey(const Key('confirmar-periodos')));
    await tester.pumpAndSettle();
    expect(
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM investment_allocations')
              .getSingle())
          .read<int>('n'),
      1,
    );
  });
}
