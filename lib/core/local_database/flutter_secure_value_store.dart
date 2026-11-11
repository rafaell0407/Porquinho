import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'stored_database_key_provider.dart';

/// [SecureValueStore] sobre o Android Keystore (via `flutter_secure_storage`).
///
/// Uso previsto: Android (e iOS, ainda não validado). Na Web NÃO deve ser
/// usado: a decisão de 10/11/2026 exige a KEK protegida por reautenticação
/// (`arquitetura.md` §17.5).
class FlutterSecureValueStore implements SecureValueStore {
  FlutterSecureValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}
