import 'package:flutter/foundation.dart';

import 'simulation_math.dart';

/// Parâmetros validados da simulação de retiradas mensais.
@immutable
class WithdrawalInput {
  const WithdrawalInput({
    required this.initialCents,
    required this.withdrawalCents,
    required this.rate,
    required this.months,
  });

  /// Patrimônio no início da simulação.
  final BigInt initialCents;

  /// Retirada desejada ao final de cada mês (zero = sem retiradas).
  final BigInt withdrawalCents;
  final InterestRate rate;
  final int months;
}

enum WithdrawalField { initial, withdrawal, rate, term }

typedef WithdrawalValidation = ({
  WithdrawalInput? input,
  Map<WithdrawalField, String> errors,
});

/// Valida os textos digitados. O patrimônio inicial é obrigatório e maior que
/// zero; a retirada vazia vale zero.
WithdrawalValidation validateWithdrawal({
  required String initial,
  required String withdrawal,
  required String rate,
  required RatePeriod ratePeriod,
  required String term,
  required TermUnit termUnit,
}) {
  final errors = <WithdrawalField, String>{};
  T? read<T>(WithdrawalField field, T Function() parse) {
    try {
      return parse();
    } on SimulationException catch (e) {
      errors[field] = e.message;
      return null;
    }
  }

  final i = read(
    WithdrawalField.initial,
    () => parseSimulationMoney(initial, required: true),
  );
  final w = read(
    WithdrawalField.withdrawal,
    () => parseSimulationMoney(withdrawal),
  );
  final r = read(
    WithdrawalField.rate,
    () => parseSimulationRate(rate, ratePeriod),
  );
  final t = read(
    WithdrawalField.term,
    () => parseSimulationTerm(term, termUnit),
  );
  if (i != null && i == BigInt.zero) {
    errors[WithdrawalField.initial] = 'Informe um patrimônio maior que zero.';
  }
  if (errors.isNotEmpty) return (input: null, errors: errors);
  return (
    input: WithdrawalInput(
      initialCents: i!,
      withdrawalCents: w!,
      rate: r!,
      months: t!,
    ),
    errors: const {},
  );
}

/// Uma linha da evolução com retiradas (mês 0 = patrimônio inicial).
@immutable
class WithdrawalRow {
  const WithdrawalRow({
    required this.month,
    required this.interest,
    required this.withdrawal,
    required this.totalWithdrawn,
    required this.totalInterest,
    required this.balance,
  });

  final int month;

  /// Juros do mês (a coluna soma [totalInterest]).
  final BigInt interest;

  /// Retirada do mês (a coluna soma [totalWithdrawn]); no mês em que o
  /// dinheiro acaba, é o que restava.
  final BigInt withdrawal;
  final BigInt totalWithdrawn;
  final BigInt totalInterest;

  /// Patrimônio inicial + juros acumulados − total retirado (nunca negativo).
  final BigInt balance;
}

@immutable
class WithdrawalResult {
  const WithdrawalResult({
    required this.input,
    required this.rows,
    required this.depletedAtMonth,
  });

  final WithdrawalInput input;

  /// Do mês 0 até o último mês simulado (o do esgotamento, se houver).
  final List<WithdrawalRow> rows;

  /// Mês em que o patrimônio chegou a zero; `null` se durou o período todo.
  final int? depletedAtMonth;

  bool get depleted => depletedAtMonth != null;
  BigInt get finalBalance => rows.last.balance;
  BigInt get totalWithdrawn => rows.last.totalWithdrawn;
  BigInt get totalInterest => rows.last.totalInterest;
}

/// Simula mês a mês: juros sobre o saldo do início do mês; retirada no final
/// do mês, depois dos juros. Se o saldo não cobre a retirada, retira o que
/// resta e a simulação para nesse mês (sem saldo negativo).
WithdrawalResult simulateWithdrawals(WithdrawalInput input) {
  if (input.months < 1 || input.months > SimulationLimits.maxMonths) {
    throw const SimulationException('Período fora do limite.');
  }
  if (input.initialCents.isNegative || input.withdrawalCents.isNegative) {
    throw const SimulationException('Os valores não podem ser negativos.');
  }
  final maxFixed = toFixed(SimulationLimits.maxResultCents);
  final wantedFixed = toFixed(input.withdrawalCents);
  var balance = toFixed(input.initialCents);
  var interestFixed = BigInt.zero;
  var withdrawnFixed = BigInt.zero;
  var shownInterest = BigInt.zero;
  var shownWithdrawn = BigInt.zero;
  int? depletedAt;
  final rows = <WithdrawalRow>[
    WithdrawalRow(
      month: 0,
      interest: BigInt.zero,
      withdrawal: BigInt.zero,
      totalWithdrawn: BigInt.zero,
      totalInterest: BigInt.zero,
      balance: input.initialCents,
    ),
  ];
  for (var month = 1; month <= input.months; month++) {
    final interest = input.rate.monthlyInterest(balance);
    interestFixed += interest;
    balance += interest;
    if (balance > maxFixed) throw resultTooLarge;
    final taken = wantedFixed < balance ? wantedFixed : balance;
    balance -= taken;
    withdrawnFixed += taken;
    final totalInterest = roundFixedToCents(interestFixed);
    final totalWithdrawn = roundFixedToCents(withdrawnFixed);
    rows.add(
      WithdrawalRow(
        month: month,
        interest: totalInterest - shownInterest,
        withdrawal: totalWithdrawn - shownWithdrawn,
        totalWithdrawn: totalWithdrawn,
        totalInterest: totalInterest,
        balance: input.initialCents + totalInterest - totalWithdrawn,
      ),
    );
    shownInterest = totalInterest;
    shownWithdrawn = totalWithdrawn;
    if (input.withdrawalCents > BigInt.zero && balance == BigInt.zero) {
      depletedAt = month;
      break;
    }
  }
  return WithdrawalResult(
    input: input,
    rows: List.unmodifiable(rows),
    depletedAtMonth: depletedAt,
  );
}
