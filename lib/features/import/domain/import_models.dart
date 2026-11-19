import '../../../core/domain/calendar_date.dart';

/// Tipo de cada linha do arquivo (RN047).
enum RowKind {
  income('income', 'Receita'),
  expense('expense', 'Despesa'),
  investment('investment', 'Investimento'),
  category('category', 'Categoria');

  const RowKind(this.key, this.label);
  final String key;
  final String label;

  static RowKind fromKey(String key) =>
      RowKind.values.firstWhere((k) => k.key == key);
}

/// Tipo de categoria (receita ou despesa).
enum CategoryKind {
  income('income', 'Receita'),
  expense('expense', 'Despesa');

  const CategoryKind(this.key, this.label);
  final String key;
  final String label;

  static CategoryKind fromKey(String key) =>
      CategoryKind.values.firstWhere((k) => k.key == key);

  static CategoryKind? ofRow(RowKind kind) => switch (kind) {
    RowKind.income => CategoryKind.income,
    RowKind.expense => CategoryKind.expense,
    _ => null,
  };
}

/// Situação de um lançamento importado.
enum EntryState { received, pending, paid, active }

/// Linha válida, pronta para as etapas seguintes. [amount] `null` = despesa
/// variável ou receita sem valor (só entra como âncora de série, RN049).
class ImportRow {
  const ImportRow({
    required this.sourceRow,
    required this.kind,
    required this.amount,
    required this.date,
    required this.state,
    this.dueOn,
    this.paidOn,
    this.description,
    this.categoryName,
    this.subcategoryName,
    this.norteId,
    this.warnings = const [],
  });

  /// Linha física no arquivo (1 = cabeçalho).
  final int sourceRow;
  final RowKind kind;
  final BigInt? amount;

  /// Competência: recebimento, competência da despesa ou data do investimento.
  final CalendarDate date;
  final EntryState state;
  final CalendarDate? dueOn;
  final CalendarDate? paidOn;
  final String? description;
  final String? categoryName;
  final String? subcategoryName;

  /// `id` do arquivo do Norte (sinal forte de duplicidade).
  final String? norteId;
  final List<String> warnings;

  /// Receita pendente ou valor em branco: só como âncora de série (D18).
  bool get anchorOnly =>
      (kind == RowKind.income && state == EntryState.pending) || amount == null;

  CategoryKind? get categoryKind => CategoryKind.ofRow(kind);
}

/// Linha de categoria ou subcategoria declarada no arquivo.
class CategoryRow {
  const CategoryRow({
    required this.sourceRow,
    required this.kind,
    required this.name,
    this.parentName,
  });

  final int sourceRow;
  final CategoryKind kind;
  final String name;

  /// Preenchido = subcategoria de [parentName].
  final String? parentName;
}

class RejectedRow {
  const RejectedRow(this.sourceRow, this.reason);
  final int sourceRow;
  final String reason;
}

/// Chave de comparação de textos: sem acento, sem diferença de maiúsculas e
/// com espaços normalizados. Usada em nomes e descrições.
String normalizeKey(String? value) {
  if (value == null) return '';
  final lower = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final c = String.fromCharCode(rune);
    out.write(_accents[c] ?? c);
  }
  return out.toString();
}

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n',
};

/// Limites (D34): os mesmos do app.
const maxDescriptionLength = 120;
const maxNameLength = 60;
