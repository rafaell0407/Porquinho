import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

import 'database_key.dart';

/// Abre o banco cifrado na Web: `sqlite3mc.wasm` sobre IndexedDB.
///
/// [location] é o nome do banco IndexedDB. O arquivo `sqlite3mc.wasm` deve
/// ser servido ao lado da página. Múltiplas abas NÃO são suportadas
/// (`arquitetura.md` §17.5, item 2).
Future<QueryExecutor> openEncryptedExecutor({
  required String location,
  required DatabaseKeyProvider keys,
}) async {
  final pragma = buildKeyPragma(await keys.loadKeyHex());
  final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3mc.wasm'));
  final fs = await IndexedDbFileSystem.open(dbName: location);
  sqlite3.registerVirtualFileSystem(fs);

  // O VFS cifrado precisa ser pedido pelo nome; o WasmDatabase do Drift não
  // aceita escolher o VFS, por isso a conexão é aberta aqui.
  final raw = sqlite3.open('/porquinho.db', vfs: 'multipleciphers-${fs.name}');
  raw.execute(pragma);

  return WasmDatabase.opened(
    raw,
  ).interceptWith(_IndexedDbFlush(sqlite3: sqlite3, fileSystem: fs));
}

/// Grava o IndexedDB depois de cada escrita fora de transação e a cada commit.
class _IndexedDbFlush extends QueryInterceptor {
  _IndexedDbFlush({required this.sqlite3, required this.fileSystem});

  final WasmSqlite3 sqlite3;
  final IndexedDbFileSystem fileSystem;

  Future<T> _then<T>(QueryExecutor executor, Future<T> result) async {
    final value = await result;
    if (executor is! TransactionExecutor) await fileSystem.flush();
    return value;
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _then(executor, super.runInsert(executor, statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _then(executor, super.runUpdate(executor, statement, args));

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _then(executor, super.runDelete(executor, statement, args));

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _then(executor, super.runCustom(executor, statement, args));

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) => _then(executor, super.runBatched(executor, statements));

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await super.commitTransaction(inner);
    await fileSystem.flush();
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    await super.close(inner);
    await fileSystem.flush();
    sqlite3.unregisterVirtualFileSystem(fileSystem);
    await fileSystem.close();
  }
}
