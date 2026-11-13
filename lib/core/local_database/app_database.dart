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

  /// Progresso do assistente inicial (RF024, D7): JSON `{etapa: done|skipped}`.
  TextColumn get onboarding => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {ownerId};
}

/// Configuração única de período (reestruturação P6, RN001/RN002): uma linha
/// por usuário, `id` = dono. Os períodos são calculados a partir dela.
class PeriodSettings extends OwnedRecord {
  TextColumn get mode => text()();
  IntColumn get customStartDay => integer().nullable()();

  @override
  List<String> get customConstraints => [
    '''CHECK ((mode = 'calendar_month' AND custom_start_day IS NULL) OR
            (mode = 'custom_cycle' AND custom_start_day BETWEEN 1 AND 31))''',
    "CHECK (mode IN ('calendar_month', 'custom_cycle'))",
    'CHECK (id = owner_id)',
  ];
}

class Categories extends OwnedRecord {
  TextColumn get kind => text()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Visual da categoria (chaves do conjunto fixo do app); subcategorias
  /// herdam. Mesmos padrões do servidor.
  TextColumn get iconKey => text().withDefault(const Constant('category'))();
  TextColumn get colorKey => text().withDefault(const Constant('gray'))();

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
}

@TableIndex.sql('''
  CREATE UNIQUE INDEX unique_income_occurrence_schedule
  ON income_entries (owner_id, recurrence_template_id, scheduled_for_date)
  WHERE recurrence_template_id IS NOT NULL
''')
class IncomeEntries extends CashEntry {
  TextColumn get receivedOn => text().nullable()();

