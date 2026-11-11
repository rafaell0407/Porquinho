import '../../core/local_database/app_database.dart';
import '../sync/download_service.dart';
import '../sync/sync_models.dart';
import '../sync/sync_service.dart';
import 'attention_models.dart';
import 'attention_repository.dart';

/// Celular: lê a fila e os conflitos do banco local; resolve pelo servidor e
/// ajusta o registro local à decisão. Nada é descartado em silêncio.
class LocalAttentionRepository implements AttentionRepository {
  LocalAttentionRepository(this._db, this._ownerId, this._sync, this._download);

  final PorquinhoDatabase _db;
  final String _ownerId;
  final SyncService _sync;
  final DownloadService _download;

  @override
  Future<List<AttentionItem>> items() async {
    final conflicts = await _sync.openConflicts(_ownerId);
    final ops = await _sync.operations(_ownerId);
    return [
      for (final c in conflicts)
        AttentionItem(
          kind: AttentionKind.conflict,
          id: c.id,
          entityType: c.entityType,
          entityId: c.entityId,
          request: normalizeRequest(c.localSnapshot),
          remote: c.remoteSnapshot,
        ),
      for (final o in ops.where((o) => o.state == OutboxState.rejected))
        AttentionItem(
          kind: AttentionKind.rejected,
          id: o.idempotencyKey,
          entityType: o.entityType,
          entityId: o.entityId,
          request: normalizeRequest(o.params),
          reason: o.lastError,
        ),
    ];
  }

  @override
  Future<void> resolve(
    AttentionItem item,
    ConflictResolution resolution, {
    Map<String, dynamic>? editedRequest,
  }) async {
    final response = await _sync.resolveConflict(
      _ownerId,
      item.id,
      resolution,
      editedRequest: editedRequest,
    );
    final record = _resolvedRecord(response, item.entityId);
    if (record != null) {
      await _download.adoptResolvedRecord(
        _ownerId,
        item.entityType,
        item.entityId,
        record,
      );
    }
  }

  /// Registro resultante da resolução: `record` (manter servidor) ou o
  /// registro devolvido pela RPC da entidade (manter aparelho / editar).
  Map<String, dynamic>? _resolvedRecord(
    Map<String, dynamic> response,
    String entityId,
  ) {
    final record = response['record'];
    if (record is Map) return Map<String, dynamic>.from(record);
    final result = response['result'];
    if (result is Map) {
      for (final value in result.values) {
        if (value is Map && value['version'] is int && value['id'] != null) {
          return Map<String, dynamic>.from(value);
        }
      }
    }
    return null;
  }

  @override
  Future<void> discard(AttentionItem item) =>
      _sync.discardAndRevert(_ownerId, item.id);

  @override
  Future<void> retry(AttentionItem item) => _db.customStatement(
    "UPDATE sync_outbox SET state = 'pending', attempts = 0, "
    'next_retry_at = NULL, last_error = NULL '
    "WHERE owner_id = ? AND idempotency_key = ? AND state = 'rejected'",
    [_ownerId, item.id],
  );
}
