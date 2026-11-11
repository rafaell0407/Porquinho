import 'package:flutter/material.dart';

import '../../core/domain/period_calendar.dart';

/// Texto curto da configuração, para telas e histórico.
String describePeriodConfig(PeriodConfig config) =>
    config.mode == PeriodMode.calendarMonth
    ? 'Mês-calendário'
    : 'Ciclo personalizado (dia ${config.customStartDay})';

/// Escolha de modalidade e dia inicial (RN001), usada no primeiro acesso e na
/// tela Período.
class PeriodConfigFields extends StatelessWidget {
  const PeriodConfigFields({
    super.key,
    required this.mode,
    required this.day,
    required this.onChanged,
  });

  final PeriodMode mode;
  final int day;
  final void Function(PeriodMode mode, int day) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioGroup<PeriodMode>(
          groupValue: mode,
          onChanged: (v) => onChanged(v ?? mode, day),
          child: const Column(
            children: [
              RadioListTile<PeriodMode>(
                value: PeriodMode.calendarMonth,
                title: Text('Mês-calendário'),
                subtitle: Text('Do dia 1 ao último dia de cada mês'),
              ),
              RadioListTile<PeriodMode>(
                value: PeriodMode.customCycle,
                title: Text('Ciclo personalizado'),
                subtitle: Text('Começa no dia que você escolher'),
              ),
            ],
          ),
        ),
        if (mode == PeriodMode.customCycle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<int>(
              key: const Key('dia-inicial'),
              initialValue: day,
              decoration: const InputDecoration(labelText: 'Dia inicial'),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('Dia $d')),
              ],
              onChanged: (v) => onChanged(mode, v ?? day),
            ),
          ),
      ],
    );
  }
}
