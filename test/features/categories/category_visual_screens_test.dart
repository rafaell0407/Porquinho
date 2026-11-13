@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/app/theme/norte_theme.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/categories_screen.dart';
import 'package:porquinho/features/categories/category_editor.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_picker.dart';
import 'package:porquinho/features/categories/category_providers.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';

/// Telas de categoria com o tema do Norte, claro e escuro, num celular
/// pequeno (360x640): nada pode estourar a tela nem dar erro de layout.
void main() {
  late PorquinhoDatabase db;
  late CategoryService service;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    service = CategoryService(
      LocalCategoryRepository(
        db,
        'u1',
        LocalChangeRecorder(db, newId: () => 'a${++ids}'),
      ),
      newId: () => 'c${++ids}',
    );
    await service.addSuggestions(
      income: ['Salário'],
      expense: ['Moradia', 'Alimentação', 'Transporte'],
    );
    final data = await service.load();
    await service.createSubcategory(
      data.categories.firstWhere((c) => c.name == 'Alimentação'),
      'Supermercado com um nome bem comprido para testar',
    );
  });
  tearDown(() => db.close());

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(ThemeData theme, Widget home) => ProviderScope(
    overrides: [categoryServiceProvider.overrideWith((ref) async => service)],
    child: MaterialApp(theme: theme, home: home),
  );

  final themes = {'claro': NorteTheme.light(), 'escuro': NorteTheme.dark()};

  for (final entry in themes.entries) {
    group('tema ${entry.key}', () {
      testWidgets('lista de categorias mostra visual e subcategorias', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(app(entry.value, const CategoriesScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Salário'), findsOneWidget);
        await tester.tap(find.text('Despesas'));
        await tester.pumpAndSettle();
        expect(find.text('Moradia'), findsOneWidget);
        expect(find.textContaining('Supermercado com um nome'), findsOneWidget);
        expect(find.byIcon(Icons.home_outlined), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('editor: escolhe ícone e cor e devolve o resultado', (
        tester,
      ) async {
        phone(tester);
        CategoryDraft? result;
        await tester.pumpWidget(
          app(
            entry.value,
            Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showCategoryEditor(
                  context,
                  title: 'Nova categoria de despesa',
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('campo-nome')), 'Pets');
        await tester.ensureVisible(find.byKey(const Key('icone-pets')));
        await tester.tap(find.byKey(const Key('icone-pets')));
        await tester.ensureVisible(find.byKey(const Key('cor-pink')));
        await tester.tap(find.byKey(const Key('cor-pink')));
        await tester.ensureVisible(find.byKey(const Key('salvar-categoria')));
        await tester.tap(find.byKey(const Key('salvar-categoria')));
        await tester.pumpAndSettle();
        expect(result?.name, 'Pets');
        expect(result?.iconKey, 'pets');
        expect(result?.colorKey, 'pink');
        expect(tester.takeException(), isNull);
      });

      testWidgets('seletor: lista, busca e resultado', (tester) async {
        phone(tester);
        final data = await service.load();
        final alimentacao = data.categories.firstWhere(
          (c) => c.name == 'Alimentação',
        );
        CategoryPick? result;
        await tester.pumpWidget(
          app(
            entry.value,
            Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showCategoryPicker(
                  context,
                  data: data,
                  kind: CategoryKind.expense,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        expect(find.text('Moradia'), findsOneWidget);
        expect(find.text('Salário'), findsNothing);

        await tester.enterText(
          find.byKey(const Key('buscar-categoria')),
          'zzz',
        );
        await tester.pumpAndSettle();
        expect(find.text('Nenhuma categoria encontrada.'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('buscar-categoria')), '');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('categoria-${alimentacao.id}')));
        await tester.pumpAndSettle();
        expect(result, isA<PickedCategory>());
        expect((result! as PickedCategory).categoryId, alimentacao.id);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
