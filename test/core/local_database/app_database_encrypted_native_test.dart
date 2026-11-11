@TestOn('vm')
// ignore_for_file: avoid_relative_lib_imports
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/local_database/app_database.dart';
import '../../../lib/core/local_database/database_key.dart';
import '../../../lib/core/local_database/encrypted_connection.dart';
import '../../generated_migrations/schema_v1.dart';
import 'database_contract.dart';

const _keyA =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _keyB =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const _maxCentavos = '9223372036854775807';

/// Contrato de persistência e migração Drift sobre arquivo cifrado
/// (SQLite3MultipleCiphers), em SQLite nativo.
void main() {
  late Directory dir;
  late String path;

  setUpAll(() => dir = Directory.systemTemp.createTempSync('porquinho_enc_'));
  tearDownAll(() => dir.deleteSync(recursive: true));
  setUp(() {
    path =
        '${dir.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}.db';
  });

  PorquinhoDatabase abrir(String key) => PorquinhoDatabase(
    LazyDatabase(
      () => openEncryptedExecutor(
        location: path,
        keys: StaticDatabaseKeyProvider(key),
      ),
    ),
  );

  group('contrato sobre arquivo cifrado', () {
    late String contractPath;
    setUpAll(() => contractPath = '${dir.path}${Platform.pathSeparator}c.db');

    runDatabaseContract(
      open: () => PorquinhoDatabase(
        LazyDatabase(
          () => openEncryptedExecutor(
            location: contractPath,
            keys: const StaticDatabaseKeyProvider(_keyA),
          ),
        ),
      ),
      reset: () async {
        final f = File(contractPath);
        if (f.existsSync()) f.deleteSync();
      },
    );
  });

  test('o arquivo não tem texto puro nem cabeçalho SQLite', () async {
    final db = abrir(_keyA);
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'cat-1',
            ownerId: 'owner-1',
            kind: 'expense',
            name: 'SEGREDO-CATEGORIA-FINANCEIRA',
            createdAt: '2026-11-10T12:00:00Z',
            updatedAt: '2026-11-10T12:00:00Z',
          ),
        );
    await db.close();

    final conteudo = String.fromCharCodes(File(path).readAsBytesSync());
    expect(conteudo.contains('SEGREDO-CATEGORIA-FINANCEIRA'), isFalse);
    expect(conteudo.startsWith('SQLite format 3'), isFalse);
  });

  test('chave correta reabre; chave errada falha', () async {
    var db = abrir(_keyA);
    await db.customSelect('SELECT 1').get();
    await db.close();

    db = abrir(_keyA);
    expect(
      await db.customSelect('SELECT count(*) AS n FROM categories').get(),
      hasLength(1),
    );
    await db.close();

    db = abrir(_keyB);
    await expectLater(
      db.customSelect('SELECT count(*) AS n FROM categories').get(),
      throwsA(anything),
    );
    await db.close();
  });

  test(
    'migra v1 -> atual (v4) em arquivo cifrado preservando centavos 2^63-1',
    () async {
      final pragma = buildKeyPragma(_keyA);
      // Cria o banco exatamente como a v1 (sem os índices da v2).
      final v1 = DatabaseAtV1(
        NativeDatabase(File(path), setup: (raw) => raw.execute(pragma)),
      );
      await v1.customStatement(
        "INSERT INTO period_configurations (id, owner_id, created_at, updated_at, "
        "mode, effective_from) VALUES ('c1','o1','t','t','calendar_month','2026-11-01')",
      );
      await v1.customStatement(
        "INSERT INTO accounting_periods (id, owner_id, created_at, updated_at, "
        "configuration_id, start_date, end_date) "
        "VALUES ('p1','o1','t','t','c1','2026-11-01','2026-12-01')",
      );
      await v1.customStatement(
        "INSERT INTO investment_allocations (id, owner_id, created_at, updated_at, "
        "amount_centavos, allocated_on, accounting_period_id) "
        "VALUES ('i1','o1','t','t','$_maxCentavos','2026-11-09','p1')",
      );
      final antes = await v1
          .customSelect(
            "SELECT count(*) AS n FROM sqlite_master "
            "WHERE type = 'index' AND name LIKE '%_period_idx'",
          )
          .getSingle();
      expect(antes.read<int>('n'), 0);
      await v1.close();

      final db = abrir(_keyA);
      final linhas = await db.select(db.investmentAllocations).get();
      expect(linhas.single.amountCentavos, BigInt.parse(_maxCentavos));

      final indices = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name IN ('income_entries_period_idx', 'expense_entries_period_idx', "
            "'investment_allocations_period_idx', 'sync_outbox_state_idx')",
          )
          .get();
      expect(indices, hasLength(4));

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 4);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();
    },
  );
}
