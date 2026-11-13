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
  Future<PeriodSettingsRecord?> settings() async {
    final rows = await _reader.select('period_settings');
    if (rows.isEmpty) return null;
    return PeriodSettingsRecord(
      config: configFromRow(rows.single),
      version: (rows.single['version'] as num).toInt(),
    );
  }

  @override
  Future<void> saveSettings(
    PeriodConfig config, {
    required int expectedVersion,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await _gateway.call(periodSettingsRpc, {
        'p_operation_id': _newId(),
        ...periodSettingsParams(config, expectedVersion),
      });
    } on SyncRejectedError catch (e) {
      throw PeriodSettingsException(e.message);
    }
    if (response['status'] != 'applied') {
      throw const PeriodSettingsException(
        'A configuração já foi alterada em outro lugar. Atualize a tela e '
        'tente de novo.',
      );
    }
  }

  @override
  Future<EntryDateSpan> entryDateSpan() async {
    // Leitura agregada (RPC somente leitura): devolve {oldest, newest}.
    final json = await _gateway.call('get_entry_date_span', const {});
    CalendarDate? parse(Object? v) =>
        v == null ? null : CalendarDate.parse(v as String);
    return EntryDateSpan(
      oldest: parse(json['oldest']),
      newest: parse(json['newest']),
    );
  }

  @override
  Future<void> refreshFromServer() async {}
}
