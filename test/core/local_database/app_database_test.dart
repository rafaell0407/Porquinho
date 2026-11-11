@TestOn('vm')
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';

void main() {
  late PorquinhoDatabase database;

  setUp(() {
    database = PorquinhoDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('cria o schema completo e habilita chaves estrangeiras', () async {
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .map((row) => row.read<String>('name'))
        .get();

    expect(
      tables,
      containsAll([
        'user_preferences',
        'period_configurations',
        'accounting_periods',
        'categories',
        'subcategories',
        'income_recurrence_templates',
        'expense_recurrence_templates',
        'income_entries',
        'expense_entries',
        'investment_allocations',
        'audit_events',
        'applied_sync_operations',
        'sync_conflicts',
        'sync_outbox',
        'sync_cursors',
      ]),
    );

    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(foreignKeys.read<int>('foreign_keys'), 1);
    final schemaVersion = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(schemaVersion.read<int>('user_version'), 4);
  });

  test('grava e lê centavos exatos no SQLite', () async {
    final amount = BigInt.parse('9007199254740993');
    const ownerId = 'owner-1';
    const now = '2026-11-09T12:00:00Z';

    await database
        .into(database.periodConfigurations)
        .insert(
          PeriodConfigurationsCompanion.insert(
            id: 'config-1',
            ownerId: ownerId,
            mode: 'calendar_month',
            effectiveFrom: '2026-11-01',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.accountingPeriods)
        .insert(
          AccountingPeriodsCompanion.insert(
            id: 'period-1',
            ownerId: ownerId,
            configurationId: 'config-1',
            startDate: '2026-11-01',
            endDate: '2026-12-01',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.investmentAllocations)
        .insert(
          InvestmentAllocationsCompanion.insert(
            id: 'investment-1',
            ownerId: ownerId,
            amountCentavos: amount,
            allocatedOn: '2026-11-09',
            accountingPeriodId: 'period-1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final saved = await database
        .select(database.investmentAllocations)
        .getSingle();
    final raw = await database
        .customSelect(
          'SELECT amount_centavos FROM investment_allocations WHERE id = ?',
          variables: const [Variable<String>('investment-1')],
        )
        .getSingle();

    expect(saved.amountCentavos, amount);
    expect(raw.read<String>('amount_centavos'), '9007199254740993');
  });
}
