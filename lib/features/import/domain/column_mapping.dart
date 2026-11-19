import 'csv_reader.dart';
import 'date_parsing.dart';
import 'import_models.dart';
import 'norte_formats.dart';
import 'value_parsing.dart';

/// Campos do Norte a que uma coluna do arquivo pode ser associada.
enum ImportField {
  kind('tipo', 'Tipo da linha'),
  description('descricao', 'Descrição'),
  amount('valor', 'Valor'),
  date('data', 'Data (recebimento, competência ou investimento)'),
  scheduledDate('data_prevista', 'Data prevista (se a data estiver vazia)'),
  dueDate('vencimento', 'Vencimento'),
  paidDate('data_pagamento', 'Data de pagamento'),
  paidAmount('valor_pago', 'Valor pago'),
  status('status', 'Situação'),
  category('categoria', 'Categoria'),
  subcategory('subcategoria', 'Subcategoria'),
  categoryKind('tipo_categoria', 'Tipo da categoria (receita/despesa)'),
  name('nome', 'Nome da categoria'),
  active('ativa', 'Categoria ativa (sim/não)'),
  parentCategory('categoria_pai', 'Categoria pai (subcategoria)'),
  norteId('id', 'Identificador do Norte');

  const ImportField(this.key, this.label);
  final String key;
  final String label;

  static ImportField fromKey(String key) =>
      ImportField.values.firstWhere((f) => f.key == key);

  /// Campos com data (todos no mesmo formato declarado).
  static const dateFields = {date, scheduledDate, dueDate, paidDate};
}

/// De onde vem o tipo de cada linha (RN047).
enum TypeSource {
  /// O arquivo inteiro tem um tipo só.
  fixed,

  /// Uma coluna de tipo cujos valores o usuário associa.
  column,

  /// Regra opcional "pelo sinal" (D35): negativo = despesa, positivo =
  /// receita, zero rejeitado.
  sign,
}

/// Significado de cada valor da coluna de situação.
enum StatusMeaning {
  normal('normal', 'Normal (recebida, pendente ou ativa conforme o tipo)'),
  received('received', 'Recebida'),
  pending('pending', 'Pendente / a receber'),
  paid('paid', 'Paga'),
  partial('partial', 'Paga em parte (rejeitada)'),
  cancelled('cancelled', 'Cancelada (não importada)');

  const StatusMeaning(this.key, this.label);
  final String key;
  final String label;

  static StatusMeaning fromKey(String key) =>
      StatusMeaning.values.firstWhere((s) => s.key == key);
}

/// Data de pagamento das despesas marcadas como pagas (D21).
enum PaidDateSource { column, entryDate }

/// Decisões do usuário nas etapas "Colunas" e "Classificação". Vai no plano
/// (sem conteúdo financeiro bruto) para permitir retomar com o mesmo arquivo.
class ImportMapping {
  const ImportMapping({
    this.columns = const {},
    this.valueFormat,
    this.dateFormat,
    this.typeSource = TypeSource.fixed,
    this.fixedKind,
    this.kindValues = const {},
    this.statusValues = const {},
    this.markExpensesPaid = false,
    this.paidDateSource = PaidDateSource.entryDate,
    this.norteFile,
  });

  /// Campo → índice da coluna no cabeçalho.
  final Map<ImportField, int> columns;
  final ValueFormat? valueFormat;
  final DateFormatKind? dateFormat;
  final TypeSource typeSource;
  final RowKind? fixedKind;

  /// Valor normalizado da coluna de tipo → tipo (`null` = ignorar a linha).
  final Map<String, RowKind?> kindValues;

  /// Valor normalizado da coluna de situação → significado.
  final Map<String, StatusMeaning> statusValues;
  final bool markExpensesPaid;
  final PaidDateSource paidDateSource;

  /// Arquivo do Norte reconhecido (remove o apóstrofo de proteção).
  final NorteFileKind? norteFile;

