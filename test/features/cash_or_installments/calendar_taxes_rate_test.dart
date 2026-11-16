import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/features/cash_or_installments/domain/business_calendar.dart';
import 'package:porquinho/features/cash_or_installments/domain/fixed_point.dart';
import 'package:porquinho/features/cash_or_installments/domain/investment_taxes.dart';

import 'fixture.dart';

CalendarDate _d(String iso) => CalendarDate.parse(iso);

void main() {
  final fixture = loadCashOrInstallmentsFixture();

  group('calendário (referência independente)', () {
    final cal = fixture['calendario'] as Map<String, dynamic>;

    test('feriados nacionais por ano', () {
      final byYear = cal['feriados'] as Map<String, dynamic>;
      for (final entry in byYear.entries) {
        expect(
          BusinessCalendar.nationalHolidays(
            int.parse(entry.key),
          ).map((d) => d.toIso()).toList(),
          entry.value,
          reason: 'ano ${entry.key}',
        );
      }
    });

    test('dias úteis no ano', () {
      final counts = cal['dias_uteis_no_ano'] as Map<String, dynamic>;
      for (final entry in counts.entries) {
        final y = int.parse(entry.key);
        expect(
          BusinessCalendar.businessDaysBetween(
            CalendarDate(y, 1, 1),
            CalendarDate(y + 1, 1, 1),
          ),
          entry.value,
          reason: 'ano $y',
        );
      }
    });

    test('dia útil anterior e próximo', () {
      (cal['dia_util_anterior'] as Map<String, dynamic>).forEach((k, v) {
        expect(BusinessCalendar.previousOrSame(_d(k)).toIso(), v, reason: k);
      });
      (cal['proximo_dia_util'] as Map<String, dynamic>).forEach((k, v) {
        expect(BusinessCalendar.nextOrSame(_d(k)).toIso(), v, reason: k);
      });
    });

    test('Páscoa em anos conhecidos', () {
      const known = {
        2024: '2024-03-31',
        2025: '2025-04-20',
        2026: '2026-04-05',
        2027: '2027-03-28',
        2038: '2038-04-25',
        2285: '2285-03-22',
      };
      known.forEach((y, iso) {
        expect(BusinessCalendar.easterSunday(y).toIso(), iso);
      });
    });

    test('Consciência Negra só a partir de 2024', () {
      expect(BusinessCalendar.isHoliday(CalendarDate(2023, 11, 20)), isFalse);
      expect(BusinessCalendar.isHoliday(CalendarDate(2024, 11, 20)), isTrue);
    });

    test('intervalo vazio ou invertido tem zero dias úteis', () {
      final d = _d('2026-11-16');
      expect(BusinessCalendar.businessDaysBetween(d, d), 0);
      expect(BusinessCalendar.businessDaysBetween(d, d.addDays(-5)), 0);
      expect(BusinessCalendar.businessDaysBetween(d, d.addDays(1)), 1);
    });

    test('a regra do resto do app (RN038) não muda', () {
      // Sexta, 20/11/2026: feriado aqui, dia útil para o restante do app.
      final d = _d('2026-11-20');
      expect(d.isBusinessDay, isTrue);
      expect(BusinessCalendar.isBusinessDay(d), isFalse);
    });
  });

  group('impostos (referência independente)', () {
    final taxes = fixture['impostos'] as Map<String, dynamic>;

    test('IOF por dia corrido', () {
      final iof = (taxes['iof_por_dia'] as List).cast<int>();
      for (var days = 0; days < iof.length; days++) {
        expect(InvestmentTaxes.iofPercent(days), iof[days], reason: '$days');
      }
      expect(InvestmentTaxes.iofPercent(400), 0);
    });

    test('IR nas viradas de faixa', () {
      (taxes['ir_permil'] as Map<String, dynamic>).forEach((k, v) {
        expect(InvestmentTaxes.irPermil(int.parse(k)), v, reason: k);
      });
    });

    test('dias negativos são recusados', () {
      expect(() => InvestmentTaxes.iofPercent(-1), throwsArgumentError);
      expect(() => InvestmentTaxes.irPermil(-1), throwsArgumentError);
    });
  });

  group('taxa diária', () {
    BigInt grow(DailyRate rate, BigInt fixed, int days) {
      var v = fixed;
      for (var i = 0; i < days; i++) {
        v += rate.dayYield(v);
      }
      return v;
    }

    test('252 dias úteis a 100% rendem exatamente a taxa anual', () {
      for (final annual in [1, 1050, 1365, 1490, 10000]) {
        final rate = DailyRate(annualRateE2: annual, percentE2: 10000);
        final start = Fixed.fromCents(BigInt.from(100000000));
        final end = grow(rate, start, 252);
        final expected =
            start * BigInt.from(10000 + annual) ~/ BigInt.from(10000);
        // Erro bem abaixo de 1 milionésimo de centavo em R$ 1 milhão.
        expect(
          (end - expected).abs() < Fixed.scale ~/ BigInt.from(1000000),
          isTrue,
          reason: 'taxa $annual',
        );
      }
    });

    test('CDI 13,65%: taxa diária confere com o mercado', () {
      // (1,1365)^(1/252) − 1 = 0,00050788037326185779… ao dia (fator diário
      // 1,00050788 divulgado pela B3 com 8 casas).
      final r = DailyRate(annualRateE2: 1365, percentE2: 10000);
      final perDay =
          r.dailyRateNumerator * BigInt.from(10).pow(20) ~/ DailyRate.rootScale;
      expect(perDay, BigInt.parse('50788037326185779'));
    });

    test('% do CDI incide sobre a taxa diária', () {
      final full = DailyRate(annualRateE2: 1365, percentE2: 10000);
      final part = DailyRate(annualRateE2: 1365, percentE2: 8500);
      final v = Fixed.fromCents(BigInt.from(1000000));
      final ratio = part.dayYield(v) * BigInt.from(10000) ~/ full.dayYield(v);
      expect(ratio.toInt(), inInclusiveRange(8499, 8500));
    });

    test('taxa zero ou 0% do CDI não rende', () {
      final v = Fixed.fromCents(BigInt.from(100000));
      expect(
        DailyRate(annualRateE2: 0, percentE2: 10000).dayYield(v),
        BigInt.zero,
      );
      expect(
        DailyRate(annualRateE2: 1365, percentE2: 0).dayYield(v),
        BigInt.zero,
      );
    });

    test('raiz inteira exata', () {
      expect(integerRoot(BigInt.from(1000), 3), BigInt.from(10));
      expect(integerRoot(BigInt.from(999), 3), BigInt.from(9));
      final big = BigInt.from(10).pow(60) + BigInt.one;
      expect(integerRoot(big, 2), BigInt.from(10).pow(30));
    });
  });
}
