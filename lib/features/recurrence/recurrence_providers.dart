import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../alerts/alert_providers.dart';
import '../auth/auth_providers.dart';
import '../categories/category_providers.dart';
import '../entries/entry_providers.dart';
import '../periods/period_navigation.dart';
import '../periods/period_providers.dart';
import 'local_recurrence_repository.dart';
import 'recurrence_models.dart';
import 'recurrence_repository.dart';
import 'recurrence_service.dart';
import 'remote_recurrence_repository.dart';

final recurrenceRepositoryProvider = FutureProvider<RecurrenceRepository>((
  ref,
) async {
  final mode = ref.watch(dataAccessModeProvider);
  if (mode == DataAccessMode.remoteOnly || kIsWeb) {
    return RemoteRecurrenceRepository(
      ref.watch(remoteTableReaderProvider),
      ref.watch(remoteGatewayProvider),
    );
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  final recorder = (await ref.watch(localRecorderProvider.future))!;
  return LocalRecurrenceRepository(db, ref.watch(ownerIdProvider), recorder);
});

final recurrenceServiceProvider = FutureProvider<RecurrenceService>((
  ref,
) async {
  return RecurrenceService(
    await ref.watch(recurrenceRepositoryProvider.future),
    await ref.watch(categoryRepositoryProvider.future),
  );
});

/// Modelos recorrentes (ativos primeiro) para Mais → Recorrências.
final recurringTemplatesProvider = FutureProvider<List<RecurringTemplate>>((
  ref,
) async {
  final service = await ref.watch(recurrenceServiceProvider.future);
  return service.templates();
});

/// Gera as ocorrências devidas ao abrir o app, depois de garantir os períodos
/// (RN038). Falhas não impedem o uso do app; a geração roda de novo na próxima
/// abertura e na sincronização.
final recurrenceGenerationProvider = FutureProvider<int>((ref) async {
  try {
    final needsSetup = await ref.watch(periodGateProvider.future);
    if (needsSetup) return 0;
    final service = await ref.watch(recurrenceServiceProvider.future);
    final created = await service.generateDue(
      ref.read(userClockProvider).today(),
    );
    if (created > 0) {
      ref.invalidate(selectedPeriodProvider);
      ref.invalidate(periodEntriesProvider);
      ref.invalidate(periodTotalsProvider);
      ref.invalidate(recurringTemplatesProvider);
    }
    await ref.read(alertsRefreshProvider)();
    return created;
  } on Object {
    return 0;
  }
});
