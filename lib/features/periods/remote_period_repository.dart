import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../sync/remote_table_reader.dart';
import '../sync/sync_models.dart';
import 'period_models.dart';
import 'period_repository.dart';

/// Web: lê e grava direto no servidor (somente online).
class RemotePeriodRepository implements PeriodRepository {
  RemotePeriodRepository(
    this._reader,
    this._gateway, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final RemoteTableReader _reader;
  final SyncRemoteGateway _gateway;
  final String Function() _newId;

  @override
  Future<List<PeriodConfigRecord>> configurations() async {
    final rows = await _reader.select(
      'period_configurations',
      orderBy: 'effective_from',
    );
    return rows
        .map(
          (r) => PeriodConfigRecord(
            id: r['id'] as String,
            config: configFromRow(r),
            effectiveFrom: CalendarDate.parse(r['effective_from'] as String),
            version: (r['version'] as num).toInt(),
          ),
        )
        .toList();
  }

  @override
  Future<List<PeriodRecord>> periods() async {
    final rows = await _reader.select(
      'accounting_periods',
      orderBy: 'start_date',
    );
    return rows
        .map(
          (r) => PeriodRecord(
            id: r['id'] as String,
            configurationId: r['configuration_id'] as String,
            range: PeriodRange(
              CalendarDate.parse(r['start_date'] as String),
              CalendarDate.parse(r['end_date'] as String),
            ),
            version: (r['version'] as num).toInt(),
          ),
        )
        .toList();
  }

  @override
  Future<void> createPeriod(PeriodDraft draft) async {
    final Map<String, dynamic> response;
    try {
      response = await _gateway.call(periodRpc(draft), {
        'p_operation_id': _newId(),
        ...periodParams(draft),
      });
    } on SyncRejectedError catch (e) {
      throw PeriodCreationException(e.message);
    }
    if (response['status'] != 'applied') {
      throw const PeriodCreationException(
        'Já existe um período nesta data. Atualize a tela e tente de novo.',
      );
    }
  }

  @override
  Future<void> refreshFromServer() async {}
}

PeriodConfig configFromRow(Map<String, dynamic> r) =>
    PeriodMode.fromDb(r['mode'] as String) == PeriodMode.calendarMonth
    ? PeriodConfig.calendarMonth()
    : PeriodConfig.customCycle((r['custom_start_day'] as num).toInt());

/// Parâmetros da RPC `create_accounting_period` (sem `p_operation_id`).
Map<String, dynamic> periodParams(PeriodDraft d) => d.earlier
    ? {'p_period_id': d.id, 'p_start_date': d.range.start.toIso()}
    : {
        'p_period_id': d.id,
        'p_configuration_id': d.configurationId,
        'p_start_date': d.range.start.toIso(),
        'p_mode': d.config.mode.dbValue,
        'p_custom_start_day': d.config.customStartDay,
      };

String periodRpc(PeriodDraft d) =>
    d.earlier ? 'create_earlier_accounting_period' : 'create_accounting_period';
