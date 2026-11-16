import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Ponto fixo da Calculadora à vista ou parcelado (spec §12): valores em
/// [BigInt] na escala de 10^18 unidades por centavo, sem `double`. O
/// arredondamento para centavos acontece só na exibição ("meio para cima").
abstract final class Fixed {
  static final BigInt scale = BigInt.from(10).pow(18);

  static BigInt fromCents(BigInt cents) => cents * scale;

  /// Unidades → centavos, meio para cima (valores nunca negativos).
  static BigInt toCentsHalfUp(BigInt fixed) {
    if (fixed.isNegative) {
      throw ArgumentError.value(fixed, 'fixed', 'valor negativo');
    }
    return (fixed + scale ~/ BigInt.two) ~/ scale;
  }

  /// Divisão arredondada para o par mais próximo (resíduo interno, na 18ª
  /// casa do centavo; não muda a política de exibição).
  static BigInt divHalfEven(BigInt numerator, BigInt denominator) {
    assert(!denominator.isNegative && denominator != BigInt.zero);
    final q = numerator ~/ denominator;
    final r = numerator.remainder(denominator);
    final twice = r.abs() * BigInt.two;
    if (twice > denominator || (twice == denominator && q.isOdd)) {
      return numerator.isNegative ? q - BigInt.one : q + BigInt.one;
    }
    return q;
  }
}

/// Rendimento de um dia útil: fator 1 + p·r, com r = (1 + a)^(1/252) − 1
/// (taxa anual [annualRateE2] em centésimos de %, base 252) e p =
/// [percentE2] / 10000 (% do CDI; Tesouro Selic = 100%). Spec §5.
@immutable
class DailyRate {
  DailyRate({required this.annualRateE2, required this.percentE2})
    : assert(annualRateE2 >= 0 && percentE2 >= 0),
      _dailyNumerator = _dailyRateNumerator(annualRateE2);

  final int annualRateE2;
  final int percentE2;

  /// r × [rootScale] (truncado; erro < 10^-30 por dia).
  final BigInt _dailyNumerator;

  static final BigInt rootScale = BigInt.from(10).pow(30);
  static final BigInt _e4 = BigInt.from(10000);
  static final Map<int, BigInt> _cache = {};

  bool get isZero => annualRateE2 == 0 || percentE2 == 0;

  /// Rendimento de um dia útil sobre [balanceFixed].
  BigInt dayYield(BigInt balanceFixed) {
    if (isZero) return BigInt.zero;
    return Fixed.divHalfEven(
      balanceFixed * BigInt.from(percentE2) * _dailyNumerator,
      _e4 * rootScale,
    );
  }

  /// r × [rootScale] (para testes).
  BigInt get dailyRateNumerator => _dailyNumerator;

  static BigInt _dailyRateNumerator(int annualRateE2) {
    if (annualRateE2 == 0) return BigInt.zero;
    return _cache.putIfAbsent(annualRateE2, () {
      // ⌊S·(1 + a)^(1/252)⌋ − S, com S = rootScale.
      final radicand =
          rootScale.pow(252) * (_e4 + BigInt.from(annualRateE2)) ~/ _e4;
      final guess = math.pow(1 + annualRateE2 / 10000, 1 / 252).toDouble();
      return integerRoot(radicand, 252, guess: guess, scale: rootScale) -
          rootScale;
    });
  }
}

/// Raiz n-ésima inteira: maior x com x^n ≤ [value] (Newton em inteiros,
/// partindo de cima). [guess] (≈ raiz ÷ [scale]) só acelera; o resultado é
/// exato com ou sem ele.
BigInt integerRoot(BigInt value, int n, {double? guess, BigInt? scale}) {
  assert(!value.isNegative && n >= 1);
  if (value < BigInt.two) return value;
  final bn = BigInt.from(n);
  BigInt x;
  if (guess != null && scale != null && guess.isFinite && guess > 0) {
    // Estimativa com folga de 10^-9 para garantir partida acima da raiz.
    x = BigInt.from(guess * 1e15) * scale ~/ BigInt.from(10).pow(15);
    x += x ~/ BigInt.from(1000000000) + BigInt.one;
    if (x.pow(n) <= value) x = BigInt.one << ((value.bitLength + n - 1) ~/ n);
  } else {
    x = BigInt.one << ((value.bitLength + n - 1) ~/ n);
  }
  while (true) {
    final y = ((bn - BigInt.one) * x + value ~/ x.pow(n - 1)) ~/ bn;
    if (y >= x) return x;
    x = y;
  }
}
