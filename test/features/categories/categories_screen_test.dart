import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/categories/categories_screen.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_providers.dart';
import 'package:porquinho/features/categories/category_repository.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/category_suggestions_screen.dart';

/// Repositório em memória: aplica as alterações como o banco faria.
class MemoryCategoryRepository implements CategoryRepository {
  final cats = <CategoryRecord>[];
  final subs = <SubcategoryRecord>[];

  @override
  Future<List<CategoryRecord>> categories() async => [...cats];

  @override
  Future<List<SubcategoryRecord>> subcategories() async => [...subs];

  @override
  Future<void> apply(List<CategoryChange> changes) async {
    for (final c in changes) {
      switch (c) {
        case CreateCategory():
          cats.add(
            CategoryRecord(
              id: c.id,
              kind: c.kind,
              name: c.name,
              isActive: true,
              version: 1,
              iconKey: c.iconKey ?? 'category',
              colorKey: c.colorKey ?? 'gray',
            ),
          );
        case EditCategory():
          _replace(
            c.category,
            name: c.name,
            iconKey: c.iconKey,
            colorKey: c.colorKey,
          );
        case RenameCategory():
          _replace(c.category, name: c.name);
        case DeactivateCategory():
          _replace(c.category, active: false);
        case CreateSubcategory():
          subs.add(
            SubcategoryRecord(
              id: c.id,
              categoryId: c.categoryId,
              name: c.name,
              isActive: true,
              version: 1,
            ),
          );
        case RenameSubcategory():
          final i = subs.indexWhere((s) => s.id == c.subcategory.id);
          subs[i] = SubcategoryRecord(
            id: c.subcategory.id,
            categoryId: c.subcategory.categoryId,
            name: c.name,
            isActive: c.subcategory.isActive,
            version: c.subcategory.version + 1,
          );
        case DeactivateSubcategory():
          final i = subs.indexWhere((s) => s.id == c.subcategory.id);
          subs[i] = SubcategoryRecord(
            id: c.subcategory.id,
            categoryId: c.subcategory.categoryId,
            name: c.subcategory.name,
            isActive: false,
            version: c.subcategory.version + 1,
          );
      }
    }
  }

  void _replace(
    CategoryRecord old, {
    String? name,
    bool? active,
    String? iconKey,
    String? colorKey,
  }) {
    final i = cats.indexWhere((c) => c.id == old.id);
    cats[i] = CategoryRecord(
      id: old.id,
      kind: old.kind,
      name: name ?? old.name,
      isActive: active ?? old.isActive,
      version: old.version + 1,
    );
  }
}

void main() {
  late MemoryCategoryRepository repo;
  var ids = 0;

  Widget app(Widget home) => ProviderScope(
    overrides: [
      categoryServiceProvider.overrideWith(
        (ref) async => CategoryService(repo, newId: () => 'id${++ids}'),
      ),
    ],
    child: MaterialApp(home: home),
  );

  setUp(() {
    repo = MemoryCategoryRepository();
    ids = 0;
  });

  testWidgets('cria, renomeia, cria subcategoria e desativa', (tester) async {
    await tester.pumpWidget(app(const CategoriesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma categoria ainda.'), findsOneWidget);

    // Nome vazio é recusado no diálogo.
    await tester.tap(find.byKey(const Key('nova-categoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um nome.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-nome')), 'Salário');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Salário'), findsOneWidget);
    expect(repo.cats.single.kind, CategoryKind.income);

    // Aba Despesas tem lista própria.
    await tester.tap(find.text('Despesas'));
    await tester.pumpAndSettle();
    expect(find.text('Salário'), findsNothing);
    await tester.tap(find.byKey(const Key('nova-categoria')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-nome')), 'Mercado');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(repo.cats.last.kind, CategoryKind.expense);

    // Editar (nome, ícone e cor).
    await tester.tap(find.byKey(Key('menu-${repo.cats.last.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-nome')), 'Supermercado');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Supermercado'), findsOneWidget);

    // Subcategoria.
    await tester.tap(find.text('Supermercado'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('nova-sub-${repo.cats.last.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-nome')), 'Feira');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Feira'), findsOneWidget);
    expect(repo.subs.single.categoryId, repo.cats.last.id);

    // Desativar: sai da lista ativa e aparece em "Desativadas".
    await tester.tap(find.byKey(Key('menu-${repo.cats.last.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desativar'));
    await tester.pumpAndSettle();
    expect(find.text('Desativadas'), findsOneWidget);
    expect(repo.cats.last.isActive, isFalse);
    await tester.tap(find.text('Desativadas'));
    await tester.pumpAndSettle();
    expect(find.text('Supermercado'), findsOneWidget);
    expect(find.text('Nova subcategoria'), findsNothing);
  });

  testWidgets('sugestões: todas marcadas, desmarcáveis, viram categorias', (
    tester,
  ) async {
    var finished = false;
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(CategorySuggestionsScreen(onFinished: () => finished = true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Adicionar 12 categorias'), findsOneWidget);
    expect(find.text('Saldo inicial'), findsNothing);
    expect(find.text('Rendimentos'), findsNothing);

    await tester.tap(find.byKey(const Key('sugestao-Mercado')));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar 11 categorias'), findsOneWidget);

    await tester.tap(find.text('Adicionar 11 categorias'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(repo.cats.length, 11);
    expect(repo.cats.any((c) => c.name == 'Mercado'), isFalse);
    expect(repo.cats.where((c) => c.kind == CategoryKind.income).length, 2);
  });

  testWidgets('"Agora não" não cria nada', (tester) async {
    var finished = false;
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(CategorySuggestionsScreen(onFinished: () => finished = true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(repo.cats, isEmpty);
  });
}
