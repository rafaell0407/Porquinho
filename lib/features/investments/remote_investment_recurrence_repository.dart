import '../../core/domain/calendar_date.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../categories/category_models.dart';
import '../recurrence/recurrence_models.dart';
import '../sync/remote_table_reader.dart';
import '../sync/sync_models.dart';
import 'investment_models.dart';
import 'investment_recurrence_repository.dart';

/// Web: lê e grava direto no servidor (somente online).
class RemoteInvestmentRecurrenceRepository
    implements InvestmentRecurrenceRepository {
  RemoteInvestmentRecurrenceRepository(
    this._reader,
    this._gateway, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final RemoteTableReader _reader;
  final SyncRemoteGateway _gateway;
  final String Function() _newId;

  static const _table = 'investment_recurrence_templates';
  static const _rpc = 'apply_investment_recurrence_template_change';

  @override
  Future<List<InvestmentTemplate>> templates() async {
    final rows = await _reader.select(_table, orderBy: 'created_at');
    final result = rows.map(_fromRow).toList();
    result.sort((a, b) => a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1));
    return result;
  }

  @override
  Future<InvestmentTemplate?> template(String id) async {
    final rows = await _reader.select(
      _table,
      filters: [RemoteFilter.eq('id', id)],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  InvestmentTemplate _fromRow(Map<String, dynamic> d) {
    final amount = d['default_amount_centavos'];
    return InvestmentTemplate(
      id: d['id'] as String,
      frequency: RecurrenceFrequency.fromDb(d['frequency'] as String),
      startsOn: CalendarDate.parse(d['starts_on'] as String),
      monthlyReferenceDay: (d['monthly_reference_day'] as num?)?.toInt(),
      defaultAmount: amount is num
          ? BigInt.from(amount)
          : BigInt.parse(amount.toString()),
      isActive: d['is_active'] as bool? ?? true,
      version: (d['version'] as num).toInt(),
    );
  }

  @override
  Future<ScheduleFacts> scheduleFacts(String templateId) async {
    final rows = await _reader.select(
      'investment_allocations',
      filters: [RemoteFilter.eq('recurrence_template_id', templateId)],
      orderBy: 'scheduled_for_date',
    );
    if (rows.isEmpty) return const ScheduleFacts();
    final last = rows.last['scheduled_for_date'] as String;
    return ScheduleFacts(lastScheduled: CalendarDate.parse(last));
  }

  Future<void> _call(Map<String, dynamic> params) async {
    final Map<String, dynamic> response;
    try {
      response = await _gateway.call(_rpc, {
        'p_operation_id': _newId(),
        ...params,
      });
    } on SyncRejectedError catch (e) {
      throw ChangeRejectedException(e.message);
    }
    if (response['status'] == 'conflict') throw const ChangeConflictException();
  }

  @override
  Future<void> updateTemplate(
    InvestmentTemplate current,
    InvestmentTemplateEdit edit,
    CalendarDate startsOn,
  ) => _call({
    'p_action': 'update',
    'p_template_id': current.id,
    'p_expected_version': current.version,
    'p_payload': {
      'frequency': edit.frequency.dbValue,
      'starts_on': startsOn.toIso(),
      'monthly_reference_day': edit.frequency == RecurrenceFrequency.monthly
          ? edit.monthlyReferenceDay
          : null,
      'default_amount_centavos': edit.defaultAmount.toString(),
    },
  });

  @override
  Future<void> stop(InvestmentTemplate current) => _call({
    'p_action': 'deactivate',
    'p_template_id': current.id,
    'p_expected_version': current.version,
    'p_payload': null,
  });
}
