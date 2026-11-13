@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';

/// Período calculado por data (reestruturação, P2): tabela única de casos,
/// também usada para conferir o servidor (P3), e limites de navegação (RN002).
CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
PeriodRange r(CalendarDate a, CalendarDate b) => PeriodRange(a, b);

List<Map<String, dynamic>> loadPeriodCases() {
  final json =
      jsonDecode(File('test/fixtures/period_cases.json').readAsStringSync())
          as Map<String, dynamic>;
  return (json['cases'] as List).cast<Map<String, dynamic>>();
}

void main() {
  group('tabela única de casos (test/fixtures/period_cases.json)', () {
    final cases = loadPeriodCases();

    test('tem casos de todas as configurações', () {
      expect(cases.length, greaterThan(200));
      final configs = {for (final c in cases) '${c['mode']}/${c['day']}'};
      expect(configs, hasLength(9));
    });

    for (final c in cases) {
      final config = PeriodConfig.fromDb(c['mode'] as String, c['day'] as int?);
      final date = CalendarDate.parse(c['date'] as String);
      test('${c['mode']} ${c['day'] ?? ''} em ${c['date']}', () {
        final range = PeriodCalendar.containing(config, date);
        expect(range.start.toIso(), c['start']);
        expect(range.end.toIso(), c['end']);
        expect(range.contains(date), isTrue);
      });
    }
  });

  group('PeriodConfig.fromDb', () {
    test('lê as duas modalidades', () {
      expect(
        PeriodConfig.fromDb('calendar_month', null),
        PeriodConfig.calendarMonth(),
      );
      expect(
        PeriodConfig.fromDb('custom_cycle', 20),
        PeriodConfig.customCycle(20),
      );
    });

    test('recusa modalidade desconhecida e ciclo sem dia', () {
      expect(() => PeriodConfig.fromDb('by_week', null), throwsStateError);
      expect(
        () => PeriodConfig.fromDb('custom_cycle', null),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('between', () {
    test('lista os períodos que cobrem as duas datas, sem lacuna', () {
      final list = PeriodCalendar.between(
        PeriodConfig.customCycle(31),
        d(2027, 1, 15),
        d(2027, 4, 30),
      );
      expect(list, [
        r(d(2026, 12, 31), d(2027, 1, 31)),
        r(d(2027, 1, 31), d(2027, 2, 28)),
        r(d(2027, 2, 28), d(2027, 3, 31)),
        r(d(2027, 3, 31), d(2027, 4, 30)),
        r(d(2027, 4, 30), d(2027, 5, 31)),
      ]);
      for (var i = 1; i < list.length; i++) {
        expect(list[i].start, list[i - 1].end);
      }
    });

    test('mesma data ou datas no mesmo período = um período', () {
      final c = PeriodConfig.calendarMonth();
      expect(PeriodCalendar.between(c, d(2026, 11, 1), d(2026, 11, 30)), [
        r(d(2026, 11, 1), d(2026, 12, 1)),
      ]);
    });

    test('fim antes do início = vazio', () {
      final c = PeriodConfig.calendarMonth();
      expect(PeriodCalendar.between(c, d(2026, 11, 2), d(2026, 11, 1)), []);
    });
  });

  group('bounds (navegação, RN002)', () {
    final monthly = PeriodConfig.calendarMonth();
    final today = d(2026, 11, 13);
    final current = r(d(2026, 11, 1), d(2026, 12, 1));

    test('sem lançamentos: só o período atual', () {
      final b = PeriodCalendar.bounds(monthly, today: today);
      expect(b, PeriodBounds(current, current));
      expect(b.hasBefore(current), isFalse);
      expect(b.hasAfter(current), isFalse);
    });

    test('do lançamento mais antigo ao mais distante no futuro', () {
      final b = PeriodCalendar.bounds(
        monthly,
        today: today,
        oldest: d(2026, 7, 31),
        newest: d(2027, 2, 1),
      );
      expect(b.first, r(d(2026, 7, 1), d(2026, 8, 1)));
      expect(b.last, r(d(2027, 2, 1), d(2027, 3, 1)));
      expect(b.hasBefore(current), isTrue);
      expect(b.hasAfter(current), isTrue);
      expect(b.hasBefore(b.first), isFalse);
      expect(b.hasAfter(b.last), isFalse);
    });

    test('sempre inclui o período atual', () {
      // Todos os lançamentos no passado: o fim é o período atual.
      final past = PeriodCalendar.bounds(
        monthly,
        today: today,
        oldest: d(2026, 1, 10),
        newest: d(2026, 3, 10),
      );
      expect(past.last, current);
      // Todos no futuro: o começo é o período atual.
      final future = PeriodCalendar.bounds(
        monthly,
        today: today,
        oldest: d(2027, 1, 10),
        newest: d(2027, 3, 10),
      );
      expect(future.first, current);
      expect(future.last, r(d(2027, 3, 1), d(2027, 4, 1)));
    });

    test('ciclo dia 20: o lançamento do dia 19 fica no período anterior', () {
      final c = PeriodConfig.customCycle(20);
      final b = PeriodCalendar.bounds(
        c,
        today: d(2026, 11, 20),
        oldest: d(2026, 10, 19),
      );
      expect(b.first, r(d(2026, 9, 20), d(2026, 10, 20)));
      expect(b.last, r(d(2026, 11, 20), d(2026, 12, 20)));
    });

    test('trocar a configuração recalcula os mesmos limites por data', () {
      final dates = (oldest: d(2026, 1, 31), newest: d(2026, 12, 31));
      for (final config in [
        monthly,
        PeriodConfig.customCycle(1),
        PeriodConfig.customCycle(15),
        PeriodConfig.customCycle(31),
      ]) {
        final b = PeriodCalendar.bounds(
          config,
          today: today,
          oldest: dates.oldest,
          newest: dates.newest,
        );
        expect(b.first.contains(dates.oldest), isTrue);
        expect(b.last.contains(dates.newest), isTrue);
        final all = PeriodCalendar.between(config, b.first.start, b.last.start);
        expect(all.first, b.first);
        expect(all.last, b.last);
      }
    });
  });
}
