import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/local_database/stored_database_key_provider.dart';

/// Guarda a sessão do Supabase (inclui o refresh token) no armazenamento
/// seguro, em vez do `SharedPreferences` padrão do SDK.
///
/// Use em `FlutterAuthClientOptions(localStorage: ...)`. Na Web não use com
/// `FlutterSecureValueStore`: ver `arquitetura.md` §17.5.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(
    this._store, {
    this.entryName = 'porquinho.session',
  });

  final SecureValueStore _store;
  final String entryName;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _store.read(entryName)) != null;

  @override
  Future<String?> accessToken() => _store.read(entryName);

  @override
  Future<void> removePersistedSession() => _store.delete(entryName);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(entryName, persistSessionString);
}
