import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/norte_theme.dart';
import '../../../core/domain/money.dart';
import '../application/simulation_controllers.dart';
import '../domain/simulation_math.dart';
import '../domain/withdrawal_simulation.dart';
import '../widgets/evolution_chart.dart';
import '../widgets/evolution_table.dart';
import '../widgets/result_cards.dart';
import '../widgets/simulation_form.dart';
import '../widgets/simulation_page.dart';

/// Premissas da simulação de retiradas (ícone de informação).
const withdrawalAssumptions = [
  'Os juros incidem sobre o saldo do início de cada mês.',
  'A retirada acontece no final do mês, depois dos juros.',
  'O saldo nunca fica negativo: se não cobre a retirada, retira-se o que '
      'resta e a simulação para nesse mês, mostrando quando o dinheiro acabou.',
  'Retirada zero dá o mesmo resultado de uma simulação sem retiradas.',
  'Taxa anual convertida na mensal equivalente: 12% ao ano ≈ 0,9489% '
      'ao mês, o que rende exatamente 12% em 12 meses.',
  'Não considera impostos, inflação nem tarifas. Não cria lançamentos.',
];

/// Juros compostos → Simular retiradas mensais
/// (rota `/juros-compostos/retiradas`). Parâmetros próprios; a simulação
/// principal não é alterada.
class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  static const _defaultRatePeriod = RatePeriod.annual;
  static const _defaultTermUnit = TermUnit.years;

  /// Valor final da simulação principal (sugestão do patrimônio inicial).
  late final String _suggestedInitial;
  late final _initial = TextEditingController(text: _suggestedInitial);
  final _withdrawal = TextEditingController();
  final _rate = TextEditingController();
  final _term = TextEditingController();
  final _resultKey = GlobalKey();
  RatePeriod _ratePeriod = _defaultRatePeriod;
  TermUnit _termUnit = _defaultTermUnit;
  Map<WithdrawalField, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    final main = ref.read(compoundInterestProvider).result;
    _suggestedInitial = main == null ? '' : moneyFieldText(main.finalTotal);
  }

  @override
  void dispose() {
    for (final c in [_initial, _withdrawal, _rate, _term]) {
      c.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    final v = validateWithdrawal(
      initial: _initial.text,
      withdrawal: _withdrawal.text,
      rate: _rate.text,
      ratePeriod: _ratePeriod,
      term: _term.text,
      termUnit: _termUnit,
    );
    setState(() => _errors = v.errors);
    final controller = ref.read(withdrawalProvider.notifier);
    if (v.input == null) {
      controller.clear();
      return;
    }
    controller.calculate(v.input!);
    scrollToResult(_resultKey);
  }

  void _clear() {
    FocusScope.of(context).unfocus();
    _initial.text = _suggestedInitial;
    for (final c in [_withdrawal, _rate, _term]) {
      c.clear();
    }
    setState(() {
      _ratePeriod = _defaultRatePeriod;
      _termUnit = _defaultTermUnit;
      _errors = const {};
    });
    ref.read(withdrawalProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = ref.watch(withdrawalProvider);
    final result = outcome.result;
    return SimulationPage(
      title: 'Retiradas mensais',
      children: [
        SimulationSection(
          title: 'Simular retiradas mensais',
          trailing: IconButton(
            key: const Key('retiradas-premissas'),
            tooltip: 'Como a simulação funciona',
            icon: const Icon(Icons.info_outline),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: () => _showAssumptions(context),
          ),
          children: [
            ResponsivePair(
              first: MoneyField(
                fieldKey: const Key('retiradas-campo-inicial'),
                controller: _initial,
                label: 'Patrimônio inicial',
                helper: _suggestedInitial.isEmpty
                    ? null
                    : 'Sugestão: valor final da simulação',
                error: _errors[WithdrawalField.initial],
              ),
              second: MoneyField(
                fieldKey: const Key('retiradas-campo-retirada'),
                controller: _withdrawal,
                label: 'Retirada mensal',
                error: _errors[WithdrawalField.withdrawal],
              ),
            ),
            const SizedBox(height: 14),
            ResponsivePair(
              first: RateField(
                keyPrefix: 'retiradas',
                controller: _rate,
                period: _ratePeriod,
                error: _errors[WithdrawalField.rate],
                onPeriodChanged: (p) => setState(() => _ratePeriod = p),
              ),
              second: TermField(
                keyPrefix: 'retiradas',
                controller: _term,
                unit: _termUnit,
                error: _errors[WithdrawalField.term],
                onUnitChanged: (u) => setState(() => _termUnit = u),
              ),
            ),
            const SizedBox(height: 20),
            SimulationActions(
              onCalculate: _calculate,
              secondary: [
                TextButton(
                  key: const Key('retiradas-limpar'),
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
          _WithdrawalResultView(key: _resultKey, result: result),
        ],
      ],
    );
  }
}

Future<void> _showAssumptions(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final body = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      return SingleChildScrollView(
        key: const Key('retiradas-premissas-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Como a simulação funciona',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final a in withdrawalAssumptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: body),
                    Expanded(child: Text(a, style: body)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    },
  );
}

class _WithdrawalResultView extends StatelessWidget {
  const _WithdrawalResultView({required this.result, super.key});

  final WithdrawalResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = NorteColors.of(context);
    final input = result.input;
    final rows = result.rows;
    final depletedAt = result.depletedAtMonth;
    return SimulationSection(
      title: 'Resultado',
      children: [
        ResultCaption(
          '${formatBrl(input.initialCents)} iniciais − '
          '${formatBrl(input.withdrawalCents)} por mês · '
          '${rateCaption(input.rate)} · ${monthsText(input.months)}',
        ),
        if (depletedAt != null)
          SimulationNotice(
            key: const Key('retiradas-esgotou'),
            icon: Icons.warning_amber_rounded,
            color: colors.pending,
            background: colors.pendingBackground,
            message:
                'O dinheiro acaba no mês $depletedAt, '
                '${depletedAt < input.months ? 'antes do fim dos ${monthsText(input.months)} simulados' : 'o último do período'}. '
                'A última retirada foi de ${formatBrl(rows.last.withdrawal)} '
                '(o que restava).',
          )
        else
          SimulationNotice(
            key: const Key('retiradas-durou'),
            icon: Icons.check_circle_outline,
            color: scheme.primary,
            background: scheme.primaryContainer,
            message:
                'O patrimônio dura todo o período de '
                '${monthsText(input.months)}.',
          ),
        const SizedBox(height: 14),
        ResultCards(
          values: [
            ResultValue(
              key: const Key('retiradas-valor-saldo'),
              label: 'Saldo final',
              cents: result.finalBalance,
            ),
            ResultValue(
              key: const Key('retiradas-valor-retirado'),
              label: 'Total retirado',
              cents: result.totalWithdrawn,
            ),
            ResultValue(
              key: const Key('retiradas-valor-juros'),
              label: 'Total em juros',
              cents: result.totalInterest,
            ),
          ],
        ),
        const SubsectionTitle('Evolução do patrimônio'),
        EvolutionChart(
          key: const Key('retiradas-grafico'),
          series: [
            ChartSeries(
              label: 'Saldo',
              color: scheme.primary,
              values: [for (final r in rows) r.balance],
            ),
            ChartSeries(
              label: 'Total retirado',
              color: scheme.onSurfaceVariant,
              values: [for (final r in rows) r.totalWithdrawn],
            ),
          ],
        ),
        const SubsectionTitle('Mês a mês'),
        EvolutionTable(
          key: const Key('retiradas-tabela'),
          headers: const [
            'Mês',
            'Juros',
            'Retirada',
            'Total retirado',
            'Saldo',
          ],
          rowCount: rows.length,
          highlightRow: depletedAt,
          cells: (i) {
            final r = rows[i];
            return [
              '${r.month}',
              formatBrl(r.interest),
              formatBrl(r.withdrawal),
              formatBrl(r.totalWithdrawn),
              formatBrl(r.balance),
            ];
          },
        ),
      ],
    );
  }
}
