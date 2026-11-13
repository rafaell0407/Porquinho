import '../../core/domain/calendar_date.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../categories/category_models.dart';
import '../entries/entry_models.dart';
import '../sync/remote_table_reader.dart';
import '../sync/sync_models.dart';
import 'recurrence_models.dart';
import 'recurrence_repository.dart';

/// Web: lê e grava direto no servidor (somente online).
class RemoteRecurrenceRepository implements RecurrenceRepository {
  RemoteRecurrenceRepository(
    this._reader,
    this._gateway, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final RemoteTableReader _reader;
  final SyncRemoteGateway _gateway;
  final String Function() _newId;

  @override
  Future<List<RecurringTemplate>> templates() async {
    final result = <RecurringTemplate>[];
    for (final kind in EntryKind.values) {
      final rows = await _reader.select(
        kind.templateTable,
        orderBy: 'created_at',
      );
      result.addAll(rows.map((r) => _fromRow(kind, r)));
    }
    result.sort((a, b) => a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1));
    return result;
  }

  @override
  Future<RecurringTemplate?> template(EntryKind kind, String id) async {
    final rows = await _reader.select(
      kind.templateTable,
      filters: [RemoteFilter.eq('id', id)],
    );
    return rows.isEmpty ? null : _fromRow(kind, rows.first);
  }

  RecurringTemplate _fromRow(EntryKind kind, Map<String, dynamic> d) {
    final amount = d['default_amount_centavos'];
    return RecurringTemplate(
      id: d['id'] as String,
      kind: kind,
      description: d['description'] as String?,
      frequency: RecurrenceFrequency.fromDb(d['frequency'] as String),
      startsOn: CalendarDate.parse(d['starts_on'] as String),
      monthlyReferenceDay: (d['monthly_reference_day'] as num?)?.toInt(),
      variableValue: d['value_mode'] == 'variable',
      defaultAmount: amount == null
          ? null
          : (amount is num
                ? BigInt.from(amount)
                : BigInt.parse(amount.toString())),
      categoryId: d['category_id'] as String?,
      subcategoryId: d['subcategory_id'] as String?,
      isActive: d['is_active'] as bool? ?? true,
      version: (d['version'] as num).toInt(),
    );
  }

  @override
  Future<ScheduleFacts> scheduleFacts(EntryKind kind, String templateId) async {
    final rows = await _reader.select(
      kind.table,
      filters: [RemoteFilter.eq('recurrence_template_id', templateId)],
      orderBy: 'scheduled_for_date',
    );
    if (rows.isEmpty) return const ScheduleFacts();
    final last = rows.last['scheduled_for_date'] as String;
    return ScheduleFacts(lastScheduled: CalendarDate.parse(last));
  }

  Future<void> _call(String rpc, Map<String, dynamic> params) async {
    final Map<String, dynamic> response;
    try {
      response = await _gateway.call(rpc, {
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
    RecurringTemplate current,
    TemplateEdit edit,
    CalendarDate startsOn,
  ) => _call(current.kind.templateRpc, {
    'p_action': 'update',
    'p_template_id': current.id,
    'p_expected_version': current.version,
    'p_payload': {
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
    },
  });

  @override
  Future<void> stop(RecurringTemplate current) =>
      _call(current.kind.templateRpc, {
        'p_action': 'deactivate',
        'p_template_id': current.id,
        'p_expected_version': current.version,
        'p_payload': null,
      });

  @override
  Future<int> generateDue(CalendarDate today) async {
    try {
      final response = await _gateway.call(
        'generate_due_recurrence_occurrences',
        {'p_operation_id': _newId()},
      );
      return ((response['income_created'] as num?) ?? 0).toInt() +
          ((response['expense_created'] as num?) ?? 0).toInt() +
          ((response['investment_created'] as num?) ?? 0).toInt();
    } on SyncRejectedError catch (e) {
      throw ChangeRejectedException(e.message);
    }
  }
}
