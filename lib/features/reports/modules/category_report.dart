import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../core/domain/reports.dart';
import '../../categories/category_appearance.dart';
import '../models/report_definition.dart';
import '../reports_providers.dart';
import '../widgets/report_parts.dart';

/// Relatórios 1 (receitas) e 2 (despesas) por categoria, do período
/// selecionado. Mesmos totais de antes (`core/domain/reports.dart`); "+N
/// categorias" e a parte "demais" da barra não mostram soma nova.
class CategoryReport extends ConsumerWidget {
  const CategoryReport({required this.income, required this.level, super.key});

  final bool income;
  final ReportLevel level;

  /// Quantas categorias aparecem no expandido.
  static const expandedTop = 5;

  /// Quantas categorias ganham cor própria na barra do compacto.
  static const compactTop = 4;

  String get _emptyText => income
      ? 'Nenhuma receita recebida neste período.'
      : 'Nenhuma despesa neste período.';

  String get _totalLabel =>
      income ? 'Recebido no período' : 'Despesas do período';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(selectedPeriodReportProvider);
    final looks = ref.watch(categoryLooksProvider).value ?? const {};
    return ReportAsync(
      value: report,
      level: level,
      onRetry: () => ref.invalidate(selectedPeriodReportProvider),
      builder: (r) {
        if (r == null) return const SizedBox.shrink();
        final range = r.periods.single.range;
        final breakdown = income ? r.incomeOf(range) : r.expenseOf(range);
        final view = _CategoryView(
          breakdown: breakdown,
          looks: looks,
          emptyText: _emptyText,
          totalLabel: _totalLabel,
          level: level,
        );
        return switch (level) {
          ReportLevel.compact || ReportLevel.preview => view.compact(context),
          ReportLevel.expanded => view.expanded(context),
          ReportLevel.full => KeyedSubtree(
            key: Key(income ? 'relatorio-receitas' : 'relatorio-despesas'),
            child: view.full(context),
          ),
        };
      },
    );
  }
}

class _CategoryView {
  const _CategoryView({
    required this.breakdown,
    required this.looks,
    required this.emptyText,
    required this.totalLabel,
    required this.level,
  });

  final CategoryBreakdown breakdown;
  final Map<String, CategoryLook> looks;
  final String emptyText;
  final String totalLabel;
  final ReportLevel level;

  String _name(CategoryTotal item) => item.categoryId == null
      ? 'Sem categoria'
      : looks[item.categoryId]?.name ?? 'Categoria';

  String _iconKey(CategoryTotal item) =>
      looks[item.categoryId]?.iconKey ?? defaultCategoryIconKey;

  Color _color(BuildContext context, CategoryTotal item) => categoryColorFor(
    looks[item.categoryId]?.colorKey ?? defaultCategoryColorKey,
    Theme.of(context).brightness,
  );

  Widget compact(BuildContext context) {
    final id = ReportScope.of(context).id;
    if (breakdown.items.isEmpty) return ReportEmpty(emptyText, level: level);
    final theme = Theme.of(context);
    final top = breakdown.items.first;
    final colored = breakdown.items.take(CategoryReport.compactTop).toList();
    final rest = breakdown.items.skip(CategoryReport.compactTop);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportHeadline(
          label: totalLabel,
          value: formatBrl(breakdown.total),
          valueKey: Key('$id-total'),
        ),
        const SizedBox(height: 4),
        Text(
          'Maior: ${_name(top)} · ${formatPercent(breakdown.basisPoints(top))}',
          key: Key('$id-maior'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedBar(
          segments: [
            for (final item in colored) (_weight(item), _color(context, item)),
            (
              rest.fold<int>(0, (sum, item) => sum + _weight(item)),
              theme.colorScheme.outline,
            ),
          ],
        ),
      ],
    );
  }

  /// Peso de desenho; categoria com valor nunca some da barra.
  int _weight(CategoryTotal item) {
    final bp = breakdown.basisPoints(item);
    return bp == 0 && item.amount > BigInt.zero ? 1 : bp;
  }

  Widget expanded(BuildContext context) {
    final id = ReportScope.of(context).id;
    if (breakdown.items.isEmpty) return ReportEmpty(emptyText, level: level);
    final shown = breakdown.items.take(CategoryReport.expandedTop).toList();
    final hidden = breakdown.items.length - shown.length;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportHeadline(
          label: totalLabel,
          value: formatBrl(breakdown.total),
          valueKey: Key('$id-total'),
        ),
        const SizedBox(height: 8),
        for (final item in shown)
          _row(context, item, Key('$id-categoria-${item.categoryId ?? 'sem'}')),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hidden == 1 ? '+1 categoria' : '+$hidden categorias',
              key: Key('$id-mais-categorias'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget full(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          child: ListTile(
            title: const Text('Total'),
            subtitle: Text(totalLabel),
            trailing: Text(
              formatBrl(breakdown.total),
              key: const Key('total-relatorio'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (breakdown.items.isEmpty) ReportEmpty(emptyText, level: level),
        for (final item in breakdown.items)
          _row(context, item, Key('categoria-${item.categoryId ?? 'sem'}')),
      ],
    );
  }

  Widget _row(BuildContext context, CategoryTotal item, Key key) {
    final theme = Theme.of(context);
    final color = _color(context, item);
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CategoryBadge(
            iconKey: _iconKey(item),
            colorKey:
                looks[item.categoryId]?.colorKey ?? defaultCategoryColorKey,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _name(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatBrl(item.amount),
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        formatPercent(breakdown.basisPoints(item)),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: breakdown.basisPoints(item) / 10000,
                    minHeight: 6,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
