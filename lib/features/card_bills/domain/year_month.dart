import '../../../core/domain/calendar_date.dart';

/// Mês de referência de uma fatura: o mês do fechamento (spec §12, fatura
/// identificada por cartão + mês do fechamento). Persistido como `AAAA-MM`.
class YearMonth implements Comparable<YearMonth> {
  YearMonth(this.year, this.month) {
    if (month < 1 || month > 12) {
      throw ArgumentError('Mês inexistente: $year-$month');
    }
  }

  factory YearMonth.fromIndex(int index) =>
      YearMonth(index ~/ 12, index % 12 + 1);

  factory YearMonth.of(CalendarDate date) => YearMonth(date.year, date.month);

  factory YearMonth.parse(String text) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(text);
    if (match == null) throw FormatException('Mês inválido: $text');
    return YearMonth(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  final int year;
  final int month;

  /// Meses desde o ano 0 (para somar e comparar).
  int get index => year * 12 + (month - 1);

  YearMonth add(int months) => YearMonth.fromIndex(index + months);

  /// Quantos meses de [other] até este (positivo se este for depois).
  int monthsSince(YearMonth other) => index - other.index;

  /// Dia [day] deste mês; dia inexistente vira o último dia do mês, sem
  /// considerar dia útil (spec §4 — não é a regra RN038 dos lançamentos).
  CalendarDate dayClamped(int day) => CalendarDate.clamped(year, month, day);

  bool isBefore(YearMonth other) => index < other.index;
  bool isAfter(YearMonth other) => index > other.index;

  String toKey() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  @override
  int compareTo(YearMonth other) => index.compareTo(other.index);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => index;

  @override
  String toString() => toKey();
}
