import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/money.dart';

/// Série do gráfico: um valor (em centavos) por mês, começando no mês 0.
class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<BigInt> values;
}

/// Converte para desenhar. O `double` só posiciona pontos e escala o eixo;
/// os valores consultados (tooltip) usam os centavos exatos.
double _reais(BigInt cents) => cents.toDouble() / 100;

/// Passo "redondo" (1, 2, 2,5 ou 5 × 10^k) próximo de [raw].
double niceStep(double raw) {
  if (raw <= 0 || raw.isNaN || raw.isInfinite) return 1;
  final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / exp;
  final nice = f <= 1
      ? 1.0
      : f <= 2
      ? 2.0
      : f <= 2.5
      ? 2.5
      : f <= 5
      ? 5.0
      : 10.0;
  return nice * exp;
}

/// Rótulo compacto do eixo vertical: "800", "8,2 mil", "1,5 mi".
String compactBrl(double value, double step) {
  final abs = value.abs();
  const units = [(1e12, 'tri'), (1e9, 'bi'), (1e6, 'mi'), (1e3, 'mil')];
  for (final (size, name) in units) {
    if (abs >= size) {
      final scaled = value / size;
      final s = step / size;
      final decimals = s >= 1 ? 0 : (s >= 0.1 ? 1 : 2);
      var text = scaled.toStringAsFixed(decimals);
      if (decimals > 0) text = text.replaceFirst(RegExp(r'\.?0+$'), '');
      return '${text.replaceAll('.', ',')} $name';
    }
  }
  return value.round().toString();
}

/// Evolução mês a mês com legenda, eixos e consulta por toque.
class EvolutionChart extends StatelessWidget {
  const EvolutionChart({required this.series, super.key})
    : assert(series.length > 0);

  final List<ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final months = series.first.values.length - 1;
    var minV = double.infinity;
    var maxV = -double.infinity;
    for (final s in series) {
      for (final v in s.values) {
        final d = _reais(v);
        minV = math.min(minV, d);
        maxV = math.max(maxV, d);
      }
    }
    // Começa no zero quando a menor série está perto dele; senão, aproxima
    // (como na referência) para a evolução ficar visível.
    if (minV < maxV * 0.35) minV = 0;
    var step = niceStep((maxV - minV) / 4);
    var minY = (minV / step).floor() * step;
    var maxY = (maxV / step).ceil() * step;
    if (maxY <= minY) {
      step = niceStep(math.max(maxV.abs(), 1) / 4);
      minY = math.max(0, minY - step);
      maxY = minY + step * 4;
    }
    final xStep = math.max(1, niceStep(months / 6).round()).toDouble();
    final showDots = months <= 36;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final s in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(s.label, style: theme.textTheme.bodySmall),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ChartBox(
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: months.toDouble(),
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: scheme.outline),
                    left: BorderSide(color: scheme.outline),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 58,
                      interval: step,
                      getTitlesWidget: (value, meta) {
                        if (value > maxY + step / 1000) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(compactBrl(value, step), style: small),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text('Mês', style: small),
                    axisNameSize: 18,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: xStep,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text('${value.toInt()}', style: small),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => scheme.inverseSurface,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipBorderRadius: BorderRadius.circular(12),
                    getTooltipItems: (spots) => [
                      for (final (i, spot) in spots.indexed)
                        LineTooltipItem(
                          '${i == 0 ? 'Mês ${spot.x.toInt()}\n' : ''}'
                          '${series[spot.barIndex].label}: '
                          '${formatBrl(series[spot.barIndex].values[spot.x.toInt()])}',
                          TextStyle(
                            color: scheme.onInverseSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  for (final s in series)
                    LineChartBarData(
                      spots: [
                        for (final (i, v) in s.values.indexed)
                          FlSpot(i.toDouble(), _reais(v)),
                      ],
                      color: s.color,
                      barWidth: 2.5,
                      isCurved: false,
                      dotData: FlDotData(
                        show: showDots,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 3,
                          color: scheme.surfaceContainer,
                          strokeWidth: 2,
                          strokeColor: s.color,
                        ),
                      ),
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

/// Altura do gráfico: proporcional no celular, limitada em tela larga.
class _ChartBox extends StatelessWidget {
  const _ChartBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      height: (constraints.maxWidth / 1.45).clamp(220.0, 360.0),
      child: child,
    ),
  );
}
