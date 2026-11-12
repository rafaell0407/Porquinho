import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/user_clock.dart';
import '../../core/infra_providers.dart';
import '../alerts/alert_providers.dart';
import '../recurrence/local_recurrence_repository.dart';
import 'download_service.dart';
import 'remote_table_reader.dart';
import 'supabase_sync_gateway.dart';
import 'supabase_sync_reader.dart';
import 'sync_models.dart';
import 'sync_service.dart';
import 'sync_status.dart';

/// Envia a fila local do usuário uma vez. `null` quando não há banco local
/// (Web), onde não há nada a sincronizar.
final syncNowProvider = Provider<Future<void> Function(String ownerId)?>((ref) {
  final manager = ref.watch(localDatabaseManagerProvider);
  if (manager == null) return null;
  final gateway = SupabaseSyncGateway(ref.watch(supabaseClientProvider));
  return (ownerId) async {
    await SyncService(await manager.open(), gateway).syncOnce(ownerId);
  };
});

/// Uma rodada completa: envia a fila e depois baixa o que mudou no servidor
/// (Entrega 27B). Devolve `false` se o download parou no meio (Entrega 69).
/// `null` quando não há banco local (Web).
final fullSyncProvider = Provider<Future<bool> Function(String ownerId)?>((
  ref,
) {
  final manager = ref.watch(localDatabaseManagerProvider);
  if (manager == null) return null;
  final client = ref.watch(supabaseClientProvider);
  final gateway = SupabaseSyncGateway(client);
  final reader = SupabaseSyncReader(client);
  return (ownerId) async {
    final db = await manager.open();
    await SyncService(db, gateway).syncOnce(ownerId);
    // Gera no servidor o que estiver devido antes de baixar (RN038): o
    // identificador é o mesmo da geração local, então nada se duplica.
    try {
      await gateway.call(generateRpc, {'p_operation_id': newUuid()});
    } on SyncRejectedError {
      // Sem período para alguma data: aparece pela própria ocorrência faltante.
    }
    final download = await DownloadService(db, reader).downloadAll(ownerId);
    // Modelos e períodos baixados podem ter novas ocorrências devidas.
    await LocalRecurrenceRepository(
      db,
      ownerId,
      null,
    ).generateDue(const UserClock().today());
    return download.completed;
  };
});

/// Endereço do Supabase (mesmo `--dart-define` usado em `main.dart`).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

final connectivityProbeProvider = Provider<ConnectivityProbe>(
  (ref) => HttpConnectivityProbe(_supabaseUrl, apiKey: _supabaseKey),
);

/// Lê as contagens da fila local. `null` quando não há banco local (Web).
final syncCountsProvider = Provider<Future<SyncCounts> Function(String)?>((
  ref,
) {
  final manager = ref.watch(localDatabaseManagerProvider);
  if (manager == null) return null;
  return (ownerId) async => SyncCounts.read(await manager.open(), ownerId);
});

/// Quantos conflitos abertos existem no servidor (usado na Web).
final remoteAttentionCountProvider = Provider<Future<int> Function()>((ref) {
  return () async {
    final rows = await SupabaseTableReader(ref.read(supabaseClientProvider))
        .select(
          'sync_conflicts',
          filters: [const RemoteFilter.eq('status', 'open')],
        );
    return rows.length;
  };
});

/// Estado de conexão/sincronização para a interface (Entrega 28).
final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  /// Uma rodada: confere a conexão, envia a fila e atualiza as contagens.
  Future<void> run(String ownerId) async {
    final syncNow = ref.read(fullSyncProvider);
    final readCounts = ref.read(syncCountsProvider);
    state = state.copyWith(phase: SyncPhase.syncing);

    final online = await ref.read(connectivityProbeProvider).isOnline();
    if (!ref.mounted) return;
    if (syncNow == null || readCounts == null) {
      // Web: nada local para enviar; acompanha a conexão e os conflitos
      // abertos no servidor (Entrega 22, decisão D11).
      var attention = 0;
      if (online) {
        try {
          attention = await ref.read(remoteAttentionCountProvider)();
        } on Object {
          attention = 0;
        }
      }
      if (!ref.mounted) return;
      state = SyncStatus(
        phase: online ? SyncPhase.synced : SyncPhase.offline,
        attentionCount: attention,
        lastSyncAt: online ? DateTime.now() : state.lastSyncAt,
      );
      return;
    }
    // Download interrompido ou com erro não conta como sincronizado (L1).
    var complete = online;
    if (online) {
      try {
        complete = await syncNow(ownerId);
        await ref.read(alertsRefreshProvider)();
      } on Object {
        // O que não subiu continua na fila e aparece nas contagens.
        complete = false;
      }
    }
    if (!ref.mounted) return;

    final counts = await readCounts(ownerId);
    if (!ref.mounted) return;
    final offline = !complete || counts.failed > 0;
    state = SyncStatus(
      phase: offline ? SyncPhase.offline : SyncPhase.synced,
      pendingCount: counts.pending,
      attentionCount: counts.attention,
      lastSyncAt: offline ? state.lastSyncAt : DateTime.now(),
    );
  }
}

/// `true` enquanto o aviso de banco local recuperado (D9) não foi dispensado.
final recoveryNoticeProvider = Provider<bool>((ref) {
  ref.watch(syncStatusProvider); // reavalia a cada rodada de sincronização
  return ref.watch(localDatabaseManagerProvider)?.needsRecoveryNotice ?? false;
});
