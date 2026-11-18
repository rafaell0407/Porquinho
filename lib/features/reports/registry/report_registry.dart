import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_definition.dart';
import '../models/report_preferences.dart';
import '../modules/category_report.dart';
import '../modules/series_reports.dart';

/// Registro centralizado dos relatórios. Recusa ID repetido ou fora do
/// formato.
class ReportRegistry {
  ReportRegistry(List<ReportDefinition> reports)
    : reports = List.unmodifiable(reports) {
    final seen = <String>{};
    for (final r in reports) {
      if (!reportIdPattern.hasMatch(r.id)) {
        throw ArgumentError.value(r.id, 'id', 'formato de ID inválido');
      }
      if (!seen.add(r.id)) {
        throw ArgumentError.value(r.id, 'id', 'ID de relatório repetido');
      }
    }
    _byId = {for (final r in reports) r.id: r};
  }

  /// Na ordem de registro (a do RF025 para os cinco primeiros).
  final List<ReportDefinition> reports;
  late final Map<String, ReportDefinition> _byId;

  ReportDefinition? byId(String id) => _byId[id];

  bool contains(String id) => _byId.containsKey(id);

  /// Lista sugerida de "Meus relatórios", na posição definida.
  List<String> get suggestedSelection {
    final suggested = reports.where((r) => r.inSuggestedList).toList()
      ..sort((a, b) => a.suggestedPosition!.compareTo(b.suggestedPosition!));
    return [for (final r in suggested) r.id];
  }
}

/// Os cinco relatórios do RF025 (`requisitos.md` §13.7), mesmos cálculos.
/// Novo relatório: criar o módulo e acrescentar a definição aqui, sem
/// `suggestedPosition` (não muda a lista de ninguém; spec §6.1).
final norteReportRegistry = ReportRegistry([
  ReportDefinition(
    id: 'income_by_category',
    name: 'Receitas por categoria',
    benefit: 'Veja de onde veio o dinheiro recebido no período.',
    icon: Icons.south_west,
    category: ReportCategory.incomeAndExpenses,
    visualization: ReportVisualization.barsByCategory,
    dataNeed: ReportDataNeed.selectedPeriod,
    suggestedPosition: 0,
    build: (level) => CategoryReport(income: true, level: level),
  ),
  ReportDefinition(
    id: 'expense_by_category',
    name: 'Despesas por categoria',
    benefit: 'Descubra para onde foi o dinheiro do período, pagas ou não.',
    icon: Icons.north_east,
    category: ReportCategory.incomeAndExpenses,
    visualization: ReportVisualization.barsByCategory,
    dataNeed: ReportDataNeed.selectedPeriod,
    suggestedPosition: 1,
    build: (level) => CategoryReport(income: false, level: level),
  ),
  ReportDefinition(
    id: 'investments_total',
    name: 'Total destinado a investimentos',
    benefit: 'Acompanhe quanto você separou para investir a cada período.',
    icon: Icons.savings_outlined,
    category: ReportCategory.investments,
    visualization: ReportVisualization.barsByPeriod,
    dataNeed: ReportDataNeed.series,
    suggestedPosition: 2,
    build: (level) => InvestmentsReport(level: level),
  ),
  ReportDefinition(
    id: 'free_money_evolution',
    name: 'Evolução do dinheiro livre',
    benefit: 'Compare o dinheiro livre de cada período com o anterior.',
    icon: Icons.show_chart,
    category: ReportCategory.overview,
    visualization: ReportVisualization.barsByPeriod,
    dataNeed: ReportDataNeed.series,
    suggestedPosition: 3,
    build: (level) => FreeMoneyReport(level: level),
  ),
  ReportDefinition(
    id: 'period_comparison',
    name: 'Comparativo por período',
    benefit: 'Receitas, despesas e investimentos lado a lado.',
    icon: Icons.stacked_bar_chart,
    category: ReportCategory.overview,
    visualization: ReportVisualization.groupedBarsByPeriod,
    dataNeed: ReportDataNeed.series,
    suggestedPosition: 4,
    build: (level) => ComparisonReport(level: level),
  ),
]);

final reportRegistryProvider = Provider<ReportRegistry>(
  (_) => norteReportRegistry,
);
