import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/norte_theme.dart';
import '../../core/domain/money.dart';
import '../entries/entry_providers.dart';
import '../periods/period_navigation.dart';

/// Dashboard: dinheiro livre do período e sua composição (receitas, despesas
/// e investimentos; decisão D1 da Fase 7, revisa a D9 da Fase 4). Nenhum
/// "saldo": o único indicador é `receitas − despesas − investimentos`; as três
/// linhas vêm do mesmo cálculo do valor principal.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(selectedPeriodProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Column(
        children: [
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
                if (!v.exists) return MissingPeriodCard(view: v);
                return const _SurplusCard();
              },
            ),
          ),
        ],
      ),
    );
  }
}

const _tabular = [FontFeature.tabularFigures()];

class _SurplusCard extends ConsumerWidget {
  const _SurplusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(periodTotalsProvider);
    final theme = Theme.of(context);
    final colors = NorteColors.of(context);
    return RefreshIndicator(
      onRefresh: () async => refreshFinanceData(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          totals.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                const Text('Não foi possível calcular o dinheiro livre.'),
            data: (t) {
              final value = t?.surplus ?? BigInt.zero;
              final income = t?.income ?? BigInt.zero;
              final expense = t?.expense ?? BigInt.zero;
              final investment = t?.investment ?? BigInt.zero;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Dinheiro livre do período',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatBrl(value),
                    key: const Key('valor-sobra'),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 40,
                      fontFeatures: _tabular,
                      color: value.isNegative
                          ? colors.expense
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SplitBar(
                    income: income,
                    expense: expense,
                    investment: investment,
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          _CompositionRow(
                            label: 'Receitas',
                            valueKey: const Key('valor-receitas'),
                            value: income,
                            dot: colors.income,
                          ),
                          const Divider(),
                          _CompositionRow(
                            label: 'Despesas',
                            valueKey: const Key('valor-despesas'),
                            value: expense,
                            dot: colors.expense,
                          ),
                          const Divider(),
                          _CompositionRow(
                            label: 'Investimentos',
                            valueKey: const Key('valor-investimentos'),
                            value: investment,
                            dot: colors.investment,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Barra de proporção (só visual): quanto das receitas foi para despesas,
/// investimentos e o que sobrou. Os valores continuam vindo do cálculo oficial.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.income,
    required this.expense,
    required this.investment,
  });

  final BigInt income;
  final BigInt expense;
  final BigInt investment;

  /// Parte em milésimos (inteiros) de [total]; nunca negativa.
  static int _permille(BigInt part, BigInt total) {
    if (total <= BigInt.zero || part <= BigInt.zero) return 0;
    return ((part * BigInt.from(1000)) ~/ total).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NorteColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final spent = expense + investment;
    // Se gastou mais do que recebeu, a barra mostra só a divisão do gasto.
    final base = income > spent ? income : spent;
    final free = income - spent;
    final segments = <(int, Color)>[
      (_permille(expense, base), colors.expense),
      (_permille(investment, base), colors.investment),
      (_permille(free, base), scheme.primary),
    ].where((s) => s.$1 > 0).toList();
    return Semantics(
      label: 'Divisão das receitas entre despesas, investimentos e livre',
      child: SizedBox(
        height: 10,
        child: segments.isEmpty
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < segments.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      flex: segments[i].$1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: segments[i].$2,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Uma linha da composição: ponto de cor, rótulo e valor em reais.
class _CompositionRow extends StatelessWidget {
  const _CompositionRow({
    required this.label,
    required this.valueKey,
    required this.value,
    required this.dot,
  });

  final String label;
  final Key valueKey;
  final BigInt value;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(
            formatBrl(value),
            key: valueKey,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}
