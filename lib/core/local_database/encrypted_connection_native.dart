import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'database_key.dart';

/// Abre o banco cifrado em [location] (caminho do arquivo SQLite).
///
/// Exige o SQLite3MultipleCiphers (`hooks.user_defines.sqlite3.source` em
/// `pubspec.yaml`). Com a chave errada, a primeira consulta falha.
Future<QueryExecutor> openEncryptedExecutor({
  required String location,
  required DatabaseKeyProvider keys,
}) async {
  final pragma = buildKeyPragma(await keys.loadKeyHex());
  return NativeDatabase(File(location), setup: (raw) => raw.execute(pragma));
}
