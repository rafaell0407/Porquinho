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
import 'package:porquinho/features/entries/entry_form_screen.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_providers.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_providers.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

class _Gateway implements SyncRemoteGateway {
  final rpcs = <String>[];

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    rpcs.add(rpc);
    return {'status': 'applied'};
  }
}

void main() {
  late PorquinhoDatabase db;
  late CategoryService categories;
  late EntryService entries;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    final recorder = LocalChangeRecorder(db, newId: () => 'a${++ids}');
    final periods = PeriodService(
      LocalPeriodRepository(db, 'u1', recorder),
      newId: () => 'p${++ids}',
    );
    final catRepo = LocalCategoryRepository(db, 'u1', recorder);
    categories = CategoryService(catRepo, newId: () => 'c${++ids}');
    entries = EntryService(
      LocalEntryRepository(db, 'u1', recorder),
      catRepo,
      periods,
      newId: () => 'e${++ids}',
    );
    await periods.setup(
      PeriodConfig.calendarMonth(),
      CalendarDate(2026, 11, 10),
    );
  });
  tearDown(() => db.close());

  Future<void> pumpForm(WidgetTester tester, Widget form) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userClockProvider.overrideWithValue(
            UserClock(now: () => DateTime.utc(2026, 11, 10, 15)),
          ),
          entryServiceProvider.overrideWith((ref) async => entries),
          categoryServiceProvider.overrideWith((ref) async => categories),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => form)),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  final saveCategory = find.byKey(const Key('salvar-categoria'));

  /// Abre o seletor e escolhe "Nova categoria" (abre o editor).
  Future<void> chooseNew(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('campo-categoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nova-categoria-form')));
    await tester.pumpAndSettle();
  }

  testWidgets('cria categoria do tipo do lançamento e a seleciona', (
    tester,
  ) async {
    await pumpForm(tester, const EntryFormScreen(kind: EntryKind.expense));
    await chooseNew(tester);
    await tester.enterText(find.byKey(const Key('campo-nome')), 'Mercado');
    await tester.ensureVisible(find.byKey(const Key('icone-car')));
    await tester.tap(find.byKey(const Key('icone-car')));
    await tester.tap(find.byKey(const Key('cor-blue')));
    await tester.tap(saveCategory);
    await tester.pumpAndSettle();

    final cats = (await categories.load()).categories;
    expect(cats.single.name, 'Mercado');
    expect(cats.single.kind.dbValue, 'expense');
    expect(cats.single.iconKey, 'car');
    expect(cats.single.colorKey, 'blue');
    expect(
      find.descendant(
        of: find.byKey(const Key('campo-categoria')),
        matching: find.text('Mercado'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('nome inválido não cria; cancelar mantém a seleção anterior', (
    tester,
  ) async {
    await categories.createCategory(CategoryKind.income, 'Salário');
    await pumpForm(tester, const EntryFormScreen(kind: EntryKind.income));
    await chooseNew(tester);
    await tester.tap(saveCategory);
    await tester.pumpAndSettle();
    expect(find.text('Informe um nome.'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect((await categories.load()).categories.length, 1);
    expect(
      find.descendant(
        of: find.byKey(const Key('campo-categoria')),
        matching: find.text('Sem categoria'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('escolhe categoria e subcategoria existentes no seletor', (
    tester,
  ) async {
    final id = await categories.createCategory(CategoryKind.expense, 'Mercado');
    await categories.createSubcategory(
      (await categories.load()).categories.single,
      'Feira',
    );
    await categories.createCategory(CategoryKind.income, 'Salário');
    await pumpForm(tester, const EntryFormScreen(kind: EntryKind.expense));

    await tester.tap(find.byKey(const Key('campo-categoria')));
    await tester.pumpAndSettle();
    // Só aparecem categorias de despesa.
    expect(find.text('Salário'), findsNothing);
    expect(find.byKey(Key('categoria-$id')), findsOneWidget);

    // Busca pelo nome da subcategoria mostra a categoria dela.
    await tester.enterText(find.byKey(const Key('buscar-categoria')), 'feira');
    await tester.pumpAndSettle();
    expect(find.text('Feira'), findsOneWidget);
    expect(find.byKey(const Key('sem-categoria')), findsNothing);

    await tester.tap(find.text('Feira'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('campo-categoria')),
        matching: find.text('Mercado › Feira'),
      ),
      findsOneWidget,
    );

    // Volta para "Sem categoria".
    await tester.tap(find.byKey(const Key('campo-categoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sem-categoria')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('campo-categoria')),
        matching: find.text('Sem categoria'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('não aparece no modo investimento', (tester) async {
    await pumpForm(tester, const EntryFormScreen.investment());
    expect(find.byKey(const Key('campo-categoria')), findsNothing);
  });

  testWidgets('offline: categoria sai da fila antes do lançamento', (
    tester,
  ) async {
    await pumpForm(tester, const EntryFormScreen(kind: EntryKind.expense));
    await chooseNew(tester);
    await tester.enterText(find.byKey(const Key('campo-nome')), 'Mercado');
    await tester.tap(saveCategory);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor')), '10,00');
    await tester.tap(find.byKey(const Key('salvar-lancamento')));
    await tester.pumpAndSettle();

    final gateway = _Gateway();
    await SyncService(db, gateway).syncOnce('u1');
    final catIndex = gateway.rpcs.indexOf('apply_category_change');
    final entryIndex = gateway.rpcs.indexWhere((r) => r.contains('entry'));
    expect(catIndex, isNonNegative);
    expect(entryIndex, greaterThan(catIndex));
  });
}
