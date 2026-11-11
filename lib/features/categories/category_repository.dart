import 'category_models.dart';

/// Categorias e subcategorias. Celular: banco local + fila de envio.
/// Web: servidor, somente online.
abstract interface class CategoryRepository {
  Future<List<CategoryRecord>> categories();
  Future<List<SubcategoryRecord>> subcategories();

  /// Grava as alterações de uma vez. No celular, tudo na mesma transação.
  Future<void> apply(List<CategoryChange> changes);
}
