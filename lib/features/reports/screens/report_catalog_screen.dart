import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/report_definition.dart';
import '../report_preferences_controller.dart';
import '../widgets/report_card.dart';
import '../widgets/report_parts.dart';
import 'reports_home_screen.dart';

/// Catálogo de relatórios (`/relatorios/catalogo`, spec §4.5): grupos em
/// ordem fixa, prévia com os dados reais do período selecionado (o próprio
/// compacto), "Adicionar" (um por vez, no fim) e "Ver relatório".
class ReportCatalogScreen extends ConsumerWidget {
  const ReportCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(reportCatalogProvider);
    final theme = Theme.of(context);
    return ReportsScaffold(
      title: 'Catálogo de relatórios',
      body: ListView(
        key: const Key('catalogo-relatorios'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final (category, reports) in catalog.groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                category.label,
                key: Key('catalogo-grupo-${category.name}'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final r in reports)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CatalogItem(
                  report: r,
                  chosen: catalog.isSelected(r.id),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CatalogItem extends ConsumerWidget {
  const _CatalogItem({required this.report, required this.chosen});

  final ReportDefinition report;
  final bool chosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: Key('catalogo-${report.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReportIcon(report.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    report.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(report.benefit, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '${report.category.label} · ${report.visualization.label}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              key: Key('catalogo-previa-${report.id}'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ReportScope(
                definition: report,
                child: report.build(ReportLevel.preview),
              ),
            ),
            const SizedBox(height: 8),
            // Lado a lado quando cabe; empilhados em tela estreita.
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              overflowSpacing: 4,
              children: [
                TextButton(
                  key: Key('catalogo-ver-${report.id}'),
                  onPressed: () =>
                      context.push(ReportsHomeScreen.detailRoute(report.id)),
                  child: const Text('Ver relatório'),
                ),
                if (chosen)
                  Row(
                    key: Key('catalogo-escolhido-${report.id}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 18, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Em Meus relatórios',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  )
                else
                  FilledButton.tonalIcon(
                    key: Key('catalogo-adicionar-${report.id}'),
                    onPressed: () => runReportAction(
                      context,
                      ref
                          .read(reportPreferencesProvider.notifier)
                          .add(report.id),
                      '${report.name} está em Meus relatórios.',
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
