import 'calendar_date.dart';

/// Modalidade de período (RN001). Os valores de texto são os do banco.
enum PeriodMode {
  calendarMonth('calendar_month'),
  customCycle('custom_cycle');

  const PeriodMode(this.dbValue);
  final String dbValue;

  static PeriodMode fromDb(String value) =>
      PeriodMode.values.firstWhere((m) => m.dbValue == value);
}

/// Configuração de período: mês-calendário ou ciclo com dia inicial 1–31.
class PeriodConfig {
  PeriodConfig.calendarMonth()
    : mode = PeriodMode.calendarMonth,
      customStartDay = null;

  PeriodConfig.customCycle(int day)
    : mode = PeriodMode.customCycle,
      customStartDay = day {
    if (day < 1 || day > 31) {
      throw ArgumentError('O dia inicial deve estar entre 1 e 31.');
    }
  }

  final PeriodMode mode;
  final int? customStartDay;

  /// Data em que começa o período do mês [year]/[month] (RN037: em meses
  /// curtos usa o último dia disponível).
  CalendarDate startInMonth(int year, int month) {
    final normalized = CalendarDate.addMonthsTo(year, month, 0);
    return switch (mode) {
      PeriodMode.calendarMonth => CalendarDate(normalized.$1, normalized.$2, 1),
      PeriodMode.customCycle => CalendarDate.clamped(
        normalized.$1,
        normalized.$2,
        customStartDay!,
      ),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodConfig &&
      other.mode == mode &&
      other.customStartDay == customStartDay;

  @override
  int get hashCode => Object.hash(mode, customStartDay);
}

/// Intervalo semiaberto `[start, end)` (RN036).
class PeriodRange {
  const PeriodRange(this.start, this.end);
  final CalendarDate start;
  final CalendarDate end;

  bool contains(CalendarDate date) =>
      !date.isBefore(start) && date.isBefore(end);

  @override
  bool operator ==(Object other) =>
      other is PeriodRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start, $end)';
}

/// Cálculo de períodos (RN001–RN003, RN036, RN037). Sem acesso a dados.
class PeriodCalendar {
  const PeriodCalendar._();

  /// Período regular da [config] que contém [date].
  static PeriodRange containing(PeriodConfig config, CalendarDate date) {
    var start = config.startInMonth(date.year, date.month);
    var startMonth = date.monthIndex;
    if (date.isBefore(start)) {
      startMonth -= 1;
      start = config.startInMonth(date.year, date.month - 1);
    }
    final next = config.startInMonth(startMonth ~/ 12, startMonth % 12 + 1 + 1);
    return PeriodRange(start, next);
  }

  /// Período seguinte a [period], na mesma configuração.
  static PeriodRange next(PeriodConfig config, PeriodRange period) =>
      containing(config, period.end);

  /// Período anterior a [period], na mesma configuração.
  static PeriodRange previous(PeriodConfig config, PeriodRange period) =>
      containing(config, period.start.addDays(-1));

  /// Fim do primeiro período com a nova [config] após uma mudança de
  /// configuração (RN002): começa em [start] (fim do período anterior) e
  /// termina na próxima fronteira da nova configuração posterior ao início.
  static PeriodRange transition(PeriodConfig config, CalendarDate start) {
    var end = config.startInMonth(start.year, start.month);
    if (!end.isAfter(start)) {
      end = config.startInMonth(start.year, start.month + 1);
    }
    return PeriodRange(start, end);
  }

  /// Períodos consecutivos de [from] até [to] (inclusive), para frente.
  static List<PeriodRange> forward(
    PeriodConfig config,
    PeriodRange from,
    CalendarDate to,
  ) {
    final result = <PeriodRange>[];
    var current = from;
    while (!to.isBefore(current.start)) {
      result.add(current);
      current = next(config, current);
    }
    return result;
  }
}
