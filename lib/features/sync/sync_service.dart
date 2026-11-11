import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/local_database/app_database.dart';
import 'sync_models.dart';

/// Fila de envio e conflitos locais (`arquitetura.md` §16.1 e §16.1.1).
///
/// Operações do mesmo registro seguem em ordem; operações independentes
/// continuam mesmo quando outro registro está em conflito. Nada é sobrescrito
/// ou descartado em silêncio.
class SyncService {
  SyncService(this._db, this._gateway, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final PorquinhoDatabase _db;
  final SyncRemoteGateway _gateway;
  final DateTime Function() _clock;

  String _now() => _clock().toUtc().toIso8601String();

  /// Grava a operação na fila. Chame dentro da mesma transação que grava o
  /// registro e a auditoria, para que nunca existam um sem o outro.
  Future<void> enqueue(OutboxOperation op) => _db.customStatement(
    'INSERT INTO sync_outbox (owner_id, idempotency_key, entity_type, '
    'entity_id, expected_version, payload_json, state, attempts) '
    "VALUES (?, ?, ?, ?, ?, ?, 'pending', 0)",
    [
      op.ownerId,
      op.idempotencyKey,
      op.entityType,
      op.entityId,
      op.expectedVersion,
      op.payloadJson,
    ],
  );

  Future<List<OutboxOperation>> operations(String ownerId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM sync_outbox WHERE owner_id = ? ORDER BY rowid',
          variables: [Variable.withString(ownerId)],
        )
        .get();
    return rows.map((r) => OutboxOperation.fromRow(r.data)).toList();
  }

