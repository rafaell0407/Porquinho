import 'package:go_router/go_router.dart';

import 'registry/report_registry.dart';
import 'screens/manage_reports_screen.dart';
import 'screens/report_catalog_screen.dart';
import 'screens/report_detail_screen.dart';
import 'screens/reports_home_screen.dart';

/// `/relatorios` e filhas: `catalogo`, `personalizar` e `:id` (tela
/// completa). Catálogo e Personalizar vêm antes de `:id`; ID inexistente volta
/// para a lista, sem erro.
GoRoute reportsRoute() => GoRoute(
  path: ReportsHomeScreen.route,
  builder: (_, _) => const ReportsHomeScreen(),
  routes: [
    GoRoute(path: 'catalogo', builder: (_, _) => const ReportCatalogScreen()),
    GoRoute(
      path: 'personalizar',
      builder: (_, _) => const ManageReportsScreen(),
    ),
    GoRoute(
      path: ':id',
      redirect: (_, state) =>
          norteReportRegistry.contains(state.pathParameters['id']!)
          ? null
          : ReportsHomeScreen.route,
      builder: (_, state) =>
          ReportDetailScreen(id: state.pathParameters['id']!),
    ),
  ],
);
