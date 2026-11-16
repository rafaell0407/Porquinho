import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import '../cash_or_installments_texts.dart';
import '../domain/cash_or_installments_engine.dart';
import '../domain/purchase_input.dart' show formatPercentE2;

/// Resultado da Calculadora à vista ou parcelado (spec §8 e §11).

/// "1.000,00" (sem "R$", para tabelas).
String plainBrl(BigInt cents) => formatBrl(cents).substring(3);

const _weekdays = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

String weekdayName(CalendarDate d) => _weekdays[d.weekday - 1];

String shortDate(CalendarDate d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

const _months = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String monthYear(CalendarDate d) =>
    '${_months[d.month - 1]}/${(d.year % 100).toString().padLeft(2, '0')}';

/// Cartão do veredito.
class VerdictCard extends StatelessWidget {
  const VerdictCard({required this.result, super.key});

  final SimulationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final verdict = result.verdict;
    final last = result.lastDueDate.toBr();
    final headline = switch (verdict) {
      Verdict.cash => 'À VISTA',
      Verdict.installments => 'A PRAZO',
      Verdict.tie => 'DÁ NO MESMO',
    };
    final pill = verdict == Verdict.tie
        ? 'Diferença menor que R\$ 1,00'
        : '${formatBrl(result.difference.abs())} a mais no seu bolso';
    Widget line(String how, BigInt cash) => Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Pagando '),
          TextSpan(
            text: how,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text:
                ', até a última parcela ($last), você terá o que comprou e '
                'mais ',
          ),
          TextSpan(
            text: formatBrl(cash),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: ' em caixa.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
    );

    return Card(
      key: const Key('avp-veredito'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 6, color: scheme.primary),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              children: [
                if (verdict != Verdict.tie)
                  Text(
                    'O MELHOR É PAGAR',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    headline,
                    key: const Key('avp-veredito-titulo'),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    pill,
                    key: const Key('avp-veredito-diferenca'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                line('À VISTA', result.cashPath.cash),
                const SizedBox(height: 10),
                line('A PRAZO', result.installmentPath.cash),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              CashOrInstallmentsTexts.footer,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Premissas usadas no resultado.
class AssumptionsBlock extends StatelessWidget {
  const AssumptionsBlock({
    required this.result,
    required this.rateDate,
    super.key,
  });

  final SimulationResult result;

  /// Data da taxa do Banco Central (`null` = taxa digitada).
  final CalendarDate? rateDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final input = result.input;
    final product = input.product;
    final apply = result.applicationDate;
    final chips = [
      'Simulação de ${input.today.toBr()}',
      apply == input.today
          ? 'Aplicação hoje'
          : 'Aplicação em ${shortDate(apply)} (1º dia útil)',
      product == InvestmentProduct.cdb
          ? 'CDB ${formatPercentE2(input.percentE2)} do CDI'
          : 'Tesouro Selic',
      '${product.indexName} ${formatPercentE2(input.annualRateE2)} a.a. · '
          '${rateDate == null ? 'taxa informada' : 'taxa de ${rateDate!.toBr()}'}',
      'Taxa constante até o fim',
    ];
    return Column(
      key: const Key('avp-premissas'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Esta simulação considera que você já tem ',
                  ),
                  TextSpan(
                    text: '${formatBrl(result.reserve)} reservados',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        ' para pagar todas as parcelas, sem depender do '
                        'rendimento.',
                  ),
                ],
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in chips)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(c, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ],
    );
  }
}

/// Comparação lado a lado.
class SideBySideTable extends StatelessWidget {
  const SideBySideTable({required this.result, super.key});

  final SimulationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final av = result.cashPath;
    final ap = result.installmentPath;
    final inst = result.input.installments;
    final allEqual = inst.every((i) => i.cents == inst.first.cents);
    final howPaid = allEqual
        ? '${inst.length}x de ${plainBrl(inst.first.cents)}'
        : '1ª de ${plainBrl(inst.first.cents)} + ${inst.length - 1}x de '
              '${plainBrl(inst.last.cents)}';
    final num = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final small = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final label = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    String neg(BigInt v) => v == BigInt.zero ? '0,00' : '−${plainBrl(v)}';

    TableRow row(
      String name,
      String a,
      String b, {
      String? noteA,
      String? noteB,
      bool total = false,
    }) {
      Widget cell(String t, String? note, {bool highlight = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: total ? 12 : 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              t,
              textAlign: TextAlign.right,
              style: total
                  ? num?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: highlight ? scheme.primary : null,
                    )
                  : num,
            ),
            if (note != null) Text(note, style: small),
          ],
        ),
      );
      return TableRow(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: total ? scheme.onSurface : scheme.outlineVariant,
              width: total ? 2 : 1,
            ),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: total ? 12 : 9),
            child: Text(
              name,
              style: total
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )
                  : label,
            ),
          ),
          cell(a, noteA, highlight: result.verdict == Verdict.cash),
          cell(b, noteB, highlight: result.verdict == Verdict.installments),
        ],
      );
    }

    return Card(
      key: const Key('avp-lado-a-lado'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Lado a lado', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.25),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    for (final h in ['À vista', 'A prazo'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          h,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                row(
                  'Valor pago',
                  plainBrl(result.input.cashPriceCents),
                  plainBrl(result.input.totalInstallmentsCents),
                  noteA: 'hoje',
                  noteB: howPaid,
                ),
                row(
                  'Fica investido no início',
                  plainBrl(av.invested),
                  plainBrl(ap.invested),
                ),
                row(
                  'Rendimento',
                  plainBrl(av.yieldCents),
                  plainBrl(ap.yieldCents),
                ),
                row('Imposto de Renda', neg(av.incomeTax), neg(ap.incomeTax)),
                row('IOF', neg(av.iof), neg(ap.iof)),
                row(
                  'Em caixa no fim',
                  formatBrl(av.cash),
                  formatBrl(ap.cash),
                  total: true,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Valores em reais. No fim, o que sobra é considerado '
              'resgatado, já com IR e IOF.',
              style: small,
            ),
          ],
        ),
      ),
    );
  }
}

