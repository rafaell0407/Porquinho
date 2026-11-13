import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../categories/category_models.dart';
import '../sync/remote_table_reader.dart';
import '../sync/sync_models.dart';
import 'investment_models.dart';
import 'investment_repository.dart';

/// Web: lê e grava direto no servidor (somente online).
class RemoteInvestmentRepository implements InvestmentRepository {
  RemoteInvestmentRepository(
    this._reader,
    this._gateway, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final RemoteTableReader _reader;
  final SyncRemoteGateway _gateway;
  final String Function() _newId;

  static const _table = 'investment_allocations';

  @override
  Future<List<InvestmentRecord>> investmentsInPeriod(PeriodRange range) async {
    final rows = await _reader.select(
      _table,
      filters: [
        RemoteFilter.gte('allocated_on', range.start.toIso()),
        RemoteFilter.lt('allocated_on', range.end.toIso()),
      ],
      orderBy: 'allocated_on',
    );
    final result = rows.map(_fromRow).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<InvestmentRecord?> investment(String id) async {
    final rows = await _reader.select(
      _table,
      filters: [RemoteFilter.eq('id', id)],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  InvestmentRecord _fromRow(Map<String, dynamic> d) {
    final amount = d['amount_centavos'];
    final scheduled = d['scheduled_for_date'] as String?;
    return InvestmentRecord(
      id: d['id'] as String,
      amount: amount is num
          ? BigInt.from(amount)
          : BigInt.parse(amount.toString()),
      date: CalendarDate.parse(d['allocated_on'] as String),
      version: (d['version'] as num).toInt(),
      cancelled: d['cancelled_at'] != null,
      templateId: d['recurrence_template_id'] as String?,
      scheduledFor: scheduled == null ? null : CalendarDate.parse(scheduled),
    );
  }

  @override
  Future<void> apply(List<InvestmentChange> changes) async {
    for (final change in changes) {
      final call = investmentRpcCallFor(change);
      final Map<String, dynamic> response;
      try {
        response = await _gateway.call(call.rpc, {
          'p_operation_id': _newId(),
          ...call.params,
        });
      } on SyncRejectedError catch (e) {
        throw ChangeRejectedException(e.message);
      }
      if (response['status'] == 'conflict') {
        throw const ChangeConflictException();
      }
    }
  }
}
