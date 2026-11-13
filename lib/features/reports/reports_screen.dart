import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/money.dart';
import '../../core/domain/reports.dart';
import '../periods/period_navigation.dart';
import 'reports_providers.dart';
import 'series_chart.dart';

/// Os cinco relatórios básicos (RF025; `requisitos.md` §13.7).
enum ReportKind {
  incomeByCategory('Receitas por categoria'),
  expenseByCategory('Despesas por categoria'),
  investments('Total destinado a investimentos'),
  evolution('Evolução do dinheiro livre entre períodos'),
  comparison('Comparativo por período');

  const ReportKind(this.title);
  final String title;

  /// Relatórios de um único período (1 a 3) ou de uma sequência (4 e 5).
  bool get isSeries =>
      this == ReportKind.evolution || this == ReportKind.comparison;
}

/// Mais → Relatórios.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportKind _kind = ReportKind.incomeByCategory;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(selectedPeriodProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButtonFormField<ReportKind>(
              key: const Key('seletor-relatorio'),
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Relatório'),
              items: [
                for (final k in ReportKind.values)
                  DropdownMenuItem(value: k, child: Text(k.title)),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
          ),
          const PeriodNavigator(),
          Expanded(
            child: view.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não foi possível carregar o período.'),
                    TextButton(
                      onPressed: () => ref.invalidate(selectedPeriodProvider),
                      child: const Text('Tentar de novo'),
                    ),
                  ],
                ),
              ),
              data: (v) {
                if (v == null) {
                  return const Center(child: Text('Nenhum período ainda.'));
                }
                return _kind.isSeries
                    ? _SeriesReport(kind: _kind)
                    : _PeriodReport(kind: _kind);
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _failure(VoidCallback retry) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Não foi possível carregar o relatório.'),
      TextButton(onPressed: retry, child: const Text('Tentar de novo')),
    ],
  ),
);

/// Relatórios 1 a 3 (um período).
class _PeriodReport extends ConsumerWidget {
  const _PeriodReport({required this.kind});

  final ReportKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(selectedPeriodReportProvider);
    final names = ref.watch(categoryNamesProvider).value ?? const {};
    return report.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          _failure(() => ref.invalidate(selectedPeriodReportProvider)),
      data: (r) {
        if (r == null) return const SizedBox.shrink();
        final id = r.periods.single.range;
        return switch (kind) {
          ReportKind.incomeByCategory => _CategoryList(
            key: const Key('relatorio-receitas'),
            breakdown: r.incomeOf(id),
            names: names,
            emptyText: 'Nenhuma receita recebida neste período.',
          ),
          ReportKind.expenseByCategory => _CategoryList(
            key: const Key('relatorio-despesas'),
            breakdown: r.expenseOf(id),
            names: names,
            emptyText: 'Nenhuma despesa neste período.',
          ),
          _ => _InvestmentTotal(total: r.totalsOf(id).investment),
        };
      },
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    super.key,
    required this.breakdown,
    required this.names,
    required this.emptyText,
  });

  final CategoryBreakdown breakdown;
  final Map<String, String> names;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('Total'),
            trailing: Text(
              formatBrl(breakdown.total),
              key: const Key('total-relatorio'),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        if (breakdown.items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(emptyText, key: const Key('relatorio-vazio')),
          ),
        for (final item in breakdown.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              key: Key('categoria-${item.categoryId ?? 'sem'}'),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.categoryId == null
                            ? 'Sem categoria'
                            : names[item.categoryId] ?? 'Categoria',
                      ),
                    ),
                    Text(formatBrl(item.amount)),
                    SizedBox(
                      width: 64,
                      child: Text(
                        _percent(breakdown.basisPoints(item)),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: breakdown.basisPoints(item) / 10000,
                  minHeight: 6,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Participação em pontos-base (1/100 de %) como "12,3%".
String _percent(int basisPoints) {
  final tenths = basisPoints ~/ 10;
  return '${tenths ~/ 10},${tenths % 10}%';
}

class _InvestmentTotal extends StatelessWidget {
  const _InvestmentTotal({required this.total});

  final BigInt total;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Total destinado a investimentos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  formatBrl(total),
                  key: const Key('total-investimentos'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Relatórios 4 e 5 (últimos 12 períodos até o selecionado).
class _SeriesReport extends ConsumerWidget {
  const _SeriesReport({required this.kind});

  final ReportKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(periodSeriesProvider);
    return series.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _failure(() => ref.invalidate(periodSeriesProvider)),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Nenhum período para mostrar.'));
        }
        // Mais recente primeiro: é o que o usuário acabou de selecionar.
        final shown = items.reversed.toList();
        final scale = shown.fold<BigInt>(BigInt.zero, (m, i) {
          final t = i.totals;
          final biggest = [
            t.surplus.abs(),
            t.income,
            t.expense,
            t.investment,
          ].reduce((a, b) => a > b ? a : b);
          return biggest > m ? biggest : m;
        });
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Últimos ${items.length} períodos até o selecionado',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: kind == ReportKind.evolution
                  ? EvolutionChart(items: items)
                  : ComparisonChart(items: items),
            ),
            for (final item in shown)
              kind == ReportKind.evolution
                  ? _EvolutionRow(item: item, scale: scale)
                  : _ComparisonRow(item: item, scale: scale),
          ],
        );
      },
    );
  }
}

String _rangeLabel(SeriesItem item) =>
    '${item.range.start.toBr()} a '
    '${item.range.end.addDays(-1).toBr()}';

double _ratio(BigInt value, BigInt scale) => scale == BigInt.zero
    ? 0
    : (value * BigInt.from(1000) ~/ scale).toInt() / 1000;

class _EvolutionRow extends StatelessWidget {
  const _EvolutionRow({required this.item, required this.scale});

  final SeriesItem item;
  final BigInt scale;

  @override
  Widget build(BuildContext context) {
    final value = item.totals.surplus;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: Key('evolucao-${item.range.start.toIso()}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_rangeLabel(item))),
              Text(
                formatBrl(value),
                style: TextStyle(
                  color: value.isNegative ? scheme.error : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _ratio(value.abs(), scale),
            minHeight: 6,
            color: value.isNegative ? scheme.error : null,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.item, required this.scale});

  final SeriesItem item;
  final BigInt scale;

  @override
  Widget build(BuildContext context) {
    final t = item.totals;
    final text = Theme.of(context).textTheme;
    Widget line(String label, BigInt value, Key key) => Padding(
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
          LinearProgressIndicator(value: _ratio(value, scale), minHeight: 4),
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
            Text(_rangeLabel(item), style: text.titleSmall),
            const SizedBox(height: 4),
            line('Receitas', t.income, Key('comp-receitas-$start')),
            line('Despesas', t.expense, Key('comp-despesas-$start')),
            line('Investimentos', t.investment, Key('comp-invest-$start')),
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
