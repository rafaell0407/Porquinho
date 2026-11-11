import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/local_database/flutter_secure_value_store.dart';
import 'core/local_database/local_database_manager.dart';
import 'core/local_database/stored_database_key_provider.dart';
import 'features/app_lock/app_lock_controller.dart';
import 'features/app_lock/app_lock_providers.dart';
import 'features/app_lock/app_lock_service.dart';
import 'features/app_lock/biometric_authenticator.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/drift_pending_sync_counter.dart';
import 'features/auth/secure_session_storage.dart';
import 'features/auth/session_controller.dart';
import 'features/auth/supabase_auth_repository.dart';
import 'features/sync/supabase_sync_gateway.dart';
import 'features/sync/sync_scheduler.dart';
import 'features/sync/sync_service.dart';

/// Configuração por `--dart-define` (nada de segredo no repositório):
/// `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Retorno do login por navegador no celular (deep link do Android).
const _mobileRedirect = 'br.com.porquinho.porquinho://login-callback';

/// Web: ainda não há banco local (a chave depende da reautenticação, opção B)
/// nem dados financeiros gravados, então não há operações pendentes.
class _NoLocalDataYet implements PendingSyncCounter {
  @override
  Future<int> countPending(String ownerId) async => 0;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  // Web: sem persistência da sessão, o que exige novo login a cada sessão do
  // navegador (decisão de 10/11/2026, opção B; `arquitetura.md` §17.5).
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: kIsWeb
          ? const EmptyLocalStorage()
          : SecureSessionStorage(FlutterSecureValueStore()),
    ),
  );

  final auth = SupabaseAuthRepository(
    Supabase.instance.client.auth,
    redirectTo: kIsWeb ? null : _mobileRedirect,
  );
  // Bloqueio por PIN/biometria: só no aplicativo móvel (RF003).
  final lock = kIsWeb
      ? AppLockController(
          AppLockService(InMemorySecureValueStore()),
          const NoBiometric(),
        )
      : AppLockController(
          AppLockService(FlutterSecureValueStore()),
          LocalAuthBiometric(),
        );
  final SessionController session;
  Future<void> Function(String ownerId)? syncNow;
  if (kIsWeb) {
    session = SessionController(auth, _NoLocalDataYet());
  } else {
    final support = await getApplicationSupportDirectory();
    final manager = LocalDatabaseManager(
      store: FlutterSecureValueStore(),
      path: '${support.path}/porquinho.db',
    );
    final gateway = SupabaseSyncGateway(Supabase.instance.client);
    syncNow = (ownerId) async => SyncService(
      await manager.open(),
      gateway,
    ).syncOnce(ownerId).then((_) {});
    session = SessionController(
      auth,
      ManagedPendingSyncCounter(manager),
      flushPending: syncNow,
      // Logout só chega aqui sem pendências: apaga banco, chave e PIN locais.
      onSignedOut: (_) async {
        await manager.closeAndWipe();
        await lock.clear();
      },
    );
  }
  await session.start();
  await lock.start(signedIn: session.state is SessionSignedIn);
  if (syncNow != null) {
    final scheduler = SyncScheduler(session, syncNow)..start();
    WidgetsBinding.instance.addObserver(_ResumeSync(scheduler.onResume));
  }

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionControllerProvider.overrideWithValue(session),
        appLockControllerProvider.overrideWithValue(lock),
      ],
      child: const PorquinhoApp(),
    ),
  );
}

/// Sincroniza ao voltar ao primeiro plano.
class _ResumeSync with WidgetsBindingObserver {
  _ResumeSync(this._onResume);
  final VoidCallback _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Configuração ausente. Execute com --dart-define=SUPABASE_URL=... '
            'e --dart-define=SUPABASE_PUBLISHABLE_KEY=...',
          ),
        ),
      ),
    ),
  );
}
