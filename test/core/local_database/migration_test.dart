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

  test('v3 -> v4 produz exatamente o esquema do snapshot v4', () async {
    final schema = await verifier.schemaAt(3);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test(
    'v1 -> v4 (passando por v2 e v3) produz o esquema do snapshot v4',
    () async {
      final schema = await verifier.schemaAt(1);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();
    },
  );

  test('criação direta na v4 equivale ao snapshot v4', () async {
    final schema = await verifier.schemaAt(4);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('v3 -> v4 preserva dados e acrescenta só campos opcionais', () async {
    final schema = await verifier.schemaAt(3);
    final raw = schema.rawDatabase;
    raw.execute(
      "INSERT INTO investment_allocations (id, owner_id, version, created_at, "
      "updated_at, amount_centavos, allocated_on, accounting_period_id, "
      "cancelled_at) VALUES ('a1', 'u1', 2, 'x', 'y', '123456', "
      "'2026-11-05', 'p1', NULL), ('a2', 'u1', 3, 'x', 'y', '0', "
      "'2026-11-06', 'p1', '2026-11-07T00:00:00Z')",
    );
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    final rows = await db
        .customSelect('SELECT * FROM investment_allocations ORDER BY id')
        .get();
    expect(rows.length, 2);
    expect(rows[0].read<String>('amount_centavos'), '123456');
    expect(rows[0].read<int>('version'), 2);
    expect(rows[0].read<String>('allocated_on'), '2026-11-05');
    expect(rows[0].data['cancelled_at'], isNull);
    expect(rows[0].data['recurrence_template_id'], isNull);
    expect(rows[0].data['scheduled_for_date'], isNull);
    expect(rows[1].read<String>('cancelled_at'), '2026-11-07T00:00:00Z');
    final templates = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM investment_recurrence_templates',
        )
        .getSingle();
    expect(templates.read<int>('n'), 0);
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND "
          "name IN ('unique_investment_occurrence_schedule', "
          "'investment_allocations_period_idx')",
        )
        .get();
    expect(idx.length, 2, reason: 'índices recriados após a reconstrução');
    await db.close();
  });

  test(
    'v4 -> v5 preserva preferências e acrescenta onboarding vazio',
    () async {
      final schema = await verifier.schemaAt(4);
      schema.rawDatabase.execute(
        "INSERT INTO user_preferences (owner_id, theme, version, updated_at) "
        "VALUES ('u1', 'dark', 3, 'x')",
      );
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 5);
      final row = await db
          .customSelect('SELECT * FROM user_preferences')
          .getSingle();
      expect(row.read<String>('theme'), 'dark');
      expect(row.read<int>('version'), 3);
      expect(row.read<String>('onboarding'), '{}');
      await db.close();
    },
  );

  test('criação direta na v5 equivale ao snapshot v5', () async {
    final schema = await verifier.schemaAt(5);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);
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

  test(
    'v5 -> v6 preserva categorias e dá o visual padrão (ícone e cor)',
    () async {
      final schema = await verifier.schemaAt(5);
      schema.rawDatabase.execute(
        "INSERT INTO categories (id, owner_id, version, created_at, "
        "updated_at, kind, name, is_active) VALUES "
        "('c1', 'u1', 3, 'x', 'y', 'expense', 'Moradia', 1)",
      );
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 6);
      final row = await db.customSelect('SELECT * FROM categories').getSingle();
      expect(row.read<String>('name'), 'Moradia');
      expect(row.read<int>('version'), 3);
      expect(row.read<String>('icon_key'), 'category');
      expect(row.read<String>('color_key'), 'gray');
      await db.close();
    },
  );

  test('criação direta na v6 equivale ao snapshot v6', () async {
    final schema = await verifier.schemaAt(6);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 6);
    await db.close();
  });

  test('v1 -> v6 (todos os passos) produz o esquema do snapshot v6', () async {
    final schema = await verifier.schemaAt(1);
    final db = PorquinhoDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 6);
    await db.close();
  });
}
