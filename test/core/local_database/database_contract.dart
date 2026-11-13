// ignore_for_file: avoid_relative_lib_imports, deprecated_member_use
import 'package:drift/drift.dart';
import 'package:matcher/expect.dart';
import 'package:test_api/test_api.dart';
import '../../../lib/core/local_database/app_database.dart';

/// Contrato de persistência executado em SQLite nativo (VM) e Drift/WASM
/// (navegador). [open] deve abrir uma conexão nova sobre o MESMO
/// armazenamento a cada chamada; [reset] limpa o armazenamento.
void runDatabaseContract({
  required PorquinhoDatabase Function() open,
  required Future<void> Function() reset,
}) {
  const owner = 'owner-1';
  const now = '2026-11-09T12:00:00Z';

  Future<void> seed(PorquinhoDatabase db) async {
    await db
        .into(db.periodSettings)
        .insert(
          PeriodSettingsCompanion.insert(
            id: owner,
            ownerId: owner,
            mode: 'calendar_month',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> insertInvestment(
    PorquinhoDatabase db,
    String id,
    BigInt amount, {
    String allocatedOn = '2026-11-09',
    String createdAt = now,
  }) {
    return db
        .into(db.investmentAllocations)
        .insert(
          InvestmentAllocationsCompanion.insert(
            id: id,
            ownerId: owner,
            amountCentavos: amount,
            allocatedOn: allocatedOn,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
  }

  setUp(reset);

  test('preserva centavos acima de 2^53 com igualdade exata', () async {
    final db = open();
    addTearDown(db.close);
    await seed(db);

    final limit = BigInt.two.pow(53); // 9007199254740992
    final values = <String, BigInt>{
      'zero': BigInt.zero,
      'um': BigInt.one,
      'seguro-max': limit - BigInt.one, // 2^53 - 1
      'limite': limit,
      'limite+1': limit + BigInt.one, // 9007199254740993
      'limite+2': limit + BigInt.two,
      'limite*3+1': limit * BigInt.from(3) + BigInt.one,
      'int64-1': BigInt.parse('9223372036854775806'),
      'int64-max': BigInt.parse('9223372036854775807'),
    };
    for (final e in values.entries) {
      await insertInvestment(db, e.key, e.value);
    }

    for (final e in values.entries) {
      final saved = await (db.select(
        db.investmentAllocations,
      )..where((t) => t.id.equals(e.key))).getSingle();
      expect(saved.amountCentavos, e.value, reason: e.key);
      final raw = await db
          .customSelect(
            'SELECT amount_centavos, typeof(amount_centavos) AS t '
            'FROM investment_allocations WHERE id = ?',
            variables: [Variable<String>(e.key)],
          )
          .getSingle();
      expect(raw.read<String>('amount_centavos'), e.value.toString());
      expect(raw.read<String>('t'), 'text', reason: e.key);
    }
  });

  test('soma local em BigInt acima de 2^53 permanece exata', () async {
    final db = open();
    addTearDown(db.close);
    await seed(db);
    await insertInvestment(db, 'a', BigInt.parse('9007199254740993'));
    await insertInvestment(db, 'b', BigInt.parse('9007199254740995'));

    final rows = await db.select(db.investmentAllocations).get();
    final total = rows.fold<BigInt>(
      BigInt.zero,
      (s, r) => s + r.amountCentavos,
    );
    expect(total, BigInt.parse('18014398509481988'));
  });

  test('preserva datas ISO e instantes UTC sem conversão', () async {
    final db = open();
    addTearDown(db.close);
    await seed(db);

    const dates = [
      '2026-11-01', // início do período
      '2026-11-30', // último dia do período
      '2026-12-01', // limite exclusivo [início, fim)
      '2026-12-31',
      '2027-01-01',
      '2028-02-29', // bissexto
      '2026-02-28',
      '1970-01-01',
      '9999-12-31',
    ];
    const instants = [
      '2026-11-09T00:00:00Z',
      '2026-11-09T23:59:59.999Z',
      '2026-11-10T00:00:00Z',
      '2026-12-31T23:59:59.999999Z',
      '2027-01-01T00:00:00Z',
      '2028-02-29T03:00:00Z',
    ];
    for (var i = 0; i < dates.length; i++) {
      await insertInvestment(
        db,
        'd$i',
        BigInt.from(i),
        allocatedOn: dates[i],
        createdAt: instants[i % instants.length],
      );
    }

    for (var i = 0; i < dates.length; i++) {
      final row = await (db.select(
        db.investmentAllocations,
      )..where((t) => t.id.equals('d$i'))).getSingle();
      expect(row.allocatedOn, dates[i]);
      expect(row.createdAt, instants[i % instants.length]);
    }
    // ordenação lexicográfica = ordenação cronológica
    final ordered =
        await (db.select(db.investmentAllocations)
              ..orderBy([(t) => OrderingTerm.asc(t.allocatedOn)]))
            .map((r) => r.allocatedOn)
            .get();
    expect(ordered, [...dates]..sort());
    // filtro por intervalo [início, fim) do período
    final inPeriod =
        await (db.select(db.investmentAllocations)..where(
              (t) =>
                  t.allocatedOn.isBiggerOrEqualValue('2026-11-01') &
                  t.allocatedOn.isSmallerThanValue('2026-12-01'),
            ))
            .map((r) => r.allocatedOn)
            .get();
    expect(inPeriod.toSet(), {'2026-11-01', '2026-11-30'});
  });

  test('persiste dados após fechar e reabrir a conexão', () async {
    var db = open();
    await seed(db);
    final big = BigInt.parse('9007199254740993');
    await insertInvestment(
      db,
      'persist-1',
      big,
      allocatedOn: '2026-11-30',
      createdAt: '2026-11-30T23:59:59.999Z',
    );
    await db.close();

    db = open();
    addTearDown(db.close);
    final row = await db.select(db.investmentAllocations).getSingle();
    expect(row.id, 'persist-1');
    expect(row.amountCentavos, big);
    expect(row.allocatedOn, '2026-11-30');
    expect(row.createdAt, '2026-11-30T23:59:59.999Z');
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.read<int>('foreign_keys'), 1);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 8);
  });
}
