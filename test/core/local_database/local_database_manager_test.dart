@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/local_database_manager.dart';
import 'package:porquinho/core/local_database/stored_database_key_provider.dart';
import 'package:porquinho/features/auth/drift_pending_sync_counter.dart';

void main() {
  test('abre cifrado, conta pendências e apaga tudo no logout', () async {
    final dir = await Directory.systemTemp.createTemp('porquinho_mgr');
    addTearDown(() => dir.delete(recursive: true));
    final store = InMemorySecureValueStore();
    final manager = LocalDatabaseManager(
      store: store,
      path: '${dir.path}/porquinho.db',
    );
    final counter = ManagedPendingSyncCounter(manager);

    expect(await counter.countPending('u1'), 0);
    final db = await manager.open();
    await db.customStatement(
      'INSERT INTO sync_outbox (owner_id, idempotency_key, entity_type, '
      "entity_id, expected_version, payload_json, state) "
      "VALUES ('u1', 'k1', 'income', 'e', 1, '{}', 'queued')",
    );
    expect(await counter.countPending('u1'), 1);
    expect(await store.read('porquinho.database_key'), isNotNull);
    // O arquivo não pode conter texto puro.
    final bytes = await File('${dir.path}/porquinho.db').readAsBytes();
    expect(String.fromCharCodes(bytes).contains('sync_outbox'), isFalse);

    await manager.closeAndWipe();

    expect(dir.listSync(), isEmpty);
    expect(await store.read('porquinho.database_key'), isNull);
    // Depois do logout, um novo acesso começa do zero.
    expect(await counter.countPending('u1'), 0);
    await manager.closeAndWipe();
  });
}
