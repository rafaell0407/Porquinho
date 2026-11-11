import 'package:drift/drift.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../../core/local_database/app_database.dart';
import '../entries/entry_models.dart';
import '../sync/local_change_recorder.dart';
import 'recurrence_models.dart';
import 'recurrence_repository.dart';

/// Celular: alterações do modelo gravam registro, auditoria e fila na mesma
/// transação; a geração das ocorrências é local e idempotente (RN038).
class LocalRecurrenceRepository implements RecurrenceRepository {
  LocalRecurrenceRepository(
    this._db,
    this._ownerId,
    this._recorder, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PorquinhoDatabase _db;
  final String _ownerId;

  /// Sem gravador (`null`) só a geração local funciona; é o uso da sincronização.
  final LocalChangeRecorder? _recorder;
  final DateTime Function() _clock;

  @override
  Future<List<RecurringTemplate>> templates() async {
    final result = <RecurringTemplate>[];
    for (final kind in EntryKind.values) {
      final rows = await _db
          .customSelect(
            'SELECT * FROM ${kind.templateTable} WHERE owner_id = ? '
            'ORDER BY is_active DESC, created_at',
            variables: [Variable.withString(_ownerId)],
          )
          .get();
      result.addAll(rows.map((r) => _fromRow(kind, r.data)));
    }
    return result;
  }

  @override
  Future<RecurringTemplate?> template(EntryKind kind, String id) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM ${kind.templateTable} WHERE owner_id = ? AND id = ?',
          variables: [Variable.withString(_ownerId), Variable.withString(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _fromRow(kind, row.data);
  }

  RecurringTemplate _fromRow(EntryKind kind, Map<String, Object?> d) {
    final amount = d['default_amount_centavos'] as String?;
    return RecurringTemplate(
      id: d['id']! as String,
      kind: kind,
      description: d['description'] as String?,
      frequency: RecurrenceFrequency.fromDb(d['frequency']! as String),
      startsOn: CalendarDate.parse(d['starts_on']! as String),
      monthlyReferenceDay: d['monthly_reference_day'] as int?,
      variableValue: d['value_mode'] == 'variable',
      defaultAmount: amount == null ? null : BigInt.parse(amount),
      categoryId: d['category_id'] as String?,
      subcategoryId: d['subcategory_id'] as String?,
      isActive: (d['is_active'] as int? ?? 1) != 0,
      version: d['version']! as int,
    );
  }

  @override
  Future<ScheduleFacts> scheduleFacts(EntryKind kind, String templateId) async {
    final row = await _db
        .customSelect(
          'SELECT MAX(scheduled_for_date) AS last FROM ${kind.table} '
          'WHERE owner_id = ? AND recurrence_template_id = ?',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(templateId),
          ],
        )
        .getSingle();
    final last = row.data['last'] as String?;
    if (last == null) return const ScheduleFacts();
    final period = await _db
        .customSelect(
          'SELECT end_date FROM accounting_periods WHERE owner_id = ? '
          'AND start_date <= ? AND ? < end_date',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(last),
            Variable.withString(last),
          ],
        )
        .getSingleOrNull();
    return ScheduleFacts(
      lastScheduled: CalendarDate.parse(last),
      lastPeriodEnd: period == null
          ? null
          : CalendarDate.parse(period.read<String>('end_date')),
    );
  }

