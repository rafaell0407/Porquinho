@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

/// Servidor simulado: aceita só a versão esperada correta e devolve a nova.
class _Server implements SyncRemoteGateway {
  int version = 1;
  final received = <int>[];

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    final expected = params['p_expected_version'] as int;
    received.add(expected);
    if (expected != version) {
      return {
        'status': 'conflict',
        'conflict_id': 'cf-${received.length}',
        'remote_category': {'id': 'c1', 'version': version},
      };
    }
    version++;
    return {
      'status': 'applied',
      'category': {'id': 'c1', 'version': version},
    };
  }
}

void main() {
  late PorquinhoDatabase db;
  late LocalChangeRecorder recorder;
  late _Server server;
  late SyncService sync;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    recorder = LocalChangeRecorder(
      db,
      clock: () => DateTime.utc(2026, 11, 10),
      newId: () => 'id-${++ids}',
    );
    server = _Server();
    sync = SyncService(db, server, clock: () => DateTime.utc(2026, 11, 10));
    await db.customStatement(
      'INSERT INTO categories (id, owner_id, version, created_at, updated_at, '
      "kind, name, is_active) VALUES ('c1', 'u1', 1, 'x', 'x', 'expense', "
      "'Mercado', 1)",
    );
  });
  tearDown(() => db.close());

  Future<int> localVersion() async =>
      (await db
              .customSelect("SELECT version FROM categories WHERE id = 'c1'")
              .getSingle())
          .read<int>('version');

  Future<void> edit(String name) async {
    final before = await localVersion();
    await recorder.record(
      ownerId: 'u1',
      entityType: 'category',
      entityId: 'c1',
      operation: 'update',
      expectedVersion: before,
      rpc: 'apply_category_change',
      params: {'p_expected_version': before, 'p_name': name},
      oldSnapshot: {'version': before},
      newSnapshot: {'name': name, 'version': before + 1},
      apply: () => db.customStatement(
        'UPDATE categories SET name = ?, version = ? WHERE id = ?',
        [name, before + 1, 'c1'],
      ),
    );
  }

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  test('registro, auditoria e fila entram juntos', () async {
    await edit('Supermercado');

    expect(await count('audit_events'), 1);
    expect(await count('sync_outbox'), 1);
    final audit = await db
        .customSelect('SELECT * FROM audit_events')
        .getSingle();
    expect(audit.read<String>('operation'), 'update');
    expect(audit.read<String>('operation_id'), 'id-1');
    expect(await localVersion(), 2);
  });

  test('falha no meio não grava nada', () async {
    await expectLater(
      recorder.record(
        ownerId: 'u1',
        entityType: 'category',
        entityId: 'c1',
        operation: 'update',
        expectedVersion: 1,
        rpc: 'apply_category_change',
        params: const {},
        apply: () async {
          await db.customStatement(
            "UPDATE categories SET name = 'X', version = 2 WHERE id = 'c1'",
          );
          throw StateError('falha simulada');
        },
      ),
      throwsStateError,
    );

    expect(await count('audit_events'), 0);
    expect(await count('sync_outbox'), 0);
    expect(await localVersion(), 1);
  });

  test('falha ao gravar a fila desfaz o registro e a auditoria', () async {
    // Chave de fila repetida: a segunda gravação viola a chave primária.
    final dup = LocalChangeRecorder(db, newId: () => 'mesmo-id');
    await dup.record(
      ownerId: 'u1',
      entityType: 'category',
      entityId: 'c1',
      operation: 'update',
      expectedVersion: 1,
      rpc: 'apply_category_change',
      params: const {},
      apply: () async {},
    );
    await expectLater(
      dup.record(
        ownerId: 'u1',
        entityType: 'category',
        entityId: 'c1',
        operation: 'update',
        expectedVersion: 1,
        rpc: 'apply_category_change',
        params: const {},
        apply: () => db.customStatement(
          "UPDATE categories SET name = 'Y' WHERE id = 'c1'",
        ),
      ),
      throwsA(anything),
    );

    expect(await count('audit_events'), 1);
    expect(await count('sync_outbox'), 1);
    final name = await db
        .customSelect("SELECT name FROM categories WHERE id = 'c1'")
        .getSingle();
    expect(name.read<String>('name'), 'Mercado');
  });

  test('versão local acompanha o servidor após o envio', () async {
    await edit('A');
    expect(await sync.syncOnce('u1'), 1);

    expect(server.version, 2);
    expect(await localVersion(), 2);
    expect(await count('sync_outbox'), 0);
  });

  test(
    'duas edições seguidas (com envio entre elas) sem conflito falso',
    () async {
      await edit('A');
      await sync.syncOnce('u1');
      await edit('B');
      await sync.syncOnce('u1');

      expect(server.received, [1, 2]);
      expect(server.version, 3);
      expect(await localVersion(), 3);
      expect(await count('sync_conflicts'), 0);
    },
  );

  test('duas edições offline seguem em ordem e sem conflito', () async {
    await edit('A');
    await edit('B');
    expect(await sync.syncOnce('u1'), 2);

    expect(server.received, [1, 2]);
    expect(await localVersion(), 3);
    expect(await count('sync_conflicts'), 0);
  });

  test('versão local mais nova nunca recua', () async {
    await edit('A');
    await edit('B'); // local = 3, fila com duas operações
    // Envia só a primeira: o servidor responde versão 2.
    final service = SyncService(
      db,
      _OnlyFirst(server),
      clock: () => DateTime.utc(2026, 11, 10),
    );
    await service.syncOnce('u1');
    expect(await localVersion(), 3);
  });
}

class _OnlyFirst implements SyncRemoteGateway {
  _OnlyFirst(this._inner);
  final _Server _inner;
  var _calls = 0;

  @override
  Future<Map<String, dynamic>> call(String rpc, Map<String, dynamic> params) {
    if (++_calls > 1) throw const SyncTransientError('sem rede');
    return _inner.call(rpc, params);
  }
}
