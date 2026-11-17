import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/reserve_calculator.dart';

import 'card_bills_fixtures.dart';

/// GF1.8 calculadora da reserva (spec §9).
void main() {
  test('apagar tudo deixa o visor vazio, sem erro', () {
    var calc = ReserveCalculator.start(BigInt.from(500));
    calc = calc.backspace().backspace();
    expect(calc.expression, '');
    expect(calc.clear().expression, '');
  });

  ReserveCalculator type(ReserveCalculator calc, String keys) {
    var r = calc;
    for (final k in keys.split('')) {
      r = switch (k) {
        '+' => r.operation(CalcOp.add),
        '-' => r.operation(CalcOp.subtract),
        '*' => r.operation(CalcOp.multiply),
        '/' => r.operation(CalcOp.divide),
        ',' => r.comma(),
        '=' => r.equals(),
        '<' => r.backspace(),
        'C' => r.clear(),
        _ => r.digit(int.parse(k)),
      };
    }
    return r;
  }

  test('começa com o valor atual e mostra a conta inteira', () {
    final start = ReserveCalculator.start(c(2820743));
    expect(start.expression, '28.207,43');
    final r = type(start, '+1500-320=');
    expect(r.display, '28.207,43 + 1.500 − 320 = 29.387,43');
    expect(r.result, c(2938743));
    expect(
      calculatorSummary(c(2820743), r.result!),
      'Atual R\$ 28.207,43 → Novo R\$ 29.387,43 (+R\$ 1.180,00)',
    );
  });

  test('× e ÷ antes de + e −', () {
    final r = type(ReserveCalculator.start(BigInt.zero), 'C100+50*2=');
    expect(r.result, c(20000));
    expect(
      type(ReserveCalculator.start(BigInt.zero), 'C10-4/2*3=').result,
      c(400),
    );
  });

  test('arredonda para o centavo mais próximo, meio para cima', () {
    expect(
      type(ReserveCalculator.start(BigInt.zero), 'C1000/3=').result,
      c(33333),
    );
    expect(type(ReserveCalculator.start(BigInt.zero), 'C2/3=').result, c(67));
    expect(type(ReserveCalculator.start(BigInt.zero), 'C0,005=').result, c(1));
    expect(type(ReserveCalculator.start(BigInt.zero), 'C0,004=').result, c(0));
    // Conta exata: 0,1 + 0,2 = 0,30 (sem erro de ponto flutuante).
    expect(
      type(ReserveCalculator.start(BigInt.zero), 'C0,1+0,2=').result,
      c(30),
    );
  });

  test('divisão por zero, negativo e teto são erros', () {
    final div = type(ReserveCalculator.start(BigInt.zero), 'C10/0=');
    expect(div.result, isNull);
    expect(div.error, 'Não é possível dividir por zero.');
    expect(
      type(ReserveCalculator.start(c(1000)), '-20=').error,
      'O resultado não pode ser negativo.',
    );
    // Negativo no meio da conta é aceito se o final não for.
    expect(
      type(ReserveCalculator.start(BigInt.zero), 'C100-200+300=').result,
      c(20000),
    );
    final over = type(ReserveCalculator.start(maxReserve), '+0,01=');
    expect(over.error, contains('10.000.000,00'));
    expect(type(ReserveCalculator.start(maxReserve), '=').result, maxReserve);
  });

  test('apagar, limpar, trocar operador e continuar do resultado', () {
    var r = type(ReserveCalculator.start(c(10000)), '+5<7');
    expect(r.expression, '100 + 7');
    r = type(r, '*-'); // troca o operador pendurado
    expect(r.expression, '100 + 7 −');
    r = type(r, '2=');
    expect(r.result, c(10500));
    r = type(r, '+1=');
    expect(r.result, c(10600));
    r = type(r, '5');
    expect(r.expression, '5');
    expect(type(r, 'C').isEmpty, isTrue);
    expect(type(ReserveCalculator.start(BigInt.zero), 'C=').error, isNotNull);
  });

  test('vírgula e milhares no visor', () {
    final r = type(ReserveCalculator.start(BigInt.zero), 'C,5+1234567,89');
    expect(r.expression, '0,5 + 1.234.567,89');
  });
}
