import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/period_calendar.dart';
import 'period_config_fields.dart';
import 'period_providers.dart';

/// Primeiro acesso: o usuário escolhe como seus períodos são contados
/// (RN001). Aparece uma única vez por conta.
class PeriodSetupScreen extends ConsumerStatefulWidget {
  const PeriodSetupScreen({super.key});

  @override
  ConsumerState<PeriodSetupScreen> createState() => _PeriodSetupScreenState();
}

class _PeriodSetupScreenState extends ConsumerState<PeriodSetupScreen> {
  PeriodMode _mode = PeriodMode.calendarMonth;
  int _day = 1;
  bool _saving = false;
  String? _error;

  PeriodConfig get _config => _mode == PeriodMode.calendarMonth
      ? PeriodConfig.calendarMonth()
      : PeriodConfig.customCycle(_day);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(periodGateProvider.notifier).setup(_config);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final range = PeriodCalendar.containing(_config, today);
    final lastDay = range.end.addDays(-1);
    return Scaffold(
      appBar: AppBar(title: const Text('Seu período')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Como você quer contar o seu mês? Uma mudança futura vale a '
            'partir do próximo período.',
          ),
          const SizedBox(height: 16),
          PeriodConfigFields(
            mode: _mode,
            day: _day,
            onChanged: (m, d) => setState(() {
              _mode = m;
              _day = d;
            }),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Seu período atual: ${range.start.toBr()} a ${lastDay.toBr()}',
                key: const Key('previa-periodo'),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando…' : 'Começar'),
          ),
        ],
      ),
    );
  }
}
