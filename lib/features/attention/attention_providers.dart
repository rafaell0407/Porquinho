import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/infra_providers.dart';
import '../auth/auth_providers.dart';
import '../periods/period_providers.dart';
import '../sync/download_service.dart';
import '../sync/supabase_sync_gateway.dart';
import '../sync/supabase_sync_reader.dart';
import '../sync/sync_providers.dart';
import '../sync/sync_service.dart';
import 'attention_models.dart';
import 'attention_repository.dart';
import 'local_attention_repository.dart';
import 'remote_attention_repository.dart';

final attentionRepositoryProvider = FutureProvider<AttentionRepository>((
  ref,
) async {
  final mode = ref.watch(dataAccessModeProvider);
  if (mode == DataAccessMode.remoteOnly || kIsWeb) {
    return RemoteAttentionRepository(
      ref.watch(remoteTableReaderProvider),
      ref.watch(remoteGatewayProvider),
    );
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  final client = ref.watch(supabaseClientProvider);
  return LocalAttentionRepository(
    db,
    ref.watch(ownerIdProvider),
    SyncService(db, SupabaseSyncGateway(client)),
    DownloadService(db, SupabaseSyncReader(client)),
  );
});

final attentionItemsProvider = FutureProvider<List<AttentionItem>>((ref) async {
  final repo = await ref.watch(attentionRepositoryProvider.future);
  final items = await repo.items();
  // O aviso no topo deve refletir a lista real (some assim que for resolvida).
  Future.microtask(() {
    if (!ref.mounted) return;
    ref.read(syncStatusProvider.notifier).setAttentionCount(items.length);
  });
  return items;
});