  Future<List<LocalConflict>> openConflicts(String ownerId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM sync_conflicts WHERE owner_id = ? AND state = ? '
          'ORDER BY created_at',
          variables: [
            Variable.withString(ownerId),
            Variable.withString(ConflictState.open),
          ],
        )
        .get();
    return rows.map((r) => LocalConflict.fromRow(r.data)).toList();
  }

  /// Envio interrompido (app fechado no meio) volta para `pending`; o reenvio
  /// é seguro pela chave idempotente.
  Future<void> recoverInterrupted(String ownerId) => _db.customStatement(
    "UPDATE sync_outbox SET state = 'pending' "
    "WHERE owner_id = ? AND state = 'sending'",
    [ownerId],
  );

  /// Envia o que estiver pronto. Para na primeira falha transitória (sem rede
  /// não adianta gastar tentativas das demais). Devolve quantas foram aplicadas.
  Future<int> syncOnce(String ownerId) async {
    await recoverInterrupted(ownerId);
    final now = _clock();
    final blocked = <String>{};
    var applied = 0;
    for (final op in await operations(ownerId)) {
      final entity = '${op.entityType}/${op.entityId}';
      if (op.state == OutboxState.conflict ||
          op.state == OutboxState.rejected) {
        blocked.add(entity);
        continue;
      }
      if (blocked.contains(entity)) continue;
      if (op.state == OutboxState.failed &&
          op.nextRetryAt != null &&
          op.nextRetryAt!.isAfter(now)) {
        blocked.add(entity);
        continue;
      }
      switch (await _send(op)) {
        case _Outcome.applied:
          applied++;
        case _Outcome.blocked:
          blocked.add(entity);
        case _Outcome.offline:
          return applied;
      }
    }
    return applied;
  }

  Future<_Outcome> _send(OutboxOperation op) async {
    await _setState(op, OutboxState.sending);
    try {
      final response = await _gateway.call(op.rpc, {
        'p_operation_id': op.idempotencyKey,
        ...op.params,
      });
      switch (response['status']) {
        case 'applied':
          await _remove(op);
          return _Outcome.applied;
        case 'conflict':
          await _storeConflict(op, response);
          return _Outcome.blocked;
        default:
          throw const SyncRejectedError('Resposta desconhecida do servidor.');
      }
    } on SyncTransientError catch (e) {
      await _fail(op, e.message);
      return _Outcome.offline;
    } on SyncRejectedError catch (e) {
      await _setState(op, OutboxState.rejected, error: e.message);
      return _Outcome.blocked;
    }
  }

  Future<void> _setState(
    OutboxOperation op,
    String state, {
    String? error,
  }) => _db.customStatement(
    'UPDATE sync_outbox SET state = ?, last_error = ?, next_retry_at = NULL '
    'WHERE owner_id = ? AND idempotency_key = ?',
    [state, error, op.ownerId, op.idempotencyKey],
  );

  Future<void> _fail(OutboxOperation op, String error) {
    final attempts = op.attempts + 1;
    final next = _clock().add(retryDelay(attempts)).toUtc().toIso8601String();
    return _db.customStatement(
      "UPDATE sync_outbox SET state = 'failed', attempts = ?, "
      'next_retry_at = ?, last_error = ? '
      'WHERE owner_id = ? AND idempotency_key = ?',
      [attempts, next, error, op.ownerId, op.idempotencyKey],
    );
  }

  Future<void> _remove(OutboxOperation op) => _db.customStatement(
    'DELETE FROM sync_outbox WHERE owner_id = ? AND idempotency_key = ?',
    [op.ownerId, op.idempotencyKey],
  );

  Future<void> _storeConflict(
    OutboxOperation op,
    Map<String, dynamic> response,
  ) async {
    final remoteKey = response.keys.firstWhere(
      (k) => k.startsWith('remote_'),
      orElse: () => '',
    );
    final remote = remoteKey.isEmpty
        ? <String, dynamic>{}
        : response[remoteKey];
    final now = _now();
    await _db.transaction(() async {
      await _db.customStatement(
        'INSERT OR IGNORE INTO sync_conflicts (id, owner_id, version, '
        'created_at, updated_at, entity_type, entity_id, expected_version, '
        'remote_version, local_snapshot_json, remote_snapshot_json, state) '
        'VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          response['conflict_id'],
          op.ownerId,
          now,
          now,
          op.entityType,
          op.entityId,
          op.expectedVersion,
          (remote as Map)['version'] ?? 0,
          jsonEncode(op.params),
          jsonEncode(remote),
          ConflictState.open,
        ],
      );
      await _setState(op, OutboxState.conflict);
    });
  }

  /// Resolve um conflito aberto. A intenção (com a chave idempotente) é gravada
  /// antes do envio; se faltar rede, chamar de novo reutiliza a mesma chave.
  /// Operações posteriores do mesmo registro não são reescritas: se ficarem
  /// defasadas, geram novo conflito para você decidir.
  Future<void> resolveConflict(
    String ownerId,
    String conflictId,
    ConflictResolution resolution, {
    Map<String, dynamic>? editedRequest,
  }) async {
    if ((resolution == ConflictResolution.edit) != (editedRequest != null)) {
      throw ArgumentError('Somente "edit" envia uma versão editada.');
    }
    final row = await _db
        .customSelect(
          'SELECT * FROM sync_conflicts WHERE owner_id = ? AND id = ?',
          variables: [
            Variable.withString(ownerId),
            Variable.withString(conflictId),
          ],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Conflito não encontrado.');
    final conflict = LocalConflict.fromRow(row.data);
    if (conflict.state != ConflictState.open) {
      throw StateError('Conflito já resolvido.');
    }

    var intent = conflict.resolution;
    if (intent == null ||
        intent['resolution'] != resolution.wireName ||
        jsonEncode(intent['request']) != jsonEncode(editedRequest)) {
      intent = {
        'operation_id': newUuid(),
        'resolution': resolution.wireName,
        'request': editedRequest,
      };
      await _db.customStatement(
        'UPDATE sync_conflicts SET resolution_json = ?, updated_at = ? '
        'WHERE owner_id = ? AND id = ?',
        [jsonEncode(intent), _now(), ownerId, conflictId],
      );
    }

    final Map<String, dynamic> response;
    try {
      response = await _gateway.call('resolve_sync_conflict', {
        'p_operation_id': intent['operation_id'],
        'p_conflict_id': conflictId,
        'p_resolution': resolution.wireName,
        'p_request': editedRequest,
      });
    } on SyncRejectedError {
      // Resolução recusada: descarta a intenção para permitir outra escolha.
      await _db.customStatement(
        'UPDATE sync_conflicts SET resolution_json = NULL '
        'WHERE owner_id = ? AND id = ?',
        [ownerId, conflictId],
      );
      rethrow;
    }
    if (response['status'] != 'resolved') {
      throw const SyncRejectedError('Resposta desconhecida do servidor.');
    }

    await _db.transaction(() async {
      await _db.customStatement(
        "UPDATE sync_conflicts SET state = 'resolved', resolution_json = ?, "
        'version = version + 1, updated_at = ? WHERE owner_id = ? AND id = ?',
        [
          jsonEncode({...intent!, 'response': response}),
          _now(),
          ownerId,
          conflictId,
        ],
      );
      await _db.customStatement(
        "DELETE FROM sync_outbox WHERE owner_id = ? AND state = 'conflict' "
        'AND entity_type = ? AND entity_id = ? AND expected_version = ?',
        [
          ownerId,
          conflict.entityType,
          conflict.entityId,
          conflict.expectedVersion,
        ],
      );
    });
  }

  /// Descarta uma operação recusada pelo servidor, por decisão do usuário.
  Future<void> discardRejected(String ownerId, String idempotencyKey) =>
      _db.customStatement(
        "DELETE FROM sync_outbox WHERE owner_id = ? AND idempotency_key = ? "
        "AND state = 'rejected'",
        [ownerId, idempotencyKey],
      );
}

enum _Outcome { applied, blocked, offline }
