import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/surplus.dart';
import 'package:porquinho/features/import/application/import_controller.dart';
import 'package:porquinho/features/import/application/import_runner.dart';
import 'package:porquinho/features/import/data/import_batch.dart';
import 'package:porquinho/features/import/data/picked_file.dart';
import 'package:porquinho/features/import/domain/category_resolution.dart';
import 'package:porquinho/features/import/domain/column_mapping.dart';
import 'package:porquinho/features/import/domain/csv_reader.dart';
import 'package:porquinho/features/import/domain/date_parsing.dart';
import 'package:porquinho/features/import/domain/duplicate_detection.dart';
import 'package:porquinho/features/import/domain/existing_data.dart';
import 'package:porquinho/features/import/domain/import_models.dart';
import 'package:porquinho/features/import/domain/text_decoding.dart';

import '../fake_import_repository.dart';

final today = CalendarDate(2026, 11, 18);

PickedFile _file(String text, {String name = 'extrato.csv'}) =>
    PickedFile(name, Uint8List.fromList(utf8.encode(text)));

ImportWizardController _controller(FakeImportRepository repo, {int id = 1}) =>
    ImportWizardController(
      repository: repo,
      today: today,
      periodConfig: () async => PeriodConfig.calendarMonth(),
      periodTotals: (ranges) async => {
        for (final r in ranges)
          r: PeriodTotals(
            income: BigInt.from(100000),
            expense: BigInt.zero,
            investment: BigInt.zero,
          ),
      },
      newBatchId: () => '00000000-0000-4000-8000-00000000000$id',
    );

const _csv =
    'Data;Histórico;Valor;Categoria\n'
    '15/08/2026;Aluguel;1.000,00;Casa\n'
    '15/09/2026;Aluguel;1.000,00;Casa\n'
    '15/10/2026;Aluguel;1.000,00;Casa\n'
    '16/10/2026;Mercado;250,50;Casa\n'
    '16/10/2026;Mercado;250,50;Casa\n'
    '17/10/2026;Luz;-10,00;Casa\n';

Future<void> _toPreview(ImportWizardController c) async {
  await c.loadFile(_file(_csv));
  expect(c.fileProblem, isNull);
  await c.next(); // colunas
  expect(c.mapping.column(ImportField.date), 0);
  expect(c.mapping.valueFormat, isNotNull);
  expect(c.mapping.dateFormat, DateFormatKind.dmy);
  expect(c.blockers, isEmpty);
  await c.next(); // classificação
  expect(c.blockers.join(), contains('tipo do arquivo'));
  c.setFixedKind(RowKind.expense);
  c.setMarkExpensesPaid(true);
  await c.next(); // categorias
  expect(c.validation!.rejected.single.reason, contains('negativo'));
  expect(c.categoryChoices['expense|casa'], const CategoryChoice.create());
  await c.next(); // duplicidades
  expect(c.duplicateGroups, hasLength(1));
  expect(c.canContinue, isFalse);
  c.decide(c.duplicateGroups.single.id, DuplicateDecision.ignore);
  await c.next(); // recorrências
  expect(c.series.single.anchor.date, CalendarDate(2026, 10, 15));
  c.toggleSeries(c.series.single.id, true);
  await c.next(); // prévia
}

