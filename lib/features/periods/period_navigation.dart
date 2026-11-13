import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import 'period_providers.dart';

/// Período exibido: sempre calculado pela configuração atual (RN002, RN036);
/// nunca precisa ser criado. [bounds] limita a navegação ao intervalo entre o
/// lançamento mais antigo e o mais distante, sempre incluindo o atual.
class PeriodView {
  const PeriodView({
    required this.range,
    required this.bounds,
    required this.config,
  });

  final PeriodRange range;
  final PeriodBounds bounds;
  final PeriodConfig config;

  bool get hasPrevious => bounds.hasBefore(range);
  bool get hasNext => bounds.hasAfter(range);
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

/// Período da data escolhida (ou de hoje) pela configuração atual; `null`
/// antes do primeiro acesso.
final selectedPeriodProvider = FutureProvider<PeriodView?>((ref) async {
  final today = ref.watch(userClockProvider).today();
  final anchor = ref.watch(periodAnchorProvider) ?? today;
  final service = await ref.watch(periodServiceProvider.future);
  final config = await service.currentConfig();
  if (config == null) return null;
  return PeriodView(
    range: PeriodCalendar.containing(config, anchor),
    bounds: await service.bounds(today),
    config: config,
  );
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
          onPressed: view.hasPrevious
              ? () => anchor.set(view.range.start.addDays(-1))
              : null,
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
          onPressed: view.hasNext ? () => anchor.set(view.range.end) : null,
        ),
      ],
    );
  }
}
