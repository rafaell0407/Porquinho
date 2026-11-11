import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
PeriodRange r(CalendarDate a, CalendarDate b) => PeriodRange(a, b);

void main() {
  final calendar = PeriodConfig.calendarMonth();

  test('mês-calendário', () {
    expect(
      PeriodCalendar.containing(calendar, d(2026, 11, 10)),
      r(d(2026, 11, 1), d(2026, 12, 1)),
    );
    expect(
      PeriodCalendar.containing(calendar, d(2026, 12, 31)),
      r(d(2026, 12, 1), d(2027, 1, 1)),
    );
    // Fim exclusivo pertence ao período seguinte (RN036).
    expect(
      PeriodCalendar.containing(calendar, d(2026, 12, 1)).start,
      d(2026, 12, 1),
    );
  });

  test('ciclo dia 20 atravessa a virada do ano', () {
    final c = PeriodConfig.customCycle(20);
    expect(
      PeriodCalendar.containing(c, d(2026, 11, 10)),
      r(d(2026, 10, 20), d(2026, 11, 20)),
    );
    expect(
      PeriodCalendar.containing(c, d(2026, 1, 5)),
      r(d(2025, 12, 20), d(2026, 1, 20)),
    );
    expect(
      PeriodCalendar.containing(c, d(2026, 11, 20)),
      r(d(2026, 11, 20), d(2026, 12, 20)),
    );
  });

  test('RN037: dia 31 em meses curtos', () {
    final c = PeriodConfig.customCycle(31);
    final p1 = PeriodCalendar.containing(c, d(2026, 1, 31));
    expect(p1, r(d(2026, 1, 31), d(2026, 2, 28)));
    final p2 = PeriodCalendar.next(c, p1);
    expect(p2, r(d(2026, 2, 28), d(2026, 3, 31)));
    final p3 = PeriodCalendar.next(c, p2);
    expect(p3, r(d(2026, 3, 31), d(2026, 4, 30)));
    expect(PeriodCalendar.next(c, p3), r(d(2026, 4, 30), d(2026, 5, 31)));
    expect(PeriodCalendar.previous(c, p3), p2);
  });

  test('ano bissexto: fevereiro com 29 dias', () {
    final c31 = PeriodConfig.customCycle(31);
    expect(
      PeriodCalendar.containing(c31, d(2028, 1, 31)),
      r(d(2028, 1, 31), d(2028, 2, 29)),
    );
    final c29 = PeriodConfig.customCycle(29);
    expect(
      PeriodCalendar.containing(c29, d(2028, 2, 29)),
      r(d(2028, 2, 29), d(2028, 3, 29)),
    );
    expect(
      PeriodCalendar.containing(c29, d(2027, 2, 28)),
      r(d(2027, 2, 28), d(2027, 3, 29)),
    );
    expect(
      PeriodCalendar.containing(c29, d(2027, 3, 1)),
      r(d(2027, 2, 28), d(2027, 3, 29)),
    );
  });

  test('transição de configuração (RN002)', () {
    // Mensal terminando em 01/12; novo ciclo dia 20: [01/12, 20/12).
    expect(
      PeriodCalendar.transition(PeriodConfig.customCycle(20), d(2026, 12, 1)),
      r(d(2026, 12, 1), d(2026, 12, 20)),
    );
    // Início depois do dia do ciclo: vai para o mês seguinte.
    expect(
      PeriodCalendar.transition(PeriodConfig.customCycle(10), d(2026, 12, 20)),
      r(d(2026, 12, 20), d(2027, 1, 10)),
    );
    // Início igual à fronteira: não gera período vazio.
    expect(
      PeriodCalendar.transition(PeriodConfig.customCycle(20), d(2026, 12, 20)),
      r(d(2026, 12, 20), d(2027, 1, 20)),
    );
    expect(
      PeriodCalendar.transition(calendar, d(2026, 12, 20)),
      r(d(2026, 12, 20), d(2027, 1, 1)),
    );
  });

  group('36 meses sem lacuna nem sobreposição nos dois sentidos', () {
    final configs = <String, PeriodConfig>{
      'mês': calendar,
      for (final day in [1, 15, 20, 28, 29, 30, 31])
        'dia $day': PeriodConfig.customCycle(day),
    };
    for (final entry in configs.entries) {
      for (final startYear in [2027, 2028]) {
        test('${entry.key} a partir de $startYear', () {
          final config = entry.value;
          var current = PeriodCalendar.containing(config, d(startYear, 1, 15));
          final forward = <PeriodRange>[current];
          for (var i = 0; i < 36; i++) {
            final next = PeriodCalendar.next(config, current);
            expect(next.start, current.end);
            expect(next.end.isAfter(next.start), isTrue);
            forward.add(next);
            current = next;
          }
          var back = forward.last;
          for (var i = 35; i >= 0; i--) {
            back = PeriodCalendar.previous(config, back);
            expect(back, forward[i]);
          }
          // Toda data cai em exatamente um período.
          for (
            var day = forward.first.start;
            day.isBefore(forward.last.start);
            day = day.addDays(1)
          ) {
            final hits = forward.where((p) => p.contains(day)).length;
            expect(hits, 1, reason: '$day');
            expect(PeriodCalendar.containing(config, day).contains(day), true);
          }
        });
      }
    }
  });

  test('forward lista até a data', () {
    final list = PeriodCalendar.forward(
      calendar,
      r(d(2026, 7, 1), d(2026, 8, 1)),
      d(2026, 10, 15),
    );
    expect(list.length, 4);
    expect(list.last, r(d(2026, 10, 1), d(2026, 11, 1)));
  });

  test('dia inicial inválido', () {
    expect(() => PeriodConfig.customCycle(0), throwsArgumentError);
    expect(() => PeriodConfig.customCycle(32), throwsArgumentError);
  });
}
