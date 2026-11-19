import '../../../core/domain/calendar_date.dart';
import 'column_mapping.dart';
import 'csv_reader.dart';
import 'date_parsing.dart';
import 'import_models.dart';
import 'norte_formats.dart';
import 'value_parsing.dart';

/// Resultado da validação de todas as linhas (RN047–RN049).
class ValidationResult {
  const ValidationResult({
    required this.rows,
    required this.categoryRows,
    required this.rejected,
    required this.cancelled,
    required this.ignoredByKind,
    required this.inactiveCategories,
    required this.emptyLines,
  });

  final List<ImportRow> rows;
  final List<CategoryRow> categoryRows;
  final List<RejectedRow> rejected;

  /// Linhas canceladas no arquivo: não importadas, contadas (D17).
  final int cancelled;

  /// Linhas cujo tipo o usuário mandou ignorar.
  final int ignoredByKind;

  /// Categorias marcadas como inativas no arquivo: ignoradas (D36).
  final int inactiveCategories;
  final int emptyLines;

  int get warningCount => rows.where((r) => r.warnings.isNotEmpty).length;
}

class _Reject implements Exception {
  const _Reject(this.reason);
  final String reason;
}

const _inactiveWords = {'nao', 'n', 'false', '0', 'inativa', 'inativo', 'no'};
const _incomeWords = {'income', 'receita', 'receitas'};
const _expenseWords = {'expense', 'despesa', 'despesas'};

