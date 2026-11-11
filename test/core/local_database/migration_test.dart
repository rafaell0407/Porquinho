// ignore_for_file: avoid_relative_lib_imports
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/local_database/app_database.dart';
import '../../generated_migrations/schema.dart';

/// Verifica que o esquema migrado é idêntico ao snapshot da versão alvo.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 -> v2 produz exatamente o esquema do snapshot v2', () async {
    final schema = await verifier.schemaAt(1);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('criação direta na v2 equivale ao snapshot v2', () async {
    final schema = await verifier.schemaAt(2);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });
}
