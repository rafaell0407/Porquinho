import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_access.dart';
import '../../../core/infra_providers.dart';
import '../../auth/auth_providers.dart';
import '../../periods/period_providers.dart';
import '../../sync/sync_models.dart';
import '../../sync/sync_providers.dart';
import '../data/card_bills_repository.dart';
import '../data/local_card_bills_repository.dart';
import '../data/remote_card_bills_repository.dart';
import 'card_bills_service.dart';

/// Repositório pelo modo de acesso: banco local no celular, servidor na Web.
final cardBillsRepositoryProvider = FutureProvider<CardBillsRepository>((
  ref,
) async {
  if (ref.watch(dataAccessModeProvider) == DataAccessMode.remoteOnly) {
    return supabaseCardBillsRepository(ref.watch(supabaseClientProvider));
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  return LocalCardBillsRepository(db, ref.watch(ownerIdProvider));
});

final cardBillsServiceProvider = FutureProvider<CardBillsService>(
  (ref) async => CardBillsService(
    await ref.watch(cardBillsRepositoryProvider.future),
    clock: ref.watch(userClockProvider),
  ),
);

/// Estado da tela: lê ao abrir (gerando as cobranças devidas) e de novo
/// depois de cada sincronização e de cada ação.
class CardBillsController extends AsyncNotifier<CardBillsSnapshot> {
  @override
  Future<CardBillsSnapshot> build() async {
    ref.watch(syncStatusProvider.select((s) => s.lastSyncAt));
    final service = await ref.watch(cardBillsServiceProvider.future);
    if (ref.read(dataAccessModeProvider) == DataAccessMode.remoteOnly &&
        await ref.read(writeGateProvider).blockedReason() != null) {
      // Web sem conexão: só lê (a leitura também falha sem conexão).
      return service.snapshot();
    }
    return service.open();
  }

  /// Executa uma ação e recarrega. Devolve a mensagem de erro, ou `null`.
  Future<String?> run(Future<void> Function(CardBillsService s) action) async {
    final blocked = await ref.read(writeGateProvider).blockedReason();
    if (blocked != null) return blocked;
    try {
      final service = await ref.read(cardBillsServiceProvider.future);
      await action(service);
      state = AsyncData(await service.snapshot());
      return null;
    } on ArgumentError catch (e) {
      return '${e.message}';
    } on DuplicatePaymentException {
      rethrow;
    } on SyncRejectedError catch (e) {
      return 'O servidor recusou: ${e.message}';
    } on SyncTransientError {
      return WriteGate.offlineMessage;
    }
  }

  Future<void> reload() async {
    final service = await ref.read(cardBillsServiceProvider.future);
    state = AsyncData(await service.snapshot());
  }
}

final cardBillsControllerProvider =
    AsyncNotifierProvider<CardBillsController, CardBillsSnapshot>(
      CardBillsController.new,
    );
