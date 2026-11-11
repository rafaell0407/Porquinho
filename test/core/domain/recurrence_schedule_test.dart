import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/recurrence_schedule.dart';

CalendarDate d(String iso) => CalendarDate.parse(iso);

void main() {
  group('mensal', () {
    test('dia 31: jan 31, fev 28, mar 31, abr 30', () {
      final s = RecurrenceSchedule.monthly(startsOn: d('2027-01-01'), day: 31);
      final dates = RecurrenceCalendar.monthlyUntil(s, d('2027-04-30'));
      expect(dates.map((e) => e.toIso()), [
        '2027-01-31',
        '2027-02-28',
        '2027-03-31',
        '2027-04-30',
      ]);
    });

    test('dia 31 em ano bissexto cai em 29/02', () {
      final s = RecurrenceSchedule.monthly(startsOn: d('2028-01-01'), day: 31);
      final dates = RecurrenceCalendar.monthlyUntil(s, d('2028-03-01'));
      expect(dates[1].toIso(), '2028-02-29');
    });

    test('dia 29 e 30 em fevereiro comum e bissexto', () {
      final s29 = RecurrenceSchedule.monthly(
        startsOn: d('2027-02-01'),
        day: 29,
      );
      expect(
        RecurrenceCalendar.monthlyUntil(s29, d('2027-02-28')).single,
        d('2027-02-28'),
      );
      final s30 = RecurrenceSchedule.monthly(
        startsOn: d('2028-02-01'),
        day: 30,
      );
      expect(
        RecurrenceCalendar.monthlyUntil(s30, d('2028-02-29')).single,
        d('2028-02-29'),
      );
    });

    test(
      'dia 31 por 48 meses: uma por mês, sempre o último dia quando curto',
      () {
        final s = RecurrenceSchedule.monthly(
          startsOn: d('2026-01-31'),
          day: 31,
        );
        final dates = RecurrenceCalendar.monthlyUntil(s, d('2029-12-31'));
        expect(dates, hasLength(48));
        for (final date in dates) {
          expect(date.day, CalendarDate.daysInMonth(date.year, date.month));
        }
        expect(dates.map((e) => e.monthIndex).toSet(), hasLength(48));
      },
    );

    test('criada em 10/05 com dia 31 → primeira em 31/05', () {
      expect(
        RecurrenceCalendar.firstMonthly(d('2026-05-10'), 31),
        d('2026-05-31'),
      );
    });

    test('criada em 31/05 com dia 10 → primeira em 10/06', () {
      expect(
        RecurrenceCalendar.firstMonthly(d('2026-05-31'), 10),
        d('2026-06-10'),
      );
    });

    test('só gera até hoje; data futura fica para depois', () {
      final s = RecurrenceSchedule.monthly(startsOn: d('2026-11-01'), day: 20);
      expect(RecurrenceCalendar.monthlyUntil(s, d('2026-11-19')), isEmpty);
      expect(RecurrenceCalendar.monthlyUntil(s, d('2026-11-20')), [
        d('2026-11-20'),
      ]);
    });

    test('início no passado recupera todas as atrasadas, uma vez cada', () {
      final s = RecurrenceSchedule.monthly(startsOn: d('2026-08-05'), day: 5);
      final dates = RecurrenceCalendar.monthlyUntil(s, d('2026-11-11'));
      expect(dates.map((e) => e.toIso()), [
        '2026-08-05',
        '2026-09-05',
        '2026-10-05',
        '2026-11-05',
      ]);
    });
  });

  group('por período', () {
    final config = PeriodConfig.customCycle(20);
    final p1 = PeriodCalendar.containing(config, d('2026-09-25'));
    final p2 = PeriodCalendar.next(config, p1);
    final p3 = PeriodCalendar.next(config, p2);

    test('uma ocorrência por período, incluindo o atual', () {
      final due = RecurrenceCalendar.periodsUntil(d('2026-09-01'), [
        p1,
        p2,
        p3,
      ], d('2026-11-25'));
      expect(due, [p1, p2, p3]);
    });

    test('criada no meio do período gera a do período atual', () {
      final due = RecurrenceCalendar.periodsUntil(d('2026-10-25'), [
        p1,
        p2,
        p3,
      ], d('2026-10-26'));
      expect(due, [p2]);
      expect(due.single.start.isBefore(d('2026-10-25')), isTrue);
    });

    test('período futuro não gera', () {
      expect(
        RecurrenceCalendar.periodsUntil(d('2026-09-01'), [
          p1,
          p2,
          p3,
        ], d('2026-10-01')),
        [p1],
      );
    });

    test('data da primeira ocorrência é o início do período', () {
      expect(
        RecurrenceCalendar.firstOccurrenceDate(
          RecurrenceFrequency.byPeriod,
          d('2026-10-10'),
          p2,
        ),
        p2.start,
      );
      expect(
        RecurrenceCalendar.firstOccurrenceDate(
          RecurrenceFrequency.monthly,
          d('2026-10-10'),
          p2,
        ),
        d('2026-10-10'),
      );
    });
  });

  group('mudança de agenda (D2)', () {
    test('dia 5 gerada em 05/11, muda para dia 20 → próxima 20/12', () {
      final floor = RecurrenceCalendar.scheduleChangeFloor(d('2026-11-05'));
      expect(floor, d('2026-12-01'));
      final start = RecurrenceCalendar.effectiveStart(
        d('2026-11-05'),
        d('2026-11-10'),
        floor: floor,
      );
      final s = RecurrenceSchedule.monthly(startsOn: start, day: 20);
      expect(RecurrenceCalendar.monthlyUntil(s, d('2026-12-31')), [
        d('2026-12-20'),
      ]);
    });

    test('mês atual sem ocorrência ainda recebe a nova data futura', () {
      final start = RecurrenceCalendar.effectiveStart(
        d('2026-11-05'),
        d('2026-11-10'),
      );
      final s = RecurrenceSchedule.monthly(startsOn: start, day: 20);
      expect(RecurrenceCalendar.monthlyUntil(s, d('2026-11-30')), [
        d('2026-11-20'),
      ]);
    });

    test('nunca cria ocorrências passadas', () {
      final start = RecurrenceCalendar.effectiveStart(
        d('2026-01-01'),
        d('2026-11-22'),
      );
      final s = RecurrenceSchedule.monthly(startsOn: start, day: 20);
      expect(RecurrenceCalendar.monthlyUntil(s, d('2026-11-30')), isEmpty);
    });

    test('piso respeita o fim do período da última ocorrência', () {
      final floor = RecurrenceCalendar.scheduleChangeFloor(
        d('2026-10-20'),
        lastPeriodEnd: d('2026-11-20'),
      );
      expect(floor, d('2026-11-20'));
    });
  });

  group('identificador determinístico (D1)', () {
    test('é igual ao calculado pelo servidor (suíte PostgreSQL)', () {
      expect(
        RecurrenceCalendar.occurrenceId(
          '3f2a9d1e-1111-4c22-8d33-aaaaaaaaaaaa',
          d('2026-11-05'),
        ),
        'd07bc585-9b84-523c-8598-d815da7b604e',
      );
    });

    test('é estável, tem formato de UUID e muda com a data', () {
      const t = '3f2a9d1e-1111-4c22-8d33-aaaaaaaaaaaa';
      final a = RecurrenceCalendar.occurrenceId(t, d('2026-11-05'));
      final b = RecurrenceCalendar.occurrenceId(
        t.toUpperCase(),
        d('2026-11-05'),
      );
      final c = RecurrenceCalendar.occurrenceId(t, d('2026-12-05'));
      expect(a, b);
      expect(a, isNot(c));
      expect(
        a,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-8[0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
  });
}
