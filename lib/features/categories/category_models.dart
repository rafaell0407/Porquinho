import 'category_appearance.dart';

/// Tipo da categoria; definido na criação e imutável (RN024).
enum CategoryKind {
  income('income', 'Receitas'),
  expense('expense', 'Despesas');

  const CategoryKind(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static CategoryKind fromDb(String value) =>
      CategoryKind.values.firstWhere((k) => k.dbValue == value);
}

class CategoryRecord {
  const CategoryRecord({
    required this.id,
    required this.kind,
    required this.name,
    required this.isActive,
    required this.version,
    this.iconKey = defaultCategoryIconKey,
    this.colorKey = defaultCategoryColorKey,
  });

  final String id;
  final CategoryKind kind;
  final String name;
  final bool isActive;
  final int version;

  /// Chaves do visual (ver `category_appearance.dart`); subcategorias herdam.
  final String iconKey;
  final String colorKey;

  Map<String, dynamic> toSnapshot() => {
    'id': id,
    'kind': kind.dbValue,
    'name': name,
    'is_active': isActive,
    'icon_key': iconKey,
    'color_key': colorKey,
    'version': version,
  };
}

class SubcategoryRecord {
  const SubcategoryRecord({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.isActive,
    required this.version,
  });

  final String id;
  final String categoryId;
  final String name;
  final bool isActive;
  final int version;

  Map<String, dynamic> toSnapshot() => {
    'id': id,
    'category_id': categoryId,
    'name': name,
    'is_active': isActive,
    'version': version,
  };
}

/// Alteração pedida pelo usuário. A versão esperada é a do registro lido.
sealed class CategoryChange {
  const CategoryChange();
}

class CreateCategory extends CategoryChange {
  const CreateCategory(
    this.id,
    this.kind,
    this.name, {
    this.iconKey,
    this.colorKey,
  });
  final String id;
  final CategoryKind kind;
  final String name;

  /// `null` = visual padrão (o servidor e o aparelho usam o mesmo).
  final String? iconKey;
  final String? colorKey;
}

/// Muda nome e/ou visual numa só operação. Só vão os campos que mudaram:
/// com nome é `rename`, sem nome é `restyle`.
class EditCategory extends CategoryChange {
  const EditCategory(this.category, {this.name, this.iconKey, this.colorKey});
  final CategoryRecord category;
  final String? name;
  final String? iconKey;
  final String? colorKey;
}

class RenameCategory extends CategoryChange {
  const RenameCategory(this.category, this.name);
  final CategoryRecord category;
  final String name;
}

class DeactivateCategory extends CategoryChange {
  const DeactivateCategory(this.category);
  final CategoryRecord category;
}

class CreateSubcategory extends CategoryChange {
  const CreateSubcategory(this.id, this.categoryId, this.name);
  final String id;
  final String categoryId;
  final String name;
}

class RenameSubcategory extends CategoryChange {
  const RenameSubcategory(this.subcategory, this.name);
  final SubcategoryRecord subcategory;
  final String name;
}

class DeactivateSubcategory extends CategoryChange {
  const DeactivateSubcategory(this.subcategory);
  final SubcategoryRecord subcategory;
}

/// Chamada ao servidor equivalente a uma [CategoryChange].
class CategoryRpcCall {
  const CategoryRpcCall({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.expectedVersion,
    required this.rpc,
    required this.params,
    this.dependsOn = const [],
  });

  final String entityType;
  final String entityId;

