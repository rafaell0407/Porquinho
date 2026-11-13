import '../sync/sync_models.dart';
import 'category_models.dart';
import 'category_repository.dart';

/// Categorias e subcategorias carregadas para a tela.
class CategoryData {
  const CategoryData(this.categories, this.subcategories);

  final List<CategoryRecord> categories;
  final List<SubcategoryRecord> subcategories;

  List<CategoryRecord> ofKind(CategoryKind kind, {required bool active}) =>
      categories.where((c) => c.kind == kind && c.isActive == active).toList();

  List<SubcategoryRecord> subsOf(String categoryId, {required bool active}) =>
      subcategories
          .where((s) => s.categoryId == categoryId && s.isActive == active)
          .toList();
}

/// Regras de categorias e subcategorias (RN024–RN026, RN040). Mesmas
/// validações da RPC, para que o que for salvo no aparelho não seja recusado
/// depois.
class CategoryService {
  CategoryService(this._repo, {String Function()? newId})
    : _newId = newId ?? newUuid;

  final CategoryRepository _repo;
  final String Function() _newId;

  static const maxNameLength = 60;

  /// Texto de erro para o usuário, ou `null` se o nome é válido.
  static String? validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Informe um nome.';
    if (trimmed.length > maxNameLength) {
      return 'Use até $maxNameLength caracteres.';
    }
    return null;
  }

  static String _checked(String name) {
    final error = validateName(name);
    if (error != null) throw ChangeRejectedException(error);
    return name.trim();
  }

  Future<CategoryData> load() async =>
      CategoryData(await _repo.categories(), await _repo.subcategories());

  /// Devolve o id da categoria criada.
  Future<String> createCategory(CategoryKind kind, String name) async {
    final id = _newId();
    await _repo.apply([CreateCategory(id, kind, _checked(name))]);
    return id;
  }

  Future<void> renameCategory(CategoryRecord category, String name) async {
    await _repo.apply([RenameCategory(category, _checked(name))]);
  }

  /// O tipo nunca muda; desativar é permitido mesmo com lançamentos (RN040).
  Future<void> deactivateCategory(CategoryRecord category) async {
    if (!category.isActive) {
      throw const ChangeRejectedException('A categoria já está desativada.');
    }
    await _repo.apply([DeactivateCategory(category)]);
  }

  /// Devolve o id da subcategoria criada.
  Future<String> createSubcategory(CategoryRecord parent, String name) async {
    if (!parent.isActive) {
      throw const ChangeRejectedException(
        'Só é possível criar subcategorias em categorias ativas.',
      );
    }
    final id = _newId();
    await _repo.apply([CreateSubcategory(id, parent.id, _checked(name))]);
    return id;
  }

  Future<void> renameSubcategory(SubcategoryRecord sub, String name) async {
    await _repo.apply([RenameSubcategory(sub, _checked(name))]);
  }

  Future<void> deactivateSubcategory(SubcategoryRecord sub) async {
    if (!sub.isActive) {
      throw const ChangeRejectedException('A subcategoria já está desativada.');
    }
    await _repo.apply([DeactivateSubcategory(sub)]);
  }

  /// Cria as sugestões escolhidas no primeiro acesso como categorias comuns,
  /// sem tratamento especial (RN024). Tudo ou nada.
  Future<void> addSuggestions({
    Iterable<String> income = const [],
    Iterable<String> expense = const [],
  }) => _repo.apply([
    for (final n in income) CreateCategory(_newId(), CategoryKind.income, n),
    for (final n in expense) CreateCategory(_newId(), CategoryKind.expense, n),
  ]);
}
