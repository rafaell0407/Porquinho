import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/period_calendar.dart';
import '../../../core/domain/surplus.dart';
import '../../../core/infra_providers.dart';
import '../../periods/period_providers.dart';
import '../../reports/reports_providers.dart';
import '../data/import_batch.dart';
import '../data/import_repository.dart';
import 'import_controller.dart';

final importRepositoryProvider = Provider<ImportRepository>(
  (ref) => RemoteImportRepository(
    SupabaseImportBackend(ref.watch(supabaseClientProvider)),
  ),
);

/// Histórico de importações (mais recentes primeiro).
final importBatchesProvider = FutureProvider.autoDispose<List<ImportBatch>>(
  (ref) => ref.watch(importRepositoryProvider).listBatches(),
);

/// Configuração de período atual (prévia por período).
final importPeriodConfigProvider = Provider<Future<PeriodConfig> Function()>(
  (ref) => () async {
    final repo = await ref.read(periodRepositoryProvider.future);
    return (await repo.settings())?.config ?? PeriodConfig.calendarMonth();
  },
);

/// Totais atuais dos períodos no servidor (dinheiro livre "antes").
final importPeriodTotalsProvider =
    Provider<
      Future<Map<PeriodRange, PeriodTotals>> Function(List<PeriodRange>)
    >(
      (ref) => (ranges) async {
        final repo = await ref.read(reportsRepositoryProvider.future);
        final report = await repo.report(ranges);
        return {for (final r in ranges) r: report.totalsOf(r)};
      },
    );

/// Cria o controlador do assistente com as dependências atuais.
ImportWizardController newImportController(WidgetRef ref) =>
    ImportWizardController(
      repository: ref.read(importRepositoryProvider),
      today: ref.read(todayProvider),
      periodConfig: ref.read(importPeriodConfigProvider),
      periodTotals: ref.read(importPeriodTotalsProvider),
    );
