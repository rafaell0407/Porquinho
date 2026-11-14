import 'package:flutter/widgets.dart';

/// Categoria do catálogo de ferramentas. Nova categoria = nova constante em
/// [ToolCategories]; a tela agrupa pelo que estiver registrado, sem mudança.
@immutable
class ToolCategory {
  const ToolCategory({
    required this.id,
    required this.label,
    required this.order,
  });

  /// Identificador estável (não aparece para o usuário).
  final String id;
  final String label;

  /// Posição entre as categorias (menor primeiro).
  final int order;

  @override
  bool operator ==(Object other) => other is ToolCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Categorias previstas. Acrescentar aqui quando surgir uma nova.
abstract final class ToolCategories {
  static const investments = ToolCategory(
    id: 'investments',
    label: 'Investimentos',
    order: 10,
  );
  static const purchasesAndCredit = ToolCategory(
    id: 'purchases_credit',
    label: 'Compras e crédito',
    order: 20,
  );
  static const planning = ToolCategory(
    id: 'planning',
    label: 'Planejamento financeiro',
    order: 30,
  );
  static const analyses = ToolCategory(
    id: 'analyses',
    label: 'Análises',
    order: 40,
  );
  static const others = ToolCategory(id: 'others', label: 'Outras', order: 90);
}

/// Como a explicação da ferramenta é apresentada.
enum ToolIntroMode {
  /// Modalidade A: abre direto; a explicação fica no ícone de informação.
  onDemand,

  /// Modalidade B: mostra a explicação antes de abrir, até o usuário marcar
  /// "Não mostrar novamente". O ícone de informação continua disponível.
  beforeFirstUse,
}

/// Textos da explicação. O aviso ([disclaimer]) é separado da explicação e
/// continua acessível mesmo depois de dispensar a apresentação.
@immutable
class ToolExplanation {
  const ToolExplanation({
    required this.purpose,
    required this.howItWorks,
    this.assumptions = const [],
    this.disclaimer,
  });

  /// Para que serve.
  final String purpose;

  /// Como funciona.
  final String howItWorks;

  /// Principais premissas e limitações.
  final List<String> assumptions;

  final String? disclaimer;
}

/// Definição centralizada de uma ferramenta do catálogo. A tela não conhece
/// nenhuma ferramenta pelo nome: tudo vem daqui.
@immutable
class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.icon,
    required this.category,
    required this.route,
    required this.explanation,
    this.introMode = ToolIntroMode.onDemand,
    this.defaultPosition,
    this.featured = false,
    this.keywords = const [],
  });

  /// ID único e estável, gravado nas preferências do usuário. Formato:
  /// `^[a-z][a-z0-9_]{0,63}$` (o servidor recusa outro). Nunca reaproveitar.
  final String id;
  final String name;
  final String shortDescription;
  final IconData icon;
  final ToolCategory category;

  /// Rota aberta pela ferramenta (cada ferramenta tem o próprio módulo).
  final String route;
  final ToolExplanation explanation;
  final ToolIntroMode introMode;

  /// Posição na configuração padrão de "Suas ferramentas"; `null` = não entra
  /// no padrão (só em "Outras ferramentas"). Ferramenta nova deve entrar com
  /// `null`, para não mudar a lista de quem nunca personalizou.
  final int? defaultPosition;

  /// Aparece na área "Em destaque" (escolha editorial).
  final bool featured;

  /// Termos extras para a busca.
  final List<String> keywords;

  bool get inDefaultSelection => defaultPosition != null;
}
