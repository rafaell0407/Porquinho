import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/infra_providers.dart';
import 'features/app_lock/app_lock_providers.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/secure_session_storage.dart';
import 'core/local_database/flutter_secure_value_store.dart';
import 'features/sync/sync_scheduler_provider.dart';

/// Configuração por `--dart-define` (nada de segredo no repositório):
/// `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  // Web: sem persistência da sessão, o que exige novo login a cada sessão do
  // navegador (`arquitetura.md` §17.5).
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: kIsWeb
          ? const EmptyLocalStorage()
          : SecureSessionStorage(FlutterSecureValueStore()),
    ),
  );

  // Web: sem banco local (caminho nulo) e, portanto, sem sincronização.
  final String? databasePath = kIsWeb
      ? null
      : '${(await getApplicationSupportDirectory()).path}/porquinho.db';

  // Todo o restante é composto pelos providers.
  final container = ProviderContainer(
    overrides: [databasePathProvider.overrideWithValue(databasePath)],
  );
  final session = container.read(sessionControllerProvider);
  await session.start();
  await container
      .read(appLockControllerProvider)
      .start(signedIn: session.state is SessionSignedIn);
  container.read(
    syncSchedulerProvider,
  ); // inicia a sincronização (celular) ou o acompanhamento da conexão (Web)

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PorquinhoApp(),
    ),
  );
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
