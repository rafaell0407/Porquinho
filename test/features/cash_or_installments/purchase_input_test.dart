import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/features/cash_or_installments/domain/cash_or_installments_engine.dart';
import 'package:porquinho/features/cash_or_installments/domain/purchase_input.dart';

import 'fixture.dart';

/// Entrada da referência → valores do formulário (já numéricos).
PurchaseValues valuesFromFixture(Map<String, dynamic> e) {
  final av = e['a_vista'] as Map<String, dynamic>;
  final pc = e['parcelado'] as Map<String, dynamic>;
  final byValue = av['modo'] == 'valor';
  final byTotal = pc['modo'] == 'total';
  return PurchaseValues(
    today: CalendarDate.parse(e['hoje'] as String),
    cashMode: byValue ? CashPriceMode.value : CashPriceMode.discount,
    cashValueCents: byValue ? fixtureCents(av['valor']) : null,
    priceCents: byValue ? null : fixtureCents(av['preco']),
    discountE2: byValue ? null : av['desconto_e2'] as int,
    installmentMode: byTotal
        ? InstallmentMode.total
        : InstallmentMode.perInstallment,
    totalCents: byTotal ? fixtureCents(pc['total']) : null,
    installmentCents: byTotal ? null : fixtureCents(pc['parcela']),
    count: pc['n'] as int,
    dueDay: e['dia_vencimento'] as int,
    bill: e['fatura'] == 'proxima' ? FirstBill.next : FirstBill.following,
    product: productFromFixture(e['produto'] as String),
    percentE2: e['percentual_e2'] as int,
    annualRateE2: e['taxa_anual_e2'] as int,
  );
}

CalendarDate _d(String iso) => CalendarDate.parse(iso);

