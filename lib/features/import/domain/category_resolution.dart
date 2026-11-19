import 'existing_data.dart';
import 'import_models.dart';

/// Etapa "Categorias" (RN050): cada nome do arquivo, por tipo, vira uma
/// categoria existente ativa do mesmo tipo, uma nova ou nenhuma. Categoria
/// desativada nunca é reativada; investimento nunca tem categoria.
enum CategoryChoiceType { existing, create, none }

class CategoryChoice {
  const CategoryChoice.existing(String this.existingId)
    : type = CategoryChoiceType.existing;
  const CategoryChoice.create()
    : type = CategoryChoiceType.create,
      existingId = null;
  const CategoryChoice.none()
    : type = CategoryChoiceType.none,
      existingId = null;

  final CategoryChoiceType type;
  final String? existingId;

  Map<String, Object?> toJson() => {'type': type.name, 'id': existingId};

  factory CategoryChoice.fromJson(Map<String, dynamic> json) =>
      switch (CategoryChoiceType.values.byName(json['type'] as String)) {
        CategoryChoiceType.existing => CategoryChoice.existing(
          json['id'] as String,
        ),
        CategoryChoiceType.create => const CategoryChoice.create(),
        CategoryChoiceType.none => const CategoryChoice.none(),
      };

  @override
  bool operator ==(Object other) =>
      other is CategoryChoice &&
      other.type == type &&
      other.existingId == existingId;

  @override
  int get hashCode => Object.hash(type, existingId);
}

String categoryKey(CategoryKind kind, String name) =>
    '${kind.key}|${normalizeKey(name)}';

String subcategoryKey(CategoryKind kind, String category, String sub) =>
    '${kind.key}|${normalizeKey(category)}|${normalizeKey(sub)}';

class SubcategoryNeed {
  SubcategoryNeed(this.key, this.name);
  final String key;

  /// Nome como aparece primeiro no arquivo (o que será criado).
  final String name;
  int rows = 0;
}

class CategoryNeed {
  CategoryNeed(this.key, this.kind, this.name);
  final String key;
  final CategoryKind kind;
  final String name;
  int rows = 0;
  final Map<String, SubcategoryNeed> subs = {};
}

/// Nomes de categoria e subcategoria usados pelas linhas e declarados nas
/// linhas de categoria, por tipo, na ordem em que aparecem.
List<CategoryNeed> collectCategoryNeeds(
  Iterable<ImportRow> rows,
  Iterable<CategoryRow> categoryRows,
) {
  final needs = <String, CategoryNeed>{};
  CategoryNeed need(CategoryKind kind, String name) => needs.putIfAbsent(
    categoryKey(kind, name),
    () => CategoryNeed(categoryKey(kind, name), kind, name.trim()),
  );
  void sub(CategoryNeed parent, String name) {
    final key = subcategoryKey(parent.kind, parent.name, name);
    parent.subs.putIfAbsent(key, () => SubcategoryNeed(key, name.trim()));
  }

  for (final c in categoryRows) {
    if (c.parentName == null) {
      need(c.kind, c.name);
    } else {
      sub(need(c.kind, c.parentName!), c.name);
    }
  }
  for (final r in rows) {
    final kind = r.categoryKind;
    if (kind == null || r.categoryName == null) continue;
    final n = need(kind, r.categoryName!);
    n.rows++;
    if (r.subcategoryName != null) {
      sub(n, r.subcategoryName!);
      final s =
          n.subs[subcategoryKey(kind, r.categoryName!, r.subcategoryName!)]!;
      s.rows++;
    }
  }
  return needs.values.toList();
}

/// Sugestão inicial: existente ativa do mesmo tipo e mesmo nome (sem
/// diferença de acento ou maiúscula); se não houver, criar. O usuário troca.
Map<String, CategoryChoice> suggestCategoryChoices(
  List<CategoryNeed> needs,
  ExistingData existing,
) {
  final choices = <String, CategoryChoice>{};
  for (final need in needs) {
    final match = existing.categories
        .where(
          (c) =>
              c.active &&
              c.kind == need.kind &&
              normalizeKey(c.name) == normalizeKey(need.name),
        )
        .firstOrNull;
    final choice = match == null
        ? const CategoryChoice.create()
        : CategoryChoice.existing(match.id);
    choices[need.key] = choice;
    for (final sub in need.subs.values) {
      choices[sub.key] = suggestSubcategoryChoice(choice, sub, existing);
    }
  }
  return choices;
}

