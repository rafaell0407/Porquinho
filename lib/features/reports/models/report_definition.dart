import 'package:flutter/widgets.dart';

/// Grupos do catálogo, em ordem fixa (decisão 8 de 17/11/2026).
enum ReportCategory {
  overview('Visão geral'),
  incomeAndExpenses('Receitas e despesas'),
  investments('Investimentos');

  const ReportCategory(this.label);

  final String label;
}

/// Tipo de visualização mostrado no catálogo e na configuração guiada.
enum ReportVisualization {
  barsByCategory('Barras por categoria'),
  barsByPeriod('Barras por período'),
  groupedBarsByPeriod('Barras agrupadas por período');

  const ReportVisualization(this.label);

  final String label;
}

/// Dados que o relatório lê: o período selecionado ou a sequência de até 12
/// períodos até ele (D8). Só documenta; os módulos usam os providers.
enum ReportDataNeed { selectedPeriod, series }

/// Nível em que o relatório é desenhado (spec §4.3). [preview] é o compacto
/// do catálogo: com período vazio mostra o ícone e a descrição.
enum ReportLevel { compact, expanded, full, preview }

/// Um relatório da central. A tela percorre o registro e nunca conhece um
/// relatório pelo nome; cada módulo desenha os seus níveis em [build].
@immutable
class ReportDefinition {
  const ReportDefinition({
    required this.id,
    required this.name,
    required this.benefit,
    required this.icon,
    required this.category,
    required this.visualization,
    required this.dataNeed,
    required this.build,
    this.suggestedPosition,
  });

  /// Estável e nunca reaproveitado (formato `^[a-z][a-z0-9_]{0,63}$`).
  final String id;
  final String name;

  /// Uma frase: para que serve.
  final String benefit;
  final IconData icon;
  final ReportCategory category;
  final ReportVisualization visualization;
  final ReportDataNeed dataNeed;

  /// Posição na lista sugerida; `null` = fora dela (relatório novo não muda a
  /// lista de ninguém, spec §6.1).
  final int? suggestedPosition;

  /// Desenha o relatório no nível pedido.
  final Widget Function(ReportLevel level) build;

  bool get inSuggestedList => suggestedPosition != null;
}
