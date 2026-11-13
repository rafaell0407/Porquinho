import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import 'period_models.dart';
import 'period_providers.dart';
import 'period_service.dart';

/// Período exibido: o que já existe ou, se ainda não foi criado, o que o
/// usuário pode criar com confirmação (RN002).
class PeriodView {
  const PeriodView({required this.range, this.record, this.missingPlan});

  final PeriodRange range;
  final PeriodRecord? record;
  final PeriodPlan? missingPlan;

  bool get exists => record != null;
}

/// Data que define o período exibido; `null` = hoje. Dashboard e Lançamentos
/// compartilham a escolha.
class PeriodAnchor extends Notifier<CalendarDate?> {
  @override
  CalendarDate? build() => null;

  void set(CalendarDate? date) => state = date;
}

final periodAnchorProvider = NotifierProvider<PeriodAnchor, CalendarDate?>(
  PeriodAnchor.new,
);

final selectedPeriodProvider = FutureProvider<PeriodView?>((ref) async {
  final anchor =
      ref.watch(periodAnchorProvider) ?? ref.watch(userClockProvider).today();
  final service = await ref.watch(periodServiceProvider.future);
  final existing = await service.periodFor(anchor);
  if (existing != null) {
    return PeriodView(range: existing.range, record: existing);
  }
  final plan = await service.planFor(anchor);
  if (plan == null) return null;
  return PeriodView(range: plan.ranges.last, missingPlan: plan);
});

/// Barra com anterior/próximo/hoje e o intervalo do período.
class PeriodNavigator extends ConsumerWidget {
  const PeriodNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(selectedPeriodProvider).value;
    if (view == null) return const SizedBox.shrink();
    final anchor = ref.read(periodAnchorProvider.notifier);
    final today = ref.watch(userClockProvider).today();
    final isCurrent = view.range.contains(today);
    final last = view.range.end.addDays(-1);
    return Row(
      children: [
        IconButton.filledTonal(
          key: const Key('periodo-anterior'),
          tooltip: 'Período anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => anchor.set(view.range.start.addDays(-1)),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${view.range.start.toBr()} a ${last.toBr()}',
                key: const Key('periodo-atual'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!isCurrent)
                TextButton(
                  key: const Key('periodo-hoje'),
                  onPressed: () => anchor.set(null),
                  child: const Text('Voltar para o período atual'),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          key: const Key('periodo-proximo'),
          tooltip: 'Próximo período',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => anchor.set(view.range.end),
        ),
      ],
    );
  }
}

/// Período ainda inexistente: pergunta antes de criar (nunca cria sozinho).
class MissingPeriodCard extends ConsumerStatefulWidget {
  const MissingPeriodCard({required this.view, super.key});

  final PeriodView view;

  @override
  ConsumerState<MissingPeriodCard> createState() => _MissingPeriodCardState();
}

class _MissingPeriodCardState extends ConsumerState<MissingPeriodCard> {
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = await ref.read(periodServiceProvider.future);
      await service.createCovering(widget.view.range.start);
      ref.invalidate(selectedPeriodProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.view.missingPlan!;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Este período ainda não foi criado.'),
            const SizedBox(height: 8),
            Text(plan.question, key: const Key('pergunta-periodos')),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('criar-periodos'),
              onPressed: _busy ? null : _create,
              child: Text(_busy ? 'Criando…' : 'Criar'),
            ),
          ],
        ),
      ),
    );
  }
}
