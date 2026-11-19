@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/import/application/import_runner.dart';
import 'package:porquinho/features/import/data/import_batch.dart';
import 'package:porquinho/features/import/data/import_repository.dart';
import 'package:porquinho/features/import/domain/backfill_preview.dart';
import 'package:porquinho/features/import/domain/column_mapping.dart';
import 'package:porquinho/features/import/domain/csv_reader.dart';
import 'package:porquinho/features/import/domain/date_parsing.dart';
import 'package:porquinho/features/import/domain/existing_data.dart';
import 'package:porquinho/features/import/domain/import_models.dart';
import 'package:porquinho/features/import/domain/import_plan.dart';
import 'package:porquinho/features/import/domain/series_detection.dart';
import 'package:porquinho/features/import/domain/text_decoding.dart';
import 'package:porquinho/features/import/domain/value_parsing.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

import '../support/supabase_local_support.dart';

/// IM7: importação contra o Supabase LOCAL — arquivo grande sem corte em
/// 1.000, queda e retomada sem duplicar, celular que baixa e não duplica a
/// geração, edição no celular durante o desfazer (conflito normal), totais
/// iguais no aparelho e no servidor, isolamento.

/// Perde respostas ou falha antes de chegar ao servidor.
class _FlakyBackend implements ImportBackend {
  _FlakyBackend(this._inner);
  final ImportBackend _inner;
  int failChunkCalls = 0;
  int loseChunkResponses = 0;

  @override
  Future<Object?> rpc(String name, Map<String, Object?> params) async {
    if (name == 'import_apply_chunk' && failChunkCalls > 0) {
      failChunkCalls--;
      throw const SyncTransientError('sem rede (simulado)');
    }
    final r = await _inner.rpc(name, params);
    if (name == 'import_apply_chunk' && loseChunkResponses > 0) {
      loseChunkResponses--;
      throw const SyncTransientError('resposta perdida (simulado)');
    }
    return r;
  }

  @override
  Future<List<Map<String, dynamic>>> selectAll(String t, String c) =>
      _inner.selectAll(t, c);

  @override
  Future<Map<String, dynamic>?> selectOne(String t, String id) =>
      _inner.selectOne(t, id);

  @override
  Future<List<Map<String, dynamic>>> selectWhere(
    String t,
    String c,
    String col,
    String v,
  ) => _inner.selectWhere(t, c, col, v);
}

String _two(int n) => n.toString().padLeft(2, '0');

ImportPlan _plan(
  String batchId,
  CalendarDate today, {
  List<String> series = const [],
}) => ImportPlan(
  batchId: batchId,
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
  confirmedSeries: series,
);

Future<RunResult> _run(
  ImportRepository repo,
  String text,
  ImportPlan plan, {
  bool resume = false,
}) {
  final bytes = Uint8List.fromList(utf8.encode(text));
  final table = parseCsv(text, CsvSeparator.semicolon);
  final assembled = assembleImport(table, plan);
  return ImportRunner(repo).run(
    plan: plan,
    file: ImportFileInfo(
      name: 'teste.csv',
      sha256: fileSha256(bytes),
      sizeBytes: bytes.length,
      rows: table.records.length,
    ),
    assembled: assembled,
    summary: {'rejected': assembled.rejected.length},
    resume: resume,
  );
}

