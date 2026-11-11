import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../entries/entry_providers.dart';
import 'period_config_fields.dart';
import 'period_models.dart';
import 'period_providers.dart';

/// Situação da configuração de períodos para a tela Período (Entrega 60).
class PeriodSettings {
  const PeriodSettings({
    required this.current,
    required this.nextStart,
    required this.scheduled,
    required this.history,
  });

  /// Configuração em vigor hoje.
  final PeriodConfig current;

  /// Quando começa o próximo período (e, portanto, uma mudança).
  final CalendarDate nextStart;
  final ScheduledChange? scheduled;
  final List<PeriodHistoryItem> history;
}

final periodSettingsProvider = FutureProvider<PeriodSettings?>((ref) async {
  final service = await ref.watch(periodServiceProvider.future);
  final today = ref.watch(todayProvider);
  final current = await service.currentConfig(today);
  final nextStart = await service.nextPeriodStart();
  if (current == null || nextStart == null) return null;
  return PeriodSettings(
    current: current,
    nextStart: nextStart,
    scheduled: await service.scheduledChange(),
    history: await service.history(),
  );
});

/// Mais → Período: ver a configuração, agendar a mudança para o próximo
/// período (RN002) e consultar o histórico.
class PeriodSettingsScreen extends ConsumerStatefulWidget {
  const PeriodSettingsScreen({super.key});

  @override
  ConsumerState<PeriodSettingsScreen> createState() =>
      _PeriodSettingsScreenState();
}

class _PeriodSettingsScreenState extends ConsumerState<PeriodSettingsScreen> {
  PeriodMode? _mode;
  int _day = 1;
  bool _saving = false;
  String? _error;

  void _initFrom(PeriodSettings s) {
    if (_mode != null) return;
    final base = s.scheduled?.config ?? s.current;
    _mode = base.mode;
    _day = base.customStartDay ?? 1;
  }

  PeriodConfig get _config => _mode == PeriodMode.calendarMonth
      ? PeriodConfig.calendarMonth()
      : PeriodConfig.customCycle(_day);

  Future<void> _apply(PeriodConfig config, PeriodSettings s) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = await ref.read(periodServiceProvider.future);
      await service.scheduleChange(config, ref.read(todayProvider));
      ref.invalidate(periodSettingsProvider);
      refreshFinanceData(ref);
      if (mounted) {
        setState(() {
          _mode = null; // volta a ler o estado salvo
          _saving = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar: $e';
        });
      }
    }
  }

  Future<void> _confirm(PeriodSettings s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mudar a configuração?'),
        content: Text(
          'A nova configuração começa em ${s.nextStart.toBr()}. '
          'O período atual não muda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const Key('confirmar-mudanca'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok == true) await _apply(_config, s);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(periodSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Período')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Não foi possível carregar a configuração.'),
        ),
        data: (s) {
          if (s == null) {
            return const Center(
              child: Text('Escolha primeiro como contar o seu período.'),
            );
          }
          _initFrom(s);
          return _body(context, s);
        },
      ),
    );
  }

  Widget _body(BuildContext context, PeriodSettings s) {
    final scheduled = s.scheduled;
    final selected = _config;
    final unchanged = scheduled == null
        ? selected == s.current
        : selected == scheduled.config;
    final cancelsChange = scheduled != null && selected == s.current;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            key: const Key('config-atual'),
            title: const Text('Configuração atual'),
            subtitle: Text(describePeriodConfig(s.current)),
          ),
        ),
        if (scheduled != null)
          Card(
            key: const Key('mudanca-agendada'),
            child: ListTile(
              title: Text(
                'Mudança agendada: ${describePeriodConfig(scheduled.config)}',
              ),
              subtitle: Text(
                'Começa em ${scheduled.startsOn.toBr()}. '
                'O período atual não muda.',
              ),
              trailing: TextButton(
                key: const Key('cancelar-mudanca'),
                onPressed: _saving ? null : () => _apply(s.current, s),
                child: const Text('Cancelar'),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Mudar a configuração',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        PeriodConfigFields(
          mode: _mode!,
          day: _day,
          onChanged: (m, d) => setState(() {
            _mode = m;
            _day = d;
          }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'A nova configuração começa em ${s.nextStart.toBr()}. '
            'O período atual não muda.',
            key: const Key('aviso-inicio'),
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('salvar-mudanca'),
          onPressed: _saving || unchanged
              ? null
              : cancelsChange
              ? () => _apply(s.current, s)
              : () => _confirm(s),
          child: Text(
            _saving
                ? 'Salvando…'
                : cancelsChange
                ? 'Manter a configuração atual'
                : 'Agendar mudança',
          ),
        ),
        const SizedBox(height: 24),
        Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in s.history)
          ListTile(
            key: Key('historico-${item.range.start.toIso()}'),
            dense: true,
            title: Text(
              '${item.range.start.toBr()} a ${item.range.end.addDays(-1).toBr()}',
            ),
            subtitle: Text(describePeriodConfig(item.config)),
          ),
      ],
    );
  }
}
