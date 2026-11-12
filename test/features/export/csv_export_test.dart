import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/export/csv_export.dart';
import 'package:porquinho/features/export/export_screen.dart';

ExportData _data() => const ExportData(
  incomes: [
    {
      'id': 'i2',
      'description': 'Salário, novembro',
      'amount_centavos': '9000000000000000123',
      'status': 'received',
      'received_on': '2026-11-05',
      'category_id': 'c1',
      'subcategory_id': null,
      'recurrence_template_id': null,
      'scheduled_for_date': null,
      'created_at': '2026-11-05T10:00:00+00:00',
      'updated_at': '2026-11-05T10:00:00+00:00',
    },
    {
      'id': 'i1',
      'description': '=SOMA(A1)',
      'amount_centavos': 1,
      'status': 'cancelled',
      'received_on': '2026-10-01',
      'category_id': 'c1',
      'subcategory_id': 's1',
      'recurrence_template_id': 't',
      'scheduled_for_date': '2026-10-01',
      'created_at': 'x',
      'updated_at': 'y',
    },
  ],
  expenses: [
    {
      'id': 'e1',
      'description': 'Aspas "duplas"',
      'amount_centavos': '12000',
      'status': 'paid',
      'competence_on': '2026-11-06',
      'due_on': '2026-11-10',
      'paid_on': '2026-11-09',
      'category_id': 'c2',
      'subcategory_id': null,
      'recurrence_template_id': null,
      'scheduled_for_date': null,
      'created_at': 'x',
      'updated_at': 'y',
    },
  ],
  investments: [
    {
      'id': 'v1',
      'amount_centavos': '30000',
      'allocated_on': '2026-11-05',
      'cancelled_at': null,
      'recurrence_template_id': null,
      'scheduled_for_date': null,
      'created_at': 'x',
      'updated_at': 'y',
    },
    {
      'id': 'v2',
      'amount_centavos': '100',
      'allocated_on': '2026-11-06',
      'cancelled_at': '2026-11-07T00:00:00+00:00',
      'recurrence_template_id': null,
      'scheduled_for_date': null,
      'created_at': 'x',
      'updated_at': 'y',
    },
  ],
  categories: [
    {'id': 'c1', 'kind': 'income', 'name': 'Salário', 'is_active': true},
    {'id': 'c2', 'kind': 'expense', 'name': 'Mercado', 'is_active': false},
  ],
  subcategories: [
    {'id': 's1', 'category_id': 'c1', 'name': 'Extra', 'is_active': true},
  ],
);

List<String> _lines(String csv) =>
    csv.substring(1).split('\r\n')..removeWhere((l) => l.isEmpty);

void main() {
  test('receitas: centavos exatos, escape, fórmula neutralizada, ordem', () {
    final csv = buildCsv(CsvKind.incomes, _data());
    expect(csv.startsWith(csvBom), isTrue);
    final lines = _lines(csv);
    expect(lines.first, startsWith('id,descricao,valor_centavos,status'));
    // Ordenado por data: a de outubro (cancelada) vem primeiro.
    expect(
      lines[1],
      "i1,'=SOMA(A1),1,cancelled,2026-10-01,Salário,Extra,sim,2026-10-01,x,y",
    );
    expect(
      lines[2],
      'i2,"Salário, novembro",9000000000000000123,received,2026-11-05,'
      'Salário,,nao,,2026-11-05T10:00:00+00:00,2026-11-05T10:00:00+00:00',
    );
    expect(lines, hasLength(3));
  });

  test('despesas: aspas duplicadas e datas', () {
    final lines = _lines(buildCsv(CsvKind.expenses, _data()));
    expect(
      lines[1],
      'e1,"Aspas ""duplas""",12000,paid,2026-11-06,2026-11-10,2026-11-09,'
      'Mercado,,nao,,x,y',
    );
  });

  test('investimentos: ativo e cancelado, sem descrição', () {
    final lines = _lines(buildCsv(CsvKind.investments, _data()));
    expect(lines.first, contains('valor_centavos,data,status'));
    expect(lines[1], 'v1,30000,2026-11-05,active,nao,,x,y');
    expect(lines[2], startsWith('v2,100,2026-11-06,cancelled,nao'));
  });

  test('categorias: inclui inativas e subcategorias com a categoria pai', () {
    final lines = _lines(buildCsv(CsvKind.categories, _data()));
    expect(lines[1], 'c1,income,Salário,sim,,');
    expect(lines[2], 'c2,expense,Mercado,nao,,');
    expect(lines[3], 's1,income,Extra,sim,c1,Salário');
  });

  test('campo vazio e nulo', () {
    expect(csvField(null), '');
    expect(csvField(''), '');
    expect(csvField(' espaço '), '" espaço "');
    expect(csvField('linha\nnova'), '"linha\nnova"');
  });

  testWidgets('no celular a tela orienta a usar a Web', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ExportScreen())),
    );
    expect(find.byKey(const Key('exportar-so-web')), findsOneWidget);
    expect(find.byKey(const Key('exportar-receitas')), findsNothing);
  });
}