  /// Operação de auditoria: create, rename ou deactivate.
  final String operation;
  final int expectedVersion;
  final String rpc;
  final Map<String, dynamic> params;
  final List<String> dependsOn;
}

/// Traduz a alteração para os parâmetros da RPC (`apply_category_change` /
/// `apply_subcategory_change`), os mesmos no celular e na Web.
CategoryRpcCall rpcCallFor(CategoryChange change) => switch (change) {
  CreateCategory(
    :final id,
    :final kind,
    :final name,
    :final iconKey,
    :final colorKey,
  ) =>
    CategoryRpcCall(
      entityType: 'category',
      entityId: id,
      operation: 'create',
      expectedVersion: 0,
      rpc: 'apply_category_change',
      params: {
        'p_action': 'create',
        'p_category_id': id,
        'p_expected_version': 0,
        'p_kind': kind.dbValue,
        'p_name': name,
        'p_icon_key': ?iconKey,
        'p_color_key': ?colorKey,
      },
    ),
  EditCategory(:final category, :final name, :final iconKey, :final colorKey) =>
    CategoryRpcCall(
      entityType: 'category',
      entityId: category.id,
      operation: name != null ? 'rename' : 'restyle',
      expectedVersion: category.version,
      rpc: 'apply_category_change',
      params: {
        'p_action': name != null ? 'rename' : 'restyle',
        'p_category_id': category.id,
        'p_expected_version': category.version,
        'p_kind': null,
        'p_name': name,
        'p_icon_key': ?iconKey,
        'p_color_key': ?colorKey,
      },
    ),
  RenameCategory(:final category, :final name) => CategoryRpcCall(
    entityType: 'category',
    entityId: category.id,
    operation: 'rename',
    expectedVersion: category.version,
    rpc: 'apply_category_change',
    params: {
      'p_action': 'rename',
      'p_category_id': category.id,
      'p_expected_version': category.version,
      'p_kind': null,
      'p_name': name,
    },
  ),
  DeactivateCategory(:final category) => CategoryRpcCall(
    entityType: 'category',
    entityId: category.id,
    operation: 'deactivate',
    expectedVersion: category.version,
    rpc: 'apply_category_change',
    params: {
      'p_action': 'deactivate',
      'p_category_id': category.id,
      'p_expected_version': category.version,
      'p_kind': null,
      'p_name': null,
    },
  ),
  CreateSubcategory(:final id, :final categoryId, :final name) =>
    CategoryRpcCall(
      entityType: 'subcategory',
      entityId: id,
      operation: 'create',
      expectedVersion: 0,
      rpc: 'apply_subcategory_change',
      params: {
        'p_action': 'create',
        'p_subcategory_id': id,
        'p_category_id': categoryId,
        'p_expected_version': 0,
        'p_name': name,
      },
      dependsOn: [categoryId],
    ),
  RenameSubcategory(:final subcategory, :final name) => CategoryRpcCall(
    entityType: 'subcategory',
    entityId: subcategory.id,
    operation: 'rename',
    expectedVersion: subcategory.version,
    rpc: 'apply_subcategory_change',
    params: {
      'p_action': 'rename',
      'p_subcategory_id': subcategory.id,
      'p_category_id': null,
      'p_expected_version': subcategory.version,
      'p_name': name,
    },
  ),
  DeactivateSubcategory(:final subcategory) => CategoryRpcCall(
    entityType: 'subcategory',
    entityId: subcategory.id,
    operation: 'deactivate',
    expectedVersion: subcategory.version,
    rpc: 'apply_subcategory_change',
    params: {
      'p_action': 'deactivate',
      'p_subcategory_id': subcategory.id,
      'p_category_id': null,
      'p_expected_version': subcategory.version,
      'p_name': null,
    },
  ),
};

/// Sugestões do primeiro acesso (RN024, decisão de 10/11/2026).
const suggestedIncomeCategories = ['Salário', 'Renda extra'];
const suggestedExpenseCategories = [
  'Moradia',
  'Alimentação',
  'Mercado',
  'Transporte',
  'Saúde',
  'Educação',
  'Lazer',
  'Contas da casa',
  'Assinaturas',
  'Fatura do cartão',
];

/// O item foi alterado em outro lugar enquanto o usuário editava.
class ChangeConflictException implements Exception {
  const ChangeConflictException([
    this.message =
        'Este item foi alterado em outro aparelho. Atualize a tela e '
        'confira antes de tentar de novo.',
  ]);
  final String message;
  @override
  String toString() => message;
}

/// Regra de negócio violada ou recusa do servidor, com texto para o usuário.
class ChangeRejectedException implements Exception {
  const ChangeRejectedException(this.message);
  final String message;
  @override
  String toString() => message;
}