void main() {
  final cases = (loadCashOrInstallmentsFixture()['casos'] as List)
      .cast<Map<String, dynamic>>();

  group('entradas → motor × referência (caminho completo)', () {
    for (final c in cases) {
      final entrada = c['entrada'] as Map<String, dynamic>;
      test(entrada['id'], () {
        final esperado = c['esperado'] as Map<String, dynamic>;
        final input = valuesFromFixture(entrada).toSimulationInput();
        expect(input.cashPriceCents, fixtureCents(esperado['valor_a_vista']));
        expect(
          input.totalInstallmentsCents,
          fixtureCents(esperado['total_parcelado']),
        );
        expectMatchesReference(simulateCashOrInstallments(input), esperado);
      });
    }
  });

  group('valor à vista com desconto (meio para cima)', () {
    test('exemplos', () {
      expect(
        cashPriceFromDiscount(BigInt.from(100000), 500),
        BigInt.from(95000),
      );
      // 1,01 × 50% = 0,505 → 0,51.
      expect(cashPriceFromDiscount(BigInt.from(101), 5000), BigInt.from(51));
      // 0,99 × 3,33% de desconto = 0,957033 → 0,96.
      expect(cashPriceFromDiscount(BigInt.from(99), 333), BigInt.from(96));
      expect(cashPriceFromDiscount(BigInt.from(100), 0), BigInt.from(100));
      expect(cashPriceFromDiscount(BigInt.one, 9999), BigInt.zero);
    });
  });

  group('divisão do total', () {
    test('resto vai para a 1ª parcela', () {
      expect(splitInstallments(BigInt.from(10000), 3), [
        BigInt.from(3334),
        BigInt.from(3333),
        BigInt.from(3333),
      ]);
      expect(splitInstallments(BigInt.from(100000), 10).toSet(), {
        BigInt.from(10000),
      });
      expect(splitInstallments(BigInt.from(5), 5), List.filled(5, BigInt.one));
    });
  });

  group('vencimentos', () {
    test('próxima fatura é depois de hoje', () {
      expect(nextBillDueDate(_d('2026-11-14'), 10), _d('2026-12-10'));
      expect(nextBillDueDate(_d('2026-11-14'), 20), _d('2026-11-20'));
      // Hoje é o dia do vencimento: vai para o mês seguinte.
      expect(nextBillDueDate(_d('2026-12-10'), 10), _d('2027-01-10'));
    });

    test('dia inexistente = último dia do mês, sempre a partir do dia', () {
      final dates = installmentDueDates(
        _d('2027-01-05'),
        31,
        FirstBill.next,
        4,
      );
      expect(dates, [
        _d('2027-01-31'),
        _d('2027-02-28'),
        _d('2027-03-31'),
        _d('2027-04-30'),
      ]);
      expect(installmentDueDates(_d('2028-01-31'), 30, FirstBill.next, 2), [
        _d('2028-02-29'),
        _d('2028-03-30'),
      ]);
    });

    test('fatura seguinte é um mês depois da próxima', () {
      expect(
        installmentDueDates(_d('2026-11-14'), 10, FirstBill.following, 2),
        [_d('2027-01-10'), _d('2027-02-10')],
      );
      expect(installmentDueDates(_d('2026-12-20'), 5, FirstBill.following, 1), [
        _d('2027-02-05'),
      ]);
    });
  });

  group('leitura dos campos', () {
    test('dinheiro', () {
      expect(parsePurchaseMoney('1.000,00'), BigInt.from(100000));
      expect(parsePurchaseMoney('R\$ 950'), BigInt.from(95000));
      expect(parsePurchaseMoney('1.000.000,00'), BigInt.from(100000000));
      for (final bad in ['', '0', '0,00', '-5', '1.000.000,01', '1,234']) {
        expect(
          () => parsePurchaseMoney(bad),
          throwsA(isA<PurchaseInputException>()),
          reason: bad,
        );
      }
    });

    test('percentual com até 2 casas', () {
      int p(String t) => parsePurchasePercent(t, maxE2: 12000);
      expect(p('100'), 10000);
      expect(p('13,65'), 1365);
      expect(p('13.65'), 1365);
      expect(p('5 %'), 500);
      expect(p('0'), 0);
      expect(p('120'), 12000);
      for (final bad in ['', '-1', '120,01', '1,234', 'abc']) {
        expect(
          () => p(bad),
          throwsA(isA<PurchaseInputException>()),
          reason: bad,
        );
      }
    });

    test('inteiros', () {
      expect(parsePurchaseInt('24', min: 1, max: 24), 24);
      for (final bad in ['', '0', '25', '1,5', '-1']) {
        expect(
          () => parsePurchaseInt(bad, min: 1, max: 24),
          throwsA(isA<PurchaseInputException>()),
          reason: bad,
        );
      }
    });

    test('formatação do percentual', () {
      expect(formatPercentE2(10000), '100%');
      expect(formatPercentE2(1365), '13,65%');
      expect(formatPercentE2(550), '5,5%');
      expect(formatPercentE2(9999), '99,99%');
    });
  });

  group('validação do formulário', () {
    final today = _d('2026-11-14');
    const ok = PurchaseForm(
      cashMode: CashPriceMode.discount,
      installmentMode: InstallmentMode.total,
      bill: FirstBill.next,
      product: InvestmentProduct.cdb,
      price: '1.000,00',
      discount: '5',
      total: '1.000,00',
      count: '10',
      dueDay: '10',
      percent: '100',
      rate: '13,65',
    );

    test('formulário do esboço gera a mesma entrada da referência', () {
      final v = validatePurchase(ok, today);
      expect(v.errors, isEmpty);
      final r = simulateCashOrInstallments(v.input!);
      expect(r.cashPath.cash, BigInt.from(5438));
      expect(r.installmentPath.cash, BigInt.from(4653));
      expect(r.verdict, Verdict.cash);
    });

    test('cada campo inválido aparece no seu lugar', () {
      final v = validatePurchase(
        const PurchaseForm(
          cashMode: CashPriceMode.value,
          installmentMode: InstallmentMode.perInstallment,
          bill: FirstBill.next,
          product: InvestmentProduct.cdb,
          cashValue: '',
          installmentValue: '0',
          count: '25',
          dueDay: '32',
          percent: '121',
          rate: '101',
        ),
        today,
      );
      expect(v.input, isNull);
      expect(v.errors.keys.toSet(), {
        PurchaseField.cashValue,
        PurchaseField.installmentValue,
        PurchaseField.count,
        PurchaseField.dueDay,
        PurchaseField.percent,
        PurchaseField.rate,
      });
    });

    test('desconto vazio vale zero; desconto que zera o valor é recusado', () {
      final none = validatePurchase(
        PurchaseForm(
          cashMode: ok.cashMode,
          installmentMode: ok.installmentMode,
          bill: ok.bill,
          product: ok.product,
          price: '1.000,00',
          total: '1.000,00',
          count: '10',
          dueDay: '10',
          rate: '13,65',
        ),
        today,
      );
      expect(none.input!.cashPriceCents, BigInt.from(100000));
      final zero = validatePurchase(
        PurchaseForm(
          cashMode: ok.cashMode,
          installmentMode: ok.installmentMode,
          bill: ok.bill,
          product: ok.product,
          price: '0,01',
          discount: '99,99',
          total: '1,00',
          count: '1',
          dueDay: '10',
          rate: '13,65',
        ),
        today,
      );
      expect(zero.errors.keys, [PurchaseField.discount]);
    });

    test(
      'total menor que 1 centavo por parcela; parcela × n acima do limite',
      () {
        final small = validatePurchase(
          PurchaseForm(
            cashMode: CashPriceMode.value,
            installmentMode: InstallmentMode.total,
            bill: ok.bill,
            product: ok.product,
            cashValue: '1,00',
            total: '0,05',
            count: '10',
            dueDay: '10',
            rate: '13,65',
          ),
          today,
        );
        expect(small.errors.keys, [PurchaseField.total]);
        final big = validatePurchase(
          PurchaseForm(
            cashMode: CashPriceMode.value,
            installmentMode: InstallmentMode.perInstallment,
            bill: ok.bill,
            product: ok.product,
            cashValue: '1,00',
            installmentValue: '50.000,00',
            count: '21',
            dueDay: '10',
            rate: '13,65',
          ),
          today,
        );
        expect(big.errors.keys, [PurchaseField.installmentValue]);
      },
    );

    test('Tesouro Selic ignora o % do CDI', () {
      final v = validatePurchase(
        PurchaseForm(
          cashMode: CashPriceMode.value,
          installmentMode: InstallmentMode.total,
          bill: ok.bill,
          product: InvestmentProduct.treasurySelic,
          cashValue: '950,00',
          total: '1.000,00',
          count: '10',
          dueDay: '10',
          percent: 'qualquer',
          rate: '14,90',
        ),
        today,
      );
      expect(v.errors, isEmpty);
      expect(v.input!.effectivePercentE2, 10000);
    });
  });
}
