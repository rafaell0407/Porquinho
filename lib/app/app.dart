import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/app_lock/app_lock_providers.dart';
import '../features/app_lock/lock_screen.dart';
import '../features/app_lock/security_screen.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/logout_flow.dart';
import '../features/auth/new_password_screen.dart';

/// Rotas: `/login` sem sessão; `/nova-senha` após o link de recuperação;
/// `/` com sessão. O Dashboard e a navegação
/// principal serão definidos na Fase 3; `/` é só um marcador.
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
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/nova-senha',
        builder: (_, _) => const NewPasswordScreen(),
      ),
      GoRoute(path: '/', builder: (_, _) => const HomePlaceholder()),
    ],
  );
});

class PorquinhoApp extends ConsumerWidget {
  const PorquinhoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Porquinho',
      theme: ThemeData(colorSchemeSeed: Colors.pink, useMaterial3: true),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Marcador até a Fase 3 (Dashboard). Só permite sair, para testar o login.
class HomePlaceholder extends ConsumerWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Porquinho')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Você está conectado.'),
            const SizedBox(height: 16),
            if (!kIsWeb) ...[
              OutlinedButton(
                onPressed: () => context.push('/seguranca'),
                child: const Text('Segurança'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: () => signOutWithPendingCheck(context, ref),
              child: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