/// Saldo aplicado nos dois caminhos: um ponto na aplicação e um por fatura.
class BalanceChart extends StatelessWidget {
  const BalanceChart({required this.result, super.key});

  final SimulationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final dates = [
      result.applicationDate,
      for (final p in result.chart) p.date,
    ];
    final cashValues = [
      result.cashPath.invested,
      for (final p in result.chart) p.cashPath,
    ];
    final instValues = [
      result.reserve,
      for (final p in result.chart) p.installmentPath,
    ];
    final series = [
      ('À vista', scheme.primary, cashValues),
      ('A prazo', scheme.onSurfaceVariant, instValues),
    ];
    var maxV = 0.0;
    for (final (_, _, values) in series) {
      for (final v in values) {
        maxV = math.max(maxV, v.toDouble() / 100);
      }
    }
    final step = _niceStep(math.max(maxV, 1) / 4);
    final maxY = (maxV / step).ceil() * step;
    final lastX = (dates.length - 1).toDouble();

    return Card(
      key: const Key('avp-grafico'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Saldo investido até a última parcela',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                for (final (name, color, _) in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 3,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(name, style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: math.max(lastX, 1),
                    minY: 0,
                    maxY: maxY <= 0 ? step : maxY,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: step,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(bottom: BorderSide(color: scheme.outline)),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          interval: step,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(_compact(value), style: small),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: math.max(1, (lastX / 3).ceilToDouble()),
                          getTitlesWidget: (value, meta) {
                            final i = value.round();
                            if (value != value.roundToDouble() ||
                                i < 0 ||
                                i >= dates.length) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(monthYear(dates[i]), style: small),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => scheme.inverseSurface,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        tooltipBorderRadius: BorderRadius.circular(10),
                        getTooltipItems: (spots) => [
                          for (final (i, s) in spots.indexed)
                            LineTooltipItem(
                              '${i == 0 ? '${dates[s.x.toInt()].toBr()}\n' : ''}'
                              '${series[s.barIndex].$1}: '
                              '${formatBrl(series[s.barIndex].$3[s.x.toInt()])}',
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
                      for (final (_, color, values) in series)
                        LineChartBarData(
                          spots: [
                            for (final (i, v) in values.indexed)
                              FlSpot(i.toDouble(), v.toDouble() / 100),
                          ],
                          color: color,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Um ponto por fatura paga. Toque num ponto para ver a data e o '
              'valor.',
              style: small,
            ),
          ],
        ),
      ),
    );
  }