  int? column(ImportField field) => columns[field];

  ImportMapping copyWith({
    Map<ImportField, int>? columns,
    ValueFormat? valueFormat,
    bool clearValueFormat = false,
    DateFormatKind? dateFormat,
    bool clearDateFormat = false,
    TypeSource? typeSource,
    RowKind? fixedKind,
    bool clearFixedKind = false,
    Map<String, RowKind?>? kindValues,
    Map<String, StatusMeaning>? statusValues,
    bool? markExpensesPaid,
    PaidDateSource? paidDateSource,
  }) => ImportMapping(
    columns: columns ?? this.columns,
    valueFormat: clearValueFormat ? null : (valueFormat ?? this.valueFormat),
    dateFormat: clearDateFormat ? null : (dateFormat ?? this.dateFormat),
    typeSource: typeSource ?? this.typeSource,
    fixedKind: clearFixedKind ? null : (fixedKind ?? this.fixedKind),
    kindValues: kindValues ?? this.kindValues,
    statusValues: statusValues ?? this.statusValues,
    markExpensesPaid: markExpensesPaid ?? this.markExpensesPaid,
    paidDateSource: paidDateSource ?? this.paidDateSource,
    norteFile: norteFile,
  );

  Map<String, Object?> toJson() => {
    'columns': {
      for (final f
          in (columns.keys.toList()..sort((a, b) => a.key.compareTo(b.key))))
        f.key: columns[f],
    },
    'value_format': valueFormat?.name,
    'date_format': dateFormat?.name,
    'type_source': typeSource.name,
    'fixed_kind': fixedKind?.key,
    'kind_values': {
      for (final k in (kindValues.keys.toList()..sort())) k: kindValues[k]?.key,
    },
    'status_values': {
      for (final k in (statusValues.keys.toList()..sort()))
        k: statusValues[k]!.key,
    },
    'mark_expenses_paid': markExpensesPaid,
    'paid_date_source': paidDateSource.name,
    'norte_file': norteFile?.name,
  };

  factory ImportMapping.fromJson(Map<String, dynamic> json) => ImportMapping(
    columns: {
      for (final e in (json['columns'] as Map).entries)
        ImportField.fromKey(e.key as String): (e.value as num).toInt(),
    },
    valueFormat: json['value_format'] == null
        ? null
        : ValueFormat.values.byName(json['value_format'] as String),
    dateFormat: json['date_format'] == null
        ? null
        : DateFormatKind.values.byName(json['date_format'] as String),
    typeSource: TypeSource.values.byName(json['type_source'] as String),
    fixedKind: json['fixed_kind'] == null
        ? null
        : RowKind.fromKey(json['fixed_kind'] as String),
    kindValues: {
      for (final e in (json['kind_values'] as Map).entries)
        e.key as String: e.value == null
            ? null
            : RowKind.fromKey(e.value as String),
    },
    statusValues: {
      for (final e in (json['status_values'] as Map).entries)
        e.key as String: StatusMeaning.fromKey(e.value as String),
    },
    markExpensesPaid: json['mark_expenses_paid'] as bool,
    paidDateSource: PaidDateSource.values.byName(
      json['paid_date_source'] as String,
    ),
    norteFile: json['norte_file'] == null
        ? null
        : NorteFileKind.values.byName(json['norte_file'] as String),
  );
}

