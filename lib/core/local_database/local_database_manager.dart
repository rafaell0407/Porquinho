import 'app_database.dart';
import 'encrypted_connection.dart';
import 'local_data_cleaner.dart';
import 'stored_database_key_provider.dart';

/// Abre o banco cifrado do app sob demanda e o apaga no logout.
///
/// Só nativo: a Web não usa banco local (`arquitetura.md` §17.5).
class LocalDatabaseManager {
  LocalDatabaseManager({
    required SecureValueStore store,
    required this.path,
    this.ownerEntryName = 'porquinho.database_owner',
  }) : _store = store;

  final SecureValueStore _store;
  final String path;
  final String ownerEntryName;
  PorquinhoDatabase? _db;
  Future<PorquinhoDatabase>? _opening;

  Future<PorquinhoDatabase> open() => _opening ??= _openNew();

  Future<PorquinhoDatabase> _openNew() async {
    final executor = await openEncryptedExecutor(
      location: path,
      keys: StoredDatabaseKeyProvider(_store),
    );
    return _db = PorquinhoDatabase(executor);
  }

  /// Conta dona dos dados deste aparelho (`null` se ainda não vinculado).
  Future<String?> boundOwner() => _store.read(ownerEntryName);

  Future<void> bindOwner(String ownerId) =>
      _store.write(ownerEntryName, ownerId);

  /// Fecha o banco e apaga arquivo e chave. Chamar só depois de confirmar que
  /// não há operações pendentes.
  Future<void> closeAndWipe() async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening;
      } on Object {
        // Falha ao abrir: ainda assim apagar o que existir.
      }
    }
    await _db?.close();
    _db = null;
    _opening = null;
    await LocalDataCleaner(_store, databasePath: path).wipe();
    await _store.delete(ownerEntryName);
  }
}
