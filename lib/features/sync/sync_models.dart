import 'dart:convert';
import 'dart:math';

/// Estados da fila local (`arquitetura.md` §16.1.1). Operação aplicada é removida.
abstract final class OutboxState {
  static const pending = 'pending';
  static const sending = 'sending';
  static const failed = 'failed';
  static const conflict = 'conflict';
  static const rejected = 'rejected';
}

abstract final class ConflictState {
  static const open = 'open';
  static const resolved = 'resolved';
}

/// Escolhas do usuário ao resolver um conflito.
enum ConflictResolution {
  keepLocal('keep_local'),
  keepRemote('keep_remote'),
  edit('edit');

  const ConflictResolution(this.wireName);
  final String wireName;
}

/// Operação gravada na fila. `rpc` e `params` descrevem a chamada ao servidor;
/// a chave idempotente e a versão esperada ficam nas colunas da fila.
class OutboxOperation {
  const OutboxOperation({
    required this.ownerId,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.expectedVersion,
    required this.rpc,
    required this.params,
    this.dependsOn = const [],
    this.state = OutboxState.pending,
    this.attempts = 0,
    this.nextRetryAt,
    this.lastError,
  });

  final String ownerId;
  final String idempotencyKey;
  final String entityType;
  final String entityId;
  final int expectedVersion;
  final String rpc;

  /// Parâmetros da RPC, exceto `p_operation_id` (= [idempotencyKey]).
  final Map<String, dynamic> params;

  /// Ids de registros de que esta operação depende (categoria, subcategoria,
  /// período). Enquanto a operação de criação de algum deles continuar na fila,
  /// esta espera, sem ser recusada (Entrega 35).
  final List<String> dependsOn;
  final String state;
  final int attempts;
  final DateTime? nextRetryAt;
  final String? lastError;

  String get payloadJson => jsonEncode({
    'rpc': rpc,
    'params': params,
    if (dependsOn.isNotEmpty) 'depends_on': dependsOn,
  });

  /// Operação que cria o registro (as demais apenas o alteram).
  bool get isCreate =>
      rpc == 'create_accounting_period' ||
      rpc == 'create_earlier_accounting_period' ||
      params['p_action'] == 'create';

  static OutboxOperation fromRow(Map<String, Object?> row) {
    final payload = jsonDecode(row['payload_json']! as String) as Map;
    final retry = row['next_retry_at'] as String?;
    return OutboxOperation(
      ownerId: row['owner_id']! as String,
      idempotencyKey: row['idempotency_key']! as String,
      entityType: row['entity_type']! as String,
      entityId: row['entity_id']! as String,
      expectedVersion: row['expected_version']! as int,
      rpc: payload['rpc']! as String,
      params: Map<String, dynamic>.from(payload['params']! as Map),
      dependsOn: [...?(payload['depends_on'] as List?)?.cast<String>()],
      state: row['state']! as String,
      attempts: row['attempts']! as int,
      nextRetryAt: retry == null ? null : DateTime.parse(retry),
      lastError: row['last_error'] as String?,
    );
  }
}

/// Conflito guardado localmente (versão do aparelho e do servidor preservadas).
class LocalConflict {
  const LocalConflict({
    required this.id,
    required this.ownerId,
    required this.entityType,
    required this.entityId,
    required this.expectedVersion,
    required this.remoteVersion,
    required this.localSnapshot,
    required this.remoteSnapshot,
    required this.state,
    this.resolution,
  });

  final String id;
  final String ownerId;
  final String entityType;
  final String entityId;
  final int expectedVersion;
  final int remoteVersion;
  final Map<String, dynamic> localSnapshot;
  final Map<String, dynamic> remoteSnapshot;
  final String state;

  /// Intenção de resolução (`operation_id`, `resolution`, `request`) gravada
  /// antes do envio, para que um reenvio use a mesma chave idempotente.
  final Map<String, dynamic>? resolution;

  static LocalConflict fromRow(Map<String, Object?> row) {
    final resolution = row['resolution_json'] as String?;
    return LocalConflict(
      id: row['id']! as String,
      ownerId: row['owner_id']! as String,
      entityType: row['entity_type']! as String,
      entityId: row['entity_id']! as String,
      expectedVersion: row['expected_version']! as int,
      remoteVersion: row['remote_version']! as int,
      localSnapshot: Map<String, dynamic>.from(
        jsonDecode(row['local_snapshot_json']! as String) as Map,
      ),
      remoteSnapshot: Map<String, dynamic>.from(
        jsonDecode(row['remote_snapshot_json']! as String) as Map,
      ),
      state: row['state']! as String,
      resolution: resolution == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(resolution) as Map),
    );
  }
}

/// Falha transitória (rede, servidor, sessão): a operação será reenviada.
class SyncTransientError implements Exception {
  const SyncTransientError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Recusa definitiva do servidor (regra de domínio ou validação).
class SyncRejectedError implements Exception {
  const SyncRejectedError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fronteira com o servidor; a implementação real usa as RPCs do Supabase.
abstract interface class SyncRemoteGateway {
  /// Chama [rpc] com [params] e devolve o JSON de resposta. Deve lançar
  /// [SyncTransientError] ou [SyncRejectedError].
  Future<Map<String, dynamic>> call(String rpc, Map<String, dynamic> params);
}

/// Espera antes da próxima tentativa: 30 s dobrando a cada falha, até 1 h.
Duration retryDelay(int attempts) {
  final seconds = 30 * pow(2, max(0, attempts - 1)).toInt();
  return Duration(seconds: min(seconds, 3600));
}

final _random = Random.secure();

/// UUID v4 para chaves idempotentes de resolução.
String newUuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
