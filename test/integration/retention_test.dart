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
import 'package:porquinho/features/sync/local_retention.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/supabase_local_support.dart';

/// D15 (X4): retenção de 12 meses com dois aparelhos no Supabase LOCAL.
class _Device {
  _Device(this.ownerId, SupabaseClient client) {
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

  Future<void> pull({DateTime Function()? clock}) async {
    final result = await DownloadService(
      db,
      reader,
      clock: clock,
    ).downloadAll(ownerId);
    expect(result.completed, isTrue);
  }

  Future<Set<String>> expenseIds() async => {
    for (final row in await localRows(
      db,
      'SELECT id FROM expense_entries WHERE owner_id = ?',
      [ownerId],
    ))
      row['id']! as String,
  };

  Future<EntryRecord> expense(String id) async =>
      (await repo.entry(EntryKind.expense, id))!;
}

void main() {
  final r = Random();

  test('apagado num aparelho some do outro parado por mais de um ano; a edição '
      'offline vira aviso e, ao descartar, sai do aparelho', () async {
    final account = await newTestAccount(r);
    final a = _Device(account.id, await account.device());
    final b = _Device(account.id, await account.device());
    addTearDown(a.db.close);
    addTearDown(b.db.close);

    // A cria duas despesas; B baixa as duas.
    Future<String> add(int cents) => a.entries.create(
      EntryDraft(
        kind: EntryKind.expense,
        amount: BigInt.from(cents),
        date: CalendarDate(2026, 11, 5),
      ),
    );
    final x = await add(1000);
    final y = await add(2000);
    await a.push();
    await b.pull();
    expect(await b.expenseIds(), {x, y});

    // A apaga as duas. B, sem rede, edita Y.
    await a.entries.cancel(await a.expense(x));
    await a.entries.cancel(await a.expense(y));
    await a.push();
    final yOnB = await b.expense(y);
    await b.entries.update(
      yOnB,
      EntryDraft(
        kind: EntryKind.expense,
        amount: BigInt.from(2500),
        date: yOnB.date,
        dueOn: yOnB.dueOn,
      ),
    );

    // Mais de 12 meses depois: o servidor limpa (só esta conta).
    final later = DateTime.now().toUtc().add(const Duration(days: 400));
    final admin = SupabaseClient(supabaseUrl, supabaseSecret);
    final purged = Map<String, dynamic>.from(
      await admin.rpc(
            'purge_expired_records',
            params: {'p_now': later.toIso8601String(), 'p_owner': account.id},
          )
          as Map,
    );
    expect(purged['expense_entries'], 2);

    // A limpa pela mesma regra, no mesmo "agora".
    final local = await LocalRetention(
      a.db,
      clock: () => later,
    ).purge(account.id);
    expect(local.entries, 2);
    expect(await a.expenseIds(), isEmpty);

    // B volta: a edição de Y é recusada com o motivo em português.
    await b.push();
    final ops = await b.sync.operations(account.id);
    expect(ops.single.state, OutboxState.rejected);
    final item = (await b.attention.items()).single;
    expect(item.kind, AttentionKind.rejected);
    expect(item.reason, contains('foi apagado'));

    // O download desde o início (parado há mais de 11 meses) tira X; Y fica
    // enquanto houver a alteração na fila.
    await b.pull(clock: () => later);
    expect(await b.expenseIds(), {y});

    // Descartar a alteração recusada: Y sai do aparelho no próximo download.
    await b.attention.discard(item);
    await b.pull(clock: () => later);
    expect(await b.expenseIds(), isEmpty);
    expect(await b.sync.operations(account.id), isEmpty);

    // Servidor sem nada desta conta nas despesas; repetir a limpeza não
    // apaga mais nada.
    final server = await (await account.device())
        .from('expense_entries')
        .select('id');
    expect(server, isEmpty);
    final again = Map<String, dynamic>.from(
      await admin.rpc(
            'purge_expired_records',
            params: {'p_now': later.toIso8601String(), 'p_owner': account.id},
          )
          as Map,
    );
    expect(again['expense_entries'], 0);
  }, skip: supabaseEnabled ? false : supabaseSkipReason);
}
