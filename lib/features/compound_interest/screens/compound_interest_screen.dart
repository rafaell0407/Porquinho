import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/money.dart';
import '../../tools/registry/tool_registry.dart' show compoundInterestTool;
import '../../tools/widgets/tool_explanation.dart' show showToolInfoSheet;
import '../application/simulation_controllers.dart';
import '../domain/compound_interest.dart';
import '../domain/simulation_math.dart';
import '../widgets/evolution_chart.dart';
import '../widgets/evolution_table.dart';
import '../widgets/result_cards.dart';
import '../widgets/simulation_form.dart';
import '../widgets/simulation_page.dart';

/// Ferramentas → Calculadora de juros compostos (rota `/juros-compostos`).
/// Só simula: não grava nada e não cria lançamentos.
class CompoundInterestScreen extends ConsumerStatefulWidget {
  const CompoundInterestScreen({super.key});

  static const route = '/juros-compostos';
  static const withdrawalsRoute = '/juros-compostos/retiradas';

  @override
  ConsumerState<CompoundInterestScreen> createState() =>
      _CompoundInterestScreenState();
}

class _CompoundInterestScreenState
    extends ConsumerState<CompoundInterestScreen> {
  static const _defaultRatePeriod = RatePeriod.annual;
  static const _defaultTermUnit = TermUnit.years;

  final _initial = TextEditingController();
  final _monthly = TextEditingController();
  final _rate = TextEditingController();
  final _term = TextEditingController();
  final _resultKey = GlobalKey();
  RatePeriod _ratePeriod = _defaultRatePeriod;
  TermUnit _termUnit = _defaultTermUnit;
  Map<CompoundField, String> _errors = const {};

  @override
  void dispose() {
    for (final c in [_initial, _monthly, _rate, _term]) {
      c.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    final v = validateCompoundInterest(
      initial: _initial.text,
      monthly: _monthly.text,
      rate: _rate.text,
      ratePeriod: _ratePeriod,
      term: _term.text,
      termUnit: _termUnit,
    );
    setState(() => _errors = v.errors);
    final controller = ref.read(compoundInterestProvider.notifier);
    if (v.input == null) {
      controller.clear();
      return;
    }
    controller.calculate(v.input!);
    scrollToResult(_resultKey);
  }

  void _clear() {
    FocusScope.of(context).unfocus();
    for (final c in [_initial, _monthly, _rate, _term]) {
      c.clear();
    }
    setState(() {
      _ratePeriod = _defaultRatePeriod;
      _termUnit = _defaultTermUnit;
      _errors = const {};
    });
    ref.read(compoundInterestProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = ref.watch(compoundInterestProvider);
    final result = outcome.result;
    return SimulationPage(
      title: 'Juros compostos',
      actions: [
        IconButton(
          key: const Key('juros-info'),
          tooltip: 'Sobre a calculadora',
          icon: const Icon(Icons.info_outline),
          onPressed: () => showToolInfoSheet(context, compoundInterestTool),
        ),
      ],
      children: [
        SimulationSection(
          title: 'Simulador de juros compostos',
          children: [
            ResponsivePair(
              first: MoneyField(
                fieldKey: const Key('juros-campo-inicial'),
                controller: _initial,
                label: 'Valor inicial',
                error: _errors[CompoundField.initial],
              ),
              second: MoneyField(
                fieldKey: const Key('juros-campo-mensal'),
                controller: _monthly,
                label: 'Valor mensal',
                error: _errors[CompoundField.monthly],
              ),
            ),
            const SizedBox(height: 14),
            ResponsivePair(
              first: RateField(
                controller: _rate,
                period: _ratePeriod,
                error: _errors[CompoundField.rate],
                onPeriodChanged: (p) => setState(() => _ratePeriod = p),
              ),
              second: TermField(
                controller: _term,
                unit: _termUnit,
                error: _errors[CompoundField.term],
                onUnitChanged: (u) => setState(() => _termUnit = u),
              ),
            ),
            const SizedBox(height: 20),
            SimulationActions(
              onCalculate: _calculate,
              secondary: [
                TextButton(
                  key: const Key('juros-simular-retiradas'),
                  onPressed: () =>
                      context.push(CompoundInterestScreen.withdrawalsRoute),
                  child: const Text('Simular retiradas mensais'),
                ),
                TextButton(
                  key: const Key('juros-limpar'),
                  onPressed: _clear,
                  child: const Text('Limpar'),
                ),
              ],
            ),
          ],
        ),
        if (outcome.error != null) ...[
          const SizedBox(height: 16),
          SimulationErrorBanner(message: outcome.error!),
        ],
        if (result != null) ...[
          const SizedBox(height: 16),
          _CompoundResult(key: _resultKey, result: result),
        ],
      ],
    );
  }
}

class _CompoundResult extends StatelessWidget {
  const _CompoundResult({required this.result, super.key});

  final CompoundInterestResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final input = result.input;
    final rows = result.rows;
    return SimulationSection(
      title: 'Resultado',
      children: [
        ResultCaption(
          '${formatBrl(input.initialCents)} iniciais + '
          '${formatBrl(input.monthlyCents)} por mês · '
          '${rateCaption(input.rate)} · ${monthsText(input.months)}',
        ),
        ResultCards(
          values: [
            ResultValue(
              key: const Key('juros-valor-final'),
              label: 'Valor total final',
              cents: result.finalTotal,
            ),
            ResultValue(
              key: const Key('juros-valor-investido'),
              label: 'Valor total investido',
              cents: result.totalInvested,
            ),
            ResultValue(
              key: const Key('juros-valor-juros'),
              label: 'Total em juros',
              cents: result.totalInterest,
            ),
          ],
        ),
        const SubsectionTitle('Evolução do patrimônio'),
        EvolutionChart(
          key: const Key('juros-grafico'),
          series: [
            ChartSeries(
              label: 'Total acumulado',
              color: scheme.primary,
              values: [for (final r in rows) r.total],
            ),
            ChartSeries(
              label: 'Total investido',
              color: scheme.onSurfaceVariant,
              values: [for (final r in rows) r.invested],
            ),
          ],
        ),
        const SubsectionTitle('Mês a mês'),
        EvolutionTable(
          key: const Key('juros-tabela'),
          headers: const [
            'Mês',
            'Juros',
            'Total investido',
            'Total juros',
            'Total acumulado',
          ],
          rowCount: rows.length,
          cells: (i) {
            final r = rows[i];
            return [
              '${r.month}',
              formatBrl(r.interest),
              formatBrl(r.invested),
              formatBrl(r.totalInterest),
              formatBrl(r.total),
            ];
          },
        ),
      ],
    );
  }
}
