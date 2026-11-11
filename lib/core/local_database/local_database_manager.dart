import 'app_database.dart';
import 'encrypted_connection.dart';
import 'local_data_cleaner.dart';
import 'stored_database_key_provider.dart';

/// Abre o banco cifrado do app sob demanda e o apaga no logout.
///
/// Só nativo: na Web a chave depende da reautenticação (opção B), ainda não
/// implementada (`arquitetura.md` §17.5).
class LocalDatabaseManager {
  LocalDatabaseManager({required SecureValueStore store, required this.path})
    : _store = store;

  final SecureValueStore _store;
  final String path;
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
  }
}
