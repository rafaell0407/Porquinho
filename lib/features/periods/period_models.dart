import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';

/// Configuração única de período do usuário (RN001/RN002, 13/11/2026), com a
/// versão usada para detectar conflitos na sincronização.
class PeriodSettingsRecord {
  const PeriodSettingsRecord({required this.config, required this.version});

  final PeriodConfig config;
  final int version;
}

/// Datas extremas dos lançamentos (competência; receita pendente pela data
/// programada), para os limites da navegação entre períodos (RN002).
class EntryDateSpan {
  const EntryDateSpan({this.oldest, this.newest});

  final CalendarDate? oldest;
  final CalendarDate? newest;
}

/// O servidor recusou a configuração ou ela mudou em outro lugar.
class PeriodSettingsException implements Exception {
  const PeriodSettingsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Configuração de período a partir das colunas do banco.
PeriodConfig configFromRow(Map<String, dynamic> r) => PeriodConfig.fromDb(
  r['mode'] as String,
  (r['custom_start_day'] as num?)?.toInt(),
);

/// RPC que grava a configuração única (servidor) e seus parâmetros, sem
/// `p_operation_id`. [expectedVersion] 0 cria; maior que 0 troca.
const periodSettingsRpc = 'set_period_settings';

Map<String, dynamic> periodSettingsParams(
  PeriodConfig config,
  int expectedVersion,
) => {
  'p_expected_version': expectedVersion,
  'p_mode': config.mode.dbValue,
  'p_custom_start_day': config.customStartDay,
};
