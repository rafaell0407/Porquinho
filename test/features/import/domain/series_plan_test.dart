import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/features/import/domain/backfill_preview.dart';
import 'package:porquinho/features/import/domain/category_resolution.dart';
import 'package:porquinho/features/import/domain/column_mapping.dart';
import 'package:porquinho/features/import/domain/csv_reader.dart';
import 'package:porquinho/features/import/domain/date_parsing.dart';
import 'package:porquinho/features/import/domain/duplicate_detection.dart';
import 'package:porquinho/features/import/domain/existing_data.dart';
import 'package:porquinho/features/import/domain/import_models.dart';
import 'package:porquinho/features/import/domain/import_plan.dart';
import 'package:porquinho/features/import/domain/series_detection.dart';
import 'package:porquinho/features/import/domain/text_decoding.dart';
import 'package:porquinho/features/import/domain/value_parsing.dart';

import '../../../fixtures/fixture_text.dart';

final today = CalendarDate(2026, 11, 18);

ImportRow _r(
  int line,
  CalendarDate date, {
  RowKind kind = RowKind.expense,
  int? amount = 10000,
  String? desc = 'Aluguel',
  String? cat,
  EntryState? state,
}) => ImportRow(
  sourceRow: line,
  kind: kind,
  amount: amount == null ? null : BigInt.from(amount),
  date: date,
  state:
      state ??
      (kind == RowKind.income
          ? EntryState.received
          : kind == RowKind.investment
          ? EntryState.active
          : EntryState.pending),
  description: kind == RowKind.investment ? null : desc,
  categoryName: cat,
);

List<SeriesCandidate> _detect(
  List<ImportRow> rows, {
  ExistingData existing = const ExistingData(),
  Map<String, CategoryChoice> choices = const {},
}) => detectSeries(rows, choices, today, existing);