/// Valida cada linha do [table] com as decisões de [mapping]. [today] fixa a
/// faixa de datas e os avisos de pagamento futuro.
ValidationResult validateRows(
  CsvTable table,
  ImportMapping mapping,
  CalendarDate today,
) {
  final rows = <ImportRow>[];
  final categoryRows = <CategoryRow>[];
  final rejected = <RejectedRow>[];
  var cancelled = 0;
  var ignoredByKind = 0;
  var inactive = 0;
  final norte = mapping.norteFile != null;

  for (final record in table.records) {
    String? cell(ImportField field) {
      final c = mapping.column(field);
      if (c == null || c >= record.fields.length) return null;
      final v = record.fields[c];
      return v.trim().isEmpty ? null : v;
    }

    String? text(ImportField field) {
      final v = cell(field)?.trim();
      if (v == null || v.isEmpty) return null;
      return norte ? unguardNorteText(v) : v;
    }

    try {
      if (record.problem != null) throw _Reject(record.problem!);
      if (record.fields.length != table.header.length) {
        throw _Reject(
          'A linha tem ${record.fields.length} campos; o cabeçalho tem '
          '${table.header.length}.',
        );
      }

      // Tipo da linha.
      RowKind? kind;
      ValueParse? signed;
      switch (mapping.typeSource) {
        case TypeSource.fixed:
          kind = mapping.fixedKind;
        case TypeSource.column:
          final raw = normalizeKey(cell(ImportField.kind));
          if (!mapping.kindValues.containsKey(raw)) {
            throw _Reject('Tipo "$raw" sem associação.');
          }
          kind = mapping.kindValues[raw];
          if (kind == null) {
            ignoredByKind++;
            continue;
          }
        case TypeSource.sign:
          final raw = cell(ImportField.amount);
          if (raw == null) throw const _Reject('Valor obrigatório.');
          signed = parseImportValue(raw, mapping.valueFormat!);
          if (!signed.ok) throw _Reject(signed.error!);
          if (signed.centavos == BigInt.zero) {
            throw const _Reject(
              'Valor zero: com a regra "pelo sinal" não dá para saber se é '
              'receita ou despesa.',
            );
          }
          kind = signed.centavos!.isNegative ? RowKind.expense : RowKind.income;
      }
      if (kind == null) throw const _Reject('Tipo da linha não definido.');

      if (kind == RowKind.category) {
        final row = _categoryRow(record.line, text);
        if (row == null) {
          inactive++;
        } else {
          categoryRows.add(row);
        }
        continue;
      }

      // Situação.
      var status = StatusMeaning.normal;
      final statusCol = mapping.column(ImportField.status);
      if (statusCol != null) {
        final raw = normalizeKey(record.fields[statusCol]);
        final meaning = mapping.statusValues[raw];
        if (meaning == null) throw _Reject('Situação "$raw" sem associação.');
        status = meaning;
      }
      if (status == StatusMeaning.cancelled) {
        cancelled++;
        continue;
      }
      if (status == StatusMeaning.partial) {
        throw const _Reject('Pagamento parcial não existe no Norte.');
      }

      final warnings = <String>[];

      // Valor.
      BigInt? amount;
      if (signed != null) {
        amount = signed.centavos!.abs();
      } else {
        final raw = cell(ImportField.amount);
        if (raw != null) {
          final v = parseImportValue(raw, mapping.valueFormat!);
          if (!v.ok) throw _Reject(v.error!);
          if (v.centavos!.isNegative) {
            throw const _Reject(
              'Valor negativo. O Norte não aceita valores negativos; se o '
              'arquivo for um extrato, ligue a regra "pelo sinal".',
            );
          }
          amount = v.centavos;
        }
      }

      // Data (competência).
      CalendarDate parseDate(String raw) {
        final d = parseImportDate(raw, mapping.dateFormat!, today);
        if (!d.ok) throw _Reject(d.error!);
        if (d.hadTime && !warnings.contains(_timeWarning)) {
          warnings.add(_timeWarning);
        }
        return d.date!;
      }

      final rawDate = cell(ImportField.date) ?? cell(ImportField.scheduledDate);
      if (rawDate == null) throw const _Reject('Data obrigatória.');
      final date = parseDate(rawDate);

      final description = text(ImportField.description);
      final categoryName = text(ImportField.category);
      final subcategoryName = text(ImportField.subcategory);
      final norteId = cell(ImportField.norteId)?.trim();

      if (kind == RowKind.investment) {
        if (amount == null) throw const _Reject('Valor obrigatório.');
        final extras = [
          if (description != null) 'descrição',
          if (categoryName != null) 'categoria',
          if (subcategoryName != null) 'subcategoria',
          if (cell(ImportField.dueDate) != null) 'vencimento',
          if (cell(ImportField.paidDate) != null) 'data de pagamento',
        ];
        if (extras.isNotEmpty) {
          warnings.add(
            'Investimento tem só valor e data: ${extras.join(', ')} '
            'ignorado(s).',
          );
        }
        rows.add(
          ImportRow(
            sourceRow: record.line,
            kind: kind,
            amount: amount,
            date: date,
            state: EntryState.active,
            norteId: norteId,
            warnings: warnings,
          ),
        );
        continue;
      }

      if (description != null &&
          description.runes.length > maxDescriptionLength) {
        throw const _Reject(
          'Descrição com mais de $maxDescriptionLength caracteres.',
        );
      }
      for (final name in [categoryName, subcategoryName]) {
        if (name != null && name.runes.length > maxNameLength) {
          throw const _Reject(
            'Nome de categoria ou subcategoria com mais de $maxNameLength '
            'caracteres.',
          );
        }
      }
      if (subcategoryName != null && categoryName == null) {
        throw const _Reject('Subcategoria sem categoria.');
      }

      if (kind == RowKind.income) {
        final state = status == StatusMeaning.pending
            ? EntryState.pending
            : EntryState.received;
        if (state == EntryState.received && amount == null) {
          throw const _Reject('Valor obrigatório.');
        }
        rows.add(
          ImportRow(
            sourceRow: record.line,
            kind: kind,
            amount: amount,
            date: date,
            state: state,
            description: description,
            categoryName: categoryName,
            subcategoryName: subcategoryName,
            norteId: norteId,
            warnings: warnings,
          ),
        );
        continue;
      }

      // Despesa.
      CalendarDate? dueOn;
      final rawDue = cell(ImportField.dueDate);
      if (rawDue != null) dueOn = parseDate(rawDue);

      final paid =
          status == StatusMeaning.paid ||
          status == StatusMeaning.received ||
          (status == StatusMeaning.normal && mapping.markExpensesPaid);
      if (!paid && amount == null && status != StatusMeaning.pending) {
        throw const _Reject('Valor obrigatório.');
      }
      CalendarDate? paidOn;
      if (paid) {
        if (amount == null) {
          throw const _Reject('Despesa paga precisa de valor.');
        }
        final rawPaid = cell(ImportField.paidDate);
        if (rawPaid != null) {
          paidOn = parseDate(rawPaid);
        } else if (mapping.markExpensesPaid &&
            mapping.paidDateSource == PaidDateSource.entryDate) {
          paidOn = date;
        } else {
          throw const _Reject('Despesa paga sem data de pagamento.');
        }
        final rawPaidAmount = cell(ImportField.paidAmount);
        if (rawPaidAmount != null) {
          final pa = parseImportValue(rawPaidAmount, mapping.valueFormat!);
          if (!pa.ok) throw _Reject(pa.error!);
          if (pa.centavos!.abs() != amount) {
            throw const _Reject(
              'Valor pago diferente do valor: pagamento parcial não existe '
              'no Norte.',
            );
          }
        }
        if (paidOn.isAfter(today)) {
          warnings.add('Pagamento com data futura (${paidOn.toBr()}).');
        } else if (paidOn.isBefore(date)) {
          warnings.add(
            'Pagamento (${paidOn.toBr()}) antes da competência '
            '(${date.toBr()}); a competência não muda.',
          );
        }
      }
      rows.add(
        ImportRow(
          sourceRow: record.line,
          kind: kind,
          amount: amount,
          date: date,
          state: paid ? EntryState.paid : EntryState.pending,
          dueOn: dueOn,
          paidOn: paidOn,
          description: description,
          categoryName: categoryName,
          subcategoryName: subcategoryName,
          norteId: norteId,
          warnings: warnings,
        ),
      );
    } on _Reject catch (e) {
      rejected.add(RejectedRow(record.line, e.reason));
    }
  }

  return ValidationResult(
    rows: rows,
    categoryRows: categoryRows,
    rejected: rejected,
    cancelled: cancelled,
    ignoredByKind: ignoredByKind,
    inactiveCategories: inactive,
    emptyLines: table.emptyLines,
  );
}

