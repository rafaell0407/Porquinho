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
    this.dependsOnConfigurationId,
    this.earlier = false,
  });

  final String id;
  final String configurationId;
  final PeriodConfig config;
  final PeriodRange range;
  final bool newConfiguration;

  /// Período adjacente cuja criação precisa ser enviada antes (Entrega 35).
  final String? dependsOnPeriodId;

  /// Configuração agendada de que o período depende (transição, Entrega 59).
  final String? dependsOnConfigurationId;

  /// Período anterior ao primeiro (Entrega 34B): usa a configuração do
  /// primeiro período e outra RPC.
  final bool earlier;
}

/// Troca (ou criação) da configuração agendada para o próximo período
/// (Entrega 59). [expectedVersion] 0 cria; maior que 0 altera a existente.
class ScheduleDraft {
  const ScheduleDraft({
    required this.configurationId,
    required this.config,
    required this.effectiveFrom,
    required this.expectedVersion,
    required this.lastPeriodId,
  });

  final String configurationId;
  final PeriodConfig config;
  final CalendarDate effectiveFrom;
  final int expectedVersion;

  /// Último período existente: a mudança só começa depois dele.
  final String lastPeriodId;

  bool get isCreate => expectedVersion == 0;
}

/// Mudança de configuração já agendada, que vale a partir de [startsOn].
class ScheduledChange {
  const ScheduledChange(this.config, this.startsOn);
  final PeriodConfig config;
  final CalendarDate startsOn;
}

/// O servidor recusou ou apontou conflito ao criar o período.
class PeriodCreationException implements Exception {
  const PeriodCreationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Período do histórico com a configuração que ele usou (Entrega 60).
class PeriodHistoryItem {
  const PeriodHistoryItem(this.id, this.range, this.config);
  final String id;
  final PeriodRange range;
  final PeriodConfig config;
}