  @override
  Future<void> updateTemplate(
    RecurringTemplate current,
    TemplateEdit edit,
    CalendarDate startsOn,
  ) {
    final now = _clock().toUtc().toIso8601String();
    final next = current.version + 1;
    final payload = <String, dynamic>{
      'description': edit.description,
      'frequency': edit.frequency.dbValue,
      'starts_on': startsOn.toIso(),
      'monthly_reference_day': edit.frequency == RecurrenceFrequency.monthly
          ? edit.monthlyReferenceDay
          : null,
      'value_mode': edit.variableValue ? 'variable' : 'fixed',
      'default_amount_centavos': edit.variableValue
          ? null
          : edit.defaultAmount?.toString(),
      'category_id': edit.categoryId,
      'subcategory_id': edit.subcategoryId,
    };
    return _recorder!.record(
      ownerId: _ownerId,
      entityType: current.kind.templateEntityType,
      entityId: current.id,
      operation: 'update',
      expectedVersion: current.version,
      rpc: current.kind.templateRpc,
      params: {
        'p_action': 'update',
        'p_template_id': current.id,
        'p_expected_version': current.version,
        'p_payload': payload,
      },
      dependsOn: [current.id, ?edit.categoryId, ?edit.subcategoryId],
      oldSnapshot: current.toSnapshot(),
      newSnapshot: {...current.toSnapshot(), ...payload, 'version': next},
      apply: () => _db.customStatement(
        'UPDATE ${current.kind.templateTable} SET description = ?, '
        'frequency = ?, starts_on = ?, monthly_reference_day = ?, '
        'value_mode = ?, default_amount_centavos = ?, category_id = ?, '
        'subcategory_id = ?, version = ?, updated_at = ? '
        'WHERE owner_id = ? AND id = ?',
        [
          payload['description'],
          payload['frequency'],
          payload['starts_on'],
          payload['monthly_reference_day'],
          payload['value_mode'],
          payload['default_amount_centavos'],
          payload['category_id'],
          payload['subcategory_id'],
          next,
          now,
          _ownerId,
          current.id,
        ],
      ),
    );
  }

  @override
  Future<void> stop(RecurringTemplate current) {
    final now = _clock().toUtc().toIso8601String();
    final next = current.version + 1;
    return _recorder!.record(
      ownerId: _ownerId,
      entityType: current.kind.templateEntityType,
      entityId: current.id,
      operation: 'deactivate',
      expectedVersion: current.version,
      rpc: current.kind.templateRpc,
      params: {
        'p_action': 'deactivate',
        'p_template_id': current.id,
        'p_expected_version': current.version,
        'p_payload': null,
      },
      dependsOn: [current.id],
      oldSnapshot: current.toSnapshot(),
      newSnapshot: {
        ...current.toSnapshot(),
        'is_active': false,
        'version': next,
      },
      apply: () => _db.customStatement(
        'UPDATE ${current.kind.templateTable} SET is_active = 0, '
        'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
        [next, now, _ownerId, current.id],
      ),
    );
  }

  /// Gera no aparelho as ocorrências devidas até [today]. O identificador é o
  /// mesmo do servidor (D1), então a geração do servidor e o download depois
  /// reconhecem a mesma ocorrência. Não grava auditoria nem fila: o servidor
  /// gera e audita a sua cópia (RN038).
  @override
  Future<int> generateDue(CalendarDate today) => _db.transaction(() async {
    final periodRows = await _db
        .customSelect(
          'SELECT id, start_date, end_date FROM accounting_periods '
          'WHERE owner_id = ? ORDER BY start_date',
          variables: [Variable.withString(_ownerId)],
        )
        .get();
    final periods = [
      for (final r in periodRows)
        (
          id: r.read<String>('id'),
          range: PeriodRange(
            CalendarDate.parse(r.read<String>('start_date')),
            CalendarDate.parse(r.read<String>('end_date')),
          ),
        ),
    ];
    final now = _clock().toUtc().toIso8601String();
    var created = 0;
    for (final kind in EntryKind.values) {
      final rows = await _db
          .customSelect(
            'SELECT * FROM ${kind.templateTable} '
            'WHERE owner_id = ? AND is_active = 1 ORDER BY id',
            variables: [Variable.withString(_ownerId)],
          )
          .get();
      for (final row in rows) {
        final template = _fromRow(kind, row.data);
        final schedule = template.schedule;
        if (schedule.isMonthly) {
          for (final date in RecurrenceCalendar.monthlyUntil(schedule, today)) {
            final period = periods
                .where((p) => p.range.contains(date))
                .firstOrNull;
            if (await _insertOccurrence(
              kind,
              template,
              date,
              now,
              periodId: period?.id,
            )) {
              created++;
            }
          }
        } else {
          final due = RecurrenceCalendar.periodsUntil(
            schedule.startsOn,
            periods.map((p) => p.range),
            today,
          );
          for (final range in due) {
            final period = periods.firstWhere((p) => p.range == range);
            if (await _insertOccurrence(
              kind,
              template,
              range.start,
              now,
              periodId: period.id,
              scheduledPeriodId: period.id,
            )) {
              created++;
            }
          }
        }
      }
    }
    created += await _generateInvestments(periods, today, now);
    return created;
  });

