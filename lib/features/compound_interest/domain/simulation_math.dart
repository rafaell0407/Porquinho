import 'package:flutter/foundation.dart';

import '../../../core/domain/money.dart';

/// Base comum das simulações da Calculadora de Juros Compostos.
///
/// Precisão: os saldos são acumulados em ponto fixo com [BigInt], na escala
/// de 10^18 unidades por centavo (nunca `double`). Cada mês arredonda só na
/// 18ª casa (meio para o par), o que mantém o erro acumulado muito abaixo de
/// um centavo mesmo em 600 meses. O arredondamento para centavos acontece
/// apenas na exibição, sempre "meio para cima", e os totais exibidos são
/// derivados uns dos outros para que cartões e tabela batam ao centavo.

/// Mensagem de entrada inválida ou resultado fora do limite (para a tela).
class SimulationException implements Exception {
  const SimulationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Periodicidade da taxa informada.
enum RatePeriod {
  monthly('mensal'),
  annual('anual');

  const RatePeriod(this.label);
  final String label;
}

/// Unidade do período da simulação.
enum TermUnit {
  months('meses'),
  years('anos');

  const TermUnit(this.label);
  final String label;
}

/// Limites das entradas e do resultado.
abstract final class SimulationLimits {
  /// Maior valor em cada campo de dinheiro: R$ 1.000.000.000,00.
  static final BigInt maxInputCents = BigInt.from(100000000000);

  /// Maior taxa aceita, em % (vale para mensal e anual).
  static const int maxRatePercent = 1000;

  /// Casas decimais aceitas na taxa.
  static const int rateDecimals = 4;

  /// Maior período: 50 anos.
  static const int maxMonths = 600;

  /// Maior patrimônio simulado: R$ 1 quatrilhão.
  static final BigInt maxResultCents = BigInt.from(10).pow(17);
}

/// Unidades internas por centavo.
final BigInt fixedScale = BigInt.from(10).pow(18);
final BigInt _two = BigInt.two;

/// Centavos → unidades internas.
BigInt toFixed(BigInt cents) => cents * fixedScale;

/// Unidades internas → centavos, arredondando "meio para cima" (valores da
/// simulação nunca são negativos).
BigInt roundFixedToCents(BigInt fixed) {
  assert(!fixed.isNegative);
  return (fixed + fixedScale ~/ _two) ~/ fixedScale;
}

/// Divisão inteira arredondada para o par mais próximo (só para o resíduo
/// interno de cada mês; não afeta a política de exibição).
BigInt _divHalfEven(BigInt numerator, BigInt denominator) {
  final q = numerator ~/ denominator;
  final r = numerator.remainder(denominator);
  final twice = r * _two;
  if (twice > denominator || (twice == denominator && q.isOdd)) {
    return q + BigInt.one;
  }
  return q;
}

/// Taxa informada pelo usuário: percentual exato com até 4 casas, guardado
/// em décimos de milésimo de ponto percentual (12,5% → 125000).
@immutable
class InterestRate {
  const InterestRate({required this.percentE4, required this.period});

  /// Atalho para testes e exemplos: `InterestRate.percent(12, annual)`.
  InterestRate.percent(int percent, RatePeriod period)
    : this(percentE4: BigInt.from(percent) * _e4, period: period);

  static final BigInt _e4 = BigInt.from(10000);

  final BigInt percentE4;
  final RatePeriod period;

  /// Escala da taxa mensal equivalente (10^42): o erro da raiz fica abaixo
  /// de 10^-42 por mês, irrelevante mesmo em 600 meses.
  static final BigInt _rootScale = BigInt.from(10).pow(42);
  static final BigInt _million = BigInt.from(1000000);

  /// Taxa mensal como fração `numerador / denominador`. Mensal é exata; anual
  /// é efetiva e convertida para a taxa mensal equivalente
  /// `(1 + anual)^(1/12) − 1` (12% a.a. ≈ 0,9489% a.m.), de modo que 12 meses
  /// a 12% a.a. rendem exatamente 12%.
  BigInt get monthlyNumerator =>
      period == RatePeriod.monthly ? percentE4 : _annualMonthlyNumerator();
  BigInt get monthlyDenominator =>
      period == RatePeriod.monthly ? _million : _rootScale;

  /// `⌊R·(1 + p)^(1/12)⌋ − R`, com p = percentE4 / 10^6 e R = [_rootScale].
  BigInt _annualMonthlyNumerator() {
    if (isZero) return BigInt.zero;
    return _annualRootCache.putIfAbsent(percentE4, () {
      final radicand = _rootScale.pow(12) * (_million + percentE4) ~/ _million;
      return integerRoot(radicand, 12) - _rootScale;
    });
  }

  static final Map<BigInt, BigInt> _annualRootCache = {};

