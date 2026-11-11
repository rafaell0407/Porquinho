import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/money.dart';
import 'package:porquinho/core/domain/user_clock.dart';

void main() {
  group('parseBrlToCentavos', () {
    test('converte formatos válidos', () {
      expect(parseBrlToCentavos('1.234,56'), BigInt.from(123456));
      expect(parseBrlToCentavos('R\$ 10'), BigInt.from(1000));
      expect(parseBrlToCentavos('0,5'), BigInt.from(50));
      expect(parseBrlToCentavos('0'), BigInt.zero);
      expect(parseBrlToCentavos('0,00'), BigInt.zero);
      expect(parseBrlToCentavos('1234,56'), BigInt.from(123456));
      expect(parseBrlToCentavos('1.234'), BigInt.from(123400));
    });

    test('recusa formatos inválidos sem arredondar', () {
      for (final text in [
        '1,234',
        '-1',
        '',
        'abc',
        '1,',
        '12.34',
        '1.2345,00',
        '1,2,3',
        '1.234.5',
      ]) {
        expect(
          () => parseBrlToCentavos(text),
          throwsA(isA<MoneyFormatException>()),
          reason: text,
        );
      }
    });

    test('mantém exatidão acima de 2^53 e recusa acima de 64 bits', () {
      expect(
        parseBrlToCentavos('92.233.720.368.547.758,07'),
        BigInt.parse('9223372036854775807'),
      );
      expect(
        parseBrlToCentavos('90.071.992.547.409,93'),
        BigInt.parse('9007199254740993'),
      );
      expect(
        () => parseBrlToCentavos('92.233.720.368.547.758,08'),
        throwsA(isA<MoneyFormatException>()),
      );
    });
  });

  test('formatBrl', () {
    expect(formatBrl(BigInt.from(123456)), 'R\$ 1.234,56');
    expect(formatBrl(BigInt.zero), 'R\$ 0,00');
    expect(formatBrl(BigInt.from(5)), 'R\$ 0,05');
    expect(formatBrl(BigInt.from(-100)), '-R\$ 1,00');
    expect(formatBrl(BigInt.from(100000000)), 'R\$ 1.000.000,00');
  });

  group('data corrente em America/Sao_Paulo', () {
    test('virada do dia pela zona, não por UTC', () {
      // 02:59 UTC = 23:59 de 09/11 em São Paulo (UTC-3).
      expect(
        todayInZone(DateTime.utc(2026, 11, 10, 2, 59)),
        CalendarDate(2026, 11, 9),
      );
      expect(
        todayInZone(DateTime.utc(2026, 11, 10, 3, 0)),
        CalendarDate(2026, 11, 10),
      );
    });

    test('UserClock usa o instante injetado', () {
      final clock = UserClock(now: () => DateTime.utc(2026, 1, 1, 1));
      expect(clock.today(), CalendarDate(2025, 12, 31));
    });
  });

  test('CalendarDate', () {
    expect(CalendarDate.parse('2024-02-29'), CalendarDate(2024, 2, 29));
    expect(() => CalendarDate(2026, 2, 29), throwsArgumentError);
    expect(CalendarDate(2026, 12, 31).addDays(1), CalendarDate(2027, 1, 1));
    expect(CalendarDate.clamped(2026, 2, 31), CalendarDate(2026, 2, 28));
    expect(CalendarDate(2026, 3, 5).toIso(), '2026-03-05');
  });
}
