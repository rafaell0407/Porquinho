import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Formato aceito para IDs de relatório (igual ao do servidor).
final reportIdPattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

/// Situação da configuração guiada do primeiro acesso.
enum ReportSetupStatus {
  done('done'),
  skipped('skipped');

  const ReportSetupStatus(this.code);

  final String code;

  static ReportSetupStatus? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// Escolhas do usuário na ferramenta Relatórios, salvas na conta
/// (`user_preferences.reports`, spec `docs/ferramentas/relatorios.md` §5).
@immutable
class ReportPreferences {
  const ReportPreferences({this.setup, this.selected, this.options = const {}});

  static const empty = ReportPreferences();

  /// `null` = configuração guiada ainda não feita.
  final ReportSetupStatus? setup;

  /// IDs em "Meus relatórios", na ordem do usuário. `null` = lista sugerida.
  /// Pode conter IDs que esta versão do app não conhece (de outra versão);
  /// eles são preservados nas gravações.
  final List<String>? selected;

  /// Reservado para configurações individuais futuras: lido e preservado,
  /// não usado nesta versão.
  final Map<String, Object?> options;

  bool get setupPending => setup == null;

  bool get isSuggested => selected == null;

  ReportPreferences withSelected(List<String>? ids) =>
      ReportPreferences(setup: setup, selected: ids, options: options);

  /// A configuração feita não volta: o primeiro status fica (como no
  /// servidor).
  ReportPreferences withSetup(ReportSetupStatus status) => ReportPreferences(
    setup: setup ?? status,
    selected: selected,
    options: options,
  );

  /// Lê o JSON gravado; valores inválidos são ignorados.
  static ReportPreferences decode(Object? raw) {
    Object? value = raw;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return empty;
      }
    }
    if (value is! Map) return empty;
    final list = value['selected'];
    final selected = list is List
        ? <String>{
            for (final e in list)
              if (e is String && reportIdPattern.hasMatch(e)) e,
          }.toList()
        : null;
    final options = value['options'];
    return ReportPreferences(
      setup: ReportSetupStatus.fromCode(value['setup']),
      selected: selected,
      options: options is Map
          ? {for (final e in options.entries) '${e.key}': e.value}
          : const {},
    );
  }

  Map<String, Object> toJson() => {
    if (setup != null) 'setup': setup!.code,
    'selected': ?selected,
    if (options.isNotEmpty) 'options': options,
  };

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is ReportPreferences &&
      other.setup == setup &&
      listEquals(other.selected, selected) &&
      jsonEncode(other.options) == jsonEncode(options);

  @override
  int get hashCode => Object.hash(
    setup,
    selected == null ? null : Object.hashAll(selected!),
    jsonEncode(options),
  );
}
