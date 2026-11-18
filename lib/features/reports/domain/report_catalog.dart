import 'package:flutter/foundation.dart';

import '../models/report_definition.dart';
import '../models/report_preferences.dart';
import '../registry/report_registry.dart';

/// Visão da central para um usuário: "Meus relatórios" (na ordem dele), o que
/// está disponível no catálogo e as operações de personalização. Puro: as
/// operações devolvem a nova lista a gravar.
class ReportCatalog {
  ReportCatalog(this.registry, this.preferences);

  final ReportRegistry registry;
  final ReportPreferences preferences;

  /// Lista gravada (ou a sugerida), incluindo IDs que este app não conhece.
  List<String> get _stored =>
      preferences.selected ?? registry.suggestedSelection;

  /// "Meus relatórios", na ordem do usuário; só relatórios conhecidos.
  List<ReportDefinition> get selected => [
    for (final id in _stored) ?registry.byId(id),
  ];

  /// Relatórios do catálogo fora de "Meus relatórios", na ordem de registro.
  List<ReportDefinition> get available {
    final chosen = _stored.toSet();
    return [
      for (final r in registry.reports)
        if (!chosen.contains(r.id)) r,
    ];
  }

  bool isSelected(String id) => _stored.contains(id);

  /// IDs gravados que esta versão do app não conhece (de outra versão):
  /// mantidos no fim da lista em toda gravação e não exibidos.
  List<String> get _unknown => [
    for (final id in _stored)
      if (!registry.contains(id)) id,
  ];

  List<String> _withUnknown(Iterable<ReportDefinition> visible) => [
    for (final r in visible) r.id,
    ..._unknown,
  ];

  /// Acrescenta ao fim de "Meus relatórios". Já escolhido ou desconhecido:
  /// lista inalterada.
  List<String> add(String id) {
    final visible = selected;
    final report = registry.byId(id);
    if (report == null || visible.any((r) => r.id == id)) {
      return _withUnknown(visible);
    }
    return _withUnknown([...visible, report]);
  }

  /// Tira de "Meus relatórios" (o relatório e os dados continuam).
  List<String> remove(String id) => _withUnknown([
    for (final r in selected)
      if (r.id != id) r,
  ]);

  /// Move de [oldIndex] para a posição final [newIndex].
  List<String> move(int oldIndex, int newIndex) {
    final visible = [...selected];
    if (oldIndex < 0 || oldIndex >= visible.length) {
      return _withUnknown(visible);
    }
    final report = visible.removeAt(oldIndex);
    visible.insert(newIndex.clamp(0, visible.length), report);
    return _withUnknown(visible);
  }

  /// Lista escolhida na configuração guiada, na ordem do registro (RF025).
  /// Igual à sugerida → `null` (continua "sugerida"); IDs desconhecidos já
  /// gravados ficam no fim.
  List<String>? fromSetup(Set<String> chosen) {
    final ordered = [
      for (final r in registry.reports)
        if (chosen.contains(r.id)) r.id,
    ];
    if (preferences.isSuggested &&
        listEquals(ordered, registry.suggestedSelection)) {
      return null;
    }
    return [...ordered, ..._unknown];
  }

  /// Catálogo agrupado na ordem fixa dos grupos (spec §4.5).
  List<(ReportCategory, List<ReportDefinition>)> get groups => [
    for (final c in ReportCategory.values)
      if (registry.reports.any((r) => r.category == c))
        (
          c,
          [
            for (final r in registry.reports)
              if (r.category == c) r,
          ],
        ),
  ];
}
