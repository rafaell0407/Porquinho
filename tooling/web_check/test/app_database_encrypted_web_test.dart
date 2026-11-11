// ignore_for_file: avoid_relative_lib_imports
@TestOn('browser')
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';
import 'package:test/test.dart';

import '../../../lib/core/local_database/app_database.dart';
import '../../../lib/core/local_database/database_key.dart';
import '../../../lib/core/local_database/encrypted_connection.dart';
import '../../../test/core/local_database/database_contract.dart';
import '../../../test/generated_migrations/schema_v1.dart';

const _keyA =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _keyB =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const _maxCentavos = '9223372036854775807';

/// Drift sobre `sqlite3mc.wasm` e IndexedDB, com o schema real do app:
/// contrato de persistência, chave errada, bytes cifrados e migração v1 -> v2.
void main() {
  var n = 0;
  late String name;

  setUp(
    () => name = 'porquinho_enc_${DateTime.now().microsecondsSinceEpoch}_${n++}',
  );
  tearDown(() => IndexedDbFileSystem.deleteDatabase(name));

  PorquinhoDatabase abrir(String key, {String? location}) => PorquinhoDatabase(
    LazyDatabase(
      () => openEncryptedExecutor(
        location: location ?? name,
        keys: StaticDatabaseKeyProvider(key),
      ),
    ),
  );

  group('contrato sobre IndexedDB cifrado', () {
    late String contractName;
    setUp(() => contractName = '${name}_contract');
    tearDown(() => IndexedDbFileSystem.deleteDatabase(contractName));

    runDatabaseContract(
      open: () => abrir(_keyA, location: contractName),
      reset: () => IndexedDbFileSystem.deleteDatabase(contractName),
    );
  });

  test('chave correta reabre; chave errada falha', () async {
    var db = abrir(_keyA);
    await db.customSelect('SELECT count(*) AS n FROM categories').get();
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

  test('os bytes no IndexedDB não contêm texto puro', () async {
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

    final fs = await IndexedDbFileSystem.open(dbName: name);
    final (file: f, outFlags: _) = fs.xOpen(
      Sqlite3Filename('/porquinho.db'),
      0x02,
    );
    final out = Uint8List(f.xFileSize());
    expect(out, isNotEmpty);
    f.xRead(out, 0);
    f.xClose();
    await fs.close();

    final texto = latin1.decode(out);
    expect(texto.contains('SEGREDO-CATEGORIA-FINANCEIRA'), isFalse);
    expect(texto.startsWith('SQLite format 3'), isFalse);
  });

  test('migra v1 -> v2 no IndexedDB cifrado preservando 2^63-1', () async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3mc.wasm'));
    final fs = await IndexedDbFileSystem.open(dbName: name);
    sqlite3.registerVirtualFileSystem(fs);
    final raw = sqlite3.open(
      '/porquinho.db',
      vfs: 'multipleciphers-${fs.name}',
    );
    raw.execute(buildKeyPragma(_keyA));
    final v1 = DatabaseAtV1(WasmDatabase.opened(raw));
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
    await v1.close();
    await fs.flush();
    sqlite3.unregisterVirtualFileSystem(fs);
    await fs.close();

    final db = abrir(_keyA);
    final linhas = await db.select(db.investmentAllocations).get();
    expect(linhas.single.amountCentavos, BigInt.parse(_maxCentavos));
    final indices = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name IN ('income_entries_period_idx', "
          "'expense_entries_period_idx', "
          "'investment_allocations_period_idx', 'sync_outbox_state_idx')",
        )
        .get();
    expect(indices, hasLength(4));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);
    await db.close();
  });
}
