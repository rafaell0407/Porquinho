@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

import '../support/supabase_local_support.dart';

/// Entrega 69: reenvio seguro e download interrompido, contra o Supabase LOCAL.
/// Mesmos `--dart-define` de `supabase_local_sync_test.dart`.
class _FlakyReader implements SyncRemoteReader {
  _FlakyReader(this._inner);
  final SyncRemoteReader _inner;

  /// Quantas páginas ainda serão entregues antes da "queda".
  int pagesBeforeFailure = 1 << 30;

  @override
  Future<Map<String, dynamic>?> fetchPreferences(String ownerId) =>
      _inner.fetchPreferences(ownerId);

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    required String ownerId,
    required String orderColumn,
    String? afterOrder,
    String? afterId,
    required int limit,
  }) {
    if (pagesBeforeFailure-- <= 0) {
      throw const SyncTransientError('queda de rede (simulada)');
    }
    return _inner.fetchPage(
      table,
      ownerId: ownerId,
      orderColumn: orderColumn,
      afterOrder: afterOrder,
      afterId: afterId,
      limit: limit,
    );
  }
}

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;

  group('Entrega 69 — reenvio seguro', () {
    test('resposta perdida: reenvio com a mesma chave não duplica', () async {
      final account = await newTestAccount(r);
      final client = await account.device();
      final db = memoryDb();
      addTearDown(db.close);
      final id = testUuid(r);
      final key = await localCreateCategory(db, account.id, id, 'Mercado');

      final gateway = FlakyGateway(SupabaseSyncGateway(client))
        ..loseNextResponses = 1;
      var now = DateTime.now();
      final sync = SyncService(db, gateway, clock: () => now);

      await sync.syncOnce(account.id);
      final ops = await sync.operations(account.id);
      expect(ops.single.state, OutboxState.failed);
      // O servidor já aplicou, mas o aparelho ainda não sabe.
      expect(
        await client.from('categories').select().eq('id', id),
        hasLength(1),
      );

      now = now.add(const Duration(minutes: 5));
      await sync.syncOnce(account.id);
      expect(await sync.operations(account.id), isEmpty);
      expect(await sync.openConflicts(account.id), isEmpty);

      expect(gateway.calls.map((c) => c.operationId).toSet(), {key});
      expect(
        await client.from('categories').select().eq('id', id),
        hasLength(1),
      );
      final audit = await client
          .from('audit_events')
          .select()
          .eq('entity_id', id);
      expect(audit, hasLength(1));
      final local = await localRows(
        db,
        'SELECT version FROM categories WHERE id = ?',
        [id],
      );
      expect(local.single['version'], 1);
    }, skip: skip);

    test(
      'app fechado em "sending": volta para pendente e envia uma vez',
      () async {
        final account = await newTestAccount(r);
        final client = await account.device();
        final db = memoryDb();
        addTearDown(db.close);
        final id = testUuid(r);
        final key = await localCreateCategory(db, account.id, id, 'Aluguel');
        await db.customStatement(
          "UPDATE sync_outbox SET state = 'sending' WHERE idempotency_key = ?",
          [key],
        );

        final sync = SyncService(db, SupabaseSyncGateway(client));
        expect(await sync.syncOnce(account.id), 1);
        expect(await sync.operations(account.id), isEmpty);
        expect(
          await client.from('categories').select().eq('id', id),
          hasLength(1),
        );

        // Repetir a mesma operação (cópia da fila) não altera nada.
        final again = await SupabaseSyncGateway(client)
            .call('apply_category_change', {
              'p_operation_id': key,
              'p_action': 'create',
              'p_category_id': id,
              'p_expected_version': 0,
              'p_kind': 'expense',
              'p_name': 'Aluguel',
            });
        expect(again['status'], 'applied');
        expect(
          await client.from('categories').select().eq('id', id),
          hasLength(1),
        );
      },
      skip: skip,
    );

    test(
      'queda no download: não perde nada e termina na rodada seguinte',
      () async {
        final account = await newTestAccount(r);
        final client = await account.device();
        final ids = [for (var i = 0; i < 3; i++) testUuid(r)];
        for (var i = 0; i < ids.length; i++) {
          await remoteCreateCategory(client, r, ids[i], 'Cat $i');
        }

        final db = memoryDb();
        addTearDown(db.close);
        final reader = _FlakyReader(SupabaseSyncReader(client))
          ..pagesBeforeFailure = 2;
        final service = DownloadService(db, reader, pageSize: 2);

        final first = await service.downloadAll(account.id);
        expect(first.completed, isFalse);

        reader.pagesBeforeFailure = 1 << 30;
        final second = await service.downloadAll(account.id);
        expect(second.completed, isTrue);
        final cats = await localRows(db, 'SELECT id FROM categories');
        expect(cats.map((c) => c['id']).toSet(), ids.toSet());

        final third = await service.downloadAll(account.id);
        expect(third.applied, 0);
        expect(await localRows(db, 'SELECT id FROM categories'), hasLength(3));
      },
      skip: skip,
    );
  });
}
