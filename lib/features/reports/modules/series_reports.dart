import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../domain/free_money_change.dart';
import '../models/report_definition.dart';
import '../reports_providers.dart';
import '../series_chart.dart';
import '../widgets/report_parts.dart';

/// Base dos relatórios 3, 4 e 5: últimos 12 períodos até o selecionado (D8),
/// mesmos totais do dinheiro livre.
abstract class _SeriesReport extends ConsumerWidget {
  const _SeriesReport({required this.level, super.key});

  final ReportLevel level;

  Widget buildSeries(BuildContext context, List<SeriesItem> items);

  @override
  Widget build(BuildContext context, WidgetRef ref) => ReportAsync(
    value: ref.watch(periodSeriesProvider),
    level: level,
    onRetry: () => ref.invalidate(periodSeriesProvider),
    builder: (items) {
      if (items.isEmpty) {
        return ReportEmpty('Nenhum período para mostrar.', level: level);
      }
      return buildSeries(context, items);
    },
  );
}

Widget _seriesCaption(BuildContext context, int count) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    'Últimos $count períodos até o selecionado',
    style: Theme.of(context).textTheme.bodySmall,
  ),
);

double _ratio(BigInt value, BigInt scale) => scale == BigInt.zero
    ? 0
    : (value * BigInt.from(1000) ~/ scale).toInt() / 1000;

/// Relatório 3: total destinado a investimentos (período e sequência).
class InvestmentsReport extends _SeriesReport {
  const InvestmentsReport({required super.level, super.key});

  static const _empty = 'Nenhum investimento nos últimos períodos.';

  @override
  Widget buildSeries(BuildContext context, List<SeriesItem> items) {
    final id = ReportScope.of(context).id;
    final color = flowColors(context).$3;
    final total = items.last.totals.investment;
    final none = items.every((i) => i.totals.investment == BigInt.zero);
    switch (level) {
      case ReportLevel.compact || ReportLevel.preview:
        if (none) return ReportEmpty(_empty, level: level);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportHeadline(
              label: 'Investido no período',
              value: formatBrl(total),
              valueKey: Key('$id-total'),
            ),
            const SizedBox(height: 10),
            MiniBars(
              values: [for (final i in items) i.totals.investment],
              color: color,
            ),
          ],
        );
      case ReportLevel.expanded:
        if (none) return ReportEmpty(_empty, level: level);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportHeadline(
              label: 'Investido no período',
              value: formatBrl(total),
              valueKey: Key('$id-total'),
            ),
            const SizedBox(height: 12),
            SeriesBarChart(
              items: items,
              height: 160,
              color: color,
              valueOf: (i) => i.totals.investment,
            ),
          ],
        );
      case ReportLevel.full:
        final theme = Theme.of(context);
        final scale = items.fold<BigInt>(
          BigInt.zero,
          (m, i) => i.totals.investment > m ? i.totals.investment : m,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Total destinado a investimentos',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatBrl(total),
                      key: const Key('total-investimentos'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (none)
              ReportEmpty(_empty, level: level)
            else ...[
              _seriesCaption(context, items.length),
              SeriesBarChart(
                items: items,
                color: color,
                valueOf: (i) => i.totals.investment,
              ),
              const SizedBox(height: 16),
              for (final item in items.reversed)
                _ValueRow(
                  key: Key('investimento-${item.range.start.toIso()}'),
                  label: rangeLabel(item.range),
                  value: item.totals.investment,
                  ratio: _ratio(item.totals.investment, scale),
                  color: color,
                ),
            ],
          ],
        );
    }
  }
}

/// Relatório 4: evolução do dinheiro livre entre períodos.
class FreeMoneyReport extends _SeriesReport {
  const FreeMoneyReport({required super.level, super.key});

  static const _empty = 'Nenhum lançamento nos últimos períodos.';

  /// Mesmo critério de "sem lançamentos": todos os totais zerados.
  static bool _isEmpty(List<SeriesItem> items) => items.every(
    (i) =>
        i.totals.income == BigInt.zero &&
        i.totals.expense == BigInt.zero &&
        i.totals.investment == BigInt.zero,
  );

  @override
  Widget buildSeries(BuildContext context, List<SeriesItem> items) {
    final id = ReportScope.of(context).id;
    final scheme = Theme.of(context).colorScheme;
    final value = items.last.totals.surplus;
    final none = _isEmpty(items);
    final scale = items.fold<BigInt>(
      BigInt.zero,
      (m, i) => i.totals.surplus.abs() > m ? i.totals.surplus.abs() : m,
    );
    Widget headline() => ReportHeadline(
      label: 'Dinheiro livre do período',
      value: formatBrl(value),
      valueKey: Key('$id-valor'),
      color: value.isNegative ? scheme.error : null,
    );
    Widget row(SeriesItem item, Key key) => _ValueRow(
      key: key,
      label: rangeLabel(item.range),
      value: item.totals.surplus,
      ratio: _ratio(item.totals.surplus.abs(), scale),
      color: item.totals.surplus.isNegative ? scheme.error : scheme.primary,
      bold: true,
      negativeColor: scheme.error,
    );
    switch (level) {
      case ReportLevel.compact || ReportLevel.preview:
        if (none) return ReportEmpty(_empty, level: level);
        final change = freeMoneyChangeFromPrevious([
          for (final i in items) i.totals.surplus,
        ]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headline(),
            if (change != null)
              Text(
                _changeText(change),
                key: Key('$id-variacao'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 10),
            MiniBars(
              values: [for (final i in items) i.totals.surplus],
              color: scheme.primary,
              negativeColor: scheme.error,
            ),
          ],
        );
      case ReportLevel.expanded:
        if (none) return ReportEmpty(_empty, level: level);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headline(),
            const SizedBox(height: 12),
            EvolutionChart(items: items, height: 160),
            const SizedBox(height: 8),
            for (final item in items.reversed.take(3))
              row(item, Key('$id-evolucao-${item.range.start.toIso()}')),
          ],
        );
      case ReportLevel.full:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _seriesCaption(context, items.length),
            if (none)
              ReportEmpty(_empty, level: level)
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EvolutionChart(items: items),
              ),
            for (final item in items.reversed)
              row(item, Key('evolucao-${item.range.start.toIso()}')),
          ],
        );
    }
  }
}