/// Associação pronta para um arquivo do Norte (o usuário confirma).
ImportMapping norteMapping(NorteFileKind kind) {
  int col(String name) => kind.header.indexOf(name);
  switch (kind) {
    case NorteFileKind.incomes:
      return ImportMapping(
        norteFile: kind,
        columns: {
          ImportField.norteId: col('id'),
          ImportField.description: col('descricao'),
          ImportField.amount: col('valor_centavos'),
          ImportField.status: col('status'),
          ImportField.date: col('data_recebimento'),
          ImportField.scheduledDate: col('data_prevista'),
          ImportField.category: col('categoria'),
          ImportField.subcategory: col('subcategoria'),
        },
        valueFormat: ValueFormat.centavos,
        dateFormat: DateFormatKind.iso,
        fixedKind: RowKind.income,
        statusValues: const {
          'received': StatusMeaning.received,
          'pending': StatusMeaning.pending,
          'cancelled': StatusMeaning.cancelled,
        },
      );
    case NorteFileKind.expenses:
      return ImportMapping(
        norteFile: kind,
        columns: {
          ImportField.norteId: col('id'),
          ImportField.description: col('descricao'),
          ImportField.amount: col('valor_centavos'),
          ImportField.status: col('status'),
          ImportField.date: col('data_competencia'),
          ImportField.dueDate: col('vencimento'),
          ImportField.paidDate: col('data_pagamento'),
          ImportField.category: col('categoria'),
          ImportField.subcategory: col('subcategoria'),
        },
        valueFormat: ValueFormat.centavos,
        dateFormat: DateFormatKind.iso,
        fixedKind: RowKind.expense,
        statusValues: const {
          'pending': StatusMeaning.pending,
          'paid': StatusMeaning.paid,
          'cancelled': StatusMeaning.cancelled,
        },
        paidDateSource: PaidDateSource.column,
      );
    case NorteFileKind.investments:
      return ImportMapping(
        norteFile: kind,
        columns: {
          ImportField.norteId: col('id'),
          ImportField.amount: col('valor_centavos'),
          ImportField.date: col('data'),
          ImportField.status: col('status'),
        },
        valueFormat: ValueFormat.centavos,
        dateFormat: DateFormatKind.iso,
        fixedKind: RowKind.investment,
        statusValues: const {
          'active': StatusMeaning.normal,
          'cancelled': StatusMeaning.cancelled,
        },
      );
    case NorteFileKind.categories:
      return ImportMapping(
        norteFile: kind,
        columns: {
          ImportField.norteId: col('id'),
          ImportField.categoryKind: col('tipo'),
          ImportField.name: col('nome'),
          ImportField.active: col('ativa'),
          ImportField.parentCategory: col('categoria_pai'),
        },
        fixedKind: RowKind.category,
      );
  }
}

/// Sugestão de associação pelo nome do cabeçalho (outros arquivos). Só
/// sugere; o usuário confirma ou troca.
Map<ImportField, int> suggestColumns(List<String> header) {
  const synonyms = <ImportField, List<String>>{
    ImportField.kind: ['tipo', 'type', 'natureza'],
    ImportField.description: [
      'descricao',
      'description',
      'historico',
      'lancamento',
      'memo',
    ],
    ImportField.amount: ['valor', 'value', 'amount', 'quantia', 'montante'],
    ImportField.date: ['data', 'date', 'data lancamento', 'competencia'],
    ImportField.dueDate: ['vencimento', 'due', 'data vencimento'],
    ImportField.paidDate: ['data pagamento', 'pagamento', 'pago em'],
    ImportField.status: ['status', 'situacao', 'estado'],
    ImportField.category: ['categoria', 'category'],
    ImportField.subcategory: ['subcategoria', 'subcategory'],
  };
  final result = <ImportField, int>{};
  final used = <int>{};
  for (final entry in synonyms.entries) {
    for (var i = 0; i < header.length; i++) {
      if (used.contains(i)) continue;
      final h = normalizeKey(header[i]).replaceAll('_', ' ');
      if (entry.value.contains(h)) {
        result[entry.key] = i;
        used.add(i);
        break;
      }
    }
  }
  return result;
}

/// Valores distintos (normalizados) de uma coluna, na ordem em que aparecem.
List<String> distinctColumnValues(CsvTable table, int column) {
  final seen = <String>{};
  final result = <String>[];
  for (final r in table.records) {
    if (column >= r.fields.length) continue;
    final v = normalizeKey(r.fields[column]);
    if (seen.add(v)) result.add(v);
  }
  return result;
}

