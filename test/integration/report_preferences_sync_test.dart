@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/preferences/preferences_repository.dart';
import 'package:porquinho/features/reports/models/report_preferences.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/supabase_local_support.dart';

/// RL7: escolhas da central de Relatórios contra o Supabase LOCAL — dois
/// aparelhos (a última lista vence; a configuração feita se soma), Web e
/// isolamento.
class _Device {
  _Device(this.account, this.client) {
    repo = LocalPreferencesRepository(db, account.id, LocalChangeRecorder(db));
    sync = SyncService(db, SupabaseSyncGateway(client));
  }

  final TestAccount account;
  final SupabaseClient client;
  final PorquinhoDatabase db = memoryDb();
  late final LocalPreferencesRepository repo;
  late final SyncService sync;

  Future<void> syncAll() async {
    for (var i = 0; i < 3; i++) {
      await sync.syncOnce(account.id);
    }
    await DownloadService(
      db,
      SupabaseSyncReader(client),
    ).downloadAll(account.id);
  }

  Future<ReportPreferences> server() async => RemotePreferencesRepository(
    SupabaseTableReader(client),
    SupabaseSyncGateway(client),
  ).reports();
}

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;

  test('dois aparelhos: a última lista vence; feita não volta', () async {
    final account = await newTestAccount(r);
    final a = _Device(account, await account.device());
    final b = _Device(account, await account.device());

    // A conclui a configuração com dois relatórios (offline primeiro).
    await a.repo.setReportSelection([
      'income_by_category',
      'period_comparison',
    ]);
    await a.repo.completeReportSetup(ReportSetupStatus.done);
    await a.syncAll();
    expect(await a.sync.operations(account.id), isEmpty);
    await b.syncAll();
    expect(
      await b.repo.reports(),
      const ReportPreferences(
        setup: ReportSetupStatus.done,
        selected: ['income_by_category', 'period_comparison'],
      ),
    );

    // Os dois mudam sem conexão; B envia antes, A depois: vale a de A.
    await b.repo.setReportSelection(['investments_total']);
    await b.repo.completeReportSetup(ReportSetupStatus.skipped);
    await a.repo.setReportSelection(['period_comparison']);
    await b.syncAll();
    await a.syncAll();
    await b.syncAll();
    final expected = const ReportPreferences(
      setup: ReportSetupStatus.done,
      selected: ['period_comparison'],
    );
    expect(await a.server(), expected);
    expect(await a.repo.reports(), expected);
    expect(await b.repo.reports(), expected);

    // Restaurar a lista sugerida chega ao outro aparelho.
    await b.repo.setReportSelection(null);
    await b.syncAll();
    await a.syncAll();
    expect((await a.repo.reports()).isSuggested, isTrue);
    expect((await a.repo.reports()).setup, ReportSetupStatus.done);
  }, skip: skip);

  test('Web grava direto e o aparelho recebe; ferramentas intactas', () async {
    final account = await newTestAccount(r);
    final client = await account.device();
    final web = RemotePreferencesRepository(
      SupabaseTableReader(client),
      SupabaseSyncGateway(client),
    );
    await web.setToolSelection(['reports']);
    await web.completeReportSetup(ReportSetupStatus.skipped);
    await web.setReportSelection(['free_money_evolution']);
    final phone = _Device(account, await account.device());
    await phone.syncAll();
    expect(
      await phone.repo.reports(),
      const ReportPreferences(
        setup: ReportSetupStatus.skipped,
        selected: ['free_money_evolution'],
      ),
    );
    expect((await phone.repo.tools()).selected, ['reports']);
  }, skip: skip);

  test('isolamento: outra conta não vê as escolhas', () async {
    final owner = await newTestAccount(r);
    final other = await newTestAccount(r);
    final a = _Device(owner, await owner.device());
    await a.repo.completeReportSetup(ReportSetupStatus.done);
    await a.repo.setReportSelection(['investments_total']);
    await a.syncAll();
    final b = _Device(other, await other.device());
    await b.syncAll();
    expect(await b.repo.reports(), ReportPreferences.empty);
    expect(await b.server(), ReportPreferences.empty);
  }, skip: skip);
}