/// "R$ X a mais/a menos que o período anterior" (diferença em centavos).
String _changeText(BigInt change) {
  if (change == BigInt.zero) return 'Igual ao período anterior';
  final amount = formatBrl(change.abs());
  return change.isNegative
      ? '$amount a menos que o período anterior'
      : '$amount a mais que o período anterior';
}

/// Relatório 5: comparativo de receitas, despesas e investimentos.
class ComparisonReport extends _SeriesReport {
  const ComparisonReport({required super.level, super.key});

  static const _empty = 'Nenhum lançamento neste período.';

  @override
  Widget buildSeries(BuildContext context, List<SeriesItem> items) {
    final id = ReportScope.of(context).id;
    final (incomeColor, expenseColor, investmentColor) = flowColors(context);
    final t = items.last.totals;
    switch (level) {
      case ReportLevel.compact || ReportLevel.preview:
        final none =
            t.income == BigInt.zero &&
            t.expense == BigInt.zero &&
            t.investment == BigInt.zero;
        if (none) return ReportEmpty(_empty, level: level);
        final sum = t.income + t.expense + t.investment;
        int weight(BigInt v) => (v * BigInt.from(10000) ~/ sum).toInt();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LegendValue(
              color: incomeColor,
              label: 'Receitas',
              value: formatBrl(t.income),
              valueKey: Key('$id-receitas'),
            ),
            LegendValue(
              color: expenseColor,
              label: 'Despesas',
              value: formatBrl(t.expense),
              valueKey: Key('$id-despesas'),
            ),
            LegendValue(
              color: investmentColor,
              label: 'Investimentos',
              value: formatBrl(t.investment),
              valueKey: Key('$id-investimentos'),
            ),
            const SizedBox(height: 10),
            SegmentedBar(
              segments: [
                (weight(t.income), incomeColor),
                (weight(t.expense), expenseColor),
                (weight(t.investment), investmentColor),
              ],
            ),
          ],
        );
      case ReportLevel.expanded:
        if (FreeMoneyReport._isEmpty(items)) {
          return ReportEmpty(
            'Nenhum lançamento nos últimos períodos.',
            level: level,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _seriesCaption(context, items.length),
            ComparisonChart(items: items),
          ],
        );
      case ReportLevel.full:
        final scale = items.fold<BigInt>(BigInt.zero, (m, i) {
          final x = i.totals;
          final biggest = [
            x.income,
            x.expense,
            x.investment,
          ].reduce((a, b) => a > b ? a : b);
          return biggest > m ? biggest : m;
        });
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _seriesCaption(context, items.length),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ComparisonChart(items: items),
            ),
            for (final item in items.reversed)
              _ComparisonCard(item: item, scale: scale),
          ],
        );
    }
  }
}

/// Linha "intervalo · valor" com barra proporcional.
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
    this.bold = false,
    this.negativeColor,
    super.key,
  });

  final String label;
  final BigInt value;
  final double ratio;
  final Color color;
  final bool bold;
  final Color? negativeColor;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                formatBrl(value),
                style: TextStyle(
                  color: value.isNegative ? negativeColor : null,
                  fontWeight: bold ? FontWeight.bold : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: color,
              backgroundColor: track,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.item, required this.scale});

  final SeriesItem item;
  final BigInt scale;

  @override
  Widget build(BuildContext context) {
    final t = item.totals;
    final text = Theme.of(context).textTheme;
    final (incomeColor, expenseColor, investmentColor) = flowColors(context);
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget line(String label, BigInt value, Key key, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: text.bodyMedium)),
              Text(formatBrl(value), key: key, style: text.bodyMedium),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _ratio(value, scale),
              minHeight: 4,
              color: color,
              backgroundColor: track,
            ),
          ),
        ],
      ),
    );
    final start = item.range.start.toIso();
    return Card(
      key: Key('comparativo-$start'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rangeLabel(item.range), style: text.titleSmall),
            const SizedBox(height: 4),
            line(
              'Receitas',
              t.income,
              Key('comp-receitas-$start'),
              incomeColor,
            ),
            line(
              'Despesas',
              t.expense,
              Key('comp-despesas-$start'),
              expenseColor,
            ),
            line(
              'Investimentos',
              t.investment,
              Key('comp-invest-$start'),
              investmentColor,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('Dinheiro livre')),
                Text(
                  formatBrl(t.surplus),
                  key: Key('comp-livre-$start'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
