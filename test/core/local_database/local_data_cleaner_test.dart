@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/local_data_cleaner.dart';
import 'package:porquinho/core/local_database/stored_database_key_provider.dart';

void main() {
  test('apaga o banco, arquivos auxiliares e a chave', () async {
    final dir = await Directory.systemTemp.createTemp('porquinho_wipe');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/porquinho.db';
    for (final s in ['', '-wal', '-shm']) {
      await File('$path$s').writeAsString('x');
    }
    final store = InMemorySecureValueStore();
    await store.write('porquinho.database_key', 'a' * 64);

    await LocalDataCleaner(store, databasePath: path).wipe();

    expect(dir.listSync(), isEmpty);
    expect(await store.read('porquinho.database_key'), isNull);
  });

  test('não falha se não há nada para apagar', () async {
    final store = InMemorySecureValueStore();
    await LocalDataCleaner(store, databasePath: 'inexistente.db').wipe();
  });
}
