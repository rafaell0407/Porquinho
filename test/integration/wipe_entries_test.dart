@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/attention/attention_models.dart';
import 'package:porquinho/features/attention/local_attention_repository.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/wipe_entries/wipe_entries_gateway.dart';
import 'package:porquinho/features/wipe_entries/wipe_entries_runner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/supabase_local_support.dart';

/// RN056 (AT3): apagar todos os lançamentos com dois aparelhos no Supabase
/// LOCAL.
class _Device {
  _Device(this.ownerId, this.client) {
    db = memoryDb();
    final recorder = LocalChangeRecorder(db);
    repo = LocalEntryRepository(db, ownerId, recorder);
    entries = EntryService(
      repo,
      LocalCategoryRepository(db, ownerId, recorder),
    );
    reader = SupabaseSyncReader(client);
    sync = SyncService(db, SupabaseSyncGateway(client));
    attention = LocalAttentionRepository(
      db,
      ownerId,
      sync,
      DownloadService(db, reader),
    );
  }

  final String ownerId;
  final SupabaseClient client;
  late final PorquinhoDatabase db;
  late final LocalEntryRepository repo;
  late final EntryService entries;
  late final SupabaseSyncReader reader;
  late final SyncService sync;
  late final LocalAttentionRepository attention;

  Future<void> push() async {
    for (var i = 0; i < 3; i++) {
      await sync.syncOnce(ownerId);
    }
  }

  Future<void> pull() async {
    final result = await DownloadService(db, reader).downloadAll(ownerId);
    expect(result.completed, isTrue);
  }

  Future<Map<String, String>> statuses(String table) async => {
    for (final row in await localRows(
      db,
      'SELECT id, status FROM $table WHERE owner_id = ?',
      [ownerId],
    ))
      row['id']! as String: row['status']! as String,
  };
}

void main() {
  final r = Random();

  test('apaga tudo no servidor; o aparelho baixa tudo apagado, a recorrência '
      'para e a edição offline do outro aparelho vira conflito', () async {
    final account = await newTestAccount(r);
    final a = _Device(account.id, await account.device());
    final b = _Device(account.id, await account.device());
    addTearDown(a.db.close);
    addTearDown(b.db.close);

    // A cria receita e duas despesas; mais uma recorrência mensal no servidor.
    Future<String> add(EntryKind kind, int cents) => a.entries.create(
      EntryDraft(
        kind: kind,
        amount: BigInt.from(cents),
        date: CalendarDate(2026, 11, 5),
      ),
    );
    final income = await add(EntryKind.income, 500000);
    final x = await add(EntryKind.expense, 1000);
    final y = await add(EntryKind.expense, 2000);
    await a.push();
    const template = 'a7e00000-0000-4000-8000-000000000001';
    final created = Map<String, dynamic>.from(
      await a.client.rpc(
            'apply_expense_recurrence_template_change',
            params: {
              'p_operation_id': newUuid(),
              'p_action': 'create',
              'p_template_id': template,
              'p_expected_version': 0,
              'p_payload': {
                'description': 'Aluguel',
                'frequency': 'monthly',
                'starts_on': '2026-10-05',
                'monthly_reference_day': 5,
                'value_mode': 'fixed',
                'default_amount_centavos': 150000,
              },
            },
          )
          as Map,
    );
    expect(created['status'], 'applied');
    await a.client.rpc(
      'generate_due_recurrence_occurrences',
      params: {'p_operation_id': newUuid()},
    );
    await a.pull();
    await b.pull();
    expect((await b.statuses('expense_entries')).length, greaterThan(2));

    // B, sem rede, edita Y.
    final yOnB = (await b.repo.entry(EntryKind.expense, y))!;
    await b.entries.update(
      yOnB,
      EntryDraft(
        kind: EntryKind.expense,
        amount: BigInt.from(2500),
        date: yOnB.date,
        dueOn: yOnB.dueOn,
      ),
    );

    // A apaga tudo (em partes de 2).
    final gateway = SupabaseWipeEntriesGateway(a.client);
    final preview = await gateway.preview();
    expect(preview.income, 1);
    expect(preview.expense, greaterThanOrEqualTo(3));
    expect(preview.templates, 1);
    expect(preview.openConflicts, 0);
    final outcome = await WipeEntriesRunner(
      gateway,
      limit: 2,
    ).run(operationId: newUuid(), asOf: preview.asOf);
    expect(outcome, isA<WipeDone>());
    final done = outcome as WipeDone;
    expect(done.income, preview.income);
    expect(done.expense, preview.expense);
    expect(done.templates, 1);

    // A baixa: tudo cancelado e a recorrência desativada; nada foi apagado
    // fisicamente (RN029).
    await a.pull();
    final aIncome = await a.statuses('income_entries');
    final aExpense = await a.statuses('expense_entries');
    expect(aIncome[income], 'cancelled');
    expect(aExpense.keys, containsAll([x, y]));
    expect(aExpense.values.toSet(), {'cancelled'});
    final tpl = await localRows(
      a.db,
      'SELECT is_active FROM expense_recurrence_templates WHERE id = ?',
      [template],
    );
    expect(tpl.single['is_active'], 0);

    // Nova geração no servidor não cria mais nada para o modelo desativado.
    final before = (await a.client.from('expense_entries').select('id')).length;
    await a.client.rpc(
      'generate_due_recurrence_occurrences',
      params: {'p_operation_id': newUuid()},
    );
    expect(
      (await a.client.from('expense_entries').select('id')).length,
      before,
    );

    // B volta: a edição de Y encontra o lançamento apagado e vira conflito.
    await b.push();
    final items = await b.attention.items();
    expect(items.map((i) => i.kind), contains(AttentionKind.conflict));

    // Com o conflito aberto, uma nova tentativa é recusada pelo servidor.
    final again = await gateway.preview();
    expect(again.openConflicts, greaterThan(0));
    final blocked = await WipeEntriesRunner(
      gateway,
    ).run(operationId: newUuid(), asOf: again.asOf);
    expect(blocked, isA<WipeBlocked>());
  }, skip: supabaseEnabled ? false : supabaseSkipReason);
}
