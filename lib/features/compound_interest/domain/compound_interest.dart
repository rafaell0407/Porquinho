import 'package:flutter/foundation.dart';

import 'simulation_math.dart';

/// Parâmetros validados da simulação de juros compostos.
@immutable
class CompoundInterestInput {
  const CompoundInterestInput({
    required this.initialCents,
    required this.monthlyCents,
    required this.rate,
    required this.months,
  });

  final BigInt initialCents;

  /// Aporte feito ao final de cada mês.
  final BigInt monthlyCents;
  final InterestRate rate;
  final int months;
}

/// Campos do formulário principal.
enum CompoundField { initial, monthly, rate, term }

/// Resultado da validação do formulário: [input] quando tudo está certo;
/// senão, a mensagem de cada campo com problema em [errors].
typedef CompoundValidation = ({
  CompoundInterestInput? input,
  Map<CompoundField, String> errors,
});

/// Valida os textos digitados. Valor inicial e aporte vazios valem zero,
/// mas ao menos um deles precisa ser maior que zero.
CompoundValidation validateCompoundInterest({
  required String initial,
  required String monthly,
  required String rate,
  required RatePeriod ratePeriod,
  required String term,
  required TermUnit termUnit,
}) {
  final errors = <CompoundField, String>{};
  T? read<T>(CompoundField field, T Function() parse) {
    try {
      return parse();
    } on SimulationException catch (e) {
      errors[field] = e.message;
      return null;
    }
  }

  final i = read(CompoundField.initial, () => parseSimulationMoney(initial));
  final m = read(CompoundField.monthly, () => parseSimulationMoney(monthly));
  final r = read(
    CompoundField.rate,
    () => parseSimulationRate(rate, ratePeriod),
  );
  final t = read(CompoundField.term, () => parseSimulationTerm(term, termUnit));
  if (i != null && m != null && i == BigInt.zero && m == BigInt.zero) {
    errors[CompoundField.initial] =
        'Informe o valor inicial ou o valor mensal.';
  }
  if (errors.isNotEmpty) return (input: null, errors: errors);
  return (
    input: CompoundInterestInput(
      initialCents: i!,
      monthlyCents: m!,
      rate: r!,
      months: t!,
    ),
    errors: const {},
  );
}

/// Uma linha da evolução (mês 0 = só o valor inicial). Valores em centavos.
@immutable
class CompoundInterestRow {
  const CompoundInterestRow({
    required this.month,
    required this.interest,
    required this.invested,
    required this.totalInterest,
    required this.total,
  });

  final int month;

  /// Juros do mês (a soma da coluna dá exatamente [totalInterest]).
  final BigInt interest;

  /// Capital próprio acumulado: valor inicial + aportes até aqui.
  final BigInt invested;

  /// Juros acumulados.
  final BigInt totalInterest;

  /// Patrimônio: [invested] + [totalInterest].
  final BigInt total;
}

@immutable
class CompoundInterestResult {
  CompoundInterestResult({required this.input, required this.rows})
    : assert(rows.length == input.months + 1);

  final CompoundInterestInput input;

  /// Meses 0 a [CompoundInterestInput.months].
  final List<CompoundInterestRow> rows;

  CompoundInterestRow get last => rows.last;
  BigInt get finalTotal => last.total;
  BigInt get totalInvested => last.invested;
  BigInt get totalInterest => last.totalInterest;
}

/// Simula mês a mês: saldo final = saldo do início × (1 + taxa mensal) +
/// aporte (aporte no final do mês). Lança [SimulationException] se o
/// patrimônio passar do limite.
CompoundInterestResult simulateCompoundInterest(CompoundInterestInput input) {
  if (input.months < 1 || input.months > SimulationLimits.maxMonths) {
    throw const SimulationException('Período fora do limite.');
  }
  if (input.initialCents.isNegative || input.monthlyCents.isNegative) {
    throw const SimulationException('Os valores não podem ser negativos.');
  }
  final maxFixed = toFixed(SimulationLimits.maxResultCents);
  final monthlyFixed = toFixed(input.monthlyCents);
  var balance = toFixed(input.initialCents);
  var interestFixed = BigInt.zero;
  var invested = input.initialCents;
  var shownInterest = BigInt.zero;
  final rows = <CompoundInterestRow>[
    CompoundInterestRow(
      month: 0,
      interest: BigInt.zero,
      invested: invested,
      totalInterest: BigInt.zero,
      total: invested,
    ),
  ];
  for (var month = 1; month <= input.months; month++) {
    final interest = input.rate.monthlyInterest(balance);
    interestFixed += interest;
    balance += interest + monthlyFixed;
    invested += input.monthlyCents;
    if (balance > maxFixed) throw resultTooLarge;
    final totalInterest = roundFixedToCents(interestFixed);
    rows.add(
      CompoundInterestRow(
        month: month,
        interest: totalInterest - shownInterest,
        invested: invested,
        totalInterest: totalInterest,
        total: invested + totalInterest,
      ),
    );
    shownInterest = totalInterest;
  }
  return CompoundInterestResult(input: input, rows: List.unmodifiable(rows));
}
