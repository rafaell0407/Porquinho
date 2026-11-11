@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/recurrence_schedule.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/categories/remote_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/entries/remote_entry_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/periods/remote_period_repository.dart';
import 'package:porquinho/features/recurrence/local_recurrence_repository.dart';
import 'package:porquinho/features/recurrence/remote_recurrence_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/totals/totals_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fase 5 contra o Supabase LOCAL (nunca o gerenciado): recorrências criadas
/// offline, geração local e no servidor com o mesmo identificador, dois
/// aparelhos e equivalência da sobra (RF027).
const _url = String.fromEnvironment('SUPABASE_URL');
const _publishable = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _secret = String.fromEnvironment('SUPABASE_SECRET_KEY');
final _enabled =
    _url.isNotEmpty && _publishable.isNotEmpty && _secret.isNotEmpty;

class _Account {
  _Account(this.client, this.id);
  final SupabaseClient client;
  final String id;
}

Future<_Account> _newAccount(Random r) async {
  final admin = SupabaseClient(_url, _secret);
  final email = 'f5-${r.nextInt(1 << 30)}@teste.local';
  final created = await admin.auth.admin.createUser(
    AdminUserAttributes(
      email: email,
      password: 'Senha-123456',
      emailConfirm: true,
    ),
  );
  final client = SupabaseClient(_url, _publishable);
  await client.auth.signInWithPassword(email: email, password: 'Senha-123456');
  return _Account(client, created.user!.id);
}

BigInt c(int v) => BigInt.from(v);

/// Um aparelho: banco local em memória ligado à conta.
class _Device {
  _Device(this.account) {
    db = PorquinhoDatabase(NativeDatabase.memory());
    final recorder = LocalChangeRecorder(db);
    periodRepo = LocalPeriodRepository(db, account.id, recorder);
    periods = PeriodService(periodRepo);
    final catRepo = LocalCategoryRepository(db, account.id, recorder);
    recurrenceRepo = LocalRecurrenceRepository(db, account.id, recorder);
    entryRepo = LocalEntryRepository(db, account.id, recorder);
    entries = EntryService(
      entryRepo,
      catRepo,
      periods,
      recurrences: recurrenceRepo,
    );
    sync = SyncService(db, SupabaseSyncGateway(account.client));
    totals = LocalTotalsRepository(db, account.id);
  }

  final _Account account;
  late final PorquinhoDatabase db;
  late final LocalPeriodRepository periodRepo;
  late final PeriodService periods;
  late final LocalRecurrenceRepository recurrenceRepo;
  late final LocalEntryRepository entryRepo;
  late final EntryService entries;
  late final SyncService sync;
  late final LocalTotalsRepository totals;

  /// Envia a fila até esvaziar; nada pode ser recusado nem conflitar.
  Future<void> drain() async {
    for (
      var i = 0;
      i < 6 && (await sync.operations(account.id)).isNotEmpty;
      i++
    ) {
      await sync.syncOnce(account.id);
    }
    final left = await sync.operations(account.id);
    expect(
      left,
      isEmpty,
      reason: left.map((o) => '${o.rpc}:${o.state}:${o.lastError}').join('; '),
    );
    expect(await sync.openConflicts(account.id), isEmpty);
  }

  Future<void> download() async {
    final result = await DownloadService(
      db,
      SupabaseSyncReader(account.client),
    ).downloadAll(account.id);
    expect(result.completed, isTrue);
  }

  Future<void> serverGenerate() => SupabaseSyncGateway(
    account.client,
  ).call('generate_due_recurrence_occurrences', {'p_operation_id': newUuid()});

  Future<Set<String>> localOccurrenceKeys(String table) async {
    final rows = await db
        .customSelect(
          'SELECT id, recurrence_template_id AS t, scheduled_for_date AS s '
          'FROM $table WHERE owner_id = ? AND recurrence_template_id IS NOT NULL',
          variables: [Variable.withString(account.id)],
        )
        .get();
    return rows
        .map((r) => '${r.read<String>('id')}|${r.read<String>('s')}')
        .toSet();
  }
}

