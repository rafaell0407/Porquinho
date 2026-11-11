import '../sync/remote_table_reader.dart';
import '../sync/sync_models.dart';
import 'attention_models.dart';
import 'attention_repository.dart';

/// Web: conflitos abertos no servidor (decisão D11). Resolve direto pela RPC.
class RemoteAttentionRepository implements AttentionRepository {
  RemoteAttentionRepository(
    this._reader,
    this._gateway, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final RemoteTableReader _reader;
  final SyncRemoteGateway _gateway;
  final String Function() _newId;

  /// Quantos conflitos abertos existem (para o aviso no topo).
  Future<int> openCount() async => (await items()).length;

  @override
  Future<List<AttentionItem>> items() async {
    final rows = await _reader.select(
      'sync_conflicts',
      filters: [const RemoteFilter.eq('status', 'open')],
      orderBy: 'created_at',
    );
    return [
      for (final r in rows)
        AttentionItem(
          kind: AttentionKind.conflict,
          id: r['id'] as String,
          entityType: r['entity_type'] as String,
          entityId: r['entity_id'] as String,
          request: normalizeRequest(asJsonMap(r['local_snapshot'])),
          remote: asJsonMap(r['remote_snapshot']),
        ),
    ];
  }

  @override
  Future<void> resolve(
    AttentionItem item,
    ConflictResolution resolution, {
    Map<String, dynamic>? editedRequest,
  }) async {
    final response = await _gateway.call('resolve_sync_conflict', {
      'p_operation_id': _newId(),
      'p_conflict_id': item.id,
      'p_resolution': resolution.wireName,
      'p_request': editedRequest,
    });
    if (response['status'] != 'resolved') {
      throw const SyncRejectedError('Não foi possível resolver o conflito.');
    }
  }

  @override
  Future<void> discard(AttentionItem item) async {}

  @override
  Future<void> retry(AttentionItem item) async {}
}
