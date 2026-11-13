import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../categories/category_models.dart';
import '../sync/remote_table_reader.dart';
import '../sync/sync_models.dart';
import 'entry_models.dart';
import 'entry_repository.dart';

/// Web: lê e grava direto no servidor (somente online).
class RemoteEntryRepository implements EntryRepository {
  RemoteEntryRepository(this._reader, this._gateway, {String Function()? newId})
    : _newId = newId ?? newUuid;

  final RemoteTableReader _reader;
  final SyncRemoteGateway _gateway;
  final String Function() _newId;

  @override
  Future<List<EntryRecord>> entriesInPeriod(PeriodRange range) async {
    final result = <EntryRecord>[];
    for (final kind in EntryKind.values) {
      final rows = await _reader.select(
        kind.table,
        filters: [
          RemoteFilter.gte(kind.dateColumn, range.start.toIso()),
          RemoteFilter.lt(kind.dateColumn, range.end.toIso()),
        ],
        orderBy: kind.dateColumn,
      );
      result.addAll(rows.map((r) => _fromRow(kind, r)));
    }
    result.addAll(await _pendingIncomeIn(range));
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// Receita recorrente ainda sem data de recebimento (pendente): aparece no
  /// período que contém a data programada.
  Future<List<EntryRecord>> _pendingIncomeIn(PeriodRange range) async {
    final rows = await _reader.select(
      EntryKind.income.table,
      filters: [
        RemoteFilter.gte('scheduled_for_date', range.start.toIso()),
        RemoteFilter.lt('scheduled_for_date', range.end.toIso()),
      ],
      orderBy: 'scheduled_for_date',
    );
    return rows
        .where((r) => r['received_on'] == null)
        .map((r) => _fromRow(EntryKind.income, r))
        .toList();
  }

  @override
  Future<EntryRecord?> entry(EntryKind kind, String id) async {
    final rows = await _reader.select(
      kind.table,
      filters: [RemoteFilter.eq('id', id)],
    );
    return rows.isEmpty ? null : _fromRow(kind, rows.first);
  }

  EntryRecord _fromRow(EntryKind kind, Map<String, dynamic> d) {
    final amount = d['amount_centavos'];
    final due = d['due_on'] as String?;
    final paid = d['paid_on'] as String?;
    final scheduled = d['scheduled_for_date'] as String?;
    return EntryRecord(
      id: d['id'] as String,
      kind: kind,
      amount: amount == null
          ? null
          : (amount is num
                ? BigInt.from(amount)
                : BigInt.parse(amount.toString())),
      status: d['status'] as String,
      date: CalendarDate.parse(((d[kind.dateColumn] as String?) ?? scheduled)!),
      version: (d['version'] as num).toInt(),
      description: d['description'] as String?,
      categoryId: d['category_id'] as String?,
      subcategoryId: d['subcategory_id'] as String?,
      dueOn: due == null ? null : CalendarDate.parse(due),
      paidOn: paid == null ? null : CalendarDate.parse(paid),
      templateId: d['recurrence_template_id'] as String?,
      scheduledFor: scheduled == null ? null : CalendarDate.parse(scheduled),
    );
  }

  @override
  Future<void> apply(List<EntryChange> changes) async {
    for (final change in changes) {
      final call = entryRpcCallFor(change);
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
