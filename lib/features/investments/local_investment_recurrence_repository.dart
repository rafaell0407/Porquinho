import 'package:drift/drift.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../../core/local_database/app_database.dart';
import '../recurrence/recurrence_models.dart';
import '../sync/local_change_recorder.dart';
import 'investment_models.dart';
import 'investment_recurrence_repository.dart';

/// Celular: alterações do modelo gravam registro, auditoria e fila na mesma
/// transação.
class LocalInvestmentRecurrenceRepository
    implements InvestmentRecurrenceRepository {
  LocalInvestmentRecurrenceRepository(
    this._db,
    this._ownerId,
    this._recorder, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PorquinhoDatabase _db;
  final String _ownerId;
  final LocalChangeRecorder _recorder;
  final DateTime Function() _clock;

  static const entityType = 'investment_recurrence_template';
  static const rpc = 'apply_investment_recurrence_template_change';

  @override
  Future<List<InvestmentTemplate>> templates() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM investment_recurrence_templates WHERE owner_id = ? '
          'ORDER BY is_active DESC, created_at',
          variables: [Variable.withString(_ownerId)],
        )
        .get();
    return rows.map((r) => _fromRow(r.data)).toList();
  }

  @override
  Future<InvestmentTemplate?> template(String id) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM investment_recurrence_templates '
          'WHERE owner_id = ? AND id = ?',
          variables: [Variable.withString(_ownerId), Variable.withString(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _fromRow(row.data);
  }

  InvestmentTemplate _fromRow(Map<String, Object?> d) => InvestmentTemplate(
    id: d['id']! as String,
    frequency: RecurrenceFrequency.fromDb(d['frequency']! as String),
    startsOn: CalendarDate.parse(d['starts_on']! as String),
    monthlyReferenceDay: d['monthly_reference_day'] as int?,
    defaultAmount: BigInt.parse(d['default_amount_centavos']! as String),
    isActive: (d['is_active'] as int? ?? 1) != 0,
    version: d['version']! as int,
  );

  @override
  Future<ScheduleFacts> scheduleFacts(String templateId) async {
    final row = await _db
        .customSelect(
          'SELECT MAX(scheduled_for_date) AS last FROM investment_allocations '
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
    InvestmentTemplate current,
    InvestmentTemplateEdit edit,
    CalendarDate startsOn,
  ) {
    final now = _clock().toUtc().toIso8601String();
    final next = current.version + 1;
    final payload = <String, dynamic>{
      'frequency': edit.frequency.dbValue,
      'starts_on': startsOn.toIso(),
      'monthly_reference_day': edit.frequency == RecurrenceFrequency.monthly
          ? edit.monthlyReferenceDay
          : null,
      'default_amount_centavos': edit.defaultAmount.toString(),
    };
    return _recorder.record(
      ownerId: _ownerId,
      entityType: entityType,
      entityId: current.id,
      operation: 'update',
      expectedVersion: current.version,
      rpc: rpc,
      params: {
        'p_action': 'update',
        'p_template_id': current.id,
        'p_expected_version': current.version,
        'p_payload': payload,
      },
      dependsOn: [current.id],
      oldSnapshot: current.toSnapshot(),
      newSnapshot: {...current.toSnapshot(), ...payload, 'version': next},
      apply: () => _db.customStatement(
        'UPDATE investment_recurrence_templates SET frequency = ?, '
        'starts_on = ?, monthly_reference_day = ?, '
        'default_amount_centavos = ?, version = ?, updated_at = ? '
        'WHERE owner_id = ? AND id = ?',
        [
          payload['frequency'],
          payload['starts_on'],
          payload['monthly_reference_day'],
          payload['default_amount_centavos'],
          next,
          now,
          _ownerId,
          current.id,
        ],
      ),
    );
  }

  @override
  Future<void> stop(InvestmentTemplate current) {
    final now = _clock().toUtc().toIso8601String();
    final next = current.version + 1;
    return _recorder.record(
      ownerId: _ownerId,
      entityType: entityType,
      entityId: current.id,
      operation: 'deactivate',
      expectedVersion: current.version,
      rpc: rpc,
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
        'UPDATE investment_recurrence_templates SET is_active = 0, '
        'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
        [next, now, _ownerId, current.id],
      ),
    );
  }
}
