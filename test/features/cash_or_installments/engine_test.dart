import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/features/cash_or_installments/domain/cash_or_installments_engine.dart';

import 'fixture.dart';

void main() {
  final cases = (loadCashOrInstallmentsFixture()['casos'] as List)
      .cast<Map<String, dynamic>>();

  group('motor × referência independente (ao centavo)', () {
    for (final c in cases) {
      final entrada = c['entrada'] as Map<String, dynamic>;
      test(entrada['id'], () {
        final esperado = c['esperado'] as Map<String, dynamic>;
        final result = simulateCashOrInstallments(
          engineInputFromFixture(entrada, esperado),
        );
        expectMatchesReference(result, esperado);
      });
    }
  });

  group('propriedades', () {
    SimulationInput base({
      int cash = 95000,
      int rate = 1365,
      int percent = 10000,
      int parcels = 10,
      int each = 10000,
    }) => SimulationInput(
      today: CalendarDate(2026, 11, 16),
      cashPriceCents: BigInt.from(cash),
      installments: [
        for (var k = 0; k < parcels; k++)
          Installment(
            dueDate: CalendarDate.clamped(2026, 12 + k, 10),
            cents: BigInt.from(each),
          ),
      ],
      product: InvestmentProduct.cdb,
      percentE2: percent,
      annualRateE2: rate,
    );

    test('a diferença não depende da reserva (controle, todos os casos)', () {
      for (final c in cases) {
        final input = engineInputFromFixture(
          c['entrada'] as Map<String, dynamic>,
          c['esperado'] as Map<String, dynamic>,
        );
        final normal = simulateCashOrInstallments(input);
        for (final extra in [1, 12345, 5000000]) {
          final bigger = simulateCashOrInstallments(
            input,
            extraReserveCents: BigInt.from(extra),
          );
          expect(bigger.reserve, normal.reserve + BigInt.from(extra));
          // Exata em ponto fixo; só o arredondamento dos acumulados pode
          // mover 1–2 centavos.
          expect(
            (bigger.difference - normal.difference).abs() <= BigInt.two,
            isTrue,
            reason: '${c['entrada']['id']} +$extra',
          );
        }
      }
    });

    test('reserva extra rende igual nos dois caminhos', () {
      final normal = simulateCashOrInstallments(base());
      final bigger = simulateCashOrInstallments(
        base(),
        extraReserveCents: BigInt.from(100000),
      );
      final gainCash = bigger.cashPath.cash - normal.cashPath.cash;
      final gainInst =
          bigger.installmentPath.cash - normal.installmentPath.cash;
      expect(gainCash > BigInt.from(100000), isTrue);
      expect((gainCash - gainInst).abs() <= BigInt.two, isTrue);
    });

    test('taxa zero: ninguém rende e não há imposto', () {
      final r = simulateCashOrInstallments(base(rate: 0));
      expect(r.installmentPath.yieldCents, BigInt.zero);
      expect(r.installmentPath.taxes, BigInt.zero);
      expect(r.installmentPath.cash, BigInt.zero);
      expect(r.cashPath.cash, BigInt.from(5000));
      expect(r.verdict, Verdict.cash);
    });

    test('tabela fecha: saldo final = inicial + rendimento − impostos − '
        'parcela, linha a linha', () {
      final r = simulateCashOrInstallments(base(rate: 1490, percent: 12000));
      var start = r.reserve;
      for (final row in r.rows) {
        expect(row.startBalance, start);
        expect(
          row.endBalance,
          row.startBalance + row.yieldCents - row.taxes - row.installment,
        );
        start = row.endBalance;
      }
      expect(
        r.finalRedemption.cash,
        r.finalRedemption.startBalance - r.finalRedemption.taxes,
      );
      expect(r.finalRedemption.cash, r.installmentPath.cash);
      final yieldSum = r.rows.fold(BigInt.zero, (s, x) => s + x.yieldCents);
      expect(yieldSum, r.installmentPath.yieldCents);
    });

    test('mais rendimento nunca piora o parcelado', () {
      BigInt cashAt(int pct) =>
          simulateCashOrInstallments(base(percent: pct)).installmentPath.cash;
      expect(cashAt(12000) >= cashAt(10000), isTrue);
      expect(cashAt(10000) >= cashAt(8500), isTrue);
    });

    test('limite do empate: menos de R\$ 1,00', () {
      expect(tieThresholdCents, BigInt.from(100));
    });

    test('entrada impossível é recusada', () {
      expect(
        () => SimulationInput(
          today: CalendarDate(2026, 11, 16),
          cashPriceCents: BigInt.one,
          installments: const [],
          product: InvestmentProduct.cdb,
          percentE2: 10000,
          annualRateE2: 1365,
        ),
        throwsArgumentError,
      );
      expect(
        () => SimulationInput(
          today: CalendarDate(2026, 11, 16),
          cashPriceCents: BigInt.one,
          installments: [
            Installment(dueDate: CalendarDate(2026, 11, 16), cents: BigInt.one),
          ],
          product: InvestmentProduct.cdb,
          percentE2: 10000,
          annualRateE2: 1365,
        ),
        throwsArgumentError,
      );
    });
  });
}