/// Subcategoria acompanha a escolha da categoria: sem categoria, sem
/// subcategoria; categoria existente, a subcategoria ativa de mesmo nome.
CategoryChoice suggestSubcategoryChoice(
  CategoryChoice category,
  SubcategoryNeed sub,
  ExistingData existing,
) {
  switch (category.type) {
    case CategoryChoiceType.none:
      return const CategoryChoice.none();
    case CategoryChoiceType.create:
      return const CategoryChoice.create();
    case CategoryChoiceType.existing:
      final match = existing.subcategories
          .where(
            (s) =>
                s.active &&
                s.categoryId == category.existingId &&
                normalizeKey(s.name) == normalizeKey(sub.name),
          )
          .firstOrNull;
      return match == null
          ? const CategoryChoice.create()
          : CategoryChoice.existing(match.id);
  }
}

/// O que impede avançar: escolha faltando, categoria inativa, de outro tipo
/// ou subcategoria que não pertence à categoria escolhida.
List<String> categoryProblems(
  List<CategoryNeed> needs,
  Map<String, CategoryChoice> choices,
  ExistingData existing,
) {
  final problems = <String>[];
  for (final need in needs) {
    final choice = choices[need.key];
    if (choice == null) {
      problems.add('Escolha o que fazer com a categoria "${need.name}".');
      continue;
    }
    if (choice.type == CategoryChoiceType.existing) {
      final c = existing.categories
          .where((c) => c.id == choice.existingId)
          .firstOrNull;
      if (c == null || !c.active || c.kind != need.kind) {
        problems.add(
          '"${need.name}": escolha uma categoria ativa do tipo '
          '${need.kind.label.toLowerCase()}.',
        );
      }
    }
    for (final sub in need.subs.values) {
      final s = choices[sub.key];
      if (s == null) {
        problems.add('Escolha o que fazer com a subcategoria "${sub.name}".');
        continue;
      }
      if (choice.type == CategoryChoiceType.none &&
          s.type != CategoryChoiceType.none) {
        problems.add('"${sub.name}": sem categoria, fica sem subcategoria.');
      }
      if (s.type == CategoryChoiceType.existing) {
        final e = existing.subcategories
            .where((x) => x.id == s.existingId)
            .firstOrNull;
        if (e == null ||
            !e.active ||
            choice.type != CategoryChoiceType.existing ||
            e.categoryId != choice.existingId) {
          problems.add(
            '"${sub.name}": escolha uma subcategoria ativa da categoria '
            'escolhida.',
          );
        }
      }
    }
  }
  return problems;
}

/// Referência à categoria de um lançamento depois das escolhas: id existente,
/// chave de categoria nova (`new:<chave>`) ou `null` (sem categoria).
class CategoryRef {
  const CategoryRef({
    this.categoryId,
    this.newCategoryKey,
    this.subId,
    this.newSubKey,
  });

  final String? categoryId;
  final String? newCategoryKey;
  final String? subId;
  final String? newSubKey;

  static const none = CategoryRef();

  bool get isNone => categoryId == null && newCategoryKey == null;

  /// Identidade estável (agrupar séries pela categoria escolhida).
  String get identity =>
      categoryId ?? (newCategoryKey == null ? '' : 'new:$newCategoryKey');
}

CategoryRef resolveCategory(
  ImportRow row,
  Map<String, CategoryChoice> choices,
) {
  final kind = row.categoryKind;
  if (kind == null || row.categoryName == null) return CategoryRef.none;
  final key = categoryKey(kind, row.categoryName!);
  final choice = choices[key];
  if (choice == null || choice.type == CategoryChoiceType.none) {
    return CategoryRef.none;
  }
  String? subId;
  String? newSub;
  if (row.subcategoryName != null) {
    final sKey = subcategoryKey(kind, row.categoryName!, row.subcategoryName!);
    final s = choices[sKey];
    if (s?.type == CategoryChoiceType.existing) subId = s!.existingId;
    if (s?.type == CategoryChoiceType.create) newSub = sKey;
  }
  return choice.type == CategoryChoiceType.existing
      ? CategoryRef(
          categoryId: choice.existingId,
          subId: subId,
          newSubKey: newSub,
        )
      : CategoryRef(newCategoryKey: key, newSubKey: newSub);
}
