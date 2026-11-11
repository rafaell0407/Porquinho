import 'dart:math';

import 'database_key.dart';

/// Armazenamento seguro de pequenos segredos (chave do banco), por plataforma.
///
/// As implementações reais (Keystore/Keychain, KEK WebCrypto) são pendência de
/// `arquitetura.md` §17.5 e devem ser adicionadas atrás desta interface.
abstract interface class SecureValueStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

/// Armazenamento em memória, para testes. Não é seguro nem persistente.
class InMemorySecureValueStore implements SecureValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String name) async => _values[name];

  @override
  Future<void> write(String name, String value) async {
    _values[name] = value;
  }

  @override
  Future<void> delete(String name) async {
    _values.remove(name);
  }
}

/// Lê a chave do banco do armazenamento seguro ou a gera na primeira execução.
///
/// Se o valor guardado for inválido, lança [StateError]: gerar outra chave
/// tornaria o banco existente ilegível e apagaria dados sem aviso.
class StoredDatabaseKeyProvider implements DatabaseKeyProvider {
  StoredDatabaseKeyProvider(
    this._store, {
    Random? random,
    this.entryName = 'porquinho.database_key',
  }) : _random = random ?? Random.secure();

  final SecureValueStore _store;
  final Random _random;
  final String entryName;
  Future<String>? _pending;

  @override
  Future<String> loadKeyHex() => _pending ??= _loadOrCreate().whenComplete(() {
    _pending = null;
  });

  Future<String> _loadOrCreate() async {
    final stored = await _store.read(entryName);
    if (stored != null) {
      try {
        buildKeyPragma(stored);
      } on ArgumentError {
        throw StateError(
          'A chave do banco guardada é inválida; não foi gerada outra para '
          'não tornar o banco existente ilegível.',
        );
      }
      return stored.toLowerCase();
    }
    final created = generateDatabaseKeyHex(_random);
    await _store.write(entryName, created);
    return created;
  }
}

/// Gera 256 bits aleatórios em hexadecimal (64 dígitos).
String generateDatabaseKeyHex(Random random) {
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
