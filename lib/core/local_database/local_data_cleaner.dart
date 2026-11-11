import 'dart:io';

import 'stored_database_key_provider.dart';

/// Limpeza local após um logout permitido (sem operações pendentes;
/// `arquitetura.md` §16.2). Apaga o arquivo do banco cifrado e a chave
/// guardada: sem a chave, qualquer cópia do arquivo fica ilegível.
///
/// O banco deve estar fechado antes de chamar [wipe].
class LocalDataCleaner {
  LocalDataCleaner(
    this._store, {
    required this.databasePath,
    this.keyEntryName = 'porquinho.database_key',
  });

  final SecureValueStore _store;
  final String databasePath;
  final String keyEntryName;

  Future<void> wipe() async {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) await file.delete();
    }
    await _store.delete(keyEntryName);
  }
}
