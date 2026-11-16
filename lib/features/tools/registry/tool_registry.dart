import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cash_or_installments/cash_or_installments_texts.dart';
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

/// Calculadora de juros compostos (`features/compound_interest/`): simulação
/// em memória, sem lançamentos. Nova: fora do padrão (`defaultPosition` nulo).
const compoundInterestTool = ToolDefinition(
  id: 'compound_interest',
  name: 'Juros compostos',
  shortDescription:
      'Calculadora: evolução de um valor com aportes ou retiradas.',
  icon: Icons.trending_up,
  category: ToolCategories.investments,
  route: '/juros-compostos',
  introMode: ToolIntroMode.beforeFirstUse,
  keywords: [
    'juros',
    'simulador',
    'simulação',
    'rendimento',
    'aporte',
    'retirada',
    'patrimônio',
    'investimento',
  ],
  explanation: ToolExplanation(
    purpose:
        'Ver como um valor pode crescer com juros compostos e aportes '
        'mensais, e quanto tempo um patrimônio dura com retiradas mensais.',
    howItWorks:
        'Informe o valor inicial, o valor mensal, a taxa de juros (mensal ou '
        'anual) e o período. A calculadora mostra o valor final, o total '
        'investido, o total em juros, um gráfico e a tabela mês a mês. Em '
        '"Simular retiradas mensais", veja o patrimônio com retiradas.',
    assumptions: [
      'Juros compostos, calculados mês a mês sobre o saldo do início do mês.',
      'Taxa anual convertida na mensal equivalente: 12% ao ano ≈ 0,9489% '
          'ao mês, o que rende exatamente 12% em 12 meses.',
      'O valor mensal entra no final de cada mês, depois dos juros.',
      'Valores arredondados para centavos só na exibição.',
      'Não considera impostos, inflação, tarifas nem mudança da taxa.',
    ],
    disclaimer:
        'É só uma simulação: não cria lançamentos, não muda o dinheiro livre '
        'e não é recomendação de investimento.',
  ),
);

/// Calculadora à vista ou parcelado (`features/cash_or_installments/`, RF028;
/// spec `docs/ferramentas/a_vista_ou_parcelado.md`): simulação em memória,
/// sem lançamentos. Nova: fora do padrão (`defaultPosition` nulo). O nome
/// longo ("Calculadora à vista ou parcelado") fica no título da tela; no
/// catálogo vai o curto, que não corta nos cartões.
const cashOrInstallmentsTool = ToolDefinition(
  id: 'cash_or_installments',
  name: 'À vista ou parcelado',
  shortDescription:
      'Calculadora: pagar à vista ou parcelar no cartão deixando o dinheiro '
      'rendendo.',
  icon: Icons.credit_card,
  category: ToolCategories.purchasesAndCredit,
  route: '/a-vista-ou-parcelado',
  introMode: ToolIntroMode.beforeFirstUse,
  initialAlert: CashOrInstallmentsTexts.initialAlert,
  keywords: [
    'calculadora',
    'à vista',
    'a vista',
    'parcelado',
    'parcelas',
    'parcelar',
    'cartão',
    'crédito',
    'desconto',
    'compra',
    'CDB',
    'CDI',
    'Tesouro Selic',
  ],
  explanation: ToolExplanation(
    purpose:
        'Descobrir se vale mais pagar uma compra à vista (com desconto) ou '
        'parcelar no cartão e deixar o dinheiro rendendo até cada fatura.',
    howItWorks:
        'Informe o valor à vista (ou o preço e o desconto), o parcelamento, '
        'o dia de vencimento do cartão e onde o dinheiro fica (CDB de '
        'liquidez diária ou Tesouro Selic). A calculadora busca a taxa no '
        'Banco Central, simula os dois caminhos dia útil a dia útil, com IR '
        'e IOF em cada resgate, e mostra quanto você terá em caixa no fim em '
        'cada um.',
    assumptions: CashOrInstallmentsTexts.assumptions,
    disclaimer:
        'É só uma simulação: não cria lançamentos, não muda o dinheiro livre '
        'e não é recomendação de investimento.',
  ),
);

/// Ferramentas do app. Nova ferramenta: criar o próprio módulo (tela, regras
/// e testes) e acrescentar a definição aqui; a tela não muda.
final norteToolRegistry = ToolRegistry(const [
  reportsTool,
  compoundInterestTool,
  cashOrInstallmentsTool,
]);

final toolRegistryProvider = Provider<ToolRegistry>((_) => norteToolRegistry);
