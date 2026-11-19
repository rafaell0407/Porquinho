import '../../../core/domain/calendar_date.dart';

/// Formatos de data aceitos (RN048), declarados por coluna.
enum DateFormatKind {
  iso('AAAA-MM-DD', '2026-01-31'),
  dmy('DD/MM/AAAA', '31/01/2026'),
  mdy('MM/DD/AAAA', '01/31/2026');

  const DateFormatKind(this.label, this.example);
  final String label;
  final String example;
}

/// Resultado da leitura de uma data.
class DateParse {
  const DateParse.ok(CalendarDate this.date, {this.hadTime = false})
    : error = null;
  const DateParse.error(String this.error) : date = null, hadTime = false;

  final CalendarDate? date;

  /// A data veio com hora: usa-se só a data, com aviso, sem converter fuso.
  final bool hadTime;
  final String? error;

  bool get ok => date != null;
}

/// Faixa aceita (D34): de 01/01/2000 até 5 anos depois de hoje.
final CalendarDate minImportDate = CalendarDate(2000, 1, 1);

CalendarDate maxImportDate(CalendarDate today) =>
    CalendarDate.clamped(today.year + 5, today.month, today.day);

final _time = RegExp(
  r'^(?:[T ]\s*)?[0-9]{1,2}:[0-9]{2}(?::[0-9]{2}(?:\.[0-9]+)?)?'
  r'(?:\s*(?:Z|[+-][0-9]{2}(?::?[0-9]{2})?))?$',
);
final _isoDate = RegExp(r'^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})(.*)$');
final _slashDate = RegExp(r'^([0-9]{1,2})[/.-]([0-9]{1,2})[/.-]([0-9]+)(.*)$');

/// Lê [raw] no [format] declarado, conferindo a faixa a partir de [today].
DateParse parseImportDate(
  String raw,
  DateFormatKind format,
  CalendarDate today,
) {
  final text = raw.trim();
  if (text.isEmpty) return const DateParse.error('Data vazia.');
  int year;
  int month;
  int day;
  String rest;
  if (format == DateFormatKind.iso) {
    final m = _isoDate.firstMatch(text);
    if (m == null) {
      return DateParse.error('Data "$raw" não está no formato AAAA-MM-DD.');
    }
    year = int.parse(m.group(1)!);
    month = int.parse(m.group(2)!);
    day = int.parse(m.group(3)!);
    rest = m.group(4)!;
  } else {
    final m = _slashDate.firstMatch(text);
    if (m == null) {
      return DateParse.error(
        'Data "$raw" não está no formato ${format.label}.',
      );
    }
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final y = m.group(3)!;
    if (y.length != 4) {
      return DateParse.error('Data "$raw" sem o ano com 4 dígitos.');
    }
    year = int.parse(y);
    (day, month) = format == DateFormatKind.dmy ? (a, b) : (b, a);
    rest = m.group(4)!;
  }
  var hadTime = false;
  if (rest.isNotEmpty) {
    if (!_time.hasMatch(rest)) {
      return DateParse.error('Data "$raw" com texto a mais.');
    }
    hadTime = true;
  }
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > CalendarDate.daysInMonth(year, month)) {
    return DateParse.error('Data "$raw" não existe.');
  }
  final date = CalendarDate(year, month, day);
  if (date.isBefore(minImportDate) || date.isAfter(maxImportDate(today))) {
    return DateParse.error(
      'Data "$raw" fora da faixa aceita (01/01/2000 até '
      '${maxImportDate(today).toBr()}).',
    );
  }
  return DateParse.ok(date, hadTime: hadTime);
}

/// Formato sugerido para a coluna; `null` quando não dá para saber (todas as
/// datas servem como DD/MM e como MM/DD com sentidos diferentes) ou há
/// conflito. Nesse caso o usuário escolhe (RN048).
DateFormatKind? suggestDateFormat(Iterable<String> values) {
  var iso = false;
  var slash = false;
  var mustDmy = false;
  var mustMdy = false;
  var differs = false;
  for (final raw in values) {
    final text = raw.trim();
    if (text.isEmpty) continue;
    if (_isoDate.hasMatch(text)) {
      iso = true;
      continue;
    }
    final m = _slashDate.firstMatch(text);
    if (m == null) continue;
    slash = true;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    if (a > 12) mustDmy = true;
    if (b > 12) mustMdy = true;
    if (a != b) differs = true;
  }
  if (iso && slash) return null;
  if (iso) return DateFormatKind.iso;
  if (!slash) return null;
  if (mustDmy && mustMdy) return null;
  if (mustDmy) return DateFormatKind.dmy;
  if (mustMdy) return DateFormatKind.mdy;
  // Todas com dia e mês até 12: só não é ambíguo se forem iguais (01/01).
  return differs ? null : DateFormatKind.dmy;
}
