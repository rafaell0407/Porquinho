import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_definition.dart';
import '../tools_providers.dart';
import '../widgets/tool_cards.dart';
import '../widgets/tool_explanation.dart';

/// Personalizar "Suas ferramentas": arrastar para ordenar, remover, adicionar
/// e restaurar o padrão (com confirmação). Cada mudança é salva na hora.
class ManageToolsScreen extends ConsumerWidget {
  const ManageToolsScreen({super.key});

  Future<void> _run(
    BuildContext context,
    Future<String?> action,
    String done,
  ) async {
    final error = await action;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? done),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar padrão?'),
        content: const Text(
          'Suas ferramentas voltam à lista e à ordem iniciais do Norte. '
          'Nenhum dado é apagado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('ferramentas-restaurar-confirmar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(
      context,
      ref.read(toolPreferencesProvider.notifier).restoreDefault(),
      'Configuração padrão restaurada.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(toolCatalogProvider);
    final controller = ref.read(toolPreferencesProvider.notifier);
    final selected = catalog.selected;
    final available = catalog.available;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget sectionTitle(String title, String subtitle) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            subtitle,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    void info(ToolDefinition t) => showToolInfoSheet(context, t);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar'),
        actions: [
          TextButton(
            key: const Key('ferramentas-restaurar'),
            onPressed: catalog.preferences.isDefault
                ? null
                : () => _restore(context, ref),
            child: const Text('Restaurar padrão'),
          ),
        ],
      ),
      body: CustomScrollView(
        key: const Key('ferramentas-personalizar-lista'),
        slivers: [
          SliverToBoxAdapter(
            child: sectionTitle(
              'Suas ferramentas',
              selected.length > 1
                  ? 'Arraste pela alça para mudar a ordem.'
                  : 'Aparecem na aba Ferramentas, nesta ordem.',
            ),
          ),
          if (selected.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Nenhuma ferramenta escolhida. Adicione abaixo.',
                  key: const Key('personalizar-vazio'),
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: selected.length,
                onReorderItem: (from, to) => controller.move(from, to),
                proxyDecorator: (child, _, animation) => AnimatedBuilder(
                  animation: animation,
                  builder: (_, child) => Material(
                    elevation: 6 * animation.value,
                    color: Colors.transparent,
                    shadowColor: scheme.shadow,
                    borderRadius: BorderRadius.circular(18),
                    child: child,
                  ),
                  child: child,
                ),
                itemBuilder: (context, index) {
                  final t = selected[index];
                  return Padding(
                    key: ValueKey('personalizar-${t.id}'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ToolRow(
                      tool: t,
                      onInfo: () => info(t),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          key: Key('ferramenta-arrastar-${t.id}'),
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.drag_indicator,
                            color: scheme.onSurfaceVariant,
                            semanticLabel: 'Arrastar ${t.name}',
                          ),
                        ),
                      ),
                      trailing: IconButton(
                        key: Key('ferramenta-remover-${t.id}'),
                        tooltip: 'Remover de Suas ferramentas',
                        color: scheme.error,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _run(
                          context,
                          controller.remove(t.id),
                          '${t.name} saiu de Suas ferramentas.',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: sectionTitle(
              'Outras ferramentas',
              available.isEmpty
                  ? 'Todas as ferramentas já estão em Suas ferramentas.'
                  : 'Toque em + para adicionar.',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.list(
              children: [
                for (final t in available)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ToolRow(
                      tool: t,
                      onInfo: () => info(t),
                      trailing: IconButton.filledTonal(
                        key: Key('ferramenta-adicionar-${t.id}'),
                        tooltip: 'Adicionar a Suas ferramentas',
                        icon: const Icon(Icons.add),
                        onPressed: () => _run(
                          context,
                          controller.add(t.id),
                          '${t.name} está em Suas ferramentas.',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
