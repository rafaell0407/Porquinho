import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/infra_providers.dart';
import '../alerts/alert_providers.dart';
import '../app_lock/app_lock_providers.dart';
import '../sync/sync_providers.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'drift_pending_sync_counter.dart';
import 'local_owner_binder.dart';
import 'session_controller.dart';
import 'supabase_auth_repository.dart';

/// Adaptador do Supabase Auth (nos testes, sobrescrito com falsos).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(
    ref.watch(supabaseClientProvider).auth,
    redirectTo: kIsWeb ? null : _mobileRedirect,
  ),
);

/// Retorno do login por navegador no celular (deep link do Android).
const _mobileRedirect = 'br.com.norte.app://login-callback';

/// Conta pendências de sincronização. Na Web não há banco local.
final pendingSyncCounterProvider = Provider<PendingSyncCounter>((ref) {
  final manager = ref.watch(localDatabaseManagerProvider);
  return manager == null
      ? const _NoLocalData()
      : ManagedPendingSyncCounter(manager);
});

class _NoLocalData implements PendingSyncCounter {
  const _NoLocalData();

  @override
  Future<int> countPending(String ownerId) async => 0;
}

/// Controlador da sessão. Quem o cria deve chamar `start()` antes de exibir o
/// app (ver `main.dart`); nos testes é sobrescrito.
final sessionControllerProvider = Provider<SessionController>((ref) {
  final manager = ref.watch(localDatabaseManagerProvider);
  final lock = ref.watch(appLockControllerProvider);
  final controller = SessionController(
    ref.watch(authRepositoryProvider),
    ref.watch(pendingSyncCounterProvider),
    flushPending: ref.watch(syncNowProvider),
    binder: manager == null ? null : ManagedLocalOwnerBinder(manager),
    // Logout só chega aqui sem pendências: apaga banco, chave e PIN locais.
    onSignedOut: manager == null
        ? null
        : (_) async {
            // Os alertas agendados pertencem ao usuário que saiu.
            await ref.read(alertSchedulerProvider).cancelAll();
            await manager.closeAndWipe();
            await lock.clear();
          },
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Estado da sessão para a interface e para o roteamento.
final sessionStateProvider = StreamProvider<SessionState>((ref) async* {
  final controller = ref.watch(sessionControllerProvider);
  yield controller.state;
  yield* controller.states;
});

/// Texto em português para cada falha de autenticação.
String authFailureMessage(AuthFailureCode code) => switch (code) {
  AuthFailureCode.invalidCredentials => 'E-mail ou senha incorretos.',
  AuthFailureCode.emailNotConfirmed =>
    'Confirme seu e-mail antes de entrar. Verifique sua caixa de entrada.',
  AuthFailureCode.emailAlreadyRegistered =>
    'Este e-mail já está cadastrado. Tente entrar ou recuperar a senha.',
  AuthFailureCode.weakPassword =>
    'Senha fraca. Escolha uma senha mais longa e difícil de adivinhar.',
  AuthFailureCode.network =>
    'Não foi possível conectar. Verifique sua internet e tente de novo.',
  AuthFailureCode.cancelled => 'Login cancelado.',
  AuthFailureCode.unknown => 'Algo deu errado. Tente novamente.',
};

/// `owner_id` do usuário logado; toda gravação local e remota deve usá-lo.
/// Lança [StateError] se não houver sessão.
final ownerIdProvider = Provider<String>((ref) {
  final state = ref.watch(sessionStateProvider).value;
  return switch (state) {
    SessionSignedIn(:final user) => user.id,
    SessionPasswordRecovery(:final user) => user.id,
    _ => throw StateError('Nenhum usuário autenticado.'),
  };
});