void main() {
  test(
    'nada é enviado antes de confirmar; depois, blocos e conclusão',
    () async {
      final repo = FakeImportRepository();
      final c = _controller(repo);
      await _toPreview(c);
      expect(c.step, ImportStep.preview);
      expect(repo.calls, isEmpty);
      final a = c.assembled!;
      expect(a.entryCount, 4);
      expect(a.series, hasLength(1));
      expect(a.backfill.single.date, CalendarDate(2026, 11, 15));
      expect(c.periods.map((p) => p.effect.range.start.month), [8, 9, 10, 11]);
      final nov = c.periods.last;
      expect(nov.freeBefore, BigInt.from(100000));
      expect(nov.freeAfter, BigInt.from(0));
      expect(c.pendingCounts!.overdueExpenses, 1);

      await c.next(); // confirmar
      expect(c.step, ImportStep.result);
      expect(c.runResult, isA<RunCompleted>());
      expect(repo.calls, ['begin', 'chunk:0', 'finish']);
      final items = repo.allItems(c.plan!.batchId);
      expect(items.map((i) => i['type']), [
        'category',
        'expense',
        'expense',
        'expense',
        'series',
      ]);
      final summary = repo.batches.values.single.summary;
      expect(summary['rejected'], 1);
      expect(summary['ignored_duplicates'], 1);
    },
  );

  test('voltar e mudar uma decisão refaz as etapas seguintes', () async {
    final c = _controller(FakeImportRepository());
    await _toPreview(c);
    c.back();
    c.back();
    expect(c.step, ImportStep.duplicates);
    c.decide(c.duplicateGroups.single.id, DuplicateDecision.importAnyway);
    expect(c.assembled, isNull);
    await c.next();
    expect(c.confirmedSeries, contains(c.series.single.id));
    await c.next();
    expect(c.assembled!.entryCount, 5);
  });

  test('UTF-8 inválido oferece Windows-1252', () async {
    final c = _controller(FakeImportRepository());
    final bytes = Uint8List.fromList([
      ...utf8.encode('descricao;valor;data\n'),
      0x50, 0xE3, 0x6F, // "Pão" em Windows-1252
      ...utf8.encode(';10;25/10/2026\n'),
    ]);
    await c.loadFile(PickedFile('banco.csv', bytes));
    expect(c.fileProblem, contains('Windows-1252'));
    c.useEncoding(ImportEncoding.windows1252);
    expect(c.fileProblem, isNull);
    expect(c.table!.records.single.fields.first, 'Pão');
  });

  test('arquivo já importado vira grupo de duplicidade', () async {
    final repo = FakeImportRepository(
      existing: ExistingData(
        imports: [
          PreviousImport(
            batchId: 'x',
            fileName: 'extrato.csv',
            fileSha256: fileSha256Of(_csv),
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
    final c = _controller(repo);
    await c.loadFile(_file(_csv));
    expect(c.previousImport, isNotNull);
  });

  test(
    'falha num bloco: retomar com o mesmo arquivo continua sem duplicar',
    () async {
      final lines = StringBuffer('descricao;valor;data\n');
      for (var i = 0; i < 600; i++) {
        lines.write('Item $i;1,00;25/10/2026\n');
      }
      final text = lines.toString();
      final repo = FakeImportRepository()
        ..failChunk = 1
        ..failRow = 300;
      final c = _controller(repo);
      await c.loadFile(_file(text));
      await c.next();
      await c.next();
      c.setFixedKind(RowKind.expense);
      await c.next();
      await c.next();
      await c.next();
      await c.next();
      expect(c.assembled!.chunks, hasLength(3));
      await c.next();
      final failed = c.runResult! as RunFailed;
      expect(failed.row, 300);
      final batch = repo.batches.values.single;
      expect(batch.status, ImportBatchStatus.interrupted);
      expect(repo.chunks[batch.id]!.keys, [0]);

      // Outro arquivo: recusado.
      final other = _controller(repo, id: 2);
      expect(
        await other.resumeWith(batch, _file('$text\nx;1;25/10/2026\n')),
        contains('mesmo arquivo'),
      );

      repo.calls.clear();
      final resumed = _controller(repo, id: 3);
      expect(await resumed.resumeWith(batch, _file(text)), isNull);
      expect(resumed.runResult, isA<RunCompleted>());
      expect(repo.calls, ['chunk:1', 'chunk:2', 'finish']);
      expect(repo.allItems(batch.id), hasLength(600));
      expect(
        repo.allItems(batch.id).map((i) => i['id']).toSet(),
        hasLength(600),
      );
    },
  );

  test('queda de conexão: o que entrou fica; retomar termina', () async {
    final repo = FakeImportRepository()..disconnectChunks = 3;
    final c = _controller(repo);
    await _toPreview(c);
    await c.next();
    expect(c.runResult, isA<RunDisconnected>());
    final batch = repo.batches.values.single;
    final resumed = _controller(repo, id: 4);
    expect(await resumed.resumeWith(batch, _file(_csv)), isNull);
    expect(resumed.runResult, isA<RunCompleted>());
  });

  test('importação em andamento bloqueia outra', () async {
    final repo = FakeImportRepository()..beginOutcome = BeginOutcome.inProgress;
    final c = _controller(repo);
    await _toPreview(c);
    await c.next();
    expect((c.runResult! as RunBlocked).outcome, BeginOutcome.inProgress);
  });
}

String fileSha256Of(String text) =>
    fileSha256(Uint8List.fromList(utf8.encode(text)));
