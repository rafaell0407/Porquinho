import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/compound_interest/domain/compound_interest.dart';
import 'package:porquinho/features/compound_interest/domain/simulation_math.dart';

BigInt c(int cents) => BigInt.from(cents);

CompoundInterestResult run({
  required int initial,
  int monthly = 0,
  required InterestRate rate,
  required int months,
}) => simulateCompoundInterest(
  CompoundInterestInput(
    initialCents: c(initial),
    monthlyCents: c(monthly),
    rate: rate,
    months: months,
  ),
);

/// Confere as relações que a tela exibe em todas as linhas.
void expectConsistent(CompoundInterestResult r) {
  var sum = BigInt.zero;
  for (final (i, row) in r.rows.indexed) {
    expect(row.month, i);
    expect(row.total, row.invested + row.totalInterest, reason: 'mês $i');
    expect(row.interest.isNegative, isFalse, reason: 'mês $i');
    sum += row.interest;
    expect(row.totalInterest, sum, reason: 'mês $i');
    expect(
      row.invested,
      r.input.initialCents + r.input.monthlyCents * BigInt.from(i),
    );
  }
  expect(r.finalTotal, r.totalInvested + r.totalInterest);
}

void main() {
  group('taxa', () {
    test('mensal é usada direto; anual vira a mensal equivalente', () {
      final monthly = InterestRate.percent(1, RatePeriod.monthly);
      final base = toFixed(c(800000));
      expect(roundFixedToCents(monthly.monthlyInterest(base)), c(8000));
      final annual = InterestRate.percent(12, RatePeriod.annual);
      // (1,12)^(1/12) − 1 ≈ 0,9489%: 8.000 × 0,0094888 ≈ 75,91.
      expect(roundFixedToCents(annual.monthlyInterest(base)), c(7591));
      expect(annual.monthlyPercentE4.percentE4, BigInt.from(9489));
      expect(annual.monthlyPercentE4.exact, isFalse);
      expect(
        InterestRate.percent(0, RatePeriod.annual).monthlyPercentE4.exact,
        isTrue,
      );
    });

    test(
      'exemplo do site de referência: 1.000 + 1.000/mês, 12% a.a., 10 anos',
      () {
        final r = run(
          initial: 100000,
          monthly: 100000,
          rate: InterestRate.percent(12, RatePeriod.annual),
          months: 120,
        );
        expect(r.totalInvested, c(12100000));
        expect(r.finalTotal, c(22503589));
        expect(r.totalInterest, c(10403589));
      },
    );

    test('raiz inteira', () {
      expect(integerRoot(BigInt.from(4096), 12), BigInt.two);
      expect(integerRoot(BigInt.from(4095), 12), BigInt.one);
      final big = BigInt.from(10).pow(42);
      expect(integerRoot(big.pow(12), 12), big);
    });

    test('lê vírgula, ponto e símbolo de %', () {
      expect(
        parseSimulationRate('0,85', RatePeriod.monthly).percentE4,
        BigInt.from(8500),
      );
      expect(
        parseSimulationRate('12.5 %', RatePeriod.annual).percentE4,
        BigInt.from(125000),
      );
      expect(parseSimulationRate('0', RatePeriod.annual).isZero, isTrue);
      expect(
        formatRatePercent(parseSimulationRate('0,8500', RatePeriod.monthly)),
        '0,85%',
      );
    });

    test(
      'recusa vazia, negativa, inválida, muitas casas e acima do limite',
      () {
        for (final bad in ['', '-1', 'abc', '1,23456', '1001', '1,2,3']) {
          expect(
            () => parseSimulationRate(bad, RatePeriod.monthly),
            throwsA(isA<SimulationException>()),
            reason: bad,
          );
        }
        expect(
          parseSimulationRate('1000', RatePeriod.monthly).percentE4,
          BigInt.from(10000000),
        );
      },
    );
  });

  group('valores e período', () {
    test('dinheiro no padrão brasileiro; vazio vale zero', () {
      expect(parseSimulationMoney('8.000,00'), c(800000));
      expect(parseSimulationMoney('R\$ 1.234,5'), c(123450));
      expect(parseSimulationMoney('  '), BigInt.zero);
      expect(parseSimulationMoney('1.000.000.000,00'), c(100000000000));
    });

    test('dinheiro inválido, negativo ou alto demais', () {
      for (final bad in ['-5', '8000.50', '1,234', '1.000.000.000,01', 'x']) {
        expect(
          () => parseSimulationMoney(bad),
          throwsA(isA<SimulationException>()),
          reason: bad,
        );
      }
    });

    test('período em meses ou anos, de 1 a 600 meses', () {
      expect(parseSimulationTerm('2', TermUnit.years), 24);
      expect(parseSimulationTerm('600', TermUnit.months), 600);
      expect(parseSimulationTerm('50', TermUnit.years), 600);
      for (final bad in ['', '0', '-1', '1,5', '601', '51a']) {
        expect(
          () => parseSimulationTerm(bad, TermUnit.months),
          throwsA(isA<SimulationException>()),
          reason: bad,
        );
      }
      expect(
        () => parseSimulationTerm('51', TermUnit.years),
        throwsA(isA<SimulationException>()),
      );
    });

    test('validação do formulário aponta cada campo', () {
      final v = validateCompoundInterest(
        initial: '',
        monthly: '',
        rate: '',
        ratePeriod: RatePeriod.annual,
        term: '0',
        termUnit: TermUnit.years,
      );
      expect(v.input, isNull);
      expect(v.errors.keys, {
        CompoundField.initial,
        CompoundField.rate,
        CompoundField.term,
      });
      final ok = validateCompoundInterest(
        initial: '8.000,00',
        monthly: '',
        rate: '12',
        ratePeriod: RatePeriod.annual,
        term: '2',
        termUnit: TermUnit.years,
      );
      expect(ok.errors, isEmpty);
      expect(ok.input!.initialCents, c(800000));
      expect(ok.input!.monthlyCents, BigInt.zero);
      expect(ok.input!.months, 24);
    });
  });

  group('simulação', () {
    test('R\$ 8.000 a 12% a.a. por 2 anos = 8.000 × 1,12²', () {
      final r = run(
        initial: 800000,
        rate: InterestRate.percent(12, RatePeriod.annual),
        months: 24,
      );
      expect(r.rows, hasLength(25));
      expect(r.rows.first.total, c(800000));
      expect(r.rows.first.interest, BigInt.zero);
      expect(r.rows[1].interest, c(7591));
      expect(r.rows[12].total, c(896000));
      expect(r.finalTotal, c(1003520));
      expect(r.totalInvested, c(800000));
      expect(r.totalInterest, c(203520));
      expectConsistent(r);
    });

    test('R\$ 8.000 a 12% a.a. por 10 anos = 8.000 × 1,12^10', () {
      final r = run(
        initial: 800000,
        rate: InterestRate.percent(12, RatePeriod.annual),
        months: 120,
      );
      expect(r.finalTotal, c(2484679));
      expectConsistent(r);
    });

    test('aporte mensal com taxa anual', () {
      final r = run(
        initial: 100000,
        monthly: 10000,
        rate: InterestRate.percent(12, RatePeriod.annual),
        months: 12,
      );
      expect(r.finalTotal, c(238465));
      expectConsistent(r);
    });

    test('aporte no final do mês: não rende no próprio mês', () {
      final r = run(
        initial: 100000,
        monthly: 10000,
        rate: InterestRate.percent(1, RatePeriod.monthly),
        months: 12,
      );
      expect(r.rows[1].interest, c(1000));
      expect(r.rows[1].total, c(111000));
      expect(r.rows[2].interest, c(1110));
      expect(r.finalTotal, c(239508));
      expect(r.totalInvested, c(220000));
      expect(r.totalInterest, c(19508));
      expectConsistent(r);
    });

    test('taxa com casas decimais e período longo', () {
      final r = run(
        initial: 0,
        monthly: 50000,
        rate: parseSimulationRate('0,85', RatePeriod.monthly),
        months: 360,
      );
      expect(r.finalTotal, c(117961939));
      expect(r.totalInvested, c(18000000));
      expectConsistent(r);
    });

    test('taxa anual fracionada (12,5% a.a.)', () {
      final r = run(
        initial: 1000000,
        rate: parseSimulationRate('12,5', RatePeriod.annual),
        months: 12,
      );
      expect(r.finalTotal, c(1125000));
      expectConsistent(r);
    });

    test('taxa zero: total = investido, sem juros', () {
      final r = run(
        initial: 100000,
        monthly: 5000,
        rate: InterestRate.percent(0, RatePeriod.monthly),
        months: 10,
      );
      expect(r.finalTotal, c(150000));
      expect(r.totalInterest, BigInt.zero);
      expectConsistent(r);
    });

    test('valor inicial zero: só aportes rendem', () {
      final r = run(
        initial: 0,
        monthly: 10000,
        rate: InterestRate.percent(1, RatePeriod.monthly),
        months: 2,
      );
      expect(r.rows[1].total, c(10000));
      expect(r.rows[2].interest, c(100));
      expect(r.finalTotal, c(20100));
      expectConsistent(r);
    });

    test('valores máximos em 600 meses continuam exatos', () {
      final r = run(
        initial: 100000000000,
        monthly: 100000000000,
        rate: InterestRate.percent(1, RatePeriod.monthly),
        months: 600,
      );
      expect(r.finalTotal, BigInt.parse('3944992309693130'));
      expectConsistent(r);
    });

    test('patrimônio acima do limite vira mensagem, não falha', () {
      expect(
        () => run(
          initial: 100000000000,
          rate: InterestRate.percent(1000, RatePeriod.monthly),
          months: 600,
        ),
        throwsA(isA<SimulationException>()),
      );
    });

    test('mesmo resultado em repetidas execuções', () {
      CompoundInterestResult once() => run(
        initial: 123456,
        monthly: 7890,
        rate: parseSimulationRate('1,2345', RatePeriod.monthly),
        months: 120,
      );
      final a = once();
      final b = once();
      for (var i = 0; i < a.rows.length; i++) {
        expect(a.rows[i].total, b.rows[i].total);
      }
      expectConsistent(a);
    });
  });
}
