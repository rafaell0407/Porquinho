import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/domain/money.dart';
import 'reports_providers.dart';

/// Gráficos dos relatórios 4 e 5. Os valores em `double` servem somente para
/// desenhar; os números exibidos em texto continuam vindo de `BigInt`.
double _reais(BigInt cents) => cents.toDouble() / 100;

String _label(SeriesItem item) {
  final start = item.range.start.toBr();
  return start.length >= 5 ? start.substring(0, 5) : start;
}

FlTitlesData _titles(List<SeriesItem> items, TextStyle? style) => FlTitlesData(
  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 28,
      getTitlesWidget: (value, meta) {
        final i = value.toInt();
        if (i < 0 || i >= items.length) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_label(items[i]), style: style),
        );
      },
    ),
  ),
);

/// Evolução do dinheiro livre: uma barra por período (mais antigo à esquerda).
class EvolutionChart extends StatelessWidget {
  const EvolutionChart({super.key, required this.items});

  /// Em ordem cronológica.
  final List<SeriesItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          titlesData: _titles(items, small),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                formatBrl(items[group.x].totals.surplus),
                TextStyle(color: scheme.onInverseSurface),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < items.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: _reais(items[i].totals.surplus),
                    color: items[i].totals.surplus.isNegative
                        ? scheme.error
                        : scheme.primary,
                    width: 14,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Comparativo: receitas, despesas e investimentos lado a lado por período.
class ComparisonChart extends StatelessWidget {
  const ComparisonChart({super.key, required this.items});

  /// Em ordem cronológica.
  final List<SeriesItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    final colors = [scheme.primary, scheme.error, scheme.tertiary];
    const names = ['Receitas', 'Despesas', 'Investimentos'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          children: [
            for (var i = 0; i < 3; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, color: colors[i]),
                  const SizedBox(width: 4),
                  Text(names[i], style: small),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              titlesData: _titles(items, small),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, rodIndex) {
                    final t = items[group.x].totals;
                    final v = [t.income, t.expense, t.investment][rodIndex];
                    return BarTooltipItem(
                      '${names[rodIndex]}\n${formatBrl(v)}',
                      TextStyle(color: scheme.onInverseSurface),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < items.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      for (final (j, v) in [
                        items[i].totals.income,
                        items[i].totals.expense,
                        items[i].totals.investment,
                      ].indexed)
                        BarChartRodData(
                          toY: _reais(v),
                          color: colors[j],
                          width: 6,
                          borderRadius: BorderRadius.circular(2),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
