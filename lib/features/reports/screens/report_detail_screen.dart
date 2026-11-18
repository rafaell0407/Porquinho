import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_definition.dart';
import '../registry/report_registry.dart';
import '../widgets/report_card.dart';
import '../widgets/report_parts.dart';

/// Tela completa de um relatório (`/relatorios/<id>`). Abre mesmo que o
/// relatório não esteja em "Meus relatórios". ID inexistente é desviado para
/// `/relatorios` na rota; aqui só por segurança.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = ref.watch(reportRegistryProvider).byId(id);
    if (definition == null) {
      return const ReportsScaffold(
        title: 'Relatórios',
        showPeriod: false,
        body: SizedBox.shrink(),
      );
    }
    return ReportsScaffold(
      title: definition.name,
      body: ReportScope(
        definition: definition,
        child: definition.build(ReportLevel.full),
      ),
    );
  }
}
