import 'dart:convert';

import '../../core/local_database/app_database.dart';
import 'sync_models.dart';

/// Gravação local única (`arquitetura.md` §16.1): registro, auditoria e fila
/// de envio entram na mesma transação. Se qualquer parte falhar, nada é
/// gravado; o app só informa "salvo" depois que [record] termina.
///
/// Convenção de versão: o chamador grava o registro com `version = anterior + 1`
/// e informa `expectedVersion = anterior`. Duas edições seguidas offline ficam
/// com versões esperadas consecutivas, iguais às que o servidor vai produzir.
/// Auditoria de outro registro tocado pela mesma operação (ex.: a configuração
/// de período criada junto com o primeiro período).
class ExtraAudit {
  const ExtraAudit({
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.newSnapshot,
  });

  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic>? newSnapshot;
}

class LocalChangeRecorder {
  LocalChangeRecorder(
    this._db, {
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? newUuid;

  final PorquinhoDatabase _db;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Executa [apply] (que grava o registro) e, na mesma transação, a auditoria
  /// e a operação de envio. Devolve a chave idempotente da operação.
  Future<String> record({
    required String ownerId,
    required String entityType,
    required String entityId,
    required String operation,
    required int expectedVersion,
    required String rpc,
    required Map<String, dynamic> params,
    required Future<void> Function() apply,
    List<String> dependsOn = const [],
    List<ExtraAudit> extraAudits = const [],
    Map<String, dynamic>? oldSnapshot,
    Map<String, dynamic>? newSnapshot,
  }) {
    final operationId = _newId();
    final now = _clock().toUtc().toIso8601String();
    return _db.transaction(() async {
      await apply();
      await _insertAudit(
        ownerId: ownerId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        operationId: operationId,
        now: now,
        oldSnapshot: oldSnapshot,
        newSnapshot: newSnapshot,
      );
      for (final extra in extraAudits) {
        await _insertAudit(
          ownerId: ownerId,
          entityType: extra.entityType,
          entityId: extra.entityId,
          operation: extra.operation,
          operationId: operationId,
          now: now,
          newSnapshot: extra.newSnapshot,
        );
      }
      final op = OutboxOperation(
        ownerId: ownerId,
        idempotencyKey: operationId,
        entityType: entityType,
        entityId: entityId,
        expectedVersion: expectedVersion,
        rpc: rpc,
        params: params,
        dependsOn: dependsOn,
      );
      await _db.customStatement(
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
      return operationId;
    });
  }

  Future<void> _insertAudit({
    required String ownerId,
    required String entityType,
    required String entityId,
    required String operation,
    required String operationId,
    required String now,
    Map<String, dynamic>? oldSnapshot,
    Map<String, dynamic>? newSnapshot,
  }) => _db.customStatement(
    'INSERT INTO audit_events (id, owner_id, version, created_at, '
    'updated_at, entity_type, entity_id, operation, actor_id, '
    'occurred_at, old_snapshot_json, new_snapshot_json, operation_id) '
    'VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      _newId(),
      ownerId,
      now,
      now,
      entityType,
      entityId,
      operation,
      ownerId,
      now,
      oldSnapshot == null ? null : jsonEncode(oldSnapshot),
      newSnapshot == null ? null : jsonEncode(newSnapshot),
      operationId,
    ],
  );
}
