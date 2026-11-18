import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/report_definition.dart';
import '../report_preferences_controller.dart';
import '../reports_providers.dart';
import '../widgets/report_card.dart';
import 'report_setup_screen.dart';

/// Ferramentas → Relatórios (rota `/relatorios`): no primeiro acesso, a
/// configuração guiada; depois, "Meus relatórios" (spec
/// `docs/ferramentas/relatorios.md` §4).
class ReportsHomeScreen extends ConsumerWidget {
  const ReportsHomeScreen({super.key});

  static const route = '/relatorios';
  static const catalogRoute = '/relatorios/catalogo';
  static const manageRoute = '/relatorios/personalizar';
  static String detailRoute(String id) => '/relatorios/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(reportPreferencesProvider);
    if (!prefs.hasValue) {
      return const ReportsScaffold(
        title: 'Relatórios',
        showPeriod: false,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (prefs.value!.setupPending) {
      return const ReportsScaffold(
        title: 'Relatórios',
        showPeriod: false,
        body: ReportSetupView(),
      );
    }
    return const ReportsScaffold(title: 'Relatórios', body: _MyReports());
  }
}

class _MyReports extends ConsumerStatefulWidget {
  const _MyReports();

  @override
  ConsumerState<_MyReports> createState() => _MyReportsState();
}

class _MyReportsState extends ConsumerState<_MyReports> {
  /// Abertos nesta visita (não é salvo; ao entrar, tudo recolhido).
  final _expanded = <String>{};
  final _keys = <String, GlobalKey>{};

  void _toggle(String id) {
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
    if (!_expanded.contains(id)) return;
    // Ao expandir, rola até o cartão (depois do redesenho).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  Widget _card(ReportDefinition r) => KeyedSubtree(
    key: _keys.putIfAbsent(r.id, GlobalKey.new),
    child: ReportCard(
      definition: r,
      expanded: _expanded.contains(r.id),
      onToggle: () => _toggle(r.id),
      onSeeAll: () => context.push(ReportsHomeScreen.detailRoute(r.id)),
    ),
  );

  /// Web larga: duas colunas; o expandido ocupa a largura toda.
  List<Widget> _layout(List<ReportDefinition> reports, bool wide) {
    const gap = SizedBox(height: 12);
    if (!wide) {
      return [
        for (final r in reports) ...[_card(r), gap],
      ];
    }
    final rows = <Widget>[];
    final pending = <ReportDefinition>[];
    void flush() {
      if (pending.isEmpty) return;
      rows
        ..add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _card(pending[0])),
                const SizedBox(width: 12),
                Expanded(
                  child: pending.length > 1
                      ? _card(pending[1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        )
        ..add(gap);
      pending.clear();
    }

    for (final r in reports) {
      if (_expanded.contains(r.id)) {
        flush();
        rows
          ..add(_card(r))
          ..add(gap);
      } else {
        pending.add(r);
        if (pending.length == 2) flush();
      }
    }
    flush();
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(reportCatalogProvider);
    final selected = catalog.selected;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(selectedPeriodReportProvider)
          ..invalidate(periodSeriesProvider)
          ..invalidate(categoryLooksProvider);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return ListView(
            key: const Key('relatorios-lista'),
            padding: EdgeInsets.fromLTRB(
              wide ? 24 : 16,
              12,
              wide ? 24 : 16,
              24,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Meus relatórios',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('relatorios-personalizar'),
                    onPressed: () =>
                        context.push(ReportsHomeScreen.manageRoute),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Personalizar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (selected.isEmpty)
                Card(
                  key: const Key('relatorios-vazio'),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.insert_chart_outlined,
                          size: 40,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Nenhum relatório em Meus relatórios.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Escolha no catálogo os relatórios que você quer '
                          'acompanhar.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const Key('relatorios-vazio-catalogo'),
                          onPressed: () =>
                              context.push(ReportsHomeScreen.catalogRoute),
                          child: const Text('Abrir catálogo'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._layout(selected, wide),
              if (selected.isNotEmpty)
                Center(
                  child: OutlinedButton.icon(
                    key: const Key('relatorios-adicionar'),
                    onPressed: () =>
                        context.push(ReportsHomeScreen.catalogRoute),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar relatório'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
