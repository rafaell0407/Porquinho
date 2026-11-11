import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/infra_providers.dart';
import '../auth/auth_providers.dart';
import '../../core/domain/surplus.dart';
import '../categories/category_providers.dart';
import '../periods/period_models.dart';
import '../periods/period_navigation.dart';
import '../periods/period_providers.dart';
import 'reports_repository.dart';

final remoteReportSourceProvider = Provider<RemoteReportSource>(
  (ref) => SupabaseReportSource(ref.watch(supabaseClientProvider)),
);

/// Celular: banco local. Web: leitura agregada no servidor.
final reportsRepositoryProvider = FutureProvider<ReportsRepository>((
  ref,
) async {
  final mode = ref.watch(dataAccessModeProvider);
  if (mode == DataAccessMode.remoteOnly || kIsWeb) {
    return RemoteReportsRepository(ref.watch(remoteReportSourceProvider));
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  return LocalReportsRepository(db, ref.watch(ownerIdProvider));
});

/// Nomes de categorias (ativas e inativas; renomear vale em todos os períodos,
/// RN040).
final categoryNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final data = await ref.watch(categoryDataProvider.future);
  return {for (final c in data.categories) c.id: c.name};
});

/// Relatórios 1 a 3: dados do período selecionado; `null` se ele não existe.
final selectedPeriodReportProvider = FutureProvider<PeriodReport?>((ref) async {
  final view = await ref.watch(selectedPeriodProvider.future);
  final id = view?.record?.id;
  if (id == null) return null;
  final repo = await ref.watch(reportsRepositoryProvider.future);
  return repo.report([id]);
});

/// Quantos períodos entram nos relatórios 4 e 5 (D8).
const reportSeriesLength = 12;

/// Um período da sequência dos relatórios 4 e 5.
class SeriesItem {
  const SeriesItem(this.period, this.totals);
  final PeriodHistoryItem period;
  final PeriodTotals totals;
}

/// Relatórios 4 e 5: até 12 períodos que terminam no selecionado, do mais
/// antigo ao mais recente (D8). Cada período aparece com o intervalo real de
/// datas, sem ajuste proporcional.
final periodSeriesProvider = FutureProvider<List<SeriesItem>>((ref) async {
  final view = await ref.watch(selectedPeriodProvider.future);
  if (view == null || !view.exists) return const [];
  final service = await ref.watch(periodServiceProvider.future);
  final upToSelected = (await service.history())
      .where((p) => !p.range.start.isAfter(view.range.start))
      .take(reportSeriesLength)
      .toList()
      .reversed
      .toList();
  final repo = await ref.watch(reportsRepositoryProvider.future);
  final report = await repo.report([for (final p in upToSelected) p.id]);
  return [for (final p in upToSelected) SeriesItem(p, report.totalsOf(p.id))];
});
