import 'package:drift/drift.dart';

import 'schema_versions.dart';

part 'app_database.g.dart';

/// Persiste centavos como texto decimal para manter a precisão no Flutter Web.
class BigIntTextConverter extends TypeConverter<BigInt, String> {
  const BigIntTextConverter();

  static final BigInt maxValue = BigInt.parse('9223372036854775807');

  @override
  BigInt fromSql(String fromDb) {
    final value = BigInt.parse(fromDb);
    _validate(value);
    if (value.toString() != fromDb) {
      throw FormatException('Centavos precisam usar texto decimal canônico.');
    }
    return value;
  }

  @override
  String toSql(BigInt value) {
    _validate(value);
    return value.toString();
  }

  void _validate(BigInt value) {
    if (value.isNegative || value > maxValue) {
      throw RangeError('Centavos devem caber em um BIGINT não negativo.');
    }
  }
}

abstract class OwnedRecord extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, id};
}

class UserPreferences extends Table {
  TextColumn get ownerId => text()();
  TextColumn get theme => text().nullable()();
  TextColumn get timeZoneId =>
      text().withDefault(const Constant('America/Sao_Paulo'))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId};
}

class PeriodConfigurations extends OwnedRecord {
  TextColumn get mode => text()();
  IntColumn get customStartDay => integer().nullable()();
  TextColumn get effectiveFrom => text()();

  @override
  List<String> get customConstraints => [
    '''CHECK ((mode = 'calendar_month' AND custom_start_day IS NULL) OR
            (mode = 'custom_cycle' AND custom_start_day BETWEEN 1 AND 31))''',
    "CHECK (mode IN ('calendar_month', 'custom_cycle'))",
  ];
}

class AccountingPeriods extends OwnedRecord {
  TextColumn get configurationId => text()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();

  @override
  List<String> get customConstraints => [
    'CHECK (start_date < end_date)',
    'UNIQUE (owner_id, start_date)',
    'FOREIGN KEY (owner_id, configuration_id) '
        'REFERENCES period_configurations (owner_id, id) ON DELETE RESTRICT',
  ];
}

class Categories extends OwnedRecord {
  TextColumn get kind => text()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('income', 'expense'))",
  ];
}

class Subcategories extends OwnedRecord {
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (owner_id, category_id) '
        'REFERENCES categories (owner_id, id) ON DELETE RESTRICT',
    'UNIQUE (owner_id, category_id, id)',
  ];
}

abstract class RecurrenceTemplate extends OwnedRecord {
  TextColumn get description => text().nullable()();
  TextColumn get frequency => text()();
  TextColumn get startsOn => text()();
  IntColumn get monthlyReferenceDay => integer().nullable()();
  TextColumn get valueMode => text()();
  TextColumn get defaultAmountCentavos =>
      text().map(const BigIntTextConverter()).nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get subcategoryId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => [
    '''CHECK ((frequency = 'monthly' AND monthly_reference_day BETWEEN 1 AND 31) OR
            (frequency = 'by_period' AND monthly_reference_day IS NULL))''',
    "CHECK (frequency IN ('monthly', 'by_period'))",
    '''CHECK ((value_mode = 'fixed' AND default_amount_centavos IS NOT NULL) OR
            (value_mode = 'variable' AND default_amount_centavos IS NULL))''',
    "CHECK (value_mode IN ('fixed', 'variable'))",
    '''CHECK (
      default_amount_centavos IS NULL OR (
        length(default_amount_centavos) BETWEEN 1 AND 19
        AND default_amount_centavos NOT GLOB '*[^0-9]*'
        AND (default_amount_centavos = '0' OR
            substr(default_amount_centavos, 1, 1) BETWEEN '1' AND '9')
        AND (length(default_amount_centavos) < 19 OR
            default_amount_centavos <= '9223372036854775807')
      )
    )''',
    'FOREIGN KEY (owner_id, category_id) '
        'REFERENCES categories (owner_id, id) ON DELETE RESTRICT',
    'FOREIGN KEY (owner_id, category_id, subcategory_id) '
        'REFERENCES subcategories (owner_id, category_id, id) ON DELETE RESTRICT',
    'CHECK (subcategory_id IS NULL OR category_id IS NOT NULL)',
  ];
}

class IncomeRecurrenceTemplates extends RecurrenceTemplate {}

class ExpenseRecurrenceTemplates extends RecurrenceTemplate {}

abstract class CashEntry extends OwnedRecord {
  TextColumn get description => text().nullable()();
  TextColumn get amountCentavos =>
      text().map(const BigIntTextConverter()).nullable()();
  TextColumn get status => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get subcategoryId => text().nullable()();
  TextColumn get recurrenceTemplateId => text().nullable()();
  TextColumn get scheduledForDate => text().nullable()();
  TextColumn get scheduledPeriodId => text().nullable()();
}

