import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';

class PeriodConfigRecord {
  const PeriodConfigRecord({
    required this.id,
    required this.config,
    required this.effectiveFrom,
    required this.version,
  });

  final String id;
  final PeriodConfig config;
  final CalendarDate effectiveFrom;
  final int version;
}

class PeriodRecord {
  const PeriodRecord({
    required this.id,
    required this.configurationId,
    required this.range,
    required this.version,
  });

  final String id;
  final String configurationId;
  final PeriodRange range;
  final int version;
}

/// Período a criar. Se [newConfiguration], a configuração [configurationId]
/// nasce junto (a RPC cria os dois na mesma transação).
class PeriodDraft {
  const PeriodDraft({
    required this.id,
    required this.configurationId,
    required this.config,
    required this.range,
    required this.newConfiguration,
    this.dependsOnPeriodId,
    this.earlier = false,
  });

  final String id;
  final String configurationId;
  final PeriodConfig config;
  final PeriodRange range;
  final bool newConfiguration;

  /// Período adjacente cuja criação precisa ser enviada antes (Entrega 35).
  final String? dependsOnPeriodId;

  /// Período anterior ao primeiro (Entrega 34B): usa a configuração do
  /// primeiro período e outra RPC.
  final bool earlier;
}

/// O servidor recusou ou apontou conflito ao criar o período.
class PeriodCreationException implements Exception {
  const PeriodCreationException(this.message);
  final String message;
  @override
  String toString() => message;
}