String _uuid(Random r) => testUuid(r);

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;
  final today = const UserClock().today();

  test(
    'arquivo grande (20 mil linhas): sem corte em 1.000 e totais iguais no '
    'aparelho e no servidor',
    () async {
      final account = await newTestAccount(r);
      final client = await account.device();
      final repo = RemoteImportRepository(SupabaseImportBackend(client));
      final text = StringBuffer('descricao;valor;data\n');
      var total = BigInt.zero;
      for (var i = 0; i < 20000; i++) {
        final cents = 100 + (i % 9973);
        total += BigInt.from(cents);
        text.write(
          'Item $i;${cents ~/ 100},${_two(cents % 100)};'
          '${13 + i % 16}/${_two(1 + i % 12)}/2025\n',
        );
      }
      final result = await _run(repo, text.toString(), _plan(_uuid(r), today));
      expect(result, isA<RunCompleted>());
      final batch = (result as RunCompleted).batch;
      expect(batch.totalChunks, 80);
      expect(batch.result!['expenses'], 20000);

      final existing = await repo.loadExisting();
      expect(existing.entries, hasLength(20000));

      final db = memoryDb();
      addTearDown(db.close);
      await DownloadService(
        db,
        SupabaseSyncReader(client),
      ).downloadAll(account.id);
      final ranges = PeriodCalendar.between(
        PeriodConfig.calendarMonth(),
        CalendarDate(2025, 1, 1),
        CalendarDate(2025, 12, 31),
      );
      final local = await LocalReportsRepository(db, account.id).report(ranges);
      final remote = await RemoteReportsRepository(
        SupabaseReportSource(client),
      ).report(ranges);
      var sum = BigInt.zero;
      for (final p in ranges) {
        expect(local.totalsOf(p), remote.totalsOf(p), reason: '$p');
        sum += remote.totalsOf(p).expense;
      }
      expect(sum, total);
    },
    timeout: const Timeout(Duration(minutes: 15)),
    skip: skip,
  );

  test(
    'queda e retomada: resposta perdida e conexão caída não duplicam',
    () async {
      final account = await newTestAccount(r);
      final client = await account.device();
      final flaky = _FlakyBackend(SupabaseImportBackend(client));
      final repo = RemoteImportRepository(flaky);
      final text = StringBuffer('descricao;valor;data\n');
      for (var i = 0; i < 700; i++) {
        text.write('Linha $i;1,00;20/03/2025\n');
      }
      final plan = _plan(_uuid(r), today);

      // Resposta do bloco 0 perdida: o reenvio é reconhecido e nada duplica;
      // depois, três falhas seguidas derrubam o envio.
      flaky
        ..loseChunkResponses = 1
        ..failChunkCalls = 0;
      var calls = 0;
      final interrupted = RemoteImportRepository(
        _CountingBackend(
          flaky,
          onChunk: () {
            calls++;
            if (calls == 3) flaky.failChunkCalls = 3;
          },
        ),
      );
      final first = await _run(interrupted, text.toString(), plan);
      expect(first, isA<RunDisconnected>());
      final applied = await repo.appliedChunks(plan.batchId);
      expect(applied, {0});

      final resumed = await _run(repo, text.toString(), plan, resume: true);
      expect(resumed, isA<RunCompleted>());
      final existing = await repo.loadExisting();
      expect(existing.entries, hasLength(700));
      expect(existing.entries.map((e) => e.id).toSet(), hasLength(700));
    },
    skip: skip,
  );

  test(
    'recorrência: celular não duplica a geração; edição no celular durante '
    'o desfazer vira conflito normal',
    () async {
      final account = await newTestAccount(r);
      final client = await account.device();
      final repo = RemoteImportRepository(SupabaseImportBackend(client));
      // Três meses seguidos até o mês anterior (dia 15) + um avulso.
      final months = [
        for (var k = 3; k >= 1; k--)
          CalendarDate.addMonthsTo(today.year, today.month, -k),
      ];
      final text = StringBuffer('descricao;valor;data\n');
      for (final m in months) {
        text.write('Aluguel;1.500,00;15/${_two(m.$2)}/${m.$1}\n');
      }
      final last = months.last;
      text.write('Mercado;200,00;20/${_two(last.$2)}/${last.$1}\n');
      final table = parseCsv(text.toString(), CsvSeparator.semicolon);
      final batchId = _uuid(r);
      final base = _plan(batchId, today);
      final rows = assembleImport(table, base).rows;
      final series = detectSeries(rows, const {}, today, const ExistingData());
      expect(series.single.status, SeriesStatus.suggested);
      final backfill = backfillFor(series.single, today);
      final plan = _plan(batchId, today, series: [series.single.id]);

      final result = await _run(repo, text.toString(), plan);
      expect(result, isA<RunCompleted>());
      final batch = (result as RunCompleted).batch;
      expect(batch.result!['occurrences'], backfill.length);

      Future<int> serverTemplateEntries() async {
        final rows = await client
            .from('expense_entries')
            .select('id')
            .not('recurrence_template_id', 'is', null);
        return rows.length;
      }

      expect(await serverTemplateEntries(), 1 + backfill.length);

      // Celular baixa, sincroniza (a sincronização chama a geração) e
      // baixa de novo: nada novo é gerado.
      final db = memoryDb();
      addTearDown(db.close);
      final download = DownloadService(db, SupabaseSyncReader(client));
      final sync = SyncService(db, SupabaseSyncGateway(client));
      await download.downloadAll(account.id);
      await sync.syncOnce(account.id);
      await download.downloadAll(account.id);
      expect(await serverTemplateEntries(), 1 + backfill.length);

      // Edição no celular do avulso importado (ainda não enviada).
      final recorder = LocalChangeRecorder(db);
      final entryRepo = LocalEntryRepository(db, account.id, recorder);
      final entries = EntryService(
        entryRepo,
        LocalCategoryRepository(db, account.id, recorder),
      );
      final market = await entryRepo.entry(
        EntryKind.expense,
        ImportIds.entry(batchId, 5),
      );
      expect(market, isNotNull);
      await entries.update(
        market!,
        EntryDraft(
          kind: EntryKind.expense,
          amount: market.amount,
          date: market.date,
          description: 'Mercado do mês',
        ),
      );

      // Web desfaz antes do envio do celular.
      UndoReport undo;
      do {
        undo = await repo.undo(batchId, limit: 3);
      } while (undo.remaining);
      expect(undo.status, ImportBatchStatus.undone);
      expect(undo.count('cancelled'), 4 + backfill.length);
      expect(undo.count('deactivated'), 1);

      // O envio do celular vira conflito normal (nunca última gravação vence).
      for (var i = 0; i < 3; i++) {
        await sync.syncOnce(account.id);
      }
      expect(await sync.openConflicts(account.id), isNotEmpty);
      final server = await client
          .from('expense_entries')
          .select('status,description')
          .eq('id', ImportIds.entry(batchId, 5))
          .single();
      expect(server['status'], 'cancelled');
      expect(server['description'], 'Mercado');
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: skip,
  );

  test('isolamento: outra conta não vê nem desfaz a importação', () async {
    final a = await newTestAccount(r);
    final b = await newTestAccount(r);
    final repoA = RemoteImportRepository(
      SupabaseImportBackend(await a.device()),
    );
    final repoB = RemoteImportRepository(
      SupabaseImportBackend(await b.device()),
    );
    final plan = _plan(_uuid(r), today);
    final result = await _run(
      repoA,
      'descricao;valor;data\nX;1,00;20/03/2025\n',
      plan,
    );
    expect(result, isA<RunCompleted>());
    expect(await repoB.listBatches(), isEmpty);
    expect(await repoB.batch(plan.batchId), isNull);
    await expectLater(repoB.undoPreview(plan.batchId), throwsA(anything));
    await expectLater(repoB.undo(plan.batchId), throwsA(anything));
    expect(
      (await repoA.listBatches()).single.status,
      ImportBatchStatus.completed,
    );
  }, skip: skip);
}

/// Conta as chamadas de bloco (para disparar a queda no ponto certo).
class _CountingBackend implements ImportBackend {
  _CountingBackend(this._inner, {required this.onChunk});
  final ImportBackend _inner;
  final void Function() onChunk;

  @override
  Future<Object?> rpc(String name, Map<String, Object?> params) {
    if (name == 'import_apply_chunk') onChunk();
    return _inner.rpc(name, params);
  }

  @override
  Future<List<Map<String, dynamic>>> selectAll(String t, String c) =>
      _inner.selectAll(t, c);

  @override
  Future<Map<String, dynamic>?> selectOne(String t, String id) =>
      _inner.selectOne(t, id);

  @override
  Future<List<Map<String, dynamic>>> selectWhere(
    String t,
    String c,
    String col,
    String v,
  ) => _inner.selectWhere(t, c, col, v);
}
