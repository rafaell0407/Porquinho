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

  group('v6 -> v7 (reestruturação de períodos P6)', () {
    void seedV6(dynamic raw) {
      // Configuração em vigor (mensal desde 2026-01) e uma mudança agendada
      // para o futuro (ciclo dia 20 em 2999): vale a de hoje.
      raw.execute(
        "INSERT INTO period_configurations (id, owner_id, version, created_at, "
        "updated_at, mode, custom_start_day, effective_from) VALUES "
        "('cfg1', 'u1', 1, 'x', 'x', 'calendar_month', NULL, '2026-01-01'), "
        "('cfg2', 'u1', 2, 'x', 'x', 'custom_cycle', 20, '2999-01-01'), "
        "('cfg3', 'u2', 1, 'x', 'x', 'custom_cycle', 5, '2026-03-05')",
      );
      raw.execute(
        "INSERT INTO accounting_periods (id, owner_id, version, created_at, "
        "updated_at, configuration_id, start_date, end_date) VALUES "
        "('p1', 'u1', 1, 'x', 'x', 'cfg1', '2026-11-01', '2026-12-01')",
      );
      raw.execute(
        "INSERT INTO income_entries (id, owner_id, version, created_at, "
        "updated_at, amount_centavos, status, received_on, "
        "accounting_period_id) VALUES "
        "('i1', 'u1', 1, 'x', 'x', '1000', 'received', '2026-11-05', 'p1')",
      );
      raw.execute(
        "INSERT INTO expense_entries (id, owner_id, version, created_at, "
        "updated_at, amount_centavos, status, competence_on, "
        "accounting_period_id) VALUES "
        "('e1', 'u1', 2, 'x', 'x', '500', 'pending', '2026-11-06', 'p1')",
      );
      raw.execute(
        "INSERT INTO investment_allocations (id, owner_id, version, "
        "created_at, updated_at, amount_centavos, allocated_on, "
        "accounting_period_id) VALUES "
        "('v1', 'u1', 1, 'x', 'x', '300', '2026-11-07', 'p1')",
      );
    }

    test('produz o esquema do snapshot v7', () async {
      final schema = await verifier.schemaAt(6);
      seedV6(schema.rawDatabase);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 7);
      await db.close();
    });

    test(
      'cria a configuração única com a de hoje e preserva os dados',
      () async {
        final schema = await verifier.schemaAt(6);
        seedV6(schema.rawDatabase);
        final db = PorquinhoDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 7);
        final settings = await db
            .customSelect('SELECT * FROM period_settings ORDER BY owner_id')
            .get();
        expect(settings.map((r) => r.data['owner_id']), ['u1', 'u2']);
        expect(settings[0].data['id'], 'u1');
        expect(settings[0].data['mode'], 'calendar_month');
        expect(settings[0].data['custom_start_day'], isNull);
        expect(settings[0].data['version'], 1);
        expect(settings[1].data['mode'], 'custom_cycle');
        expect(settings[1].data['custom_start_day'], 5);
        // Lançamentos intactos, com o vínculo antigo preservado.
        final e = await db
            .customSelect('SELECT * FROM expense_entries')
            .getSingle();
        expect(e.data['version'], 2);
        expect(e.data['accounting_period_id'], 'p1');
        expect(
          (await db.customSelect('SELECT * FROM income_entries').get()).length,
          1,
        );
        expect(
          (await db.customSelect('SELECT * FROM investment_allocations').get())
              .length,
          1,
        );
        await db.close();
      },
    );

    test('depois da migração, lançamentos sem período são aceitos', () async {
      final schema = await verifier.schemaAt(6);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 7);
      await db.customStatement(
        "INSERT INTO income_entries (id, owner_id, version, created_at, "
        "updated_at, amount_centavos, status, received_on) VALUES "
        "('i2', 'u1', 1, 'x', 'x', '1', 'received', '1999-01-31')",
      );
      await db.customStatement(
        "INSERT INTO expense_entries (id, owner_id, version, created_at, "
        "updated_at, amount_centavos, status, competence_on) VALUES "
        "('e2', 'u1', 1, 'x', 'x', '1', 'pending', '2040-12-31')",
      );
      await db.customStatement(
        "INSERT INTO investment_allocations (id, owner_id, version, "
        "created_at, updated_at, amount_centavos, allocated_on) VALUES "
        "('v2', 'u1', 1, 'x', 'x', '1', '2030-06-15')",
      );
      // A regra de status continua: recebida sem data é recusada.
      await expectLater(
        db.customStatement(
          "INSERT INTO income_entries (id, owner_id, version, created_at, "
          "updated_at, amount_centavos, status) VALUES "
          "('i3', 'u1', 1, 'x', 'x', '1', 'received')",
        ),
        throwsA(anything),
      );
      await db.close();
    });

    test('criação direta na v7 equivale ao snapshot v7', () async {
      final schema = await verifier.schemaAt(7);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 7);
      await db.close();
    });

    test('v1 -> v7 (todos os passos)', () async {
      final schema = await verifier.schemaAt(1);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 7);
      await db.close();
    });
  });

  group('v7 -> v8 (reestruturação de períodos P7)', () {
    void seedV7(dynamic raw) {
      raw.execute(
        "INSERT INTO period_settings (id, owner_id, version, created_at, "
        "updated_at, mode, custom_start_day) VALUES "
        "('u1', 'u1', 2, 'x', 'x', 'custom_cycle', 20)",
      );
      raw.execute(
        "INSERT INTO period_configurations (id, owner_id, version, created_at, "
        "updated_at, mode, effective_from) VALUES "
        "('cfg1', 'u1', 1, 'x', 'x', 'calendar_month', '2026-01-01')",
      );
      raw.execute(
        "INSERT INTO accounting_periods (id, owner_id, version, created_at, "
        "updated_at, configuration_id, start_date, end_date) VALUES "
        "('p1', 'u1', 1, 'x', 'x', 'cfg1', '2026-11-01', '2026-12-01')",
      );
      raw.execute(
        "INSERT INTO income_recurrence_templates (id, owner_id, version, "
        "created_at, updated_at, frequency, starts_on, monthly_reference_day, "
        "value_mode) VALUES ('t1', 'u1', 1, 'x', 'x', 'monthly', "
        "'2026-11-05', 5, 'variable')",
      );
      raw.execute(
        "INSERT INTO income_entries (id, owner_id, version, created_at, "
        "updated_at, amount_centavos, status, received_on, "
        "accounting_period_id) VALUES "
        "('i1', 'u1', 3, 'x', 'x', '9223372036854775807', 'received', "
        "'2026-11-05', 'p1')",
      );
      raw.execute(
        "INSERT INTO income_entries (id, owner_id, version, created_at, "
        "updated_at, status, recurrence_template_id, scheduled_for_date) "
        "VALUES ('i2', 'u1', 1, 'x', 'x', 'pending', 't1', '2026-12-05')",
      );
      raw.execute(
        "INSERT INTO expense_entries (id, owner_id, version, created_at, "
        "updated_at, amount_centavos, status, competence_on, due_on, paid_on, "
        "accounting_period_id) VALUES ('e1', 'u1', 2, 'x', 'x', '500', "
        "'paid', '2026-11-06', '2026-11-10', '2026-11-09', 'p1')",
      );
      raw.execute(
        "INSERT INTO investment_allocations (id, owner_id, version, "
        "created_at, updated_at, amount_centavos, allocated_on, "
        "accounting_period_id) VALUES "
        "('v1', 'u1', 1, 'x', 'x', '300', '2026-11-07', 'p1')",
      );
      // Pendências antigas de período, sem destino depois da P7.
      raw.execute(
        "INSERT INTO sync_outbox (owner_id, idempotency_key, entity_type, "
        "entity_id, expected_version, payload_json, state, attempts) VALUES "
        "('u1', 'k1', 'accounting_period', 'p2', 0, '{}', 'pending', 0), "
        "('u1', 'k2', 'income_entry', 'i1', 2, '{}', 'pending', 0)",
      );
      raw.execute(
        "INSERT INTO sync_conflicts (id, owner_id, version, created_at, "
        "updated_at, entity_type, entity_id, expected_version, remote_version, "
        "local_snapshot_json, remote_snapshot_json, state) VALUES "
        "('c1', 'u1', 1, 'x', 'x', 'period_configuration', 'cfg1', 1, 2, "
        "'{}', '{}', 'open')",
      );
    }

    test('produz o esquema do snapshot v8', () async {
      final schema = await verifier.schemaAt(7);
      seedV7(schema.rawDatabase);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);
      await db.close();
    });

    test('remove períodos e vínculos e preserva o dinheiro', () async {
      final schema = await verifier.schemaAt(7);
      seedV7(schema.rawDatabase);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
            "('accounting_periods', 'period_configurations')",
          )
          .get();
      expect(tables, isEmpty);
      for (final t in [
        'income_entries',
        'expense_entries',
        'investment_allocations',
      ]) {
        final cols = await db
            .customSelect("SELECT name FROM pragma_table_info('$t')")
            .get();
        final names = cols.map((r) => r.read<String>('name')).toList();
        expect(names, isNot(contains('accounting_period_id')), reason: t);
        expect(names, isNot(contains('scheduled_period_id')), reason: t);
      }
      final i1 = await db
          .customSelect("SELECT * FROM income_entries WHERE id = 'i1'")
          .getSingle();
      expect(i1.data['amount_centavos'], '9223372036854775807');
      expect(i1.data['version'], 3);
      final i2 = await db
          .customSelect("SELECT * FROM income_entries WHERE id = 'i2'")
          .getSingle();
      expect(i2.data['scheduled_for_date'], '2026-12-05');
      final e1 = await db
          .customSelect('SELECT * FROM expense_entries')
          .getSingle();
      expect(e1.data['paid_on'], '2026-11-09');
      expect(e1.data['status'], 'paid');
      expect(
        (await db.customSelect('SELECT * FROM investment_allocations').get())
            .length,
        1,
      );
      final settings = await db
          .customSelect('SELECT * FROM period_settings')
          .getSingle();
      expect(settings.data['custom_start_day'], 20);
      expect(settings.data['version'], 2);
      final outbox = await db
          .customSelect('SELECT idempotency_key FROM sync_outbox')
          .get();
      expect(outbox.map((r) => r.read<String>('idempotency_key')), ['k2']);
      expect(
        await db.customSelect('SELECT * FROM sync_conflicts').get(),
        isEmpty,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();
    });

    test('criação direta na v8 equivale ao snapshot v8', () async {
      final schema = await verifier.schemaAt(8);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);
      await db.close();
    });

    test('v1 -> v8 (todos os passos)', () async {
      final schema = await verifier.schemaAt(1);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);
      await db.close();
    });
  });

  group('v8 -> v9 (aba Ferramentas)', () {
    test(
      'produz o esquema do snapshot v9 e preserva as preferências',
      () async {
        final schema = await verifier.schemaAt(8);
        schema.rawDatabase.execute(
          "INSERT INTO user_preferences (owner_id, theme, time_zone_id, "
          "version, updated_at, onboarding) VALUES ('u1', 'dark', "
          "'America/Sao_Paulo', 4, 'x', '{\"intro\":\"done\"}')",
        );
        final db = PorquinhoDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 9);
        final row = await db
            .customSelect('SELECT * FROM user_preferences')
            .getSingle();
        expect(row.data['theme'], 'dark');
        expect(row.data['version'], 4);
        expect(row.data['onboarding'], '{"intro":"done"}');
        expect(row.data['tools'], '{}');
        await db.close();
      },
    );

    test('criação direta na v9 equivale ao snapshot v9', () async {
      final schema = await verifier.schemaAt(9);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });

    test('v1 -> v9 (todos os passos)', () async {
      final schema = await verifier.schemaAt(1);
      final db = PorquinhoDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });
  });
}
