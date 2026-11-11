import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../auth/auth_providers.dart';
import '../periods/period_navigation.dart';
import '../periods/period_providers.dart';
import 'investment_models.dart';
import 'investment_recurrence_repository.dart';
import 'investment_recurrence_service.dart';
import 'investment_repository.dart';
import 'investment_service.dart';
import 'local_investment_recurrence_repository.dart';
import 'local_investment_repository.dart';
import 'remote_investment_recurrence_repository.dart';
import 'remote_investment_repository.dart';

final investmentRepositoryProvider = FutureProvider<InvestmentRepository>((
  ref,
) async {
  final mode = ref.watch(dataAccessModeProvider);
  if (mode == DataAccessMode.remoteOnly || kIsWeb) {
    return RemoteInvestmentRepository(
      ref.watch(remoteTableReaderProvider),
      ref.watch(remoteGatewayProvider),
    );
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  final recorder = (await ref.watch(localRecorderProvider.future))!;
  return LocalInvestmentRepository(db, ref.watch(ownerIdProvider), recorder);
});

final investmentServiceProvider = FutureProvider<InvestmentService>((
  ref,
) async {
  return InvestmentService(
    await ref.watch(investmentRepositoryProvider.future),
    await ref.watch(periodServiceProvider.future),
  );
});

/// Investimentos do período exibido (vazio se o período ainda não existe).
final periodInvestmentsProvider = FutureProvider<List<InvestmentRecord>>((
  ref,
) async {
  final view = await ref.watch(selectedPeriodProvider.future);
  final periodId = view?.record?.id;
  if (periodId == null) return const [];
  final service = await ref.watch(investmentServiceProvider.future);
  return service.investmentsInPeriod(periodId);
});

final investmentRecurrenceRepositoryProvider =
    FutureProvider<InvestmentRecurrenceRepository>((ref) async {
      final mode = ref.watch(dataAccessModeProvider);
      if (mode == DataAccessMode.remoteOnly || kIsWeb) {
        return RemoteInvestmentRecurrenceRepository(
          ref.watch(remoteTableReaderProvider),
          ref.watch(remoteGatewayProvider),
        );
      }
      final db = (await ref.watch(localDatabaseProvider.future))!;
      final recorder = (await ref.watch(localRecorderProvider.future))!;
      return LocalInvestmentRecurrenceRepository(
        db,
        ref.watch(ownerIdProvider),
        recorder,
      );
    });

final investmentRecurrenceServiceProvider =
    FutureProvider<InvestmentRecurrenceService>((ref) async {
      return InvestmentRecurrenceService(
        await ref.watch(investmentRecurrenceRepositoryProvider.future),
      );
    });

/// Modelos de investimento recorrente (ativos primeiro) para Mais → Recorrências.
final investmentTemplatesProvider = FutureProvider<List<InvestmentTemplate>>((
  ref,
) async {
  final service = await ref.watch(investmentRecurrenceServiceProvider.future);
  return service.templates();
});
