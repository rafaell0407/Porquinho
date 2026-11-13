import 'package:flutter/material.dart';

import 'category_appearance.dart';
import 'category_models.dart';
import 'category_service.dart';

/// Resultado do seletor de categoria.
sealed class CategoryPick {
  const CategoryPick();
}

/// Categoria (e, opcionalmente, subcategoria) escolhida.
class PickedCategory extends CategoryPick {
  const PickedCategory(this.categoryId, [this.subcategoryId]);
  final String categoryId;
  final String? subcategoryId;
}

/// "Sem categoria".
class PickedNone extends CategoryPick {
  const PickedNone();
}

/// O usuário quer criar uma categoria nova.
class PickedCreate extends CategoryPick {
  const PickedCreate();
}

/// Folha de escolha da categoria do lançamento: busca, categorias agrupadas
/// com suas subcategorias e a opção de criar uma nova. Só categorias ativas do
/// tipo pedido (mais a que já estava escolhida, se foi desativada).
Future<CategoryPick?> showCategoryPicker(
  BuildContext context, {
  required CategoryData data,
  required CategoryKind kind,
  String? selectedCategoryId,
  String? selectedSubcategoryId,
}) {
  return showModalBottomSheet<CategoryPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => _Picker(
        data: data,
        kind: kind,
        selectedCategoryId: selectedCategoryId,
        selectedSubcategoryId: selectedSubcategoryId,
        controller: controller,
      ),
    ),
  );
}

class _Picker extends StatefulWidget {
  const _Picker({
    required this.data,
    required this.kind,
    required this.selectedCategoryId,
    required this.selectedSubcategoryId,
    required this.controller,
  });

  final CategoryData data;
  final CategoryKind kind;
  final String? selectedCategoryId;
  final String? selectedSubcategoryId;
  final ScrollController controller;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  String _query = '';

  static String _norm(String s) => s.toLowerCase().trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _norm(_query);
    final groups = <(CategoryRecord, List<SubcategoryRecord>)>[];
    for (final c in widget.data.categories.where(
      (c) =>
          c.kind == widget.kind &&
          (c.isActive || c.id == widget.selectedCategoryId),
    )) {
      final subs = widget.data.subcategories
          .where(
            (s) =>
                s.categoryId == c.id &&
                (s.isActive || s.id == widget.selectedSubcategoryId),
          )
          .toList();
      if (q.isEmpty) {
        groups.add((c, subs));
      } else if (_norm(c.name).contains(q)) {
        groups.add((c, subs));
      } else {
        final hits = subs.where((s) => _norm(s.name).contains(q)).toList();
        if (hits.isNotEmpty) groups.add((c, hits));
      }
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const Key('buscar-categoria'),
            decoration: const InputDecoration(
              hintText: 'Buscar categoria',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (q.isEmpty)
                ListTile(
                  key: const Key('sem-categoria'),
                  leading: const CategoryBadge(
                    iconKey: 'category',
                    colorKey: 'gray',
                  ),
                  title: const Text('Sem categoria'),
                  trailing: _Radio(selected: widget.selectedCategoryId == null),
                  onTap: () => Navigator.pop(context, const PickedNone()),
                ),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma categoria encontrada.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final (c, subs) in groups) ...[
                Material(
                  color: theme.colorScheme.surfaceContainer,
                  child: ListTile(
                    key: Key('categoria-${c.id}'),
                    leading: CategoryBadge(
                      iconKey: c.iconKey,
                      colorKey: c.colorKey,
                      filled: true,
                    ),
                    title: Text(
                      c.isActive ? c.name : '${c.name} (desativada)',
                      style: theme.textTheme.titleMedium,
                    ),
                    trailing: _Radio(
                      selected:
                          widget.selectedCategoryId == c.id &&
                          widget.selectedSubcategoryId == null,
                    ),
                    onTap: () => Navigator.pop(context, PickedCategory(c.id)),
                  ),
                ),
                for (final s in subs)
                  ListTile(
                    key: Key('subcategoria-${s.id}'),
                    contentPadding: const EdgeInsets.only(left: 28, right: 16),
                    leading: CategoryBadge(
                      iconKey: c.iconKey,
                      colorKey: c.colorKey,
                      size: 34,
                    ),
                    title: Text(s.name),
                    trailing: _Radio(
                      selected: widget.selectedSubcategoryId == s.id,
                    ),
                    onTap: () =>
                        Navigator.pop(context, PickedCategory(c.id, s.id)),
                  ),
              ],
              if (q.isEmpty) ...[
                const SizedBox(height: 8),
                ListTile(
                  key: const Key('nova-categoria-form'),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.add),
                  ),
                  title: const Text('Nova categoria'),
                  onTap: () => Navigator.pop(context, const PickedCreate()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Seleção única: círculo (não quadrado, que indicaria várias escolhas).
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: 2,
          ),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
