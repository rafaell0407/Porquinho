import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'category_appearance.dart';
import 'category_editor.dart';
import 'category_models.dart';
import 'category_name_dialog.dart';
import 'category_providers.dart';
import 'category_service.dart';

/// Mais > Categorias: criar, editar (nome, ícone e cor) e desativar categorias
/// e subcategorias de receitas e despesas (RN024–RN026, RN040).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(categoryDataProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categorias'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Receitas'),
              Tab(text: 'Despesas'),
            ],
          ),
        ),
        body: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível carregar as categorias.'),
                TextButton(
                  onPressed: () => ref.invalidate(categoryDataProvider),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
          data: (d) => TabBarView(
            children: [
              _KindTab(kind: CategoryKind.income, data: d),
              _KindTab(kind: CategoryKind.expense, data: d),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindTab extends ConsumerWidget {
  const _KindTab({required this.kind, required this.data});

  final CategoryKind kind;
  final CategoryData data;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(CategoryService s) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = await ref.read(categoryServiceProvider.future);
      await action(service);
      ref.invalidate(categoryDataProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = data.ofKind(kind, active: true);
    final inactive = data.ofKind(kind, active: false);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('nova-categoria'),
        onPressed: () async {
          final draft = await showCategoryEditor(
            context,
            title: kind == CategoryKind.income
                ? 'Nova categoria de receita'
                : 'Nova categoria de despesa',
          );
          if (draft != null && context.mounted) {
            await _run(
              context,
              ref,
              (s) => s.createCategory(
                kind,
                draft.name,
                iconKey: draft.iconKey,
                colorKey: draft.colorKey,
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova categoria'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(categoryDataProvider),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (active.isEmpty && inactive.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhuma categoria ainda.'),
              ),
            for (final c in active)
              _CategoryGroup(category: c, data: data, run: _run),
            if (inactive.isNotEmpty)
              ExpansionTile(
                title: const Text('Desativadas'),
                children: [
                  for (final c in inactive)
                    ListTile(
                      leading: CategoryBadge(
                        iconKey: c.iconKey,
                        colorKey: c.colorKey,
                      ),
                      title: Text(c.name),
                      subtitle: const Text('Desativada'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

typedef _Runner =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      Future<void> Function(CategoryService s) action,
    );

/// Categoria como cabeçalho colorido, com as subcategorias logo abaixo.
class _CategoryGroup extends ConsumerWidget {
  const _CategoryGroup({
    required this.category,
    required this.data,
    required this.run,
  });

  final CategoryRecord category;
  final CategoryData data;
  final _Runner run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subs = data.subsOf(category.id, active: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Material(
          color: theme.colorScheme.surfaceContainer,
          child: ListTile(
            key: PageStorageKey('cat-${category.id}'),
            leading: CategoryBadge(
              iconKey: category.iconKey,
              colorKey: category.colorKey,
              filled: true,
            ),
            title: Text(category.name, style: theme.textTheme.titleMedium),
            subtitle: subs.isEmpty
                ? null
                : Text('${subs.length} subcategorias'),
            trailing: PopupMenuButton<String>(
              key: Key('menu-${category.id}'),
              onSelected: (action) async {
                if (action == 'editar') {
                  final draft = await showCategoryEditor(
                    context,
                    title: 'Editar categoria',
                    initialName: category.name,
                    initialIcon: category.iconKey,
                    initialColor: category.colorKey,
                  );
                  if (draft != null && context.mounted) {
                    await run(
                      context,
                      ref,
                      (s) => s.editCategory(
                        category,
                        name: draft.name,
                        iconKey: draft.iconKey,
                        colorKey: draft.colorKey,
                      ),
                    );
                  }
                } else if (action == 'desativar') {
                  await run(
                    context,
                    ref,
                    (s) => s.deactivateCategory(category),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'desativar', child: Text('Desativar')),
              ],
            ),
          ),
        ),
        for (final s in subs)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 28, right: 16),
            leading: CategoryBadge(
              iconKey: category.iconKey,
              colorKey: category.colorKey,
              size: 34,
            ),
            title: Text(s.name),
            trailing: PopupMenuButton<String>(
              key: Key('menu-${s.id}'),
              onSelected: (action) async {
                if (action == 'renomear') {
                  final name = await askName(
                    context,
                    title: 'Renomear subcategoria',
                    initial: s.name,
                  );
                  if (name != null && context.mounted) {
                    await run(
                      context,
                      ref,
                      (svc) => svc.renameSubcategory(s, name),
                    );
                  }
                } else if (action == 'desativar') {
                  await run(
                    context,
                    ref,
                    (svc) => svc.deactivateSubcategory(s),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'renomear', child: Text('Renomear')),
                PopupMenuItem(value: 'desativar', child: Text('Desativar')),
              ],
            ),
          ),
        ListTile(
          key: Key('nova-sub-${category.id}'),
          contentPadding: const EdgeInsets.only(left: 28, right: 16),
          leading: CircleAvatar(
            radius: 17,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            child: const Icon(Icons.add, size: 18),
          ),
          title: const Text('Adicionar subcategoria'),
          onTap: () async {
            final name = await askName(context, title: 'Nova subcategoria');
            if (name != null && context.mounted) {
              await run(
                context,
                ref,
                (s) => s.createSubcategory(category, name),
              );
            }
          },
        ),
      ],
    );
  }
}
