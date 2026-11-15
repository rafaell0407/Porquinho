import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/compound_interest/domain/compound_interest.dart';
import 'package:porquinho/features/compound_interest/domain/simulation_math.dart';
import 'package:porquinho/features/compound_interest/domain/withdrawal_simulation.dart';

BigInt c(int cents) => BigInt.from(cents);

final onePercent = InterestRate.percent(1, RatePeriod.monthly);

WithdrawalResult run({
  required int initial,
  required int withdrawal,
  InterestRate? rate,
  int months = 24,
}) => simulateWithdrawals(
  WithdrawalInput(
    initialCents: c(initial),
    withdrawalCents: c(withdrawal),
    rate: rate ?? onePercent,
    months: months,
  ),
);

/// Relações exibidas na tela, em todas as linhas.
void expectConsistent(WithdrawalResult r) {
  var interest = BigInt.zero;
  var withdrawn = BigInt.zero;
  for (final (i, row) in r.rows.indexed) {
    expect(row.month, i);
    expect(row.interest.isNegative, isFalse, reason: 'mês $i');
    expect(row.withdrawal.isNegative, isFalse, reason: 'mês $i');
    expect(row.balance.isNegative, isFalse, reason: 'mês $i');
    interest += row.interest;
    withdrawn += row.withdrawal;
    expect(row.totalInterest, interest, reason: 'mês $i');
    expect(row.totalWithdrawn, withdrawn, reason: 'mês $i');
    expect(
      row.balance,
      r.input.initialCents + row.totalInterest - row.totalWithdrawn,
      reason: 'mês $i',
    );
  }
}

void main() {
  test('retirada menor que os juros: patrimônio cresce', () {
    final r = run(initial: 10000000, withdrawal: 50000);
    expect(r.depleted, isFalse);
    expect(r.rows, hasLength(25));
    expect(r.rows[1].interest, c(100000));
    expect(r.rows[1].withdrawal, c(50000));
    expect(r.rows[1].balance, c(10050000));
    expect(r.finalBalance, c(11348673));
    expect(r.totalWithdrawn, c(1200000));
    expectConsistent(r);
  });

  test('retirada igual aos juros: patrimônio fica parado', () {
    final r = run(initial: 10000000, withdrawal: 100000);
    expect(r.depleted, isFalse);
    for (final row in r.rows) {
      expect(row.balance, c(10000000));
    }
    expect(r.totalInterest, c(2400000));
    expect(r.totalWithdrawn, c(2400000));
    expectConsistent(r);
  });

  test('retirada maior que os juros: patrimônio diminui', () {
    final r = run(initial: 10000000, withdrawal: 150000);
    expect(r.depleted, isFalse);
    expect(r.finalBalance, c(8651327));
    expect(r.totalWithdrawn, c(3600000));
    expectConsistent(r);
  });

  test('esgotamento: para no mês em que o dinheiro acaba, sem negativo', () {
    final r = run(initial: 1000000, withdrawal: 150000);
    expect(r.depletedAtMonth, 7);
    expect(r.rows, hasLength(8));
    expect(r.finalBalance, BigInt.zero);
    expect(r.rows.last.withdrawal < c(150000), isTrue);
    expect(r.totalWithdrawn, c(1040105));
    expect(r.totalInterest, c(40105));
    expectConsistent(r);
  });

  test('taxa zero: só retiradas; acaba exatamente no mês esperado', () {
    final r = run(
      initial: 1000000,
      withdrawal: 100000,
      rate: InterestRate.percent(0, RatePeriod.monthly),
    );
    expect(r.depletedAtMonth, 10);
    expect(r.totalInterest, BigInt.zero);
    expect(r.totalWithdrawn, c(1000000));
    expect(r.rows[5].balance, c(500000));
    expectConsistent(r);
  });

  test('taxa zero sem esgotar', () {
    final r = run(
      initial: 1000000,
      withdrawal: 10000,
      rate: InterestRate.percent(0, RatePeriod.monthly),
      months: 12,
    );
    expect(r.depleted, isFalse);
    expect(r.finalBalance, c(880000));
    expectConsistent(r);
  });

  test('retirada zero equivale à simulação sem retiradas', () {
    final rate = parseSimulationRate('0,85', RatePeriod.monthly);
    final r = run(initial: 1234567, withdrawal: 0, rate: rate, months: 120);
    final base = simulateCompoundInterest(
      CompoundInterestInput(
        initialCents: c(1234567),
        monthlyCents: BigInt.zero,
        rate: rate,
        months: 120,
      ),
    );
    expect(r.depleted, isFalse);
    expect(r.rows, hasLength(base.rows.length));
    for (var i = 0; i < base.rows.length; i++) {
      expect(r.rows[i].balance, base.rows[i].total, reason: 'mês $i');
      expect(r.rows[i].interest, base.rows[i].interest, reason: 'mês $i');
      expect(r.rows[i].withdrawal, BigInt.zero);
    }
    expectConsistent(r);
  });

  test('taxa anual usa a mensal equivalente (12% a.a. < 1% a.m.)', () {
    final a = run(
      initial: 1000000,
      withdrawal: 0,
      rate: InterestRate.percent(12, RatePeriod.annual),
    );
    final m = run(initial: 1000000, withdrawal: 0);
    expect(a.finalBalance < m.finalBalance, isTrue);
    expect(a.rows[1].interest, c(9489));
  });

  test('validação: patrimônio obrigatório e campos inválidos', () {
    final v = validateWithdrawal(
      initial: '0',
      withdrawal: '-1',
      rate: 'x',
      ratePeriod: RatePeriod.monthly,
      term: '',
      termUnit: TermUnit.months,
    );
    expect(v.input, isNull);
    expect(v.errors.keys.toSet(), WithdrawalField.values.toSet());
    final ok = validateWithdrawal(
      initial: '100.000,00',
      withdrawal: '',
      rate: '1',
      ratePeriod: RatePeriod.monthly,
      term: '2',
      termUnit: TermUnit.years,
    );
    expect(ok.errors, isEmpty);
    expect(ok.input!.withdrawalCents, BigInt.zero);
    expect(ok.input!.months, 24);
  });

  test('resultado gigante vira mensagem', () {
    expect(
      () => run(
        initial: 100000000000,
        withdrawal: 0,
        rate: InterestRate.percent(1000, RatePeriod.monthly),
        months: 600,
      ),
      throwsA(isA<SimulationException>()),
    );
  });
}
