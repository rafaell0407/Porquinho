@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/periods/remote_period_repository.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/totals/totals_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/supabase_local_support.dart';

/// Reestruturação P6: configuração única sincronizada entre aparelhos e Web,
/// com conflito por versão (nunca "última gravação vence"); lançamentos sem
/// período gravado somam igual no aparelho e no servidor.
CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);

class _Device {
  _Device(this.account, this.client) {
    db = memoryDb();
    final recorder = LocalChangeRecorder(db);
    periods = PeriodService(LocalPeriodRepository(db, account.id, recorder));
    entries = EntryService(
      LocalEntryRepository(db, account.id, recorder),
      LocalCategoryRepository(db, account.id, recorder),
    );
    sync = SyncService(db, SupabaseSyncGateway(client));
  }

  final TestAccount account;
  final SupabaseClient client;
  late final PorquinhoDatabase db;
  late final PeriodService periods;
  late final EntryService entries;
  late final SyncService sync;

  Future<void> push() async {
    for (var i = 0; i < 5; i++) {
      await sync.syncOnce(account.id);
    }
  }

  Future<void> download() async {
    final r = await DownloadService(
      db,
      SupabaseSyncReader(client),
    ).downloadAll(account.id);
    expect(r.completed, isTrue);
  }
}

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;

  test(
    'configuração única: segundo aparelho, Web e conflito por versão',
    () async {
      final account = await newTestAccount(r);
      final client = await account.device();
      final d1 = _Device(account, client);
      final d2 = _Device(account, client);
      addTearDown(d1.db.close);
      addTearDown(d2.db.close);
      final web = PeriodService(
        RemotePeriodRepository(
          SupabaseTableReader(client),
          SupabaseSyncGateway(client),
        ),
      );

      // Primeiro acesso no aparelho 1, sincroniza.
      await d1.periods.setup(PeriodConfig.calendarMonth());
      await d1.push();
      expect(await d1.sync.operations(account.id), isEmpty);
      expect(await web.currentConfig(), PeriodConfig.calendarMonth());

      // Aparelho 2 baixa e não pergunta de novo.
      await d2.download();
      expect(await d2.periods.needsSetup(), isFalse);
      expect(await d2.periods.currentConfig(), PeriodConfig.calendarMonth());

      // Troca na Web: o aparelho baixa a nova configuração.
      await web.change(PeriodConfig.customCycle(20));
      await d1.download();
      expect(await d1.periods.currentConfig(), PeriodConfig.customCycle(20));

      // Os dois aparelhos trocam offline a partir da mesma versão.
      await d2.download();
      await d1.periods.change(PeriodConfig.customCycle(5));
      await d2.periods.change(PeriodConfig.customCycle(31));
      await d1.push();
      await d2.push();
      // O primeiro a chegar vale; o segundo vira conflito, sem sobrescrever.
      expect(await web.currentConfig(), PeriodConfig.customCycle(5));
      final conflicts = await d2.sync.openConflicts(account.id);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.entityType, 'period_settings');

      // Manter a do aparelho 2: reaplica sobre a versão atual.
      final response = await d2.sync.resolveConflict(
        account.id,
        conflicts.single.id,
        ConflictResolution.keepLocal,
      );
      expect(response['status'], 'resolved');
      expect(await web.currentConfig(), PeriodConfig.customCycle(31));
      await d1.download();
      expect(await d1.periods.currentConfig(), PeriodConfig.customCycle(31));
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: skip,
  );

  test(
    'lançamentos em qualquer data: sem período gravado, somas iguais',
    () async {
      final account = await newTestAccount(r);
      final client = await account.device();
      final dev = _Device(account, client);
      addTearDown(dev.db.close);
      await dev.periods.setup(PeriodConfig.customCycle(31));
      Future<void> add(EntryKind k, int cents, CalendarDate date) =>
          dev.entries.create(
            EntryDraft(
              kind: k,
              amount: BigInt.from(cents),
              date: date,
              dueOn: k == EntryKind.expense ? date : null,
            ),
          );
      // Fronteiras do ciclo dia 31, um ano bissexto e datas distantes.
      for (final date in [
        d(2024, 2, 29),
        d(2026, 1, 31),
        d(2026, 2, 27),
        d(2026, 2, 28),
        d(2026, 3, 30),
        d(2026, 3, 31),
        d(2031, 12, 31),
      ]) {
        await add(EntryKind.income, 10000 + date.day, date);
        await add(EntryKind.expense, 300 + date.month, date);
      }
      await dev.push();
      expect(await dev.sync.operations(account.id), isEmpty);
      expect(await dev.sync.openConflicts(account.id), isEmpty);

      final row =
          (await client.from('income_entries').select().limit(1)).single;
      expect(
        row.containsKey('accounting_period_id'),
        isFalse,
        reason: 'servidor sem vínculo com período (P7)',
      );

      final remote = RemoteTotalsRepository(
        RemoteReportsRepository(SupabaseReportSource(client)),
      );
      final local = LocalTotalsRepository(dev.db, account.id);
      for (final p in PeriodCalendar.between(
        PeriodConfig.customCycle(31),
        d(2024, 2, 1),
        d(2026, 4, 30),
      )) {
        expect(
          await remote.totalsFor(p),
          await local.totalsFor(p),
          reason: '$p',
        );
      }
      final feb = await dev.periods.periodFor(d(2026, 2, 27));
      expect(feb, PeriodRange(d(2026, 1, 31), d(2026, 2, 28)));
      final t = await remote.totalsFor(feb);
      expect(t.income, BigInt.from(10031 + 10027));
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: skip,
  );
}
