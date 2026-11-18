import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/main_shell.dart' show NorteNavBar;
import '../../dashboard/dashboard_screen.dart' show PeriodHeader;
import '../../periods/period_navigation.dart';
import '../../transactions/transactions_screen.dart' show showNewEntryChooser;
import '../models/report_definition.dart';
import 'report_parts.dart';

/// Ícone do relatório num quadrado suave.
class ReportIcon extends StatelessWidget {
  const ReportIcon(this.icon, {this.size = 36, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.55, color: scheme.onPrimaryContainer),
    );
  }
}

/// Moldura de um relatório em "Meus relatórios": compacto; tocar expande na
/// própria lista; "Ver tudo" abre a tela completa; "Recolher" fecha.
class ReportCard extends StatelessWidget {
  const ReportCard({
    required this.definition,
    required this.expanded,
    required this.onToggle,
    required this.onSeeAll,
    super.key,
  });

  final ReportDefinition definition;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final id = definition.id;
    final theme = Theme.of(context);
    return Card(
      key: Key('relatorio-card-$id'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: expanded ? null : onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ReportIcon(definition.icon, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      definition.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('relatorio-expandir-$id'),
                    tooltip: expanded ? 'Recolher' : 'Expandir',
                    onPressed: onToggle,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 6),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: ReportScope(
                    definition: definition,
                    child: definition.build(
                      expanded ? ReportLevel.expanded : ReportLevel.compact,
                    ),
                  ),
                ),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.end,
                    overflowSpacing: 4,
                    children: [
                      TextButton(
                        key: Key('relatorio-recolher-$id'),
                        onPressed: onToggle,
                        child: const Text('Recolher'),
                      ),
                      FilledButton.tonal(
                        key: Key('relatorio-ver-tudo-$id'),
                        onPressed: onSeeAll,
                        child: const Text('Ver tudo'),
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

/// Estrutura comum das telas de Relatórios: título, seletor de período global
/// (o mesmo da Home) opcional e barra inferior com Ferramentas selecionada.
class ReportsScaffold extends ConsumerWidget {
  const ReportsScaffold({
    required this.title,
    required this.body,
    this.showPeriod = true,
    this.actions,
    super.key,
  });

  final String title;
  final Widget body;
  final bool showPeriod;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = showPeriod ? ref.watch(selectedPeriodProvider) : null;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      bottomNavigationBar: NorteNavBar(
        currentIndex: 1,
        onTab: (i) => context.go(NorteNavBar.tabRoutes[i]),
        onAdd: () => showNewEntryChooser(context, ref),
      ),
      body: view == null
          ? body
          : view.when(
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
              data: (v) => v == null
                  ? const Center(child: Text('Nenhum período ainda.'))
                  : Column(
                      children: [
                        PeriodHeader(view: v),
                        Expanded(child: body),
                      ],
                    ),
            ),
    );
  }
}

/// Mostra o resultado de uma gravação (ou o erro) num aviso curto.
Future<void> runReportAction(
  BuildContext context,
  Future<String?> action,
  String done,
) async {
  final error = await action;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(error ?? done),
        duration: const Duration(seconds: 2),
      ),
    );
}
