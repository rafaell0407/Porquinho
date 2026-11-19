@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/entries/remote_entry_repository.dart';
import 'package:porquinho/features/import/application/import_runner.dart';
import 'package:porquinho/features/import/data/import_repository.dart';
import 'package:porquinho/features/import/domain/column_mapping.dart';
import 'package:porquinho/features/import/domain/csv_reader.dart';
import 'package:porquinho/features/import/domain/date_parsing.dart';
import 'package:porquinho/features/import/domain/import_models.dart';
import 'package:porquinho/features/import/domain/import_plan.dart';
import 'package:porquinho/features/import/domain/text_decoding.dart';
import 'package:porquinho/features/import/domain/value_parsing.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

import '../support/supabase_local_support.dart';

/// T6: desempenho com muitos dados (metas da RN043).
///
/// Cria uma conta de teste com `PERF_ROWS` lançamentos (padrão 20.000; 80%
/// despesas e 20% receitas, espalhados por 10 anos), mede as operações que o
/// usuário sente e imprime uma tabela. A conta é apagada no fim (pela própria
/// exclusão de conta) e também pela limpeza dos scripts de teste.
///
/// Valores vêm de `--dart-define` (`PERF_ROWS=100000` para o caso extremo).
const _perfRows = int.fromEnvironment('PERF_ROWS', defaultValue: 20000);

/// `PERF_KEEP_ACCOUNT=1` não apaga a conta no fim (para inspecionar o banco).
const _keepAccount = int.fromEnvironment('PERF_KEEP_ACCOUNT') == 1;

String _two(int n) => n.toString().padLeft(2, '0');

ImportPlan _plan(String batchId, CalendarDate today, RowKind kind) =>
    ImportPlan(
      batchId: batchId,
      today: today,
      encoding: ImportEncoding.utf8,
      separator: CsvSeparator.semicolon,
      mapping: ImportMapping(
        columns: const {
          ImportField.description: 0,
          ImportField.amount: 1,
          ImportField.date: 2,
        },
        valueFormat: ValueFormat.reaisComma,
        dateFormat: DateFormatKind.dmy,
        fixedKind: kind,
      ),
      categoryChoices: const {},
      duplicateDecisions: const {},
      ignoredRows: const [],
      confirmedSeries: const [],
    );

/// Gera o CSV: [count] linhas, de 2016 a 2025, datas até o dia 28.
String _csv(int count, String prefix) {
  final text = StringBuffer('descricao;valor;data\n');
  for (var i = 0; i < count; i++) {
    final cents = 100 + (i * 37 % 9973);
    text.write(
      '$prefix $i;${cents ~/ 100},${_two(cents % 100)};'
      '${1 + i % 28}/${_two(1 + (i ~/ 28) % 12)}/${2016 + (i ~/ 336) % 10}\n',
    );
  }
  return text.toString();
}

Future<void> _import(
  ImportRepository repo,
  String text,
  ImportPlan plan,
) async {
  final bytes = Uint8List.fromList(utf8.encode(text));
  final table = parseCsv(text, CsvSeparator.semicolon);
  final assembled = assembleImport(table, plan);
  final result = await ImportRunner(repo).run(
    plan: plan,
    file: ImportFileInfo(
      name: 'perf.csv',
      sha256: fileSha256(bytes),
      sizeBytes: bytes.length,
      rows: table.records.length,
    ),
    assembled: assembled,
    summary: {'rejected': assembled.rejected.length},
  );
  expect(result, isA<RunCompleted>());
}

class _Row {
  _Row(this.name, this.ms, {this.goalMs});
  final String name;
  final int ms;
  final int? goalMs;

