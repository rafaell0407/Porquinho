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

  test('v2 -> v3 produz exatamente o esquema do snapshot v3', () async {
    final schema = await verifier.schemaAt(2);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('v1 -> v3 (passando pela v2) produz o esquema do snapshot v3', () async {
    final schema = await verifier.schemaAt(1);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('criação direta na v3 equivale ao snapshot v3', () async {
    final schema = await verifier.schemaAt(3);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('v2 -> v3 preserva dados e troca per_period por by_period', () async {
    final schema = await verifier.schemaAt(2);
    final raw = schema.rawDatabase;
    raw.execute(
      "INSERT INTO income_recurrence_templates (id, owner_id, version, "
      "created_at, updated_at, frequency, starts_on, value_mode) "
      "VALUES ('t1', 'u1', 1, 'x', 'x', 'per_period', '2026-11-01', "
      "'variable')",
    );
    raw.execute(
      "INSERT INTO income_entries (id, owner_id, version, created_at, "
      "updated_at, description, status, recurrence_template_id, "
      "scheduled_for_date) VALUES ('e1', 'u1', 1, 'x', 'x', 'Salário', "
      "'pending', 't1', '2026-11-01')",
    );
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final t = await db
        .customSelect(
          "SELECT frequency, description FROM income_recurrence_templates",
        )
        .getSingle();
    expect(t.read<String>('frequency'), 'by_period');
    expect(t.data['description'], isNull);
    final e = await db
        .customSelect("SELECT description FROM income_entries")
        .getSingle();
    expect(e.read<String>('description'), 'Salário');
    await db.close();
  });
}
