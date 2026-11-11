import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../core/local_database/app_database.dart';

enum SyncPhase {
  /// Ainda sem nenhuma rodada nesta abertura do app.
  idle,
  syncing,

  /// Nada pendente de envio e nada esperando decisão.
  synced,

  /// Sem conexão com o servidor ou envio com falha transitória: os dados estão
  /// salvos no aparelho e serão enviados quando a conexão voltar.
  offline,
}

/// Estado mostrado ao usuário.
class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.attentionCount = 0,
    this.lastSyncAt,
  });

  final SyncPhase phase;

  /// Operações ainda por enviar (pendentes, em envio ou com falha transitória).
  final int pendingCount;

  /// Itens que exigem decisão: conflitos abertos e operações recusadas.
  final int attentionCount;
  final DateTime? lastSyncAt;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? attentionCount,
    DateTime? lastSyncAt,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    pendingCount: pendingCount ?? this.pendingCount,
    attentionCount: attentionCount ?? this.attentionCount,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );
}

/// Contagens lidas da fila local.
class SyncCounts {
  const SyncCounts({
    required this.pending,
    required this.failed,
    required this.attention,
  });

  final int pending;

  /// Parte de [pending] com falha transitória (indício de falta de conexão).
  final int failed;
  final int attention;

  static Future<SyncCounts> read(PorquinhoDatabase db, String ownerId) async {
    final row = await db
        .customSelect(
          'SELECT '
          "(SELECT COUNT(*) FROM sync_outbox WHERE owner_id = ?1 "
          "AND state IN ('pending','sending','failed')) AS pending, "
          "(SELECT COUNT(*) FROM sync_outbox WHERE owner_id = ?1 "
          "AND state = 'failed') AS failed, "
          "(SELECT COUNT(*) FROM sync_conflicts WHERE owner_id = ?1 "
          "AND state = 'open') "
          "+ (SELECT COUNT(*) FROM sync_outbox WHERE owner_id = ?1 "
          "AND state = 'rejected') AS attention",
          variables: [Variable.withString(ownerId)],
        )
        .getSingle();
    return SyncCounts(
      pending: row.read<int>('pending'),
      failed: row.read<int>('failed'),
      attention: row.read<int>('attention'),
    );
  }
}

/// Verifica se o servidor está alcançável.
abstract interface class ConnectivityProbe {
  Future<bool> isOnline();
}

/// Qualquer resposta HTTP do servidor conta como "online". Usa `package:http`,
/// que funciona no celular e no navegador (mesmo código nas duas plataformas).
class HttpConnectivityProbe implements ConnectivityProbe {
  HttpConnectivityProbe(
    this._baseUrl, {
    this.apiKey = '',
    this.timeout = const Duration(seconds: 5),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String _baseUrl;
  final String apiKey;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<bool> isOnline() async {
    try {
      await _client
          .get(
            Uri.parse('$_baseUrl/auth/v1/health'),
            headers: {if (apiKey.isNotEmpty) 'apikey': apiKey},
          )
          .timeout(timeout);
      return true;
    } on Object {
      return false;
    }
  }
}
