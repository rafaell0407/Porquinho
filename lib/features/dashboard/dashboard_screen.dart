import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/norte_theme.dart';
import '../../core/domain/money.dart';
import '../../core/domain/period_calendar.dart';
import '../entries/entry_models.dart';
import '../entries/entry_providers.dart';
import '../periods/period_navigation.dart';
import '../periods/period_providers.dart';
import '../sync/sync_providers.dart';
import '../transactions/transactions_screen.dart';

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
      body: view.when(
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
          return Column(
            children: [
              PeriodHeader(view: v),
              Expanded(
                child: v.exists
                    ? const _DashboardBody()
                    : MissingPeriodCard(view: v),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _tabular = [FontFeature.tabularFigures()];
const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
const _monthsShort = [
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

/// "Novembro 2026" para mês-calendário inteiro; ciclo com dia inicial mostra
/// o intervalo (`dd/MM/aaaa a dd/MM/aaaa`).
String _periodLabel(PeriodRange range) {
  final start = range.start;
  final end = range.end;
  final wholeMonth =
      start.day == 1 && end.day == 1 && end.monthIndex == start.monthIndex + 1;
  if (wholeMonth) {
    final name = _months[start.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} ${start.year}';
  }
  return '${start.toBr()} a ${end.addDays(-1).toBr()}';
}

/// Seletor de período (pílula com setas) e botão "+" para novo lançamento.
class PeriodHeader extends ConsumerWidget {
  const PeriodHeader({
    required this.view,
    this.newButtonKey = const Key('dashboard-novo'),
    super.key,
  });

  final PeriodView view;
  final Key newButtonKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final anchor = ref.read(periodAnchorProvider.notifier);
    final today = ref.watch(userClockProvider).today();
    final isCurrent = view.range.contains(today);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('periodo-anterior'),
                    tooltip: 'Período anterior',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => anchor.set(view.range.start.addDays(-1)),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _periodLabel(view.range),
                        key: const Key('periodo-atual'),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('periodo-proximo'),
                    tooltip: 'Próximo período',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => anchor.set(view.range.end),
                  ),
                ],
              ),
            ),
          ),
          if (!isCurrent)
            TextButton(
              key: const Key('periodo-hoje'),
              onPressed: () => anchor.set(null),
              child: const Text('Atual'),
            ),
          if (view.exists) const SizedBox(width: 12),
          if (view.exists)
            IconButton.filled(
              key: newButtonKey,
              tooltip: 'Novo lançamento',
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                fixedSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.add),
              onPressed: () => showNewEntryChooser(context, ref),
            ),
        ],
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(periodTotalsProvider);
    final theme = Theme.of(context);
    final colors = NorteColors.of(context);
    final attention = ref.watch(syncStatusProvider).attentionCount;
    final entries = ref.watch(periodEntriesProvider).value ?? const [];
    final receivable = entries.where((e) => e.isPendingIncome).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return RefreshIndicator(
      onRefresh: () async => refreshFinanceData(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                  const SizedBox(height: 8),
                  Text(
                    'Dinheiro livre do período',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _BigAmount(
                    value: value,
                    color: value.isNegative
                        ? colors.expense
                        : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(height: 16),
                  _SplitBar(
                    income: income,
                    expense: expense,
                    investment: investment,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendItem(
                        label: 'Receitas',
                        valueKey: const Key('valor-receitas'),
                        value: income,
                        dot: colors.income,
                      ),
                      _LegendItem(
                        label: 'Despesas',
                        valueKey: const Key('valor-despesas'),
                        value: expense,
                        dot: colors.expense,
                      ),
                      _LegendItem(
                        label: 'Investimentos',
                        valueKey: const Key('valor-investimentos'),
                        value: investment,
                        dot: colors.investment,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          if (attention > 0) ...[
            const SizedBox(height: 24),
            _AttentionCard(count: attention),
          ],
          if (receivable.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ReceivableSection(items: receivable),
          ],
        ],
      ),
    );
  }
}

/// Valor grande com o prefixo "R$" (e o sinal) menores. O texto completo
/// continua sendo o de [formatBrl].
class _BigAmount extends StatelessWidget {
  const _BigAmount({required this.value, required this.color});

  final BigInt value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final full = formatBrl(value);
    final cut = full.indexOf('R\$ ') + 3;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        key: const Key('valor-sobra'),
        TextSpan(
          children: [
            TextSpan(
              text: full.substring(0, cut),
              style: TextStyle(
                fontSize: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(text: full.substring(cut)),
          ],
        ),
        style: theme.textTheme.displaySmall?.copyWith(
          fontSize: 44,
          fontFeatures: _tabular,
          color: color,
        ),
      ),
    );
  }
}

/// Barra de composição (só visual): receitas, despesas e investimentos,
/// proporcionais aos valores reais do período.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.income,
    required this.expense,
    required this.investment,
  });

  final BigInt income;
  final BigInt expense;
  final BigInt investment;

  /// Parte em milésimos (inteiros) de [total]; nunca negativa, mínimo 1 se
  /// houver valor (para o segmento continuar visível).
  static int _permille(BigInt part, BigInt total) {
    if (total <= BigInt.zero || part <= BigInt.zero) return 0;
    final p = ((part * BigInt.from(1000)) ~/ total).toInt();
    return p < 1 ? 1 : p;
  }

  @override
  Widget build(BuildContext context) {
    final colors = NorteColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final total = income + expense + investment;
    final segments = <(int, Color)>[
      (_permille(income, total), colors.income),
      (_permille(expense, total), colors.expense),
      (_permille(investment, total), colors.investment),
    ].where((s) => s.$1 > 0).toList();
    return Semantics(
      label: 'Composição do período: receitas, despesas e investimentos',
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

/// Item da legenda: ponto de cor, rótulo e valor em reais.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatBrl(value),
              key: valueKey,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: _tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo com ícone, usado à esquerda dos cards.
class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

/// Itens que precisam de decisão (os mesmos da tela de atenção).
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = NorteColors.of(context);
    return Card(
      key: const Key('card-atencao'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/atencao'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _IconBubble(icon: Icons.schedule, color: colors.pending),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 item precisa de atenção'
                          : '$count itens precisam de atenção',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toque para ver e resolver',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Receitas pendentes (recorrentes ainda não confirmadas): não entram no
/// dinheiro livre até a confirmação (RN005).
class _ReceivableSection extends StatelessWidget {
  const _ReceivableSection({required this.items});

  final List<EntryRecord> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = NorteColors.of(context);
    return Card(
      key: const Key('card-a-receber'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A receber (ainda não conta)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final e in items) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _IconBubble(icon: Icons.arrow_upward, color: colors.income),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.description?.trim().isNotEmpty == true
                              ? e.description!
                              : 'Receita',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'previsto ${e.date.day} '
                          '${_monthsShort[e.date.month - 1]}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatBrl(e.amount ?? BigInt.zero),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: _tabular,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