@TableIndex.sql('''
  CREATE UNIQUE INDEX unique_income_occurrence_schedule
  ON income_entries (owner_id, recurrence_template_id, scheduled_for_date)
  WHERE recurrence_template_id IS NOT NULL
''')
@TableIndex(
  name: 'income_entries_period_idx',
  columns: {#ownerId, #accountingPeriodId},
)
class IncomeEntries extends CashEntry {
  TextColumn get receivedOn => text().nullable()();
  TextColumn get accountingPeriodId => text().nullable()();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (owner_id, accounting_period_id) '
        'REFERENCES accounting_periods (owner_id, id) ON DELETE RESTRICT',
    'FOREIGN KEY (owner_id, recurrence_template_id) '
        'REFERENCES income_recurrence_templates (owner_id, id) ON DELETE RESTRICT',
    'FOREIGN KEY (owner_id, category_id) '
        'REFERENCES categories (owner_id, id) ON DELETE RESTRICT',
    'FOREIGN KEY (owner_id, category_id, subcategory_id) '
        'REFERENCES subcategories (owner_id, category_id, id) ON DELETE RESTRICT',
    '''CHECK (
      amount_centavos IS NULL OR (
        length(amount_centavos) BETWEEN 1 AND 19
        AND amount_centavos NOT GLOB '*[^0-9]*'
        AND (amount_centavos = '0' OR
            substr(amount_centavos, 1, 1) BETWEEN '1' AND '9')
        AND (length(amount_centavos) < 19 OR
            amount_centavos <= '9223372036854775807')
      )
    )''',
    '''CHECK (status IN ('pending', 'received', 'cancelled'))''',
    '''CHECK (status <> 'received' OR
            (received_on IS NOT NULL AND accounting_period_id IS NOT NULL
            AND amount_centavos IS NOT NULL))''',
    '''CHECK (amount_centavos IS NOT NULL OR recurrence_template_id IS NOT NULL)''',
    '''CHECK (status <> 'pending' OR
        (received_on IS NULL AND accounting_period_id IS NULL))''',
    'CHECK (subcategory_id IS NULL OR category_id IS NOT NULL)',
  ];
}

@TableIndex.sql('''
  CREATE UNIQUE INDEX unique_expense_occurrence_schedule
  ON expense_entries (owner_id, recurrence_template_id, scheduled_for_date)
  WHERE recurrence_template_id IS NOT NULL
''')
@TableIndex(
  name: 'expense_entries_period_idx',
  columns: {#ownerId, #accountingPeriodId},
)
class ExpenseEntries extends CashEntry {
  TextColumn get accountingPeriodId => text()();
  TextColumn get competenceOn => text()();
  TextColumn get dueOn => text().nullable()();
  TextColumn get paidOn => text().nullable()();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (owner_id, accounting_period_id) '
        'REFERENCES accounting_periods (owner_id, id) ON DELETE RESTRICT',
    'FOREIGN KEY (owner_id, recurrence_template_id) '
        'REFERENCES expense_recurrence_templates (owner_id, id) ON DELETE RESTRICT',
    'FOREIGN KEY (owner_id, category_id) '
        'REFERENCES categories (owner_id, id) ON DELETE RESTRICT',
    'FOREIGN KEY (owner_id, category_id, subcategory_id) '
        'REFERENCES subcategories (owner_id, category_id, id) ON DELETE RESTRICT',
    '''CHECK (
      amount_centavos IS NULL OR (
        length(amount_centavos) BETWEEN 1 AND 19
        AND amount_centavos NOT GLOB '*[^0-9]*'
        AND (amount_centavos = '0' OR
            substr(amount_centavos, 1, 1) BETWEEN '1' AND '9')
        AND (length(amount_centavos) < 19 OR
            amount_centavos <= '9223372036854775807')
      )
    )''',
    '''CHECK (status IN ('pending', 'paid', 'cancelled'))''',
    '''CHECK (status <> 'paid' OR paid_on IS NOT NULL)''',
    '''CHECK (status <> 'pending' OR paid_on IS NULL)''',
    '''CHECK (amount_centavos IS NOT NULL OR recurrence_template_id IS NOT NULL)''',
    'CHECK (subcategory_id IS NULL OR category_id IS NOT NULL)',
  ];
}