const _timeWarning =
    'Data com hora: foi usada só a data, sem conversão de fuso.';

/// Linha de categoria; `null` = inativa no arquivo (ignorada, D36).
CategoryRow? _categoryRow(int line, String? Function(ImportField) text) {
  final name = text(ImportField.name);
  if (name == null) throw const _Reject('Categoria sem nome.');
  if (name.runes.length > maxNameLength) {
    throw const _Reject('Nome com mais de $maxNameLength caracteres.');
  }
  final rawKind = normalizeKey(text(ImportField.categoryKind));
  final CategoryKind kind;
  if (_incomeWords.contains(rawKind)) {
    kind = CategoryKind.income;
  } else if (_expenseWords.contains(rawKind)) {
    kind = CategoryKind.expense;
  } else {
    throw _Reject('Tipo de categoria "$rawKind" desconhecido.');
  }
  final active = text(ImportField.active);
  if (active != null && _inactiveWords.contains(normalizeKey(active))) {
    return null;
  }
  final parent = text(ImportField.parentCategory);
  if (parent != null && parent.runes.length > maxNameLength) {
    throw const _Reject('Nome com mais de $maxNameLength caracteres.');
  }
  return CategoryRow(
    sourceRow: line,
    kind: kind,
    name: name,
    parentName: parent,
  );
}
