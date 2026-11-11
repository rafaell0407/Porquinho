import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'calendar_date.dart';
import 'period_calendar.dart';

/// Frequência de uma recorrência (RN010, RN014). Valores de texto = banco.
enum RecurrenceFrequency {
  monthly('monthly', 'Todo mês'),
  byPeriod('by_period', 'Todo período');

  const RecurrenceFrequency(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static RecurrenceFrequency fromDb(String value) =>
      RecurrenceFrequency.values.firstWhere((f) => f.dbValue == value);
}

/// Agenda de um modelo recorrente: frequência, início e, se mensal, o dia de
/// referência (1–31). Sem acesso a dados (RN038).
class RecurrenceSchedule {
  RecurrenceSchedule.monthly({required this.startsOn, required int day})
    : frequency = RecurrenceFrequency.monthly,
      monthlyReferenceDay = day {
    if (day < 1 || day > 31) {
      throw ArgumentError('O dia de referência deve estar entre 1 e 31.');
    }
  }

  RecurrenceSchedule.byPeriod({required this.startsOn})
    : frequency = RecurrenceFrequency.byPeriod,
      monthlyReferenceDay = null;

  final RecurrenceFrequency frequency;
  final CalendarDate startsOn;
  final int? monthlyReferenceDay;

  bool get isMonthly => frequency == RecurrenceFrequency.monthly;

  RecurrenceSchedule withStart(CalendarDate start) => isMonthly
      ? RecurrenceSchedule.monthly(startsOn: start, day: monthlyReferenceDay!)
      : RecurrenceSchedule.byPeriod(startsOn: start);

  @override
  bool operator ==(Object other) =>
      other is RecurrenceSchedule &&
      other.frequency == frequency &&
      other.startsOn == startsOn &&
      other.monthlyReferenceDay == monthlyReferenceDay;

  @override
  int get hashCode => Object.hash(frequency, startsOn, monthlyReferenceDay);
}

/// Cálculo das datas programadas (RN038, decisões D1–D6 da Fase 5). As mesmas
/// regras da função `generate_due_recurrence_occurrences` do servidor.
abstract final class RecurrenceCalendar {
  /// Data de referência do mês [year]/[month]: o dia [day] ou, em mês curto, o
  /// último dia disponível (31 → 30/28/29), sem alterar os meses seguintes.
  static CalendarDate monthlyDate(int year, int month, int day) =>
      CalendarDate.clamped(year, month, day);

  /// Primeira data de referência maior ou igual ao início (RN038): criada em
  /// 10/05 com dia 31 → 31/05; criada em 31/05 com dia 10 → 10/06.
  static CalendarDate firstMonthly(CalendarDate startsOn, int day) {
    final inMonth = monthlyDate(startsOn.year, startsOn.month, day);
    return inMonth.isBefore(startsOn)
        ? monthlyDate(startsOn.year, startsOn.month + 1, day)
        : inMonth;
  }

  /// Datas mensais de [startsOn] até [today], inclusive, uma por mês. [after]
  /// (opcional) descarta datas anteriores a ele (agenda alterada, D2).
  static List<CalendarDate> monthlyUntil(
    RecurrenceSchedule schedule,
    CalendarDate today, {
    CalendarDate? after,
  }) {
    final day = schedule.monthlyReferenceDay!;
    final result = <CalendarDate>[];
    var cursor = firstMonthly(schedule.startsOn, day);
    while (!cursor.isAfter(today)) {
      if (after == null || !cursor.isBefore(after)) result.add(cursor);
      final next = CalendarDate.addMonthsTo(cursor.year, cursor.month, 1);
      cursor = monthlyDate(next.$1, next.$2, day);
    }
    return result;
  }

  /// Períodos que geram ocorrência por período: os que terminam depois do
  /// início e começam até hoje (inclui o período atual, mesmo se o modelo foi
  /// criado no meio dele). A data da ocorrência é o início do período.
  static List<PeriodRange> periodsUntil(
    CalendarDate startsOn,
    Iterable<PeriodRange> periods,
    CalendarDate today,
  ) =>
      periods
          .where((p) => p.end.isAfter(startsOn) && !p.start.isAfter(today))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  /// Data programada da primeira ocorrência ao criar a recorrência a partir
  /// de um lançamento com data [entryDate] (D8): mensal = a própria data;
  /// por período = início do período que contém a data.
  static CalendarDate firstOccurrenceDate(
    RecurrenceFrequency frequency,
    CalendarDate entryDate,
    PeriodRange? containingPeriod,
  ) => frequency == RecurrenceFrequency.monthly
      ? entryDate
      : containingPeriod!.start;

  /// Primeiro dia a partir do qual a agenda alterada pode gerar (D2): nunca
  /// no mesmo mês nem no mesmo período da última ocorrência já gerada.
  /// [lastScheduled] é a maior data programada do modelo; [lastPeriodEnd] é o
  /// fim do período que contém essa data, se existir.
  static CalendarDate scheduleChangeFloor(
    CalendarDate lastScheduled, {
    CalendarDate? lastPeriodEnd,
  }) {
    final next = CalendarDate.addMonthsTo(
      lastScheduled.year,
      lastScheduled.month,
      1,
    );
    final monthStart = CalendarDate(next.$1, next.$2, 1);
    if (lastPeriodEnd != null && lastPeriodEnd.isAfter(monthStart)) {
      return lastPeriodEnd;
    }
    return monthStart;
  }

  /// Início efetivo de uma agenda alterada: o pedido, nunca antes de hoje
  /// (não cria passadas) nem antes do [floor] (sem duplicar mês/período).
  static CalendarDate effectiveStart(
    CalendarDate requested,
    CalendarDate today, {
    CalendarDate? floor,
  }) {
    var start = requested;
    if (start.isBefore(today)) start = today;
    if (floor != null && start.isBefore(floor)) start = floor;
    return start;
  }

  /// Identificador determinístico da ocorrência (D1): UUID derivado de
  /// `md5('<modelo>|<data programada>')`, com versão 5 e variante 8. O
  /// servidor calcula igual (`public.recurrence_occurrence_id`).
  static String occurrenceId(String templateId, CalendarDate scheduled) {
    final hex = md5
        .convert(
          utf8.encode('${templateId.toLowerCase()}|${scheduled.toIso()}'),
        )
        .toString();
    final chars = hex.split('');
    chars[12] = '5';
    chars[16] = '8';
    final h = chars.join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