/// Amostra de uma coluna (para sugerir formatos), sem vazios.
List<String> columnSample(CsvTable table, int column, {int limit = 2000}) => [
  for (final r in table.records.take(limit))
    if (column < r.fields.length && r.fields[column].trim().isNotEmpty)
      r.fields[column],
];

/// O que ainda impede avançar nas etapas "Colunas" e "Classificação".
/// Lista vazia = pode avançar.
List<String> mappingProblems(ImportMapping m, CsvTable table) {
  final problems = <String>[];
  final cols = m.columns;
  final onlyCategories =
      m.typeSource == TypeSource.fixed && m.fixedKind == RowKind.category;

  switch (m.typeSource) {
    case TypeSource.fixed:
      if (m.fixedKind == null) problems.add('Escolha o tipo do arquivo.');
    case TypeSource.column:
      final c = cols[ImportField.kind];
      if (c == null) {
        problems.add('Associe a coluna de tipo.');
      } else {
        final missing = distinctColumnValues(
          table,
          c,
        ).where((v) => !m.kindValues.containsKey(v)).toList();
        if (missing.isNotEmpty) {
          problems.add(
            'Diga o que significa cada valor da coluna de tipo '
            '(falta: ${missing.map((v) => v.isEmpty ? '(vazio)' : v).join(', ')}).',
          );
        }
      }
    case TypeSource.sign:
      break;
  }

  final hasEntries =
      !onlyCategories &&
      (m.typeSource != TypeSource.column ||
          m.kindValues.isEmpty ||
          m.kindValues.values.any((k) => k != null && k != RowKind.category));
  final hasCategories =
      onlyCategories ||
      (m.typeSource == TypeSource.column &&
          m.kindValues.values.contains(RowKind.category));

  if (hasEntries) {
    if (cols[ImportField.amount] == null) {
      problems.add('Associe a coluna de valor.');
    }
    if (cols[ImportField.date] == null) {
      problems.add('Associe a coluna de data.');
    }
    if (cols[ImportField.amount] != null && m.valueFormat == null) {
      problems.add('Escolha o formato do valor.');
    }
  }
  final usesDates = ImportField.dateFields.any(cols.containsKey);
  if (usesDates && m.dateFormat == null) {
    problems.add('Escolha o formato da data.');
  }
  if (hasCategories && cols[ImportField.name] == null) {
    problems.add('Associe a coluna com o nome da categoria.');
  }
  if (hasCategories && cols[ImportField.categoryKind] == null) {
    problems.add('Associe a coluna com o tipo da categoria.');
  }
  if (cols[ImportField.subcategory] != null &&
      cols[ImportField.category] == null) {
    problems.add('Subcategoria exige a coluna de categoria.');
  }
  final status = cols[ImportField.status];
  if (status != null) {
    final missing = distinctColumnValues(
      table,
      status,
    ).where((v) => !m.statusValues.containsKey(v)).toList();
    if (missing.isNotEmpty) {
      problems.add(
        'Diga o que significa cada situação '
        '(falta: ${missing.map((v) => v.isEmpty ? '(vazio)' : v).join(', ')}).',
      );
    }
  }
  if (m.markExpensesPaid &&
      m.paidDateSource == PaidDateSource.column &&
      cols[ImportField.paidDate] == null) {
    problems.add(
      'Associe a coluna de data de pagamento ou use a data da despesa.',
    );
  }
  final indexes = cols.values.toList();
  if (indexes.toSet().length != indexes.length) {
    problems.add('Uma coluna foi associada a dois campos.');
  }
  if (indexes.any((i) => i < 0 || i >= table.header.length)) {
    problems.add('Associação com coluna inexistente.');
  }
  return problems;
}
