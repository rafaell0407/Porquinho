/// Exportação CSV (Entrega 74, decisão D4: só na Web). Um arquivo por tipo.
///
/// Regras:
/// - valores em centavos inteiros e exatos (`valor_centavos`), nunca decimais;
/// - lançamentos cancelados também saem, com `status = cancelled` (a auditoria
///   é preservada);
/// - UTF-8 com BOM, separador vírgula, campos entre aspas quando necessário
///   (RFC 4180); quebras de linha `\r\n`.
enum CsvKind {
  incomes('receitas', 'Receitas'),
  expenses('despesas', 'Despesas'),
  investments('investimentos', 'Investimentos'),
  categories('categorias', 'Categorias');

  const CsvKind(this.fileBase, this.label);
  final String fileBase;
  final String label;
}

/// Linhas do servidor (como vêm das tabelas) necessárias para os quatro CSVs.
class ExportData {
  const ExportData({
    required this.incomes,
    required this.expenses,
    required this.investments,
    required this.categories,
    required this.subcategories,
  });

  final List<Map<String, dynamic>> incomes;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> investments;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> subcategories;
}

const csvBom = '﻿';

/// Escapa um campo: aspas quando houver vírgula, aspas, quebra de linha ou
/// espaço nas pontas. Também neutraliza fórmulas de planilha (`=`, `+`, `-`,
/// `@`) em textos livres, prefixando apóstrofo.
String csvField(Object? value, {bool text = false}) {
  if (value == null) return '';
  var s = value.toString();
  if (text && s.isNotEmpty && '=+-@\t\r'.contains(s[0])) s = "'$s";
  final needsQuotes =
      s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r') ||
      s != s.trim();
  return needsQuotes ? '"${s.replaceAll('"', '""')}"' : s;
}

String _row(List<String> fields) => '${fields.join(',')}\r\n';

String _status(Object? s) => s?.toString() ?? '';

String _yesNo(Object? templateId) => templateId == null ? 'nao' : 'sim';

/// Gera o conteúdo (com BOM) do CSV de [kind].
String buildCsv(CsvKind kind, ExportData data) {
  final categoryName = {
    for (final c in data.categories) c['id'] as String: c['name'] as String,
  };
  final subcategoryName = {
    for (final s in data.subcategories) s['id'] as String: s['name'] as String,
  };
  String cat(Object? id) => id == null ? '' : (categoryName[id] ?? '');
  String sub(Object? id) => id == null ? '' : (subcategoryName[id] ?? '');

  final out = StringBuffer(csvBom);
  switch (kind) {
    case CsvKind.incomes:
      out.write(
        _row([
          'id',
          'descricao',
          'valor_centavos',
          'status',
          'data_recebimento',
          'categoria',
          'subcategoria',
          'recorrente',
          'data_prevista',
          'criado_em',
          'atualizado_em',
        ]),
      );
      for (final r in _byDate(data.incomes, 'received_on')) {
        out.write(
          _row([
            csvField(r['id']),
            csvField(r['description'], text: true),
            csvField(r['amount_centavos']),
            csvField(_status(r['status'])),
            csvField(r['received_on']),
            csvField(cat(r['category_id']), text: true),
            csvField(sub(r['subcategory_id']), text: true),
            _yesNo(r['recurrence_template_id']),
            csvField(r['scheduled_for_date']),
            csvField(r['created_at']),
            csvField(r['updated_at']),
          ]),
        );
      }
    case CsvKind.expenses:
      out.write(
        _row([
          'id',
          'descricao',
          'valor_centavos',
          'status',
          'data_competencia',
          'vencimento',
          'data_pagamento',
          'categoria',
          'subcategoria',
          'recorrente',
          'data_prevista',
          'criado_em',
          'atualizado_em',
        ]),
      );
      for (final r in _byDate(data.expenses, 'competence_on')) {
        out.write(
          _row([
            csvField(r['id']),
            csvField(r['description'], text: true),
            csvField(r['amount_centavos']),
            csvField(_status(r['status'])),
            csvField(r['competence_on']),
            csvField(r['due_on']),
            csvField(r['paid_on']),
            csvField(cat(r['category_id']), text: true),
            csvField(sub(r['subcategory_id']), text: true),
            _yesNo(r['recurrence_template_id']),
            csvField(r['scheduled_for_date']),
            csvField(r['created_at']),
            csvField(r['updated_at']),
          ]),
        );
      }
    case CsvKind.investments:
      out.write(
        _row([
          'id',
          'valor_centavos',
          'data',
          'status',
          'recorrente',
          'data_prevista',
          'criado_em',
          'atualizado_em',
        ]),
      );
      for (final r in _byDate(data.investments, 'allocated_on')) {
        out.write(
          _row([
            csvField(r['id']),
            csvField(r['amount_centavos']),
            csvField(r['allocated_on']),
            r['cancelled_at'] == null ? 'active' : 'cancelled',
            _yesNo(r['recurrence_template_id']),
            csvField(r['scheduled_for_date']),
            csvField(r['created_at']),
            csvField(r['updated_at']),
          ]),
        );
      }
    case CsvKind.categories:
      out.write(
        _row([
          'id',
          'tipo',
          'nome',
          'ativa',
          'categoria_pai_id',
          'categoria_pai',
        ]),
      );
      for (final c in data.categories) {
        out.write(
          _row([
            csvField(c['id']),
            csvField(c['kind']),
            csvField(c['name'], text: true),
            c['is_active'] == true ? 'sim' : 'nao',
            '',
            '',
          ]),
        );
      }
      for (final s in data.subcategories) {
        out.write(
          _row([
            csvField(s['id']),
            csvField(
              data.categories
                      .where((c) => c['id'] == s['category_id'])
                      .map((c) => c['kind'])
                      .firstOrNull ??
                  '',
            ),
            csvField(s['name'], text: true),
            s['is_active'] == true ? 'sim' : 'nao',
            csvField(s['category_id']),
            csvField(cat(s['category_id']), text: true),
          ]),
        );
      }
  }
  return out.toString();
}

/// Ordem estável: por data e depois por id.
List<Map<String, dynamic>> _byDate(
  List<Map<String, dynamic>> rows,
  String dateColumn,
) {
  final sorted = [...rows];
  sorted.sort((a, b) {
    final c = '${a[dateColumn] ?? ''}'.compareTo('${b[dateColumn] ?? ''}');
    return c != 0 ? c : '${a['id']}'.compareTo('${b['id']}');
  });
  return sorted;
}
