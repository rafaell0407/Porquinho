import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _SurplusCard extends ConsumerWidget {
  const _SurplusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(periodTotalsProvider);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async => refreshFinanceData(ref),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: totals.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    const Text('Não foi possível calcular o dinheiro livre.'),
                data: (t) {
                  final value = t?.surplus ?? BigInt.zero;
                  return Column(
                    children: [
                      Text(
                        'Dinheiro livre do período',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatBrl(value),
                        key: const Key('valor-sobra'),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: value.isNegative
                              ? theme.colorScheme.error
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      _CompositionRow(
                        label: 'Receitas',
                        valueKey: const Key('valor-receitas'),
                        value: t?.income ?? BigInt.zero,
                      ),
                      _CompositionRow(
                        label: 'Despesas',
                        valueKey: const Key('valor-despesas'),
                        value: t?.expense ?? BigInt.zero,
                      ),
                      _CompositionRow(
                        label: 'Investimentos',
                        valueKey: const Key('valor-investimentos'),
                        value: t?.investment ?? BigInt.zero,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma linha da composição: rótulo e valor em reais.
class _CompositionRow extends StatelessWidget {
  const _CompositionRow({
    required this.label,
    required this.valueKey,
    required this.value,
  });

  final String label;
  final Key valueKey;
  final BigInt value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatBrl(value), key: valueKey, style: style),
        ],
      ),
    );
  }
}
