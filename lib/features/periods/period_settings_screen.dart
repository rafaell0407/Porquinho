import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/period_calendar.dart';
import '../entries/entry_providers.dart';
import 'period_config_fields.dart';
import 'period_providers.dart';

/// Configuração atual (`null` antes do primeiro acesso).
final periodSettingsProvider = FutureProvider<PeriodConfig?>((ref) async {
  final service = await ref.watch(periodServiceProvider.future);
  return service.currentConfig();
});

/// Mais → Período (RN002, 13/11/2026): uma configuração única, trocável a
/// qualquer momento. A troca vale na hora para todos os períodos, passados e
/// futuros; os totais de períodos antigos podem mudar.
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

  void _initFrom(PeriodConfig current) {
    if (_mode != null) return;
    _mode = current.mode;
    _day = current.customStartDay ?? 1;
  }

  PeriodConfig get _config => _mode == PeriodMode.calendarMonth
      ? PeriodConfig.calendarMonth()
      : PeriodConfig.customCycle(_day);

  Future<void> _apply(PeriodConfig config) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = await ref.read(periodServiceProvider.future);
      await service.change(config);
      ref.invalidate(periodSettingsProvider);
      refreshFinanceData(ref);
      if (mounted) {
        setState(() {
          _mode = null; // volta a ler o estado salvo
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuração de período alterada.')),
        );
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

  Future<void> _confirm() async {
    final config = _config;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mudar a configuração?'),
        content: Text(
          'A partir de agora, todos os períodos, inclusive os passados, '
          'passam a ser ${describePeriodConfig(config).toLowerCase()}. '
          'Os lançamentos não mudam, mas os totais de períodos antigos podem '
          'mudar, e arquivos CSV já exportados podem não bater com a tela.',
          key: const Key('aviso-mudanca'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const Key('confirmar-mudanca'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mudar'),
          ),
        ],
      ),
    );
    if (ok == true) await _apply(config);
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
        data: (current) {
          if (current == null) {
            return const Center(
              child: Text('Escolha primeiro como contar o seu período.'),
            );
          }
          _initFrom(current);
          return _body(context, current);
        },
      ),
    );
  }

  Widget _body(BuildContext context, PeriodConfig current) {
    final selected = _config;
    final today = ref.watch(todayProvider);
    final preview = PeriodCalendar.containing(selected, today);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            key: const Key('config-atual'),
            title: const Text('Configuração atual'),
            subtitle: Text(describePeriodConfig(current)),
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
            'Com esta configuração, o período atual vai de '
            '${preview.start.toBr()} a ${preview.end.addDays(-1).toBr()}. '
            'A mudança vale na hora para todos os períodos, passados e '
            'futuros.',
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
          onPressed: _saving || selected == current ? null : _confirm,
          child: Text(_saving ? 'Salvando…' : 'Mudar configuração'),
        ),
      ],
    );
  }
}
