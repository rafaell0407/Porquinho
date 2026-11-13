import 'package:drift/drift.dart';

import '../../core/domain/calendar_date.dart';
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
    return ScheduleFacts(lastScheduled: CalendarDate.parse(last));
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
        // Só "Todo mês" gera (13/11/2026); modelos antigos "por período"
        // ficam no histórico, sem novas ocorrências.
        if (!schedule.isMonthly) continue;
        for (final date in RecurrenceCalendar.monthlyUntil(schedule, today)) {
          if (await _insertOccurrence(kind, template, date, now)) created++;
        }
      }
    }
    created += await _generateInvestments(today, now);
    return created;
  });

  /// Investimentos recorrentes (D7): mesma agenda e mesmo identificador das
  /// outras recorrências; entram na sobra do período da data programada, sem
  /// confirmação (D9).
  Future<int> _generateInvestments(CalendarDate today, String now) async {
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
      // Só "Todo mês" gera; modelos antigos "por período" não geram mais.
      if (d['frequency'] != 'monthly') continue;
      final schedule = RecurrenceSchedule.monthly(
        startsOn: startsOn,
        day: d['monthly_reference_day']! as int,
      );
      for (final date in RecurrenceCalendar.monthlyUntil(schedule, today)) {
        if (await _insertInvestment(templateId, amount, date, now)) {
          created++;
        }
      }
    }
    return created;
  }

  /// Já existe ocorrência do modelo [templateId] no mês de [date]? Nunca há
  /// duas no mesmo mês (D2), nem quando a regra do dia mudou (RN038,
  /// 13/11/2026: ocorrências antigas ficam na data em que foram geradas).
  Future<bool> _hasOccurrenceInMonth(
    String table,
    String templateId,
    CalendarDate date,
  ) async {
    final start = CalendarDate(date.year, date.month, 1);
    final next = CalendarDate.addMonthsTo(date.year, date.month, 1);
    final rows = await _db
        .customSelect(
          'SELECT 1 FROM $table WHERE owner_id = ? '
          'AND recurrence_template_id = ? '
          'AND scheduled_for_date >= ? AND scheduled_for_date < ? LIMIT 1',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(templateId),
            Variable.withString(start.toIso()),
            Variable.withString(CalendarDate(next.$1, next.$2, 1).toIso()),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<bool> _insertInvestment(
    String templateId,
    String amount,
    CalendarDate date,
    String now,
  ) async {
    if (await _hasOccurrenceInMonth(
      'investment_allocations',
      templateId,
      date,
    )) {
      return false;
    }
    await _db.customStatement(
      'INSERT INTO investment_allocations (id, owner_id, version, created_at, '
      'updated_at, amount_centavos, allocated_on, '
      'recurrence_template_id, scheduled_for_date) '
      'VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?)',
      [
        RecurrenceCalendar.occurrenceId(templateId, date),
        _ownerId,
        now,
        now,
        amount,
        date.toIso(),
        templateId,
        date.toIso(),
      ],
    );
    return true;
  }

  /// `true` se criou (nunca duas do mesmo modelo no mesmo mês). A despesa
  /// conta no período que contém a data programada (RN004).
  Future<bool> _insertOccurrence(
    EntryKind kind,
    RecurringTemplate t,
    CalendarDate date,
    String now,
  ) async {
    final income = kind == EntryKind.income;
    if (await _hasOccurrenceInMonth(kind.table, t.id, date)) return false;
    final iso = date.toIso();
    await _db.customStatement(
      'INSERT INTO ${kind.table} (id, owner_id, version, created_at, '
      'updated_at, description, amount_centavos, status, category_id, '
      'subcategory_id, recurrence_template_id, scheduled_for_date'
      "${income ? '' : ', competence_on, due_on'}) "
      "VALUES (?, ?, 1, ?, ?, ?, ?, 'pending', ?, ?, ?, ?"
      "${income ? '' : ', ?, ?'})",
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
        if (!income) ...[iso, iso],
      ],
    );
    return true;
  }
}