void main() {
  final r = Random();
  const skip = 'defina SUPABASE_URL/PUBLISHABLE_KEY/SECRET_KEY';
  final today = todayInZone(DateTime.now().toUtc());
  final thisMonth = CalendarDate(today.year, today.month, 1);
  CalendarDate monthsAgo(int n) {
    final p = CalendarDate.addMonthsTo(thisMonth.year, thisMonth.month, -n);
    return CalendarDate(p.$1, p.$2, 1);
  }

  Future<Set<String>> serverKeys(_Account a, String table) async {
    final rows = await SupabaseTableReader(a.client).select(table);
    return rows
        .where((e) => e['recurrence_template_id'] != null)
        .map((e) => '${e['id']}|${e['scheduled_for_date']}')
        .toSet();
  }

  EntryDraft draft(EntryKind k, int? cents, CalendarDate date) => EntryDraft(
    kind: k,
    amount: cents == null ? null : c(cents),
    date: date,
    description: k.label,
  );

  test(
    'celular offline → servidor: mesmas ocorrências, mesma sobra, sem duplicar',
    () async {
      final a = await _newAccount(r);
      final dev = _Device(a);
      addTearDown(dev.db.close);

      await dev.periods.setup(PeriodConfig.calendarMonth(), today);
      await dev.entries.createMissingPeriods(monthsAgo(3));

      // Offline: despesa fixa (3 meses atrás), variável e receita recorrente.
      final expenseStart = CalendarDate(
        monthsAgo(3).year,
        monthsAgo(3).month,
        28,
      );
      final expenseId = await dev.entries.create(
        draft(EntryKind.expense, 9000, expenseStart),
        repeat: const RepeatChoice(frequency: RecurrenceFrequency.monthly),
      );
      await dev.entries.create(
        draft(EntryKind.expense, null, monthsAgo(2)),
        repeat: const RepeatChoice(
          frequency: RecurrenceFrequency.byPeriod,
          variableValue: true,
        ),
      );
      final incomeStart = CalendarDate(
        monthsAgo(3).year,
        monthsAgo(3).month,
        5,
      );
      final incomeId = await dev.entries.create(
        draft(EntryKind.income, 300000, incomeStart),
        repeat: const RepeatChoice(frequency: RecurrenceFrequency.monthly),
      );

      // Geração local ao abrir (celular offline) e edições das ocorrências.
      await dev.recurrenceRepo.generateDue(today);
      final firstExpense = (await dev.entryRepo.entry(
        EntryKind.expense,
        expenseId,
      ))!;
      await dev.entries.pay(firstExpense, today);
      final firstIncome = (await dev.entryRepo.entry(
        EntryKind.income,
        incomeId,
      ))!;
      await dev.entries.receive(firstIncome, today);

      await dev.drain();
      await dev.serverGenerate();
      await dev.download();

      // Mesmas ocorrências (ids e datas) no aparelho e no servidor.
      for (final table in ['expense_entries', 'income_entries']) {
        expect(
          await serverKeys(a, table),
          await dev.localOccurrenceKeys(table),
          reason: table,
        );
      }
      // Ids determinísticos (D1).
      final rows = await SupabaseTableReader(
        a.client,
      ).select('expense_entries');
      for (final row in rows.where(
        (e) => e['recurrence_template_id'] != null,
      )) {
        expect(
          row['id'],
          RecurrenceCalendar.occurrenceId(
            row['recurrence_template_id'] as String,
            CalendarDate.parse(row['scheduled_for_date'] as String),
          ),
        );
      }

      // Datas do servidor = datas do domínio (dia 28 mensal desde 3 meses).
      final templates = await dev.recurrenceRepo.templates();
      final monthlyExpense = templates.firstWhere(
        (t) => t.kind == EntryKind.expense && t.monthlyReferenceDay != null,
      );
      final expected = RecurrenceCalendar.monthlyUntil(
        monthlyExpense.schedule,
        today,
      ).map((e) => e.toIso()).toList();
      final serverDates = (await SupabaseTableReader(a.client).select(
        'expense_entries',
        filters: [RemoteFilter.eq('recurrence_template_id', monthlyExpense.id)],
        orderBy: 'scheduled_for_date',
      )).map((e) => e['scheduled_for_date']).toList();
      expect(serverDates, expected);

      // Sobra igual no aparelho e no servidor (RF027) em todos os períodos.
      final remoteTotals = RemoteTotalsRepository(
        RemoteReportsRepository(SupabaseReportSource(a.client)),
      );
      for (final p in await dev.periodRepo.periods()) {
        expect(
          await remoteTotals.totalsFor(p.id),
          await dev.totals.totalsFor(p.id),
          reason: p.range.toString(),
        );
      }

      // Repetir a rodada não duplica.
      await dev.serverGenerate();
      await dev.recurrenceRepo.generateDue(today);
      expect(
        await serverKeys(a, 'expense_entries'),
        hasLength(
          rows.where((e) => e['recurrence_template_id'] != null).length,
        ),
      );
    },
    skip: _enabled ? false : skip,
  );

  test(
    'dois aparelhos offline geram a mesma ocorrência, sem conflito nem duplicata',
    () async {
      final a = await _newAccount(r);
      final d1 = _Device(a);
      addTearDown(d1.db.close);
      await d1.periods.setup(PeriodConfig.calendarMonth(), today);
      await d1.entries.createMissingPeriods(monthsAgo(2));
      await d1.entries.create(
        draft(
          EntryKind.expense,
          5000,
          CalendarDate(monthsAgo(2).year, monthsAgo(2).month, 10),
        ),
        repeat: const RepeatChoice(frequency: RecurrenceFrequency.monthly),
      );
      await d1.drain();

      // Segundo aparelho: baixa tudo e, offline, gera por conta própria.
      final d2 = _Device(a);
      addTearDown(d2.db.close);
      await d2.download();
      await d1.recurrenceRepo.generateDue(today);
      await d2.recurrenceRepo.generateDue(today);
      expect(
        await d1.localOccurrenceKeys('expense_entries'),
        await d2.localOccurrenceKeys('expense_entries'),
        reason: 'mesmos ids e datas nos dois aparelhos',
      );

      // Cada aparelho altera uma ocorrência diferente, offline.
      final ids = (await d1.localOccurrenceKeys(
        'expense_entries',
      )).map((e) => e.split('|').first).toList()..sort();
      expect(ids.length, greaterThanOrEqualTo(3));
      final e1 = (await d1.entryRepo.entry(EntryKind.expense, ids[1]))!;
      final e2 = (await d2.entryRepo.entry(EntryKind.expense, ids[2]))!;
      await d1.entries.pay(e1, today);
      await d2.entries.cancel(e2);

      await d1.drain();
      await d2.drain();
      await d1.serverGenerate();
      await d2.serverGenerate();

      final server = await serverKeys(a, 'expense_entries');
      expect(server, hasLength(ids.length));
      await d1.download();
      await d2.download();
      final remoteTotals = RemoteTotalsRepository(
        RemoteReportsRepository(SupabaseReportSource(a.client)),
      );
      for (final p in await d1.periodRepo.periods()) {
        final remote = await remoteTotals.totalsFor(p.id);
        expect(await d1.totals.totalsFor(p.id), remote, reason: 'aparelho 1');
        expect(await d2.totals.totalsFor(p.id), remote, reason: 'aparelho 2');
      }
    },
    skip: _enabled ? false : skip,
  );

  test(
    'Web (repositórios remotos): Repetir, geração por RPC, confirmar e parar',
    () async {
      final a = await _newAccount(r);
      final reader = SupabaseTableReader(a.client);
      final gateway = SupabaseSyncGateway(a.client);
      final periods = PeriodService(RemotePeriodRepository(reader, gateway));
      final catRepo = RemoteCategoryRepository(reader, gateway);
      final recurrenceRepo = RemoteRecurrenceRepository(reader, gateway);
      final entryRepo = RemoteEntryRepository(reader, gateway);
      final entries = EntryService(
        entryRepo,
        catRepo,
        periods,
        recurrences: recurrenceRepo,
      );
      await periods.setup(PeriodConfig.calendarMonth(), today);

      final id = await entries.create(
        draft(EntryKind.income, 100000, today),
        repeat: const RepeatChoice(frequency: RecurrenceFrequency.monthly),
      );
      final pending = (await entryRepo.entry(EntryKind.income, id))!;
      expect(pending.status, 'pending');
      final period = (await periods.periodFor(today))!;
      expect((await entryRepo.entriesInPeriod(period.id)).map((e) => e.id), [
        id,
      ], reason: 'receita pendente aparece no período da data programada');
      expect(
        (await RemoteTotalsRepository(
          RemoteReportsRepository(SupabaseReportSource(a.client)),
        ).totalsFor(period.id)).surplus,
        BigInt.zero,
      );
      await entries.receive(pending, today);
      expect(
        (await RemoteTotalsRepository(
          RemoteReportsRepository(SupabaseReportSource(a.client)),
        ).totalsFor(period.id)).surplus,
        c(100000),
      );

      expect(await recurrenceRepo.generateDue(today), 0);
      final template = (await recurrenceRepo.templates()).single;
      await recurrenceRepo.stop(template);
      expect((await recurrenceRepo.templates()).single.isActive, isFalse);
    },
    skip: _enabled ? false : skip,
  );
}
