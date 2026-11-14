import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Formato aceito para IDs de ferramenta (igual ao do servidor).
final toolIdPattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

/// Escolhas do usuário na aba Ferramentas, salvas na conta
/// (`user_preferences.tools`).
@immutable
class ToolPreferences {
  const ToolPreferences({this.selected, this.dismissedIntros = const {}});

  static const empty = ToolPreferences();

  /// IDs em "Suas ferramentas", na ordem do usuário. `null` = configuração
  /// padrão do app (nunca personalizou ou restaurou o padrão). Pode conter IDs
  /// que esta versão do app não conhece (vindos de outra versão); eles são
  /// preservados nas gravações.
  final List<String>? selected;

  /// Ferramentas com a explicação inicial dispensada ("Não mostrar
  /// novamente").
  final Set<String> dismissedIntros;

  bool get isDefault => selected == null;

  ToolPreferences withSelected(List<String>? ids) =>
      ToolPreferences(selected: ids, dismissedIntros: dismissedIntros);

  ToolPreferences withDismissed(String id) => ToolPreferences(
    selected: selected,
    dismissedIntros: {...dismissedIntros, id},
  );

  /// Lê o JSON gravado; valores inválidos são ignorados.
  static ToolPreferences decode(Object? raw) {
    Object? value = raw;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return empty;
      }
    }
    if (value is! Map) return empty;
    List<String>? ids(Object? list) => list is List
        ? [
            for (final e in list)
              if (e is String && toolIdPattern.hasMatch(e)) e,
          ]
        : null;
    final selected = ids(value['selected']);
    return ToolPreferences(
      selected: selected?.toSet().toList(),
      dismissedIntros: (ids(value['dismissed_intros']) ?? const []).toSet(),
    );
  }

  Map<String, Object> toJson() => {
    'selected': ?selected,
    if (dismissedIntros.isNotEmpty)
      'dismissed_intros': dismissedIntros.toList(),
  };

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is ToolPreferences &&
      listEquals(other.selected, selected) &&
      setEquals(other.dismissedIntros, dismissedIntros);

  @override
  int get hashCode => Object.hash(
    selected == null ? null : Object.hashAll(selected!),
    Object.hashAllUnordered(dismissedIntros),
  );
}
