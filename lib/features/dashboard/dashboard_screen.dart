import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/money.dart';
import '../entries/entry_providers.dart';
import '../periods/period_navigation.dart';

/// Dashboard da Fase 4: somente a sobra do período (decisão D9). Nenhum
/// "saldo": o único indicador é `receitas − despesas − investimentos`.
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
                    const Text('Não foi possível calcular a sobra.'),
                data: (t) {
                  final value = t?.surplus ?? BigInt.zero;
                  return Column(
                    children: [
                      Text(
                        'Sobra do período',
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
