@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/auth/drift_pending_sync_counter.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

class FakeGateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];
  final handlers =
      <String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)>{};

  @override
  Future<Map<String, dynamic>> call(String rpc, Map<String, dynamic> params) {
    calls.add((rpc, params));
    return handlers[rpc]!(params);
  }
}

OutboxOperation op(String key, String entity, {int version = 1}) =>
    OutboxOperation(
      ownerId: 'u1',
      idempotencyKey: key,
      entityType: 'category',
      entityId: entity,
      expectedVersion: version,
      rpc: 'apply_category_change',
      params: {
        'p_action': 'rename',
        'p_category_id': entity,
        'p_expected_version': version,
        'p_kind': null,
        'p_name': 'Nome $key',
      },
    );

void main() {
  late PorquinhoDatabase db;
  late FakeGateway gateway;
  late DateTime now;
  late SyncService service;

  setUp(() {
    db = PorquinhoDatabase(NativeDatabase.memory());
    gateway = FakeGateway();
    now = DateTime.utc(2026, 11, 10, 12);
    service = SyncService(db, gateway, clock: () => now);
  });
  tearDown(() => db.close());

  Future<Map<String, dynamic>> applied(Map<String, dynamic> _) async => {
    'status': 'applied',
  };

  test('aplicada sai da fila e a chave idempotente vai ao servidor', () async {
    await service.enqueue(op('k1', 'c1'));
    gateway.handlers['apply_category_change'] = applied;

    expect(await service.syncOnce('u1'), 1);
    expect(await service.operations('u1'), isEmpty);
    expect(gateway.calls.single.$2['p_operation_id'], 'k1');
    expect(await DriftPendingSyncCounter(db).countPending('u1'), 0);
  });

  test('falha transitória: failed com espera crescente e para o envio', () async {
    await service.enqueue(op('k1', 'c1'));
    await service.enqueue(op('k2', 'c2'));
    gateway.handlers['apply_category_change'] = (_) async =>
        throw const SyncTransientError('sem rede');

    expect(await service.syncOnce('u1'), 0);
    expect(gateway.calls.length, 1);
    var ops = await service.operations('u1');
    expect(ops[0].state, OutboxState.failed);
    expect(ops[0].attempts, 1);
    expect(ops[0].nextRetryAt, now.add(const Duration(seconds: 30)));
    expect(ops[1].state, OutboxState.pending);

    // Antes do prazo, a operação falha não é reenviada e bloqueia o mesmo registro.
    await service.enqueue(op('k3', 'c1', version: 2));
    gateway.handlers['apply_category_change'] = applied;
    expect(await service.syncOnce('u1'), 1); // só k2 (c2)
    expect((await service.operations('u1')).map((o) => o.idempotencyKey), [
      'k1',
      'k3',
    ]);

    now = now.add(const Duration(seconds: 31));
    expect(await service.syncOnce('u1'), 2);
    expect(await service.operations('u1'), isEmpty);
  });

  test(
    'envio interrompido volta a pending e reenvia com a mesma chave',
    () async {
      await service.enqueue(op('k1', 'c1'));
      await db.customStatement("UPDATE sync_outbox SET state = 'sending'");
      gateway.handlers['apply_category_change'] = applied;

      expect(await service.syncOnce('u1'), 1);
      expect(gateway.calls.single.$2['p_operation_id'], 'k1');
    },
  );

  test(
    'conflito é guardado, bloqueia só o registro e preserva as versões',
    () async {
      await service.enqueue(op('k1', 'c1'));
      await service.enqueue(op('k2', 'c1', version: 2));
      await service.enqueue(op('k3', 'c2'));
      gateway.handlers['apply_category_change'] = (p) async =>
          p['p_category_id'] == 'c1'
          ? {
              'status': 'conflict',
              'conflict_id': 'cf1',
              'remote_category': {'id': 'c1', 'version': 5, 'name': 'Remoto'},
            }
          : applied(p);

      expect(await service.syncOnce('u1'), 1);
      final ops = await service.operations('u1');
      expect(ops.map((o) => (o.idempotencyKey, o.state)), [
        ('k1', OutboxState.conflict),
        ('k2', OutboxState.pending),
      ]);
      final conflicts = await service.openConflicts('u1');
      expect(conflicts.single.id, 'cf1');
      expect(conflicts.single.remoteVersion, 5);
      expect(conflicts.single.localSnapshot['p_name'], 'Nome k1');
      expect(conflicts.single.remoteSnapshot['name'], 'Remoto');

      // Reexecutar não duplica o conflito nem envia o que está bloqueado.
      gateway.calls.clear();
      await service.syncOnce('u1');
      expect(gateway.calls, isEmpty);
      expect(await DriftPendingSyncCounter(db).countPending('u1'), 3);
    },
  );

  test('recusa definitiva fica rejected até decisão do usuário', () async {
    await service.enqueue(op('k1', 'c1'));
    gateway.handlers['apply_category_change'] = (_) async =>
        throw const SyncRejectedError('categoria inativa');
    await service.syncOnce('u1');

    var ops = await service.operations('u1');
    expect(ops.single.state, OutboxState.rejected);
    expect(ops.single.lastError, 'categoria inativa');

    await service.discardRejected('u1', 'k1');
    expect(await service.operations('u1'), isEmpty);
  });

  group('resolução', () {
    Future<void> makeConflict() async {
      await service.enqueue(op('k1', 'c1'));
      gateway.handlers['apply_category_change'] = (_) async => {
        'status': 'conflict',
        'conflict_id': 'cf1',
        'remote_category': {'version': 5},
      };
      await service.syncOnce('u1');
    }

    test(
      'sem rede reaproveita a chave; ao concluir fecha conflito e fila',
      () async {
        await makeConflict();
        gateway.handlers['resolve_sync_conflict'] = (_) async =>
            throw const SyncTransientError('sem rede');
        await expectLater(
          service.resolveConflict('u1', 'cf1', ConflictResolution.keepLocal),
          throwsA(isA<SyncTransientError>()),
        );

        gateway.handlers['resolve_sync_conflict'] = (_) async => {
          'status': 'resolved',
        };
        await service.resolveConflict(
          'u1',
          'cf1',
          ConflictResolution.keepLocal,
        );

        final keys = gateway.calls
            .where((c) => c.$1 == 'resolve_sync_conflict')
            .map((c) => c.$2['p_operation_id'])
            .toList();
        expect(keys.length, 2);
        expect(keys[0], keys[1]);
        expect(await service.openConflicts('u1'), isEmpty);
        expect(await service.operations('u1'), isEmpty);
        expect(await DriftPendingSyncCounter(db).countPending('u1'), 0);
      },
    );

    test('edit exige versão editada; as demais não aceitam', () async {
      await makeConflict();
      expect(
        () => service.resolveConflict('u1', 'cf1', ConflictResolution.edit),
        throwsArgumentError,
      );
      expect(
        () => service.resolveConflict(
          'u1',
          'cf1',
          ConflictResolution.keepRemote,
          editedRequest: {'a': 1},
        ),
        throwsArgumentError,
      );
    });

    test('resolução recusada mantém o conflito aberto', () async {
      await makeConflict();
      gateway.handlers['resolve_sync_conflict'] = (_) async =>
          throw const SyncRejectedError('não reaplicável');
      await expectLater(
        service.resolveConflict('u1', 'cf1', ConflictResolution.keepLocal),
        throwsA(isA<SyncRejectedError>()),
      );
      expect((await service.openConflicts('u1')).single.resolution, isNull);
      expect(
        (await service.operations('u1')).single.state,
        OutboxState.conflict,
      );
    });
  });

  group('dependências entre operações (Entrega 35)', () {
    OutboxOperation create(String key, String entity) => OutboxOperation(
      ownerId: 'u1',
      idempotencyKey: key,
      entityType: 'category',
      entityId: entity,
      expectedVersion: 0,
      rpc: 'apply_category_change',
      params: {'p_action': 'create', 'p_category_id': entity},
    );

    OutboxOperation entry(String key, String entity, List<String> deps) =>
        OutboxOperation(
          ownerId: 'u1',
          idempotencyKey: key,
          entityType: 'income_entry',
          entityId: entity,
          expectedVersion: 0,
          rpc: 'apply_income_entry_change',
          params: {'p_action': 'create', 'p_entry_id': entity},
          dependsOn: deps,
        );

    test('dependente segue depois da criação, na mesma passada', () async {
      await service.enqueue(create('k1', 'cat1'));
      await service.enqueue(entry('k2', 'e1', ['cat1']));
      gateway.handlers['apply_category_change'] = applied;
      gateway.handlers['apply_income_entry_change'] = applied;
      expect(await service.syncOnce('u1'), 2);
      expect(gateway.calls.map((c) => c.$1).toList(), [
        'apply_category_change',
        'apply_income_entry_change',
      ]);
    });

    test('categoria em conflito segura o lançamento sem recusa', () async {
      await service.enqueue(create('k1', 'cat1'));
      await service.enqueue(entry('k2', 'e1', ['cat1']));
      await service.enqueue(entry('k3', 'e2', []));
      gateway.handlers['apply_category_change'] = (_) async => {
        'status': 'conflict',
        'conflict_id': 'cf1',
        'remote_category': {'version': 1},
      };
      gateway.handlers['apply_income_entry_change'] = applied;
      expect(await service.syncOnce('u1'), 1);
      // Só o lançamento sem dependência foi enviado.
      expect(
        gateway.calls.where((c) => c.$1 == 'apply_income_entry_change').length,
        1,
      );
      final ops = await service.operations('u1');
      expect(ops.map((o) => o.idempotencyKey), ['k1', 'k2']);
      expect(ops.last.state, OutboxState.pending);
    });

    test('categoria com falha de rede mantém o lançamento esperando', () async {
      await service.enqueue(create('k1', 'cat1'));
      await service.enqueue(entry('k2', 'e1', ['cat1']));
      gateway.handlers['apply_category_change'] = (_) async =>
          throw const SyncTransientError('sem rede');
      expect(await service.syncOnce('u1'), 0);
      expect(gateway.calls.length, 1);
      expect((await service.operations('u1')).last.state, OutboxState.pending);
    });

    test('criação já aplicada antes não segura o dependente', () async {
      await service.enqueue(entry('k2', 'e1', ['cat1']));
      gateway.handlers['apply_income_entry_change'] = applied;
      expect(await service.syncOnce('u1'), 1);
    });

    test('dependência sobrevive à gravação e à leitura da fila', () async {
      await service.enqueue(entry('k2', 'e1', ['cat1', 'per1']));
      final stored = (await service.operations('u1')).single;
      expect(stored.dependsOn, ['cat1', 'per1']);
      expect(stored.params.containsKey('depends_on'), isFalse);
    });
  });

  test('atraso de reenvio dobra e tem teto de 1 hora', () {
    expect(retryDelay(1), const Duration(seconds: 30));
    expect(retryDelay(2), const Duration(seconds: 60));
    expect(retryDelay(3), const Duration(seconds: 120));
    expect(retryDelay(20), const Duration(hours: 1));
  });

  test('classificação de erros do servidor', () {
    expect(SupabaseSyncGateway.isDefinitiveRejection('22023'), isTrue);
    expect(SupabaseSyncGateway.isDefinitiveRejection('23505'), isTrue);
    expect(SupabaseSyncGateway.isDefinitiveRejection('P0002'), isTrue);
    expect(SupabaseSyncGateway.isDefinitiveRejection('40001'), isFalse);
    expect(SupabaseSyncGateway.isDefinitiveRejection('28000'), isFalse);
    expect(SupabaseSyncGateway.isDefinitiveRejection(null), isFalse);
  });
}