  String get verdict => goalMs == null
      ? ''
      : ms <= goalMs!
      ? 'ok'
      : 'ACIMA DA META';
}

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;
  final today = const UserClock().today();
  final rows = <_Row>[];

  Future<T> timed<T>(
    String name,
    Future<T> Function() body, {
    int? goalMs,
  }) async {
    final sw = Stopwatch()..start();
    final value = await body();
    sw.stop();
    rows.add(_Row(name, sw.elapsedMilliseconds, goalMs: goalMs));
    return value;
  }

  test(
    'desempenho com $_perfRows lançamentos',
    () async {
      final account = await newTestAccount(r);
      final client = await account.device();
      final owner = account.id;
      final month = PeriodCalendar.between(
        PeriodConfig.calendarMonth(),
        CalendarDate(2025, 6, 1),
        CalendarDate(2025, 6, 30),
      ).single;
      final year = PeriodCalendar.between(
        PeriodConfig.calendarMonth(),
        CalendarDate(2025, 1, 1),
        CalendarDate(2025, 12, 31),
      );
      final decade = PeriodCalendar.between(
        PeriodConfig.calendarMonth(),
        CalendarDate(2016, 1, 1),
        CalendarDate(2025, 12, 31),
      );

      // ---- Criação dos dados (pela própria importação do app) ----
      final importRepo = RemoteImportRepository(SupabaseImportBackend(client));
      final expenses = _perfRows * 8 ~/ 10;
      final incomes = _perfRows - expenses;
      await timed(
        'Criar $expenses despesas (importação)',
        () => _import(
          importRepo,
          _csv(expenses, 'Despesa'),
          _plan(testUuid(r), today, RowKind.expense),
        ),
      );
      await timed(
        'Criar $incomes receitas (importação)',
        () => _import(
          importRepo,
          _csv(incomes, 'Receita'),
          _plan(testUuid(r), today, RowKind.income),
        ),
      );

      // ---- Servidor (caminho da Web, e do que a nuvem entrega ao celular) ----
      final remoteReports = RemoteReportsRepository(
        SupabaseReportSource(client),
      );
      final remoteTotals = RemoteTotalsRepository(remoteReports);
      final remoteEntries = RemoteEntryRepository(
        SupabaseTableReader(client),
        SupabaseSyncGateway(client),
      );
      await timed(
        'Servidor: Home (totais de 1 período)',
        () => remoteTotals.totalsFor(month),
        goalMs: 1000,
      );
      await timed(
        'Servidor: lista de lançamentos de 1 mês',
        () => remoteEntries.entriesInPeriod(month),
        goalMs: 1000,
      );
      await timed(
        'Servidor: relatórios de 12 períodos',
        () => remoteReports.report(year),
      );
      await timed(
        'Servidor: relatórios de 120 períodos (10 anos)',
        () => remoteReports.report(decade),
      );
      await timed(
        'Servidor: salvar 1 despesa (Web)',
        () => remoteEntries.apply([
          CreateEntry(
            testUuid(r),
            EntryDraft(
              kind: EntryKind.expense,
              amount: BigInt.from(1234),
              date: CalendarDate(2025, 6, 15),
              description: 'Salvar teste',
            ),
          ),
        ]),
        goalMs: 500,
      );

      // ---- Celular: baixa tudo para o banco local e mede as leituras ----
      final db = memoryDb();
      addTearDown(db.close);
      await timed(
        'Celular: primeira sincronização (baixar tudo)',
        () =>
            DownloadService(db, SupabaseSyncReader(client)).downloadAll(owner),
      );
      final recorder = LocalChangeRecorder(db);
      final localEntries = LocalEntryRepository(db, owner, recorder);
      final localTotals = LocalTotalsRepository(db, owner);
      final localReports = LocalReportsRepository(db, owner);
      final service = EntryService(
        localEntries,
        LocalCategoryRepository(db, owner, recorder),
      );

      await timed(
        'Celular: Home (totais de 1 período)',
        () => localTotals.totalsFor(month),
        goalMs: 1000,
      );
      await timed(
        'Celular: dinheiro livre recalculado',
        () => localTotals.totalsFor(month),
        goalMs: 300,
      );
      await timed(
        'Celular: lista de lançamentos de 1 mês',
        () => localEntries.entriesInPeriod(month),
        goalMs: 1000,
      );
      await timed(
        'Celular: relatórios de 12 períodos',
        () => localReports.report(year),
      );
      await timed(
        'Celular: relatórios de 120 períodos (10 anos)',
        () => localReports.report(decade),
      );
      await timed(
        'Celular: salvar 1 despesa (local)',
        () => service.create(
          EntryDraft(
            kind: EntryKind.expense,
            amount: BigInt.from(4321),
            date: CalendarDate(2025, 6, 16),
            description: 'Salvar local',
          ),
        ),
        goalMs: 500,
      );
      await timed(
        'Celular: enviar 1 lançamento ao servidor',
        () => SyncService(db, SupabaseSyncGateway(client)).syncOnce(owner),
        goalMs: 5000,
      );

      // ---- Planos de consulta do celular (usa índice ou lê tudo?) ----
      final plans = <String>[];
      Future<void> plan(String label, String sql, List<Object> args) async {
        final result = await db
            .customSelect(
              'EXPLAIN QUERY PLAN $sql',
              variables: [for (final a in args) Variable.withString('$a')],
            )
            .get();
        for (final row in result) {
          plans.add('$label -> ${row.data['detail']}');
        }
      }

      await plan(
        'despesas do período',
        'SELECT * FROM expense_entries WHERE owner_id = ? AND '
            '(competence_on >= ? AND competence_on < ?) '
            'ORDER BY competence_on DESC, created_at DESC',
        [owner, '2025-06-01', '2025-07-01'],
      );
      await plan(
        'receitas do período',
        'SELECT * FROM income_entries WHERE owner_id = ? AND '
            '((received_on >= ? AND received_on < ?) OR '
            '(received_on IS NULL AND scheduled_for_date >= ? '
            'AND scheduled_for_date < ?))',
        [owner, '2025-06-01', '2025-07-01', '2025-06-01', '2025-07-01'],
      );
      await plan(
        'totais de receitas',
        'SELECT status, amount_centavos FROM income_entries '
            "WHERE owner_id = ? AND received_on >= ? AND received_on < ? "
            "AND status = 'received'",
        [owner, '2025-06-01', '2025-07-01'],
      );

      // ---- Apagar conta com muitos dados (pior caso do T10) ----
      // O relatório é impresso antes e a falha não derruba o teste: se a
      // exclusão estourar o tempo do servidor, os outros tempos não se perdem.
      final deleteWatch = Stopwatch()..start();
      String? deleteFailure;
      try {
        if (_keepAccount) throw 'conta mantida (PERF_KEEP_ACCOUNT=1)';
        await client.rpc(
          'delete_my_account',
          params: {'p_confirmation': 'DELETE_MY_ACCOUNT'},
        );
      } on Object catch (e) {
        deleteFailure = '$e';
      }
      deleteWatch.stop();
      rows.add(
        _Row(
          deleteFailure == null
              ? 'Servidor: apagar a conta com todos os dados'
              : 'Servidor: apagar a conta FALHOU ($deleteFailure)',
          deleteWatch.elapsedMilliseconds,
        ),
      );

      // ---- Relatório ----
      final out = StringBuffer(
        '\n===== DESEMPENHO ($_perfRows lançamentos) =====\n',
      );
      for (final row in rows) {
        final goal = row.goalMs == null ? '' : ' (meta ${row.goalMs} ms)';
        out.writeln(
          '${row.name.padRight(52)} ${row.ms.toString().padLeft(7)} ms$goal '
          '${row.verdict}',
        );
      }
      out.writeln('--- planos de consulta no celular ---');
      plans.forEach(out.writeln);
      // ignore: avoid_print
      print(out);
    },
    timeout: const Timeout(Duration(minutes: 40)),
    skip: skip,
  );
}
