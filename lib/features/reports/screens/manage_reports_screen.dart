import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../report_preferences_controller.dart';
import '../widgets/report_card.dart';
import 'reports_home_screen.dart';

/// Personalizar "Meus relatórios" (`/relatorios/personalizar`, spec §4.6):
/// arrastar para ordenar, remover (os dados não são apagados), abrir o
/// catálogo e restaurar a configuração inicial (com confirmação, sem reabrir
/// a configuração guiada). Cada mudança é salva na hora.
class ManageReportsScreen extends ConsumerWidget {
  const ManageReportsScreen({super.key});

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar configuração inicial?'),
        content: const Text(
          'Meus relatórios volta aos cinco relatórios, na ordem inicial. '
          'Nenhum dado é apagado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('relatorios-restaurar-confirmar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runReportAction(
      context,
      ref.read(reportPreferencesProvider.notifier).restoreSuggested(),
      'Configuração inicial restaurada.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(reportCatalogProvider);
    final controller = ref.read(reportPreferencesProvider.notifier);
    final selected = catalog.selected;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ReportsScaffold(
      title: 'Personalizar',
      showPeriod: false,
      body: CustomScrollView(
        key: const Key('relatorios-personalizar-lista'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meus relatórios',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    selected.length > 1
                        ? 'Arraste pela alça para mudar a ordem. Remover só '
                              'tira da lista; seus dados não são apagados.'
                        : 'Remover só tira da lista; seus dados não são '
                              'apagados.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Nenhum relatório em Meus relatórios. Abra o catálogo para '
                  'adicionar.',
                  key: const Key('relatorios-personalizar-vazio'),
                  style: theme.textTheme.bodyMedium?.copyWith(
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
                    borderRadius: BorderRadius.circular(16),
                    child: child,
                  ),
                  child: child,
                ),
                itemBuilder: (context, index) {
                  final r = selected[index];
                  return Padding(
                    key: ValueKey('relatorios-personalizar-${r.id}'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                key: Key('relatorio-arrastar-${r.id}'),
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.drag_indicator,
                                  color: scheme.onSurfaceVariant,
                                  semanticLabel: 'Arrastar ${r.name}',
                                ),
                              ),
                            ),
                            ReportIcon(r.icon, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    r.benefit,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: Key('relatorio-remover-${r.id}'),
                              tooltip: 'Remover de Meus relatórios',
                              color: scheme.error,
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => runReportAction(
                                context,
                                controller.remove(r.id),
                                '${r.name} saiu de Meus relatórios. Seus '
                                'dados não foram apagados.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const Key('relatorios-personalizar-catalogo'),
                    onPressed: () =>
                        context.push(ReportsHomeScreen.catalogRoute),
                    icon: const Icon(Icons.add),
                    label: const Text('Abrir catálogo'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('relatorios-restaurar'),
                    onPressed: catalog.preferences.isSuggested
                        ? null
                        : () => _restore(context, ref),
                    child: const Text('Restaurar configuração inicial'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