  static double _niceStep(double raw) {
    final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / exp;
    final nice = f <= 1
        ? 1.0
        : f <= 2
        ? 2.0
        : f <= 5
        ? 5.0
        : 10.0;
    return nice * exp;
  }

  static String _compact(double v) {
    if (v >= 1e6) {
      return '${(v / 1e6).toStringAsFixed(v % 1e6 == 0 ? 0 : 1).replaceAll('.', ',')} mi';
    }
    if (v >= 1e4) {
      return '${(v / 1e3).toStringAsFixed(v % 1e3 == 0 ? 0 : 1).replaceAll('.', ',')} mil';
    }
    final whole = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) b.write('.');
      b.write(whole[i]);
    }
    return b.toString();
  }
}

/// Tabela "A prazo, fatura a fatura" (rola na horizontal só dentro dela).
class InstallmentsTable extends StatelessWidget {
  const InstallmentsTable({required this.result, super.key});

  final SimulationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cell = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: scheme.onSurface,
    );
    final head = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurfaceVariant,
    );
    final note = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    const headers = [
      'Data',
      'Saldo inicial',
      'Rendimento',
      'Impostos',
      'Parcela paga',
      'Saldo final',
    ];

    Widget c(String t, {TextStyle? style, bool left = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Text(
        t,
        textAlign: left ? TextAlign.left : TextAlign.right,
        style: style ?? cell,
        softWrap: false,
      ),
    );

    String? noteFor(InstallmentRow r) {
      if (r.paidFromReserve) return 'paga direto da reserva';
      if (r.redeemDate != r.dueDate) {
        return 'vence ${weekdayName(r.dueDate)}; resgate em '
            '${shortDate(r.redeemDate)}';
      }
      return null;
    }

    final border = BorderSide(color: scheme.outlineVariant);
    final rows = <TableRow>[
      TableRow(
        children: [
          for (final (i, h) in headers.indexed) c(h, style: head, left: i == 0),
        ],
      ),
      for (final (i, r) in result.rows.indexed)
        TableRow(
          key: ValueKey('avp-tabela-linha-$i'),
          decoration: BoxDecoration(border: Border(top: border)),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.dueDate.toBr(), style: cell),
                  if (noteFor(r) case final n?)
                    Text(n, style: note?.copyWith(fontSize: 10)),
                ],
              ),
            ),
            c(plainBrl(r.startBalance)),
            c(plainBrl(r.yieldCents)),
            c(plainBrl(r.taxes)),
            c(plainBrl(r.installment)),
            c(plainBrl(r.endBalance)),
          ],
        ),
      TableRow(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.onSurface, width: 2)),
        ),
        children: [
          c(
            'Resgate do que sobrou',
            left: true,
            style: cell?.copyWith(fontWeight: FontWeight.w700),
          ),
          c(plainBrl(result.finalRedemption.startBalance)),
          c('—'),
          c(plainBrl(result.finalRedemption.taxes)),
          c('—'),
          c(
            '${plainBrl(result.finalRedemption.cash)} em caixa',
            style: cell?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ];

    return Card(
      key: const Key('avp-tabela'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'A prazo, fatura a fatura',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              key: const Key('avp-tabela-horizontal'),
              scrollDirection: Axis.horizontal,
              primary: false,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: rows,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Impostos = IR + IOF. Arraste a tabela para o lado para ver '
                'todas as colunas.',
                style: note,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
