import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/database_key.dart';
import 'package:porquinho/core/local_database/stored_database_key_provider.dart';

void main() {
  test('gera chave válida na primeira execução e a persiste', () async {
    final store = InMemorySecureValueStore();
    final provider = StoredDatabaseKeyProvider(store);

    final key = await provider.loadKeyHex();

    expect(() => buildKeyPragma(key), returnsNormally);
    expect(await store.read('porquinho.database_key'), key);
  });

  test('reutiliza a mesma chave em novas instâncias', () async {
    final store = InMemorySecureValueStore();
    final first = await StoredDatabaseKeyProvider(store).loadKeyHex();
    final second = await StoredDatabaseKeyProvider(store).loadKeyHex();

    expect(second, first);
  });

  test('chamadas concorrentes geram uma única chave', () async {
    final store = InMemorySecureValueStore();
    final provider = StoredDatabaseKeyProvider(store);

    final keys = await Future.wait([
      provider.loadKeyHex(),
      provider.loadKeyHex(),
      provider.loadKeyHex(),
    ]);

    expect(keys.toSet(), hasLength(1));
  });

  test('chave guardada inválida falha sem sobrescrever', () async {
    final store = InMemorySecureValueStore();
    await store.write('porquinho.database_key', 'abc');
    final provider = StoredDatabaseKeyProvider(store);

    await expectLater(provider.loadKeyHex(), throwsStateError);
    expect(await store.read('porquinho.database_key'), 'abc');
  });

  test('chaves geradas diferem entre armazenamentos', () async {
    final a = await StoredDatabaseKeyProvider(
      InMemorySecureValueStore(),
    ).loadKeyHex();
    final b = await StoredDatabaseKeyProvider(
      InMemorySecureValueStore(),
    ).loadKeyHex();

    expect(a, isNot(b));
  });

  test('generateDatabaseKeyHex produz 64 dígitos hexadecimais', () {
    final key = generateDatabaseKeyHex(Random(1));
    expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}
