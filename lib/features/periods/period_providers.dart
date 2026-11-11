import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../../core/domain/user_clock.dart';
import '../../core/infra_providers.dart';
import '../../core/local_database/app_database.dart';
import '../auth/auth_providers.dart';
import '../categories/category_providers.dart';
import '../sync/local_change_recorder.dart';
import '../sync/remote_table_reader.dart';
import '../sync/supabase_sync_gateway.dart';
import '../sync/sync_models.dart';
import '../sync/sync_providers.dart';
import 'local_period_repository.dart';
import 'period_repository.dart';
import 'period_service.dart';
import 'remote_period_repository.dart';

/// Relógio do usuário (zona `America/Sao_Paulo`); testes sobrescrevem.
final userClockProvider = Provider<UserClock>((ref) => const UserClock());

/// Banco local aberto; `null` na Web.
final localDatabaseProvider = FutureProvider<PorquinhoDatabase?>((ref) async {
  final manager = ref.watch(localDatabaseManagerProvider);
  return manager?.open();
});

final remoteTableReaderProvider = Provider<RemoteTableReader>(
  (ref) => SupabaseTableReader(ref.watch(supabaseClientProvider)),
);

final remoteGatewayProvider = Provider<SyncRemoteGateway>(
  (ref) => SupabaseSyncGateway(ref.watch(supabaseClientProvider)),
);

/// Gravador local (registro + auditoria + fila). Só existe no celular.
final localRecorderProvider = FutureProvider<LocalChangeRecorder?>((ref) async {
  final db = await ref.watch(localDatabaseProvider.future);
  return db == null ? null : LocalChangeRecorder(db);
});

/// Rodada de sincronização completa sob demanda, só com conexão (celular).
final refreshFromServerProvider = Provider<Future<void> Function()?>((ref) {
  final fullSync = ref.watch(fullSyncProvider);
  if (fullSync == null) return null;
  final probe = ref.watch(connectivityProbeProvider);
  final owner = ref.watch(ownerIdProvider);
  return () async {
    if (await probe.isOnline()) await fullSync(owner);
  };
});

final periodRepositoryProvider = FutureProvider<PeriodRepository>((ref) async {
  final mode = ref.watch(dataAccessModeProvider);
  if (mode == DataAccessMode.remoteOnly || kIsWeb) {
    return RemotePeriodRepository(
      ref.watch(remoteTableReaderProvider),
      ref.watch(remoteGatewayProvider),
    );
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  final recorder = (await ref.watch(localRecorderProvider.future))!;
  return LocalPeriodRepository(
    db,
    ref.watch(ownerIdProvider),
    recorder,
    refresh: ref.watch(refreshFromServerProvider),
  );
});

final periodServiceProvider = FutureProvider<PeriodService>(
  (ref) async =>
      PeriodService(await ref.watch(periodRepositoryProvider.future)),
);

/// Primeiro acesso e períodos até hoje, ao abrir o app (Entrega 34A).
/// `true` = falta escolher a configuração de período.
class PeriodGateNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final service = await ref.watch(periodServiceProvider.future);
    if (await service.needsSetup()) return true;
    await service.ensureUpTo(ref.read(userClockProvider).today());
    return false;
  }

  Future<void> setup(PeriodConfig config) async {
    final service = await ref.read(periodServiceProvider.future);
    await service.setup(config, ref.read(userClockProvider).today());
    // Primeiro acesso: depois do período, oferece as categorias sugeridas.
    ref.read(pendingSuggestionsProvider.notifier).show();
    state = const AsyncData(false);
  }
}

final periodGateProvider = AsyncNotifierProvider<PeriodGateNotifier, bool>(
  PeriodGateNotifier.new,
);

/// Hoje, na zona do usuário.
final todayProvider = Provider<CalendarDate>(
  (ref) => ref.watch(userClockProvider).today(),
);