  /// Taxa mensal em décimos de milésimo de ponto percentual, arredondada
  /// (para exibição). `exact` indica se não houve arredondamento.
  ({BigInt percentE4, bool exact}) get monthlyPercentE4 {
    final scaled = monthlyNumerator * _million;
    final q = scaled ~/ monthlyDenominator;
    final r = scaled.remainder(monthlyDenominator);
    final rounded = r * _two >= monthlyDenominator ? q + BigInt.one : q;
    return (percentE4: rounded, exact: r == BigInt.zero);
  }

  bool get isZero => percentE4 == BigInt.zero;

  /// Juros de um mês sobre [balanceFixed] (unidades internas).
  BigInt monthlyInterest(BigInt balanceFixed) =>
      _divHalfEven(balanceFixed * monthlyNumerator, monthlyDenominator);

  @override
  bool operator ==(Object other) =>
      other is InterestRate &&
      other.percentE4 == percentE4 &&
      other.period == period;

  @override
  int get hashCode => Object.hash(percentE4, period);
}

/// Raiz n-ésima inteira: maior x com x^n ≤ [value] (Newton em inteiros).
BigInt integerRoot(BigInt value, int n) {
  assert(!value.isNegative && n >= 1);
  if (value < _two) return value;
  final bn = BigInt.from(n);
  var x = BigInt.one << ((value.bitLength + n - 1) ~/ n);
  while (true) {
    final y = ((bn - BigInt.one) * x + value ~/ x.pow(n - 1)) ~/ bn;
    if (y >= x) return x;
    x = y;
  }
}

/// Campo de dinheiro opcional: vazio vale zero. Aceita o padrão brasileiro
/// ("8.000,00", "8000", "R$ 8.000"). Recusa negativo e acima do limite.
BigInt parseSimulationMoney(String text, {bool required = false}) {
  if (text.trim().isEmpty) {
    if (required) throw const SimulationException('Informe um valor.');
    return BigInt.zero;
  }
  final BigInt cents;
  try {
    cents = parseBrlToCentavos(text);
  } on MoneyFormatException catch (e) {
    throw SimulationException(e.message);
  }
  if (cents > SimulationLimits.maxInputCents) {
    throw const SimulationException(
      'Use um valor de até R\$ 1.000.000.000,00.',
    );
  }
  return cents;
}

final _ratePattern = RegExp(r'^(\d{1,4})(?:[.,](\d{1,4}))?$');

/// Taxa em % com vírgula (ou ponto) decimal e até 4 casas: "12", "0,85".
InterestRate parseSimulationRate(String text, RatePeriod period) {
  var t = text.trim();
  if (t.endsWith('%')) t = t.substring(0, t.length - 1).trim();
  if (t.isEmpty) throw const SimulationException('Informe a taxa de juros.');
  if (t.startsWith('-')) {
    throw const SimulationException('A taxa não pode ser negativa.');
  }
  final m = _ratePattern.firstMatch(t);
  if (m == null) {
    final decimals = RegExp(r'^\d+[.,](\d+)$').firstMatch(t);
    if (decimals != null &&
        decimals.group(1)!.length > SimulationLimits.rateDecimals) {
      throw const SimulationException('Use no máximo 4 casas decimais.');
    }
    throw const SimulationException('Taxa inválida. Exemplo: 0,85');
  }
  final whole = BigInt.parse(m.group(1)!);
  final frac = BigInt.parse((m.group(2) ?? '').padRight(4, '0'));
  final e4 = whole * BigInt.from(10000) + frac;
  if (e4 > BigInt.from(SimulationLimits.maxRatePercent * 10000)) {
    throw const SimulationException('Use uma taxa de até 1.000%.');
  }
  return InterestRate(percentE4: e4, period: period);
}

/// Período em número inteiro de meses ou anos → meses (1 a 600).
int parseSimulationTerm(String text, TermUnit unit) {
  final t = text.trim();
  if (t.isEmpty) throw const SimulationException('Informe o período.');
  if (t.startsWith('-')) {
    throw const SimulationException('O período não pode ser negativo.');
  }
  if (!RegExp(r'^\d{1,4}$').hasMatch(t)) {
    throw SimulationException(
      'Use um número inteiro de ${unit == TermUnit.years ? 'anos' : 'meses'}.',
    );
  }
  final months = int.parse(t) * (unit == TermUnit.years ? 12 : 1);
  if (months == 0) {
    throw const SimulationException(
      'O período precisa ser de pelo menos 1 mês.',
    );
  }
  if (months > SimulationLimits.maxMonths) {
    throw const SimulationException(
      'O período máximo é de 50 anos (600 meses).',
    );
  }
  return months;
}

/// Erro de patrimônio grande demais (evita números sem sentido na tela).
const resultTooLarge = SimulationException(
  'O resultado passa de R\$ 1 quatrilhão. Reduza a taxa, os valores ou o '
  'período.',
);

/// Formata a taxa para exibição: "1%", "0,85%".
String formatRatePercent(InterestRate rate) {
  final whole = rate.percentE4 ~/ BigInt.from(10000);
  var frac = (rate.percentE4 % BigInt.from(10000)).toString().padLeft(4, '0');
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? '$whole%' : '$whole,$frac%';
}
