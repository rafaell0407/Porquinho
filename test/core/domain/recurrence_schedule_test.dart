@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/recurrence_schedule.dart';

CalendarDate d(String iso) => CalendarDate.parse(iso);

void main() {
  group('mensal', () {
    test('dia 31 (RN038): jan 31, fev 26 (28 é domingo), mar 31, abr 30', () {
      final s = RecurrenceSchedule.monthly(startsOn: d('2027-01-01'), day: 31);
      final dates = RecurrenceCalendar.monthlyUntil(s, d('2027-04-30'));
      expect(dates.map((e) => e.toIso()), [
        '2027-01-31', // domingo, mas o dia existe: mantém
        '2027-02-26', // 28/02 é domingo: sexta anterior
        '2027-03-31',
        '2027-04-30', // sexta
      ]);
    });

    test('dia que existe fica mesmo em sábado ou domingo', () {
      // 31/05/2026 é domingo; 31/01/2026 é sábado.
      expect(RecurrenceCalendar.monthlyDate(2026, 5, 31), d('2026-05-31'));
      expect(RecurrenceCalendar.monthlyDate(2026, 1, 31), d('2026-01-31'));
      expect(RecurrenceCalendar.monthlyDate(2026, 11, 15), d('2026-11-15'));
    });

    test('dia inexistente: último dia útil; meses seguintes voltam ao dia', () {
      // 28/02/2026 é sábado → 27/02; 30/04/2026 é quinta → 30/04.
      final s = RecurrenceSchedule.monthly(startsOn: d('2026-01-31'), day: 31);
      final dates = RecurrenceCalendar.monthlyUntil(s, d('2026-05-31'));
      expect(dates.map((e) => e.toIso()), [
        '2026-01-31',
        '2026-02-27',
        '2026-03-31',
        '2026-04-30',
        '2026-05-31',
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
      // 28/02/2027 é domingo: sexta 26/02.
      expect(
        RecurrenceCalendar.monthlyUntil(s29, d('2027-02-28')).single,
        d('2027-02-26'),
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

    test('dia 31 por 48 meses: uma por mês; mês curto = último dia útil', () {
      final s = RecurrenceSchedule.monthly(startsOn: d('2026-01-31'), day: 31);
      final dates = RecurrenceCalendar.monthlyUntil(s, d('2029-12-31'));
      expect(dates, hasLength(48));
      for (final date in dates) {
        final last = CalendarDate.daysInMonth(date.year, date.month);
        if (last == 31) {
          expect(date.day, 31, reason: '$date');
        } else {
          // Último dia útil do mês: nenhum dia útil depois dele no mês.
          expect(date.isBusinessDay, isTrue, reason: '$date');
          for (var day = date.day + 1; day <= last; day++) {
            expect(
              CalendarDate(date.year, date.month, day).isBusinessDay,
              isFalse,
              reason: '$date',
            );
          }
        }
      }
      expect(dates.map((e) => e.monthIndex).toSet(), hasLength(48));
    });

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

  group(
    'tabela única de casos (test/fixtures/monthly_recurrence_cases.json)',
    () {
      final json =
          jsonDecode(
                File(
                  'test/fixtures/monthly_recurrence_cases.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final cases = (json['cases'] as List).cast<Map<String, dynamic>>();

      test('mesma tabela do teste SQL do servidor', () {
        expect(cases, hasLength(360));
        final sql = File(
          'supabase/tests/recurrence_monthly_date_cases_test.sql',
        ).readAsStringSync();
        for (final c in cases) {
          expect(
            sql,
            contains(
              "(${c['year']}, ${c['month']}, ${c['day']}, DATE '${c['date']}')",
            ),
          );
        }
      });

      for (final c in cases) {
        test('${c['year']}-${c['month']} dia ${c['day']}', () {
          expect(
            RecurrenceCalendar.monthlyDate(
              c['year'] as int,
              c['month'] as int,
              c['day'] as int,
            ).toIso(),
            c['date'],
          );
        });
      }
    },
  );

  group('só "Todo mês"', () {
    test('única frequência que pode ser escolhida', () {
      expect(RecurrenceFrequency.selectable, [RecurrenceFrequency.monthly]);
      // Modelos antigos "por período" ainda são lidos do banco.
      expect(
        RecurrenceFrequency.fromDb('by_period'),
        RecurrenceFrequency.byPeriod,
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
