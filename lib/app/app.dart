import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/app_lock/app_lock_providers.dart';
import '../features/app_lock/lock_screen.dart';
import '../features/app_lock/security_screen.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/new_password_screen.dart';
import '../features/attention/attention_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/more/more_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/periods/period_gate.dart';
import '../features/preferences/preferences_providers.dart';
import '../features/preferences/theme_screen.dart';
import '../features/periods/period_settings_screen.dart';
import '../features/export/export_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/recurrence/recurrences_screen.dart';
import 'theme/norte_theme.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/sync/sync_indicator.dart';
import '../shared/main_shell.dart';

/// Rotas: `/login` sem sessão; `/nova-senha` após o link de recuperação;
/// com sessão, as três abas `/` (Dashboard), `/lancamentos` e `/mais`.
final routerProvider = Provider<GoRouter>((ref) {
  final controller = ref.watch(sessionControllerProvider);
  final refresh = ValueNotifier<int>(0);
  final sub = controller.states.listen((_) => refresh.value++);
  final lock = ref.watch(appLockControllerProvider);
  final lockSub = lock.changes.listen((_) => refresh.value++);
  ref.onDispose(() {
    sub.cancel();
    lockSub.cancel();
    refresh.dispose();
  });

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final current = controller.state;
      final at = state.matchedLocation;
      // Segurança (PIN/biometria) só existe no celular.
      if (kIsWeb && at == '/seguranca') return '/mais';
      if (current is SessionPasswordRecovery) {
        return at == '/nova-senha' ? null : '/nova-senha';
      }
      if (current is! SessionSignedIn) return at == '/login' ? null : '/login';
      if (lock.locked) return at == '/bloqueio' ? null : '/bloqueio';
      return (at == '/login' || at == '/nova-senha' || at == '/bloqueio')
          ? '/'
          : null;
    },
    routes: [
      GoRoute(path: '/bloqueio', builder: (_, _) => const LockScreen()),
      GoRoute(path: '/seguranca', builder: (_, _) => const SecurityScreen()),
      GoRoute(path: '/categorias', builder: (_, _) => const CategoriesScreen()),
      GoRoute(path: '/atencao', builder: (_, _) => const AttentionScreen()),
      GoRoute(
        path: '/periodo',
        builder: (_, _) => const PeriodSettingsScreen(),
      ),
      GoRoute(path: '/relatorios', builder: (_, _) => const ReportsScreen()),
      GoRoute(
        path: '/configuracao-inicial',
        builder: (context, _) => OnboardingScreen(onExit: () => context.pop()),
      ),
      GoRoute(path: '/tema', builder: (_, _) => const ThemeScreen()),
      GoRoute(path: '/exportar', builder: (_, _) => const ExportScreen()),
      GoRoute(
        path: '/recorrencias',
        builder: (_, _) => const RecurrencesScreen(),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/nova-senha',
        builder: (_, _) => const NewPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => PeriodGate(
          child: MainShell(
            navigationShell: shell,
            banner: const SyncIndicator(),
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lancamentos',
                builder: (_, _) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/mais', builder: (_, _) => const MoreScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

class PorquinhoApp extends ConsumerWidget {
  const PorquinhoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Norte',
      theme: NorteTheme.light(),
      darkTheme: NorteTheme.dark(),
      themeMode: ref.watch(themeModeProvider).value ?? ThemeMode.system,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
