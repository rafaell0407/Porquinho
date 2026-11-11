import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_database/flutter_secure_value_store.dart';
import 'local_database/local_database_manager.dart';
import 'local_database/stored_database_key_provider.dart';

/// Armazenamento seguro do dispositivo (chave do banco, PIN).
final secureValueStoreProvider = Provider<SecureValueStore>(
  (ref) => FlutterSecureValueStore(),
);

/// Caminho do arquivo do banco local. `null` na Web (sem banco local).
/// Sobrescrito em `main.dart` depois de resolver o diretório do aplicativo.
final databasePathProvider = Provider<String?>((ref) => null);

/// Gerenciador do banco local cifrado; `null` quando não há banco (Web).
final localDatabaseManagerProvider = Provider<LocalDatabaseManager?>((ref) {
  final path = ref.watch(databasePathProvider);
  if (path == null) return null;
  return LocalDatabaseManager(
    store: ref.watch(secureValueStoreProvider),
    path: path,
  );
});

/// Cliente do Supabase; exige `Supabase.initialize` prévio (feito em `main`).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
