import 'dart:io';

import 'package:sqlite3/common.dart' show SqliteException;

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

  /// Arquivo ilegível guardado na última recuperação (D9), ou `null`.
  String? recoveredFrom;

  /// `true` enquanto o aviso da recuperação não foi mostrado ao usuário.
  bool get needsRecoveryNotice => recoveredFrom != null && !_noticeShown;
  bool _noticeShown = false;
  void markRecoveryNoticeShown() => _noticeShown = true;

  Future<PorquinhoDatabase> _openNew() async {
    try {
      return _db = await _openAndCheck();
    } on SqliteException catch (e) {
      // Banco ilegível (chave perdida ou arquivo corrompido). Decisão D9:
      // guarda o arquivo, recomeça vazio e deixa a sincronização baixar tudo
      // do servidor; só se perde o que não tinha sido sincronizado.
      if (e.resultCode != _notADatabase && e.resultCode != _corrupt) rethrow;
      await _setAsideUnreadable();
      return _db = await _openAndCheck();
    }
  }

  static const _corrupt = 11;
  static const _notADatabase = 26;

  Future<PorquinhoDatabase> _openAndCheck() async {
    final executor = await openEncryptedExecutor(
      location: path,
      keys: StoredDatabaseKeyProvider(_store),
    );
    final db = PorquinhoDatabase(executor);
    try {
      // Primeira consulta: com chave errada ou arquivo corrompido, falha aqui.
      await db.customSelect('SELECT count(*) FROM sqlite_master').get();
    } on Object {
      await db.close();
      rethrow;
    }
    return db;
  }

  Future<void> _setAsideUnreadable() async {
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final aside = '$path.unreadable-$stamp';
    final file = File(path);
    if (await file.exists()) await file.rename(aside);
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final extra = File('$path$suffix');
      if (await extra.exists()) await extra.delete();
    }
    await _store.delete('porquinho.database_key');
    recoveredFrom = aside;
    _noticeShown = false;
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
