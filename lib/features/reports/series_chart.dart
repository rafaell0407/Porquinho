import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme/norte_theme.dart';
import '../../core/domain/money.dart';
import 'reports_providers.dart';

/// Gráficos dos relatórios 4 e 5. Os valores em `double` servem somente para
/// desenhar; os números exibidos em texto continuam vindo de `BigInt`.
double _reais(BigInt cents) => cents.toDouble() / 100;

String _label(SeriesItem item) {
  final start = item.range.start.toBr();
  return start.length >= 5 ? start.substring(0, 5) : start;
}

/// Espaço mínimo entre dois rótulos do eixo, em pixels lógicos.
const double _labelGap = 8;

/// De quantos em quantos períodos mostrar rótulo no eixo (A8): 1 mostra
/// todos; 2 mostra um sim, outro não; e assim por diante. Calculado pela
/// largura disponível, para que os rótulos nunca fiquem colados.
@visibleForTesting
int axisLabelStep({
  required int count,
  required double width,
  required double labelWidth,
}) {
  if (count <= 1 || width <= 0 || !width.isFinite) return 1;
  final slot = width / count;
  final step = ((labelWidth + _labelGap) / slot).ceil();
  return step < 1 ? 1 : step;
}

/// Se o rótulo do índice [i] aparece. Conta a partir do período mais
/// recente (à direita), que sempre tem rótulo.
@visibleForTesting
bool showAxisLabel(int i, int count, int step) => (count - 1 - i) % step == 0;

double _labelWidth(TextStyle? style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: '00/00', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final w = painter.width;
  painter.dispose();
  return w;
}

FlTitlesData _titles(
  BuildContext context,
  List<SeriesItem> items,
  TextStyle? style,
  double width,
) {
  final step = axisLabelStep(
    count: items.length,
    width: width,
    labelWidth: _labelWidth(style, MediaQuery.textScalerOf(context)),
  );
  return FlTitlesData(
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
          if (!showAxisLabel(i, items.length, step)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_label(items[i]), style: style),
          );
        },
      ),
    ),
  );
}

/// Uma barra por período (mais antigo à esquerda) com o valor de [valueOf].
/// Negativos na cor de erro.
class SeriesBarChart extends StatelessWidget {
  const SeriesBarChart({
    super.key,
    required this.items,
    required this.valueOf,
    this.color,
    this.height = 200,
  });

  /// Em ordem cronológica.
  final List<SeriesItem> items;
  final BigInt Function(SeriesItem item) valueOf;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) => BarChart(
          BarChartData(
            titlesData: _titles(context, items, small, box.maxWidth),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  formatBrl(valueOf(items[group.x])),
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
                      toY: _reais(valueOf(items[i])),
                      color: valueOf(items[i]).isNegative
                          ? scheme.error
                          : color ?? scheme.primary,
                      width: 14,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Evolução do dinheiro livre: uma barra por período (mais antigo à esquerda).
class EvolutionChart extends StatelessWidget {
  const EvolutionChart({super.key, required this.items, this.height = 200});

  /// Em ordem cronológica.
  final List<SeriesItem> items;
  final double height;

  @override
  Widget build(BuildContext context) => SeriesBarChart(
    items: items,
    height: height,
    valueOf: (i) => i.totals.surplus,
  );
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
    final flow = NorteColors.of(context);
    final colors = [flow.income, flow.expense, flow.investment];
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
          child: LayoutBuilder(
            builder: (context, box) => BarChart(
              BarChartData(
                titlesData: _titles(context, items, small, box.maxWidth),
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
        ),
      ],
    );
  }
}
