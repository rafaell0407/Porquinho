import '../../../core/domain/calendar_date.dart';

/// Dias úteis da Calculadora à vista ou parcelado (spec
/// `docs/ferramentas/a_vista_ou_parcelado.md` §4.2): segunda a sexta, menos
/// os feriados nacionais (calendário usado pelo mercado para o CDI).
///
/// Vale **só nesta ferramenta**. O resto do app usa `CalendarDate.isBusinessDay`
/// (segunda a sexta, sem feriados; RN038).
abstract final class BusinessCalendar {
  static final Map<int, Set<CalendarDate>> _cache = {};

  /// Domingo de Páscoa (algoritmo de Meeus/Jones/Butcher, calendário
  /// gregoriano).
  static CalendarDate easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final n = h + l - 7 * m + 114;
    return CalendarDate(year, n ~/ 31, n % 31 + 1);
  }

  /// Feriados nacionais do ano, em ordem.
  static List<CalendarDate> nationalHolidays(int year) {
    final easter = easterSunday(year);
    final days = <CalendarDate>[
      CalendarDate(year, 1, 1),
      easter.addDays(-48), // segunda de Carnaval
      easter.addDays(-47), // terça de Carnaval
      easter.addDays(-2), // Sexta-feira Santa
      CalendarDate(year, 4, 21),
      CalendarDate(year, 5, 1),
      easter.addDays(60), // Corpus Christi
      CalendarDate(year, 9, 7),
      CalendarDate(year, 10, 12),
      CalendarDate(year, 11, 2),
      CalendarDate(year, 11, 15),
      // Dia Nacional de Zumbi e da Consciência Negra (Lei 14.759/2023).
      if (year >= 2024) CalendarDate(year, 11, 20),
      CalendarDate(year, 12, 25),
    ]..sort();
    return List.unmodifiable(days);
  }

  static bool isHoliday(CalendarDate date) => _cache
      .putIfAbsent(date.year, () => nationalHolidays(date.year).toSet())
      .contains(date);

  static bool isBusinessDay(CalendarDate date) =>
      date.weekday <= DateTime.friday && !isHoliday(date);

  /// A própria data, se for dia útil; senão, o próximo dia útil.
  static CalendarDate nextOrSame(CalendarDate date) {
    var d = date;
    while (!isBusinessDay(d)) {
      d = d.addDays(1);
    }
    return d;
  }

  /// A própria data, se for dia útil; senão, o dia útil anterior.
  static CalendarDate previousOrSame(CalendarDate date) {
    var d = date;
    while (!isBusinessDay(d)) {
      d = d.addDays(-1);
    }
    return d;
  }

  /// Dias úteis `d` com `start <= d < end` (0 se `end <= start`).
  static int businessDaysBetween(CalendarDate start, CalendarDate end) {
    var count = 0;
    for (var d = start; d.isBefore(end); d = d.addDays(1)) {
      if (isBusinessDay(d)) count++;
    }
    return count;
  }

  /// Dias corridos de [start] até [end].
  static int calendarDaysBetween(CalendarDate start, CalendarDate end) =>
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
}