  /// Investimentos recorrentes (D7): mesma agenda e mesmo identificador das
  /// outras recorrências; entram na sobra do período da data programada, sem
  /// confirmação (D9). Sem período para a data, fica para a próxima rodada.
  Future<int> _generateInvestments(
    List<({String id, PeriodRange range})> periods,
    CalendarDate today,
    String now,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM investment_recurrence_templates '
          'WHERE owner_id = ? AND is_active = 1 ORDER BY id',
          variables: [Variable.withString(_ownerId)],
        )
        .get();
    var created = 0;
    for (final row in rows) {
      final d = row.data;
      final templateId = d['id']! as String;
      final startsOn = CalendarDate.parse(d['starts_on']! as String);
      final amount = d['default_amount_centavos']! as String;
      final monthly = d['frequency'] == 'monthly';
      final schedule = monthly
          ? RecurrenceSchedule.monthly(
              startsOn: startsOn,
              day: d['monthly_reference_day']! as int,
            )
          : RecurrenceSchedule.byPeriod(startsOn: startsOn);
      if (monthly) {
        for (final date in RecurrenceCalendar.monthlyUntil(schedule, today)) {
          final period = periods
              .where((p) => p.range.contains(date))
              .firstOrNull;
          if (period == null) continue;
          if (await _insertInvestment(
            templateId,
            amount,
            date,
            now,
            period.id,
          )) {
            created++;
          }
        }
      } else {
        final due = RecurrenceCalendar.periodsUntil(
          startsOn,
          periods.map((p) => p.range),
          today,
        );
        for (final range in due) {
          final period = periods.firstWhere((p) => p.range == range);
          if (await _insertInvestment(
            templateId,
            amount,
            range.start,
            now,
            period.id,
            scheduledPeriodId: period.id,
          )) {
            created++;
          }
        }
      }
    }
    return created;
  }

  Future<bool> _insertInvestment(
    String templateId,
    String amount,
    CalendarDate date,
    String now,
    String periodId, {
    String? scheduledPeriodId,
  }) async {
    final exists = await _db
        .customSelect(
          'SELECT 1 FROM investment_allocations WHERE owner_id = ? '
          'AND recurrence_template_id = ? AND scheduled_for_date = ?',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(templateId),
            Variable.withString(date.toIso()),
          ],
        )
        .get();
    if (exists.isNotEmpty) return false;
    await _db.customStatement(
      'INSERT INTO investment_allocations (id, owner_id, version, created_at, '
      'updated_at, amount_centavos, allocated_on, accounting_period_id, '
      'recurrence_template_id, scheduled_for_date, scheduled_period_id) '
      'VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        RecurrenceCalendar.occurrenceId(templateId, date),
        _ownerId,
        now,
        now,
        amount,
        date.toIso(),
        periodId,
        templateId,
        date.toIso(),
        scheduledPeriodId,
      ],
    );
    return true;
  }

  /// `true` se criou. Despesa sem período para a data não é criada agora (o
  /// período é criado ao abrir o app; a geração roda de novo a cada abertura).
  Future<bool> _insertOccurrence(
    EntryKind kind,
    RecurringTemplate t,
    CalendarDate date,
    String now, {
    String? periodId,
    String? scheduledPeriodId,
  }) async {
    final income = kind == EntryKind.income;
    if (!income && periodId == null) return false;
    final exists = await _db
        .customSelect(
          'SELECT 1 FROM ${kind.table} WHERE owner_id = ? '
          'AND recurrence_template_id = ? AND scheduled_for_date = ?',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(t.id),
            Variable.withString(date.toIso()),
          ],
        )
        .get();
    if (exists.isNotEmpty) return false;
    final iso = date.toIso();
    await _db.customStatement(
      'INSERT INTO ${kind.table} (id, owner_id, version, created_at, '
      'updated_at, description, amount_centavos, status, category_id, '
      'subcategory_id, recurrence_template_id, scheduled_for_date, '
      'scheduled_period_id${income ? '' : ', competence_on, due_on, '
                'accounting_period_id'}) '
      "VALUES (?, ?, 1, ?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?"
      "${income ? '' : ', ?, ?, ?'})",
      [
        RecurrenceCalendar.occurrenceId(t.id, date),
        _ownerId,
        now,
        now,
        t.description,
        t.defaultAmount?.toString(),
        t.categoryId,
        t.subcategoryId,
        t.id,
        iso,
        scheduledPeriodId,
        if (!income) ...[iso, iso, periodId],
      ],
    );
    return true;
  }
}