void main() {
  group('detecção de séries', () {
    test('3 meses seguidos, âncora = mais recente, fixa', () {
      final s = _detect([
        _r(2, CalendarDate(2026, 9, 5)),
        _r(3, CalendarDate(2026, 10, 5)),
        _r(4, CalendarDate(2026, 11, 5)),
      ]).single;
      expect(s.status, SeriesStatus.suggested);
      expect(s.anchor.sourceRow, 4);
      expect(s.fixed, isTrue);
      expect(s.defaultAmount, BigInt.from(10000));
      expect(s.referenceDay, 5);
      expect(s.dayDiffers, isFalse);
    });

    test('2 meses não bastam; lacuna corta a série', () {
      expect(
        _detect([
          _r(2, CalendarDate(2026, 10, 5)),
          _r(3, CalendarDate(2026, 11, 5)),
        ]),
        isEmpty,
      );
      expect(
        _detect([
          _r(2, CalendarDate(2026, 7, 5)),
          _r(3, CalendarDate(2026, 8, 5)),
          _r(4, CalendarDate(2026, 10, 5)),
          _r(5, CalendarDate(2026, 11, 5)),
        ]),
        isEmpty,
      );
    });

    test('dois no mesmo mês da âncora: sem série', () {
      expect(
        _detect([
          _r(2, CalendarDate(2026, 9, 5)),
          _r(3, CalendarDate(2026, 10, 5)),
          _r(4, CalendarDate(2026, 11, 5)),
          _r(5, CalendarDate(2026, 11, 20)),
        ]),
        isEmpty,
      );
    });

    test('tolerância de 3 dias e aviso de dia diferente', () {
      final s = _detect([
        _r(2, CalendarDate(2026, 8, 10)),
        _r(3, CalendarDate(2026, 9, 10)),
        _r(4, CalendarDate(2026, 10, 10)),
        _r(5, CalendarDate(2026, 11, 13)),
      ]).single;
      expect(s.rows, hasLength(4));
      expect(s.habitualDay, 10);
      expect(s.referenceDay, 13);
      expect(s.dayDiffers, isTrue);

      // 4 dias de diferença: a âncora não é consistente.
      expect(
        _detect([
          _r(2, CalendarDate(2026, 8, 10)),
          _r(3, CalendarDate(2026, 9, 10)),
          _r(4, CalendarDate(2026, 10, 10)),
          _r(5, CalendarDate(2026, 11, 14)),
        ]),
        isEmpty,
      );
    });

    test('fim de mês e dia útil: dia 31 em fevereiro e em sábado', () {
      // 31/01/2026 (sáb), 27/02/2026 (sex: 28/02 é sábado), 31/03/2026.
      final rows = [
        _r(2, CalendarDate(2026, 1, 31)),
        _r(3, CalendarDate(2026, 2, 27)),
        _r(4, CalendarDate(2026, 3, 31)),
      ];
      final s = detectSeries(
        rows,
        const {},
        CalendarDate(2026, 4, 10),
        const ExistingData(),
      ).single;
      expect(s.habitualDay, 31);
      expect(s.status, SeriesStatus.suggested);
    });

    test('valores diferentes = variável; investimento agrupa por valor', () {
      final variable = _detect([
        _r(2, CalendarDate(2026, 9, 5), amount: 100),
        _r(3, CalendarDate(2026, 10, 5), amount: 120),
        _r(4, CalendarDate(2026, 11, 5), amount: 90),
      ]).single;
      expect(variable.fixed, isFalse);
      expect(variable.defaultAmount, isNull);

      final inv = _detect([
        _r(2, CalendarDate(2026, 9, 1), kind: RowKind.investment, amount: 500),
        _r(3, CalendarDate(2026, 10, 1), kind: RowKind.investment, amount: 500),
        _r(4, CalendarDate(2026, 11, 1), kind: RowKind.investment, amount: 500),
        _r(5, CalendarDate(2026, 11, 2), kind: RowKind.investment, amount: 7),
      ]).single;
      expect(inv.fixed, isTrue);
      expect(inv.description, isNull);
    });

    test('descrição vazia não forma série', () {
      expect(
        _detect([
          _r(2, CalendarDate(2026, 9, 5), desc: null),
          _r(3, CalendarDate(2026, 10, 5), desc: ' '),
          _r(4, CalendarDate(2026, 11, 5), desc: ''),
        ]),
        isEmpty,
      );
    });

    test('série encerrada (âncora antes do mês anterior) e futura', () {
      final ended = _detect([
        _r(2, CalendarDate(2026, 6, 5)),
        _r(3, CalendarDate(2026, 7, 5)),
        _r(4, CalendarDate(2026, 9, 5)),
        _r(5, CalendarDate(2026, 8, 5)),
      ]).single;
      expect(ended.status, SeriesStatus.ended);

      final previous = _detect([
        _r(2, CalendarDate(2026, 8, 5)),
        _r(3, CalendarDate(2026, 9, 5)),
        _r(4, CalendarDate(2026, 10, 5)),
      ]).single;
      expect(previous.status, SeriesStatus.suggested);

      final future = _detect([
        _r(2, CalendarDate(2026, 10, 5)),
        _r(3, CalendarDate(2026, 11, 5)),
        _r(4, CalendarDate(2026, 12, 5)),
      ]).single;
      expect(future.status, SeriesStatus.future);
    });

    test('colisão com modelo ativo ou lançamento nos meses gerados', () {
      final rows = [
        _r(2, CalendarDate(2026, 8, 5)),
        _r(3, CalendarDate(2026, 9, 5)),
        _r(4, CalendarDate(2026, 10, 5)),
      ];
      final withTemplate = _detect(
        rows,
        existing: const ExistingData(
          templates: [
            ExistingTemplate(
              id: 't',
              kind: RowKind.expense,
              active: true,
              description: 'ALUGUEL',
            ),
          ],
        ),
      ).single;
      expect(withTemplate.status, SeriesStatus.collision);

      final inactive = _detect(
        rows,
        existing: const ExistingData(
          templates: [
            ExistingTemplate(
              id: 't',
              kind: RowKind.expense,
              active: false,
              description: 'Aluguel',
            ),
          ],
        ),
      ).single;
      expect(inactive.status, SeriesStatus.suggested);

      final withEntry = _detect(
        rows,
        existing: ExistingData(
          entries: [
            ExistingEntry(
              id: 'e',
              kind: RowKind.expense,
              date: CalendarDate(2026, 11, 5),
              amount: BigInt.one,
              cancelled: false,
              description: 'aluguel',
            ),
          ],
        ),
      ).single;
      expect(withEntry.status, SeriesStatus.collision);
      expect(withEntry.collisionReason, contains('05/11/2026'));
    });

    test('âncora pendente (receita do Norte) só na última posição', () {
      final s = _detect([
        _r(2, CalendarDate(2026, 9, 10), kind: RowKind.income),
        _r(3, CalendarDate(2026, 10, 10), kind: RowKind.income),
        _r(
          4,
          CalendarDate(2026, 11, 10),
          kind: RowKind.income,
          state: EntryState.pending,
        ),
      ]).single;
      expect(s.anchor.state, EntryState.pending);
    });
  });

  group('atrasadas', () {
    test('âncora no mês anterior gera o mês atual se o dia já passou', () {
      final s = _detect([
        _r(2, CalendarDate(2026, 8, 5)),
        _r(3, CalendarDate(2026, 9, 5)),
        _r(4, CalendarDate(2026, 10, 5)),
      ]).single;
      final b = backfillFor(s, today);
      expect(b.single.date, CalendarDate(2026, 11, 5));
      expect(b.single.counts, isTrue);

      final late = _detect([
        _r(2, CalendarDate(2026, 8, 25)),
        _r(3, CalendarDate(2026, 9, 25)),
        _r(4, CalendarDate(2026, 10, 25)),
      ]).single;
      expect(backfillFor(late, today), isEmpty);
    });

    test('âncora futura no mês atual não gera atrasadas', () {
      final s = _detect([
        _r(2, CalendarDate(2026, 9, 28)),
        _r(3, CalendarDate(2026, 10, 28)),
        _r(4, CalendarDate(2026, 11, 28)),
      ]).single;
      expect(backfillFor(s, today), isEmpty);
    });

    test('mesma data da tabela de casos do servidor', () {
      final json =
          jsonDecode(readFixture('test/fixtures/monthly_recurrence_cases.json'))
              as Map<String, dynamic>;
      var checked = 0;
      for (final c in (json['cases'] as List).cast<Map<String, dynamic>>()) {
        final year = c['year'] as int;
        final month = c['month'] as int;
        final day = c['day'] as int;
        final prev = CalendarDate.addMonthsTo(year, month, -1);
        if (day > CalendarDate.daysInMonth(prev.$1, prev.$2)) continue;
        final anchor = CalendarDate(prev.$1, prev.$2, day);
        final rows = [
          _r(2, CalendarDate.clamped(prev.$1, prev.$2 - 2, day)),
          _r(3, CalendarDate.clamped(prev.$1, prev.$2 - 1, day)),
          _r(4, anchor),
        ];
        final endOfMonth = CalendarDate(
          year,
          month,
          CalendarDate.daysInMonth(year, month),
        );
        final s = detectSeries(
          rows,
          const {},
          endOfMonth,
          const ExistingData(),
        ).where((x) => x.anchor.sourceRow == 4).firstOrNull;
        if (s == null) continue;
        expect(
          backfillFor(s, endOfMonth).single.date.toIso(),
          c['date'],
          reason: '$year-$month dia $day',
        );
        checked++;
      }
      expect(checked, greaterThan(200));
    });

    test('efeito por período e contagens', () {
      final rows = [
        _r(2, CalendarDate(2026, 10, 5), amount: 1000),
        _r(3, CalendarDate(2026, 10, 6), kind: RowKind.income, amount: 5000),
        _r(4, CalendarDate(2026, 11, 1), kind: RowKind.investment, amount: 200),
        _r(
          5,
          CalendarDate(2026, 11, 10),
          kind: RowKind.income,
          amount: 300,
          state: EntryState.pending,
        ),
      ];
      final backfill = [
        BackfillOccurrence(
          seriesId: 's',
          kind: RowKind.expense,
          date: CalendarDate(2026, 11, 5),
          amount: BigInt.from(1000),
        ),
        BackfillOccurrence(
          seriesId: 'v',
          kind: RowKind.expense,
          date: CalendarDate(2026, 11, 6),
          amount: null,
        ),
      ];
      final effect = effectByPeriod(
        rows,
        backfill,
        PeriodConfig.calendarMonth(),
      );
      expect(effect, hasLength(2));
      expect(effect[0].delta, BigInt.from(4000));
      expect(effect[1].delta, BigInt.from(-1200));
      expect(effect[1].entries, 4);

      final counts = countPending(rows, {rows[0]}, backfill, today);
      expect(counts.overdueExpenses, 3);
      expect(counts.pendingIncomes, 1);
      expect(counts.unpricedExpenses, 1);
    });
  });

  group('plano', () {
    const text =
        'tipo;descricao;valor;data;categoria;subcategoria\n'
        'D;Aluguel;1.000,00;05/08/2026;Casa;\n'
        'D;Aluguel;1.000,00;05/09/2026;Casa;\n'
        'D;Aluguel;1.000,00;05/10/2026;Casa;\n'
        'R;Salário;5.000,00;01/10/2026;Trabalho;Fixo\n'
        'I;;300,00;02/10/2026;;\n'
        'D;Luz;100,00;05/10/2026;Casa;Contas\n'
        'D;Luz;100,00;05/10/2026;Casa;Contas\n';
    final table = parseCsv(text, CsvSeparator.semicolon);
    final mapping = ImportMapping(
      columns: const {
        ImportField.kind: 0,
        ImportField.description: 1,
        ImportField.amount: 2,
        ImportField.date: 3,
        ImportField.category: 4,
        ImportField.subcategory: 5,
      },
      valueFormat: ValueFormat.reaisComma,
      dateFormat: DateFormatKind.dmy,
      typeSource: TypeSource.column,
      kindValues: const {
        'd': RowKind.expense,
        'r': RowKind.income,
        'i': RowKind.investment,
      },
    );

    ImportPlan plan({List<String> series = const []}) => ImportPlan(
      batchId: '11111111-1111-4111-8111-111111111111',
      today: today,
      encoding: ImportEncoding.utf8,
      separator: CsvSeparator.semicolon,
      mapping: mapping,
      categoryChoices: const {
        'expense|casa': CategoryChoice.existing('cat-casa'),
        'expense|casa|contas': CategoryChoice.create(),
        'income|trabalho': CategoryChoice.create(),
        'income|trabalho|fixo': CategoryChoice.create(),
      },
      duplicateDecisions: const {'file-values:7': DuplicateDecision.ignore},
      ignoredRows: const [8],
      confirmedSeries: series,
    );

    test('ids determinísticos e mesmo plano para as mesmas decisões', () {
      final a = assembleImport(table, plan());
      final b = assembleImport(table, plan());
      expect(jsonEncode(a.items), jsonEncode(b.items));
      expect(plan().hash, plan().hash);
      expect(
        ImportPlan.fromJson(
          jsonDecode(jsonEncode(plan().toJson())) as Map<String, dynamic>,
        ).hash,
        plan().hash,
      );
      expect(plan(series: ['x']).hash, isNot(plan().hash));
      expect(
        ImportIds.entry('b', 2),
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-8[0-9a-f]{3}-')),
      );
    });

    test('ordem: categorias, subcategorias, lançamentos, séries', () {
      final s = detectSeries(
        assembleImport(table, plan()).rows,
        plan().categoryChoices,
        today,
        const ExistingData(),
      ).single;
      final a = assembleImport(table, plan(series: [s.id]));
      expect(a.items.map((i) => i['type']), [
        'category',
        'subcategory',
        'subcategory',
        'expense',
        'expense',
        'income',
        'investment',
        'expense',
        'series',
      ]);
      final series = a.items.last;
      expect(series['row'], 4);
      final template = series['template'] as Map;
      expect(template['starts_on'], '2026-10-05');
      expect(template['monthly_reference_day'], 5);
      expect(template['value_mode'], 'fixed');
      expect(template['default_amount_centavos'], 100000);
      expect(template['category_id'], 'cat-casa');
      expect(a.backfill.single.date, CalendarDate(2026, 11, 5));
      expect(a.ignoredByDuplicates, 1);
      expect(a.newCategories, 1);
      expect(a.newSubcategories, 2);

      final income = a.items.firstWhere((i) => i['type'] == 'income');
      final sub = a.items.firstWhere(
        (i) => i['type'] == 'subcategory' && i['name'] == 'Fixo',
      );
      final cat = a.items.firstWhere((i) => i['type'] == 'category');
      expect(income['category_id'], cat['id']);
      expect(income['subcategory_id'], sub['id']);
      expect(sub['category_id'], cat['id']);
    });

    test('âncora pendente sem série confirmada vira rejeitada', () {
      final t = parseCsv(
        'descricao;valor;data;status\nA;10;05/10/2026;pend\n',
        CsvSeparator.semicolon,
      );
      final p = ImportPlan(
        batchId: 'b',
        today: today,
        encoding: ImportEncoding.utf8,
        separator: CsvSeparator.semicolon,
        mapping: const ImportMapping(
          columns: {
            ImportField.description: 0,
            ImportField.amount: 1,
            ImportField.date: 2,
            ImportField.status: 3,
          },
          valueFormat: ValueFormat.reaisComma,
          dateFormat: DateFormatKind.dmy,
          fixedKind: RowKind.income,
          statusValues: {'pend': StatusMeaning.pending},
        ),
        categoryChoices: const {},
        duplicateDecisions: const {},
        ignoredRows: const [],
        confirmedSeries: const [],
      );
      final a = assembleImport(t, p);
      expect(a.items, isEmpty);
      expect(a.rejected.single.reason, contains('recorrência confirmada'));
    });

    test('blocos de até 250 itens', () {
      final lines = StringBuffer('descricao;valor;data\n');
      for (var i = 0; i < 600; i++) {
        lines.write('X$i;1;05/10/2026\n');
      }
      final t = parseCsv(lines.toString(), CsvSeparator.semicolon);
      final p = ImportPlan(
        batchId: 'b',
        today: today,
        encoding: ImportEncoding.utf8,
        separator: CsvSeparator.semicolon,
        mapping: const ImportMapping(
          columns: {
            ImportField.description: 0,
            ImportField.amount: 1,
            ImportField.date: 2,
          },
          valueFormat: ValueFormat.reaisComma,
          dateFormat: DateFormatKind.dmy,
          fixedKind: RowKind.expense,
        ),
        categoryChoices: const {},
        duplicateDecisions: const {},
        ignoredRows: const [],
        confirmedSeries: const [],
      );
      final chunks = assembleImport(t, p).chunks;
      expect(chunks.map((c) => c.length), [250, 250, 100]);
    });
  });
}
