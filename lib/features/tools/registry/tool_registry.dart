import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_definition.dart';
import '../models/tool_preferences.dart';

/// Catálogo centralizado. Recusa ID repetido ou fora do formato.
class ToolRegistry {
  ToolRegistry(List<ToolDefinition> tools) : tools = List.unmodifiable(tools) {
    final seen = <String>{};
    for (final t in tools) {
      if (!toolIdPattern.hasMatch(t.id)) {
        throw ArgumentError.value(t.id, 'id', 'formato de ID inválido');
      }
      if (!seen.add(t.id)) {
        throw ArgumentError.value(t.id, 'id', 'ID de ferramenta repetido');
      }
    }
    _byId = {for (final t in tools) t.id: t};
  }

  /// Na ordem de registro.
  final List<ToolDefinition> tools;
  late final Map<String, ToolDefinition> _byId;

  ToolDefinition? byId(String id) => _byId[id];

  bool contains(String id) => _byId.containsKey(id);

  /// Configuração padrão de "Suas ferramentas", na posição definida.
  List<String> get defaultSelection {
    final defaults = tools.where((t) => t.inDefaultSelection).toList()
      ..sort((a, b) => a.defaultPosition!.compareTo(b.defaultPosition!));
    return [for (final t in defaults) t.id];
  }

  List<ToolDefinition> get featured =>
      tools.where((t) => t.featured).toList(growable: false);

  /// Categorias com ao menos uma ferramenta, em ordem.
  List<ToolCategory> get categories {
    final set = {for (final t in tools) t.category}.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return set;
  }
}

/// Relatórios (RF025): os cinco relatórios existentes, sem mudança de cálculo.
const reportsTool = ToolDefinition(
  id: 'reports',
  name: 'Relatórios',
  shortDescription: 'Receitas, despesas, investimentos e dinheiro livre.',
  icon: Icons.bar_chart_outlined,
  category: ToolCategories.analyses,
  route: '/relatorios',
  defaultPosition: 0,
  keywords: [
    'receitas',
    'despesas',
    'investimentos',
    'categoria',
    'evolução',
    'comparativo',
    'dinheiro livre',
    'gráfico',
  ],
  explanation: ToolExplanation(
    purpose:
        'Ver para onde foi o seu dinheiro e como o dinheiro livre mudou de '
        'um período para outro.',
    howItWorks:
        'Cinco relatórios: receitas por categoria, despesas por categoria, '
        'total destinado a investimentos, evolução do dinheiro livre e '
        'comparativo de receitas, despesas e investimentos. Escolha o '
        'relatório e navegue entre os períodos.',
    assumptions: [
      'Usa a sua configuração de período.',
      'Soma pelas mesmas regras do dinheiro livre: receita só depois de '
          'confirmada; lançamento cancelado não conta.',
      'Lançamento sem categoria aparece em "Sem categoria".',
    ],
    disclaimer:
        'Mostra só o que você registrou no Norte. Não é previsão, não '
        'considera saldo bancário nem rentabilidade.',
  ),
);

/// Ferramentas do app. Nova ferramenta: criar o próprio módulo (tela, regras
/// e testes) e acrescentar a definição aqui; a tela não muda.
final norteToolRegistry = ToolRegistry(const [reportsTool]);

final toolRegistryProvider = Provider<ToolRegistry>((_) => norteToolRegistry);