@TableIndex(
  name: 'investment_allocations_period_idx',
  columns: {#ownerId, #accountingPeriodId},
)
class InvestmentAllocations extends OwnedRecord {
  TextColumn get amountCentavos => text().map(const BigIntTextConverter())();
  TextColumn get allocatedOn => text()();
  TextColumn get accountingPeriodId => text()();
  TextColumn get cancelledAt => text().nullable()();

  @override
  List<String> get customConstraints => [
    '''CHECK (
      amount_centavos IS NULL OR (
        length(amount_centavos) BETWEEN 1 AND 19
        AND amount_centavos NOT GLOB '*[^0-9]*'
        AND (amount_centavos = '0' OR
            substr(amount_centavos, 1, 1) BETWEEN '1' AND '9')
        AND (length(amount_centavos) < 19 OR
            amount_centavos <= '9223372036854775807')
      )
    )''',
    'FOREIGN KEY (owner_id, accounting_period_id) '
        'REFERENCES accounting_periods (owner_id, id) ON DELETE RESTRICT',
  ];
}

class AuditEvents extends OwnedRecord {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get actorId => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get oldSnapshotJson => text().nullable()();
  TextColumn get newSnapshotJson => text().nullable()();
  TextColumn get operationId => text()();
}

class AppliedSyncOperations extends Table {
  TextColumn get ownerId => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get contentHash => text()();
  TextColumn get resultJson => text()();
  TextColumn get appliedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, idempotencyKey};
}

class SyncConflicts extends OwnedRecord {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get expectedVersion => integer()();
  IntColumn get remoteVersion => integer()();
  TextColumn get localSnapshotJson => text()();
  TextColumn get remoteSnapshotJson => text()();
  TextColumn get state => text()();
  TextColumn get resolutionJson => text().nullable()();
}

@TableIndex(name: 'sync_outbox_state_idx', columns: {#ownerId, #state})
class SyncOutbox extends Table {
  TextColumn get ownerId => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get expectedVersion => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get state => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextRetryAt => text().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, idempotencyKey};
}

/// Ponto até onde cada tabela já foi baixada do servidor (Entrega 27B).
/// `lastOrderValue` e `lastId` são o último (`updated_at`/`occurred_at`, `id`)
/// gravado; o próximo download recomeça logo depois dele.
class SyncCursors extends Table {
  TextColumn get ownerId => text()();
  TextColumn get sourceTable => text()();
  TextColumn get lastOrderValue => text()();
  TextColumn get lastId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, sourceTable};
}

@DriftDatabase(
  tables: [
    UserPreferences,
    PeriodConfigurations,
    AccountingPeriods,
    Categories,
    Subcategories,
    IncomeRecurrenceTemplates,
    ExpenseRecurrenceTemplates,
    IncomeEntries,
    ExpenseEntries,
    InvestmentAllocations,
    AuditEvents,
    AppliedSyncOperations,
    SyncConflicts,
    SyncOutbox,
    SyncCursors,
  ],
)
class PorquinhoDatabase extends _$PorquinhoDatabase {
  /// A conexão é injetada; a abertura persistente deve usar
  /// `openEncryptedExecutor` (encrypted_connection.dart).
  PorquinhoDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    onUpgrade: stepByStep(
      // v2: índices por período e por estado do outbox (sem mudar colunas).
      from1To2: (migrator, schema) async {
        await migrator.create(schema.incomeEntriesPeriodIdx);
        await migrator.create(schema.expenseEntriesPeriodIdx);
        await migrator.create(schema.investmentAllocationsPeriodIdx);
        await migrator.create(schema.syncOutboxStateIdx);
      },
      // v3 (Entrega 27B): alinha o esquema local ao do servidor para o
      // download — `by_period` (era `per_period`), descrição opcional nos
      // lançamentos, descrição nas recorrências — e cria `sync_cursors`.
      from2To3: (migrator, schema) async {
        await migrator.alterTable(
          TableMigration(
            schema.incomeRecurrenceTemplates,
            columnTransformer: {
              schema.incomeRecurrenceTemplates.frequency:
                  const CustomExpression(
                    "CASE frequency WHEN 'per_period' THEN 'by_period' "
                    'ELSE frequency END',
                  ),
            },
            newColumns: [schema.incomeRecurrenceTemplates.description],
          ),
        );
        await migrator.alterTable(
          TableMigration(
            schema.expenseRecurrenceTemplates,
            columnTransformer: {
              schema.expenseRecurrenceTemplates.frequency:
                  const CustomExpression(
                    "CASE frequency WHEN 'per_period' THEN 'by_period' "
                    'ELSE frequency END',
                  ),
            },
            newColumns: [schema.expenseRecurrenceTemplates.description],
          ),
        );
        await migrator.alterTable(TableMigration(schema.incomeEntries));
        await migrator.alterTable(TableMigration(schema.expenseEntries));
        await migrator.create(schema.syncCursors);
      },
    ),
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );
}
