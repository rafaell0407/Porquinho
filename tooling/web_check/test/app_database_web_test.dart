// ignore_for_file: avoid_relative_lib_imports
@TestOn('browser')
library;

import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';
import 'package:test/test.dart';

import '../../../lib/core/local_database/app_database.dart';
import '../../../test/core/local_database/database_contract.dart';

/// Drift sobre SQLite/WASM no navegador. O armazenamento é um sistema de
/// arquivos virtual em memória que sobrevive ao fechamento da conexão; não
/// valida IndexedDB (depende da prova técnica de persistência Web).
void main() {
  late WasmSqlite3 sqlite3;
  late InMemoryFileSystem fileSystem;

  setUpAll(() async {
    sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    fileSystem = InMemoryFileSystem();
    sqlite3.registerVirtualFileSystem(fileSystem, makeDefault: true);
  });

  test('usa SQLite/WASM de fato', () async {
    final db = PorquinhoDatabase(
      WasmDatabase(sqlite3: sqlite3, path: '/probe.db'),
    );
    final version = await db
        .customSelect('SELECT sqlite_version() AS v')
        .getSingle();
    expect(version.read<String>('v'), isNotEmpty);
    await db.close();
  });

  runDatabaseContract(
    open: () =>
        PorquinhoDatabase(WasmDatabase(sqlite3: sqlite3, path: '/contract.db')),
    reset: () async {
      fileSystem.xDelete('/contract.db', 0);
    },
  );
}
