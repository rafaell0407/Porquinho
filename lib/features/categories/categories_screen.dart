import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'category_models.dart';
import 'category_providers.dart';
import 'category_service.dart';

/// Mais > Categorias: criar, renomear e desativar categorias e subcategorias
/// de receitas e despesas (RN024–RN026, RN040).
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

/// Pede um nome ao usuário; valida como o servidor (não vazio, até 60).
Future<String?> askName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  String? error;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('campo-nome'),
          controller: controller,
          autofocus: true,
          maxLength: CategoryService.maxNameLength,
          decoration: InputDecoration(labelText: 'Nome', errorText: error),
          onSubmitted: (_) => _submit(context, controller, (e) {
            setState(() => error = e);
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _submit(context, controller, (e) {
              setState(() => error = e);
            }),
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

void _submit(
  BuildContext context,
  TextEditingController controller,
  void Function(String?) onError,
) {
  final problem = CategoryService.validateName(controller.text);
  if (problem != null) {
    onError(problem);
    return;
  }
  Navigator.pop(context, controller.text.trim());
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
          final name = await askName(
            context,
            title: kind == CategoryKind.income
                ? 'Nova categoria de receita'
                : 'Nova categoria de despesa',
          );
          if (name != null && context.mounted) {
            await _run(context, ref, (s) => s.createCategory(kind, name));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova categoria'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(categoryDataProvider),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (active.isEmpty && inactive.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhuma categoria ainda.'),
              ),
            for (final c in active)
              _CategoryTile(category: c, data: data, run: _run),
            if (inactive.isNotEmpty)
              ExpansionTile(
                title: const Text('Desativadas'),
                children: [
                  for (final c in inactive)
                    ListTile(
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

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    required this.category,
    required this.data,
    required this.run,
  });

  final CategoryRecord category;
  final CategoryData data;
  final _Runner run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = data.subsOf(category.id, active: true);
    return ExpansionTile(
      key: PageStorageKey('cat-${category.id}'),
      title: Text(category.name),
      subtitle: subs.isEmpty ? null : Text('${subs.length} subcategorias'),
      trailing: PopupMenuButton<String>(
        key: Key('menu-${category.id}'),
        onSelected: (action) async {
          if (action == 'renomear') {
            final name = await askName(
              context,
              title: 'Renomear categoria',
              initial: category.name,
            );
            if (name != null && context.mounted) {
              await run(context, ref, (s) => s.renameCategory(category, name));
            }
          } else if (action == 'desativar') {
            await run(context, ref, (s) => s.deactivateCategory(category));
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'renomear', child: Text('Renomear')),
          PopupMenuItem(value: 'desativar', child: Text('Desativar')),
        ],
      ),
      children: [
        for (final s in subs)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
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
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          leading: const Icon(Icons.add),
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
