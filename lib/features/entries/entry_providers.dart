import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/surplus.dart';
import '../auth/auth_providers.dart';
import '../categories/category_providers.dart';
import '../periods/period_navigation.dart';
import '../periods/period_providers.dart';
import '../totals/totals_repository.dart';
import 'entry_models.dart';
import 'entry_repository.dart';
import 'entry_service.dart';
import 'local_entry_repository.dart';
import 'remote_entry_repository.dart';

final entryRepositoryProvider = FutureProvider<EntryRepository>((ref) async {
  final mode = ref.watch(dataAccessModeProvider);
  if (mode == DataAccessMode.remoteOnly || kIsWeb) {
    return RemoteEntryRepository(
      ref.watch(remoteTableReaderProvider),
      ref.watch(remoteGatewayProvider),
    );
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  final recorder = (await ref.watch(localRecorderProvider.future))!;
  return LocalEntryRepository(db, ref.watch(ownerIdProvider), recorder);
});

final entryServiceProvider = FutureProvider<EntryService>((ref) async {
  return EntryService(
    await ref.watch(entryRepositoryProvider.future),
    await ref.watch(categoryRepositoryProvider.future),
    await ref.watch(periodServiceProvider.future),
  );
});

final totalsRepositoryProvider = FutureProvider<TotalsRepository>((ref) async {
  final mode = ref.watch(dataAccessModeProvider);
  if (mode == DataAccessMode.remoteOnly || kIsWeb) {
    return RemoteTotalsRepository(ref.watch(remoteTableReaderProvider));
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  return LocalTotalsRepository(db, ref.watch(ownerIdProvider));
});

/// Lançamentos do período exibido (vazio se o período ainda não existe).
final periodEntriesProvider = FutureProvider<List<EntryRecord>>((ref) async {
  final view = await ref.watch(selectedPeriodProvider.future);
  final periodId = view?.record?.id;
  if (periodId == null) return const [];
  final service = await ref.watch(entryServiceProvider.future);
  return service.entriesInPeriod(periodId);
});

/// Sobra e totais do período exibido, sempre derivados dos lançamentos.
final periodTotalsProvider = FutureProvider<PeriodTotals?>((ref) async {
  final view = await ref.watch(selectedPeriodProvider.future);
  final periodId = view?.record?.id;
  if (periodId == null) return null;
  final repo = await ref.watch(totalsRepositoryProvider.future);
  return repo.totalsFor(periodId);
});

/// Atualiza listas, totais e períodos depois de gravar.
void refreshFinanceData(WidgetRef ref) {
  ref.invalidate(selectedPeriodProvider);
  ref.invalidate(periodEntriesProvider);
  ref.invalidate(periodTotalsProvider);
}