  @override
  List<String> get customConstraints => [
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
            (received_on IS NOT NULL AND amount_centavos IS NOT NULL))''',
    '''CHECK (amount_centavos IS NOT NULL OR recurrence_template_id IS NOT NULL)''',
    '''CHECK (status <> 'pending' OR received_on IS NULL)''',
    'CHECK (subcategory_id IS NULL OR category_id IS NOT NULL)',
  ];
}

@TableIndex.sql('''
  CREATE UNIQUE INDEX unique_expense_occurrence_schedule
  ON expense_entries (owner_id, recurrence_template_id, scheduled_for_date)
  WHERE recurrence_template_id IS NOT NULL
''')
class ExpenseEntries extends CashEntry {
  TextColumn get competenceOn => text()();
  TextColumn get dueOn => text().nullable()();
  TextColumn get paidOn => text().nullable()();

  @override
  List<String> get customConstraints => [
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

/// Modelo de investimento recorrente (Fase 6, D7–D9): só agenda e valor padrão
/// fixo; sem descrição, categoria nem valor variável.
class InvestmentRecurrenceTemplates extends OwnedRecord {
  TextColumn get frequency => text()();
  TextColumn get startsOn => text()();
  IntColumn get monthlyReferenceDay => integer().nullable()();
  TextColumn get defaultAmountCentavos =>
      text().map(const BigIntTextConverter())();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => [
    '''CHECK ((frequency = 'monthly' AND monthly_reference_day BETWEEN 1 AND 31) OR
            (frequency = 'by_period' AND monthly_reference_day IS NULL))''',
    "CHECK (frequency IN ('monthly', 'by_period'))",
    '''CHECK (
      length(default_amount_centavos) BETWEEN 1 AND 19
      AND default_amount_centavos NOT GLOB '*[^0-9]*'
      AND (default_amount_centavos = '0' OR
          substr(default_amount_centavos, 1, 1) BETWEEN '1' AND '9')
      AND (length(default_amount_centavos) < 19 OR
          default_amount_centavos <= '9223372036854775807')
    )''',
  ];
}

@TableIndex.sql('''
  CREATE UNIQUE INDEX unique_investment_occurrence_schedule
  ON investment_allocations (owner_id, recurrence_template_id, scheduled_for_date)
  WHERE recurrence_template_id IS NOT NULL
''')
class InvestmentAllocations extends OwnedRecord {
  TextColumn get amountCentavos => text().map(const BigIntTextConverter())();
  TextColumn get allocatedOn => text()();

  TextColumn get cancelledAt => text().nullable()();
  TextColumn get recurrenceTemplateId => text().nullable()();
  TextColumn get scheduledForDate => text().nullable()();

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
    'FOREIGN KEY (owner_id, recurrence_template_id) '
        'REFERENCES investment_recurrence_templates (owner_id, id) '
        'ON DELETE RESTRICT',
    '''CHECK (
      (recurrence_template_id IS NULL AND scheduled_for_date IS NULL)
      OR (recurrence_template_id IS NOT NULL AND scheduled_for_date IS NOT NULL)
    )''',
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
    PeriodSettings,
    Categories,
    Subcategories,
    IncomeRecurrenceTemplates,
    ExpenseRecurrenceTemplates,
    InvestmentRecurrenceTemplates,
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
  int get schemaVersion => 8;

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
      // v4 (Fase 6, Entrega 56): recorrência de investimento — tabela do
      // modelo e campos de ocorrência (opcionais) em investment_allocations.
      from3To4: (migrator, schema) async {
        await migrator.create(schema.investmentRecurrenceTemplates);
        await migrator.alterTable(
          TableMigration(
            schema.investmentAllocations,
            newColumns: [
              schema.investmentAllocations.recurrenceTemplateId,
              schema.investmentAllocations.scheduledForDate,
              schema.investmentAllocations.scheduledPeriodId,
            ],
          ),
        );
        await migrator.create(schema.uniqueInvestmentOccurrenceSchedule);
      },
      // v5 (Fase 7, Entrega 67): progresso do assistente inicial na conta.
      from4To5: (migrator, schema) async {
        await migrator.addColumn(
          schema.userPreferences,
          schema.userPreferences.onboarding,
        );
      },
      // v6 (Renovação visual V2): ícone e cor das categorias.
      from5To6: (migrator, schema) async {
        await migrator.addColumn(schema.categories, schema.categories.iconKey);
        await migrator.addColumn(schema.categories, schema.categories.colorKey);
      },
      // v7 (Reestruturação de períodos P6): configuração única de período
      // (a que vale hoje, como no servidor) e vínculo com o período opcional.
      from6To7: (migrator, schema) async {
        await migrator.create(schema.periodSettings);
        final now = DateTime.now().toUtc().toIso8601String();
        await customStatement(
          'INSERT INTO period_settings (id, owner_id, version, created_at, '
          'updated_at, mode, custom_start_day) '
          'SELECT c.owner_id, c.owner_id, 1, ?, ?, c.mode, c.custom_start_day '
          'FROM period_configurations c WHERE c.rowid = ('
          'SELECT c2.rowid FROM period_configurations c2 '
          'WHERE c2.owner_id = c.owner_id ORDER BY '
          "(c2.effective_from <= date('now', 'localtime')) DESC, "
          "CASE WHEN c2.effective_from <= date('now', 'localtime') "
          'THEN c2.effective_from END DESC, c2.effective_from ASC LIMIT 1)',
          [now, now],
        );
        await migrator.alterTable(TableMigration(schema.incomeEntries));
        await migrator.alterTable(TableMigration(schema.expenseEntries));
        await migrator.alterTable(TableMigration(schema.investmentAllocations));
      },
      // v8 (Reestruturação de períodos P7): sem períodos gravados nem vínculo
      // do lançamento com o período. Operações e conflitos pendentes de
      // períodos antigos não têm mais destino no servidor e são descartados.
      from7To8: (migrator, schema) async {
        await customStatement(
          'DELETE FROM sync_outbox WHERE entity_type IN '
          "('accounting_period', 'period_configuration')",
        );
        await customStatement(
          'DELETE FROM sync_conflicts WHERE entity_type IN '
          "('accounting_period', 'period_configuration')",
        );
        await customStatement(
          "DELETE FROM sync_cursors WHERE source_table IN "
          "('accounting_periods', 'period_configurations')",
        );
        for (final index in [
          'income_entries_period_idx',
          'expense_entries_period_idx',
          'investment_allocations_period_idx',
        ]) {
          await customStatement('DROP INDEX IF EXISTS $index');
        }
        await migrator.alterTable(TableMigration(schema.incomeEntries));
        await migrator.alterTable(TableMigration(schema.expenseEntries));
        await migrator.alterTable(TableMigration(schema.investmentAllocations));
        await customStatement('DROP TABLE IF EXISTS accounting_periods');
        await customStatement('DROP TABLE IF EXISTS period_configurations');
      },
    ),
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );
}
