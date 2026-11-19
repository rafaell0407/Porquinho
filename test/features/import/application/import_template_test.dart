import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/surplus.dart';
import 'package:porquinho/features/import/application/import_controller.dart';
import 'package:porquinho/features/import/data/picked_file.dart';
import 'package:porquinho/features/import/domain/column_mapping.dart';
import 'package:porquinho/features/import/domain/csv_reader.dart';
import 'package:porquinho/features/import/domain/date_parsing.dart';
import 'package:porquinho/features/import/domain/import_models.dart';
import 'package:porquinho/features/import/domain/import_template.dart';
import 'package:porquinho/features/import/domain/value_parsing.dart';

import '../fake_import_repository.dart';

void main() {
  test('o modelo tem BOM, ponto e vírgula e uma linha por exemplo', () {
    final text = ImportTemplate.content();
    expect(text.codeUnitAt(0) == 0xFEFF, isTrue);
    expect(detectSeparator(text.substring(1)), CsvSeparator.semicolon);
    final lines = text.split('\r\n')..removeLast();
    expect(lines, hasLength(1 + ImportTemplate.rows.length));
    for (final r in ImportTemplate.rows) {
      expect(r, hasLength(ImportTemplate.header.length));
    }
  });

  test('o modelo segue o passo a passo sem rejeitar nenhuma linha', () async {
    final c = ImportWizardController(
      repository: FakeImportRepository(),
      today: CalendarDate(2026, 11, 18),
      periodConfig: () async => PeriodConfig.calendarMonth(),
      periodTotals: (ranges) async => {
        for (final r in ranges) r: PeriodTotals.zero,
      },
      newBatchId: () => '00000000-0000-4000-8000-000000000001',
    );
    await c.loadFile(
      PickedFile(
        ImportTemplate.fileName,
        Uint8List.fromList(utf8.encode(ImportTemplate.content())),
      ),
    );
    expect(c.fileProblem, isNull);
    expect(c.norteKind, isNull);
    expect(c.table!.records, hasLength(ImportTemplate.rows.length));

    // Colunas: todas associadas sozinhas, formatos sem dúvida.
    await c.next();
    expect(c.mapping.columns.keys.toSet(), {
      ImportField.kind,
      ImportField.date,
      ImportField.description,
      ImportField.amount,
      ImportField.category,
      ImportField.subcategory,
      ImportField.status,
      ImportField.dueDate,
      ImportField.paidDate,
    });
    expect(c.mapping.valueFormat, ValueFormat.reaisComma);
    expect(c.mapping.dateFormat, DateFormatKind.dmy);
    expect(c.blockers, isEmpty);

    // Classificação, como no passo a passo.
    await c.next();
    c.setTypeSource(TypeSource.column);
    c.setKindValue('receita', RowKind.income);
    c.setKindValue('despesa', RowKind.expense);
    c.setKindValue('investimento', RowKind.investment);
    c.setStatusValue('recebida', StatusMeaning.received);
    c.setStatusValue('paga', StatusMeaning.paid);
    c.setStatusValue('pendente', StatusMeaning.pending);
    c.setStatusValue('', StatusMeaning.normal);
    expect(c.blockers, isEmpty);

    await c.next(); // categorias
    final v = c.validation!;
    expect(v.rejected, isEmpty);
    expect(v.rows.map((r) => (r.kind, r.state)), [
      (RowKind.income, EntryState.received),
      (RowKind.expense, EntryState.paid),
      (RowKind.expense, EntryState.paid),
      (RowKind.expense, EntryState.pending),
      (RowKind.investment, EntryState.active),
    ]);
    expect(v.rows[2].subcategoryName, 'Mercado');
    expect(v.rows[3].dueOn, CalendarDate(2026, 10, 25));
    expect(v.rows[4].amount, BigInt.from(50000));
    expect(v.rows[4].warnings, isEmpty);
  });
}
