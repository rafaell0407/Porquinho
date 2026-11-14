import '../models/tool_definition.dart';
import '../models/tool_preferences.dart';
import '../registry/tool_registry.dart';

/// Visão do catálogo para um usuário: o que está em "Suas ferramentas" (na
/// ordem dele), o que está disponível e as operações de personalização.
/// Puro: as operações devolvem a nova lista a gravar.
class ToolCatalog {
  ToolCatalog(this.registry, this.preferences);

  final ToolRegistry registry;
  final ToolPreferences preferences;

  /// Lista gravada (ou o padrão), incluindo IDs que este app não conhece.
  List<String> get _stored => preferences.selected ?? registry.defaultSelection;

  /// "Suas ferramentas", na ordem do usuário; só ferramentas conhecidas.
  List<ToolDefinition> get selected => [
    for (final id in _stored) ?registry.byId(id),
  ];

  /// "Outras ferramentas": as do catálogo que não estão escolhidas, na ordem
  /// de registro. Ferramenta nova aparece aqui automaticamente.
  List<ToolDefinition> get available {
    final chosen = _stored.toSet();
    return [
      for (final t in registry.tools)
        if (!chosen.contains(t.id)) t,
    ];
  }

  List<ToolDefinition> get featured => registry.featured;

  bool isSelected(String id) => _stored.contains(id);

  bool introDismissed(String id) => preferences.dismissedIntros.contains(id);

  /// IDs gravados que esta versão do app não conhece (de outra versão).
  /// São mantidos no fim da lista em toda gravação.
  List<String> get _unknown => [
    for (final id in _stored)
      if (!registry.contains(id)) id,
  ];

  List<String> _withUnknown(List<ToolDefinition> visible) => [
    for (final t in visible) t.id,
    ..._unknown,
  ];

  /// Acrescenta ao fim de "Suas ferramentas". Já escolhida ou desconhecida:
  /// lista inalterada.
  List<String> add(String id) {
    final visible = selected;
    final tool = registry.byId(id);
    if (tool == null || visible.any((t) => t.id == id)) {
      return _withUnknown(visible);
    }
    return _withUnknown([...visible, tool]);
  }

  /// Tira de "Suas ferramentas" (a ferramenta e seus dados continuam).
  List<String> remove(String id) => _withUnknown([
    for (final t in selected)
      if (t.id != id) t,
  ]);

  /// Move de [oldIndex] para a posição final [newIndex].
  List<String> move(int oldIndex, int newIndex) {
    final visible = [...selected];
    if (oldIndex < 0 || oldIndex >= visible.length) {
      return _withUnknown(visible);
    }
    final tool = visible.removeAt(oldIndex);
    visible.insert(newIndex.clamp(0, visible.length), tool);
    return _withUnknown(visible);
  }
}

/// Texto sem acento e em minúsculas, para a busca.
String normalizeForSearch(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final i = from.indexOf(char);
    buffer.write(i >= 0 ? to[i] : char);
  }
  return buffer.toString();
}

/// Busca pelo nome, descrição e termos extras; e filtro por categoria
/// (`null` = todas).
bool toolMatches(ToolDefinition tool, {String query = '', String? categoryId}) {
  if (categoryId != null && tool.category.id != categoryId) return false;
  final q = normalizeForSearch(query.trim());
  if (q.isEmpty) return true;
  final haystack = normalizeForSearch(
    [tool.name, tool.shortDescription, ...tool.keywords].join(' '),
  );
  return q.split(RegExp(r'\s+')).every(haystack.contains);
}

/// Agrupa por categoria, na ordem das categorias e mantendo a ordem interna.
List<(ToolCategory, List<ToolDefinition>)> groupByCategory(
  List<ToolDefinition> tools,
) {
  final groups = <ToolCategory, List<ToolDefinition>>{};
  for (final t in tools) {
    groups.putIfAbsent(t.category, () => []).add(t);
  }
  final keys = groups.keys.toList()..sort((a, b) => a.order.compareTo(b.order));
  return [for (final k in keys) (k, groups[k]!)];
}
