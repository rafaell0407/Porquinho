import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_definition.dart';
import '../models/report_preferences.dart';
import '../registry/report_registry.dart';
import '../report_preferences_controller.dart';
import '../widgets/report_card.dart';

/// Configuração guiada do primeiro acesso (spec §4.1): os relatórios em
/// cartões selecionáveis, sem prévia, todos marcados na ordem do RF025.
class ReportSetupView extends ConsumerStatefulWidget {
  const ReportSetupView({super.key});

  @override
  ConsumerState<ReportSetupView> createState() => _ReportSetupViewState();
}

class _ReportSetupViewState extends ConsumerState<ReportSetupView> {
  late final Set<String> _chosen = {
    for (final r in ref.read(reportRegistryProvider).reports) r.id,
  };
  bool _saving = false;

  Future<void> _finish(ReportSetupStatus status) async {
    setState(() => _saving = true);
    final error = await ref
        .read(reportPreferencesProvider.notifier)
        .completeSetup(status, chosen: _chosen);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(reportRegistryProvider).reports;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final none = _chosen.isEmpty;
    return Column(
      key: const Key('configuracao-relatorios'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Text(
                'Escolha seus relatórios',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Monte a sua área de relatórios: os escolhidos aparecem '
                'juntos, com um resumo de cada um, no período que você '
                'estiver vendo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (final r in reports)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SelectableReport(
                    report: r,
                    selected: _chosen.contains(r.id),
                    onChanged: _saving
                        ? null
                        : (on) => setState(
                            () => on ? _chosen.add(r.id) : _chosen.remove(r.id),
                          ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Você pode mudar isso depois em Personalizar.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (none)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Escolha ao menos um relatório ou toque em Pular.',
                      key: const Key('configuracao-aviso'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('configuracao-pular'),
                        onPressed: _saving
                            ? null
                            : () => _finish(ReportSetupStatus.skipped),
                        child: const Text('Pular'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('configuracao-concluir'),
                        onPressed: none || _saving
                            ? null
                            : () => _finish(ReportSetupStatus.done),
                        child: const Text('Concluir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectableReport extends StatelessWidget {
  const _SelectableReport({
    required this.report,
    required this.selected,
    required this.onChanged,
  });

  final ReportDefinition report;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('configuracao-${report.id}'),
        onTap: onChanged == null ? null : () => onChanged!(!selected),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              ReportIcon(report.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(report.benefit, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      report.visualization.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: onChanged == null
                    ? null
                    : (v) => onChanged!(v ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
