/// Data civil (sem hora nem fuso), usada por períodos e lançamentos.
/// Persistida como texto ISO `AAAA-MM-DD`, igual ao banco local e ao servidor.
class CalendarDate implements Comparable<CalendarDate> {
  CalendarDate(this.year, this.month, this.day) {
    if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) {
      throw ArgumentError('Data inexistente: $year-$month-$day');
    }
  }

  factory CalendarDate.parse(String iso) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (match == null) {
      throw FormatException('Data inválida: $iso');
    }
    return CalendarDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int year;
  final int month;
  final int day;

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static int daysInMonth(int year, int month) {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && isLeapYear(year)) {
      return 29;
    }
    return days[month - 1];
  }

  /// Dia [day] do mês, limitado ao último dia disponível (RN037).
  static CalendarDate clamped(int year, int month, int day) {
    final normalized = _normalizeMonth(year, month);
    final last = daysInMonth(normalized.$1, normalized.$2);
    return CalendarDate(normalized.$1, normalized.$2, day > last ? last : day);
  }

  /// Primeiro dia do mês [month] do ano [year], aceitando mês fora de 1–12.
  static (int, int) _normalizeMonth(int year, int month) {
    final index = year * 12 + (month - 1);
    return (index ~/ 12, index % 12 + 1);
  }

  /// Soma [months] meses ao par ano/mês, devolvendo ano/mês normalizados.
  static (int, int) addMonthsTo(int year, int month, int months) =>
      _normalizeMonth(year, month + months);

  /// Número de meses desde o ano 0; útil para contar meses entre datas.
  int get monthIndex => year * 12 + (month - 1);

  CalendarDate addDays(int days) {
    final result = DateTime.utc(year, month, day).add(Duration(days: days));
    return CalendarDate(result.year, result.month, result.day);
  }

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// `dd/MM/aaaa`, formato exibido ao usuário.
  String toBr() =>
      '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/'
      '${year.toString().padLeft(4, '0')}';

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
