import '../../../core/domain/money.dart';
import 'card_bill_models.dart';

/// Calculadora do campo "Dinheiro reservado" (spec §9).
///
/// - Teclas: números, vírgula, `+ − × ÷`, apagar, limpar e `=`.
/// - Conta exata em frações ([BigInt]), sem ponto flutuante; × e ÷ antes de
///   + e − (`100 + 50 × 2 = 200`).
/// - Resultado final arredondado para o centavo mais próximo, meio para cima
///   (1.000 ÷ 3 = 333,33; 2 ÷ 3 = 0,67).
/// - Resultado negativo não é aceito; divisão por zero é erro; teto da
///   reserva R$ 10.000.000,00.

enum CalcOp {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const CalcOp(this.symbol);
  final String symbol;

  bool get isHigh => this == multiply || this == divide;
}

/// Fração exata.
class _Fraction {
  _Fraction(BigInt num, BigInt den)
    : num = den.isNegative ? -num : num,
      den = den.abs();

  final BigInt num;
  final BigInt den;

  _Fraction operator +(_Fraction o) =>
      _Fraction(num * o.den + o.num * den, den * o.den);
  _Fraction operator -(_Fraction o) =>
      _Fraction(num * o.den - o.num * den, den * o.den);
  _Fraction operator *(_Fraction o) => _Fraction(num * o.num, den * o.den);
  _Fraction operator /(_Fraction o) => _Fraction(num * o.den, den * o.num);

  bool get isZero => num == BigInt.zero;
  bool get isNegative => num.isNegative;

  /// Centavos, meio para cima (para valores não negativos).
  BigInt toCentavosHalfUp() {
    final scaled = num * BigInt.from(100);
    return (scaled * BigInt.two + den) ~/ (den * BigInt.two);
  }
}

class CalculatorError implements Exception {
  const CalculatorError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Limites do que se digita em cada número.
const _maxIntegerDigits = 10;
const _maxDecimalDigits = 6;

/// Estado da calculadora: números digitados (texto, com vírgula) e
/// operadores intercalados.
class ReserveCalculator {
  ReserveCalculator._(this._numbers, this._ops, this._result, this._error);

  /// Começa com o valor atual da reserva no visor.
  factory ReserveCalculator.start(BigInt current) =>
      ReserveCalculator._([_centavosToInput(current)], const [], null, null);

  final List<String> _numbers;
  final List<CalcOp> _ops;

  /// Resultado depois de `=` (centavos), ou `null`.
  final BigInt? _result;
  final String? _error;

  BigInt? get result => _result;
  String? get error => _error;
  bool get isEmpty =>
      _numbers.isEmpty || (_numbers.length == 1 && _numbers.first.isEmpty);

  /// Conta visível: "28.207,43 + 1.500 − 320".
  String get expression {
    final b = StringBuffer();
    for (var i = 0; i < _numbers.length; i++) {
      if (i > 0) b.write(' ${_ops[i - 1].symbol} ');
      b.write(_formatInput(_numbers[i]));
    }
    if (_ops.isNotEmpty && _ops.length == _numbers.length) {
      b.write(' ${_ops.last.symbol}');
    }
    return b.toString();
  }

  /// Conta completa com o resultado: "… = 29.387,43".
  String get display {
    final r = _result;
    return r == null ? expression : '$expression = ${_formatCentavos(r)}';
  }

  ReserveCalculator _with({
    List<String>? numbers,
    List<CalcOp>? ops,
    BigInt? result,
    String? error,
  }) => ReserveCalculator._(numbers ?? _numbers, ops ?? _ops, result, error);

  /// Depois de `=`, um número novo recomeça a conta; um operador continua a
  /// partir do resultado.
  ReserveCalculator _afterResult({required bool continueWithResult}) {
    if (_result == null) return this;
    return continueWithResult
        ? ReserveCalculator._([_centavosToInput(_result)], const [], null, null)
        : ReserveCalculator._(const [], const [], null, null);
  }

  bool get _expectingNumber => _numbers.length == _ops.length;

  ReserveCalculator digit(int d) {
    if (d < 0 || d > 9) throw ArgumentError('Dígito inválido');
    final base = _afterResult(continueWithResult: false);
    final numbers = [...base._numbers];
    if (base._expectingNumber) numbers.add('');
    final current = numbers.last;
    final parts = current.split(',');
    if (parts.length == 2) {
      if (parts[1].length >= _maxDecimalDigits) return base;
    } else {
      final integer = parts[0] == '0' ? '' : parts[0];
      if (integer.length >= _maxIntegerDigits) return base;
      numbers[numbers.length - 1] = '$integer$d';
      return base._with(numbers: numbers);
    }
    numbers[numbers.length - 1] = '$current$d';
    return base._with(numbers: numbers);
  }

  ReserveCalculator comma() {
    final base = _afterResult(continueWithResult: false);
    final numbers = [...base._numbers];
    if (base._expectingNumber) numbers.add('');
    final current = numbers.last;
    if (current.contains(',')) return base;
    numbers[numbers.length - 1] = current.isEmpty ? '0,' : '$current,';
    return base._with(numbers: numbers);
  }

  ReserveCalculator operation(CalcOp op) {
    final base = _afterResult(continueWithResult: true);
    if (base._numbers.isEmpty) return base;
    if (base._expectingNumber) {
      return base._with(
        ops: [...base._ops.sublist(0, base._ops.length - 1), op],
      );
    }
    return base._with(ops: [...base._ops, op]);
  }

  ReserveCalculator backspace() {
    if (_result != null) return _with();
    if (_numbers.isEmpty) return this;
    if (_expectingNumber) {
      return _with(ops: _ops.sublist(0, _ops.length - 1));
    }
    final last = _numbers.last;
    final numbers = [..._numbers];
    if (last.length <= 1) {
      numbers.removeLast();
    } else {
      numbers[numbers.length - 1] = last.substring(0, last.length - 1);
    }
    return _with(numbers: numbers);
  }

  ReserveCalculator clear() =>
      ReserveCalculator._(const [], const [], null, null);

  /// `=`: calcula; erros ficam em [error] e o resultado fica vazio.
  ReserveCalculator equals() {
    try {
      return _with(result: evaluate());
    } on CalculatorError catch (e) {
      return _with(error: e.message);
    }
  }

  /// Valor final em centavos, validado para a reserva.
  BigInt evaluate() {
    if (_numbers.isEmpty || (_numbers.length == 1 && _numbers.first.isEmpty)) {
      throw const CalculatorError('Digite um valor.');
    }
    final numbers = [for (final n in _numbers) _parse(n)];
    final ops = [..._ops];
    if (ops.length == numbers.length) ops.removeLast(); // operador pendurado
    // 1ª passada: × e ÷.
    final terms = <_Fraction>[numbers.first];
    final lowOps = <CalcOp>[];
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final value = numbers[i + 1];
      if (op.isHigh) {
        if (op == CalcOp.divide && value.isZero) {
          throw const CalculatorError('Não é possível dividir por zero.');
        }
        terms[terms.length - 1] = op == CalcOp.multiply
            ? terms.last * value
            : terms.last / value;
      } else {
        lowOps.add(op);
        terms.add(value);
      }
    }
    // 2ª passada: + e −.
    var total = terms.first;
    for (var i = 0; i < lowOps.length; i++) {
      total = lowOps[i] == CalcOp.add
          ? total + terms[i + 1]
          : total - terms[i + 1];
    }
    if (total.isNegative) {
      throw const CalculatorError('O resultado não pode ser negativo.');
    }
    final cents = total.toCentavosHalfUp();
    if (cents > maxReserve) {
      throw CalculatorError('A reserva vai até ${formatBrl(maxReserve)}.');
    }
    return cents;
  }

  static _Fraction _parse(String input) {
    if (input.isEmpty) return _Fraction(BigInt.zero, BigInt.one);
    final parts = input.split(',');
    final integer = parts[0].isEmpty ? '0' : parts[0];
    final decimals = parts.length > 1 ? parts[1] : '';
    final den = BigInt.from(10).pow(decimals.length);
    return _Fraction(BigInt.parse('$integer$decimals'), den);
  }

  static String _centavosToInput(BigInt cents) {
    final reais = cents ~/ BigInt.from(100);
    final c = (cents % BigInt.from(100)).toInt();
    if (c == 0) return reais == BigInt.zero ? '0' : '$reais';
    return '$reais,${c.toString().padLeft(2, '0')}';
  }

  /// "28207,43" → "28.207,43".
  static String _formatInput(String input) {
    final parts = input.split(',');
    final integer = parts[0];
    final grouped = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      if (i > 0 && (integer.length - i) % 3 == 0) grouped.write('.');
      grouped.write(integer[i]);
    }
    return parts.length > 1 ? '$grouped,${parts[1]}' : grouped.toString();
  }

  static String _formatCentavos(BigInt cents) =>
      formatBrl(cents).replaceFirst('R\$ ', '');
}

/// Resumo "Atual R$ X → Novo R$ Y (+R$ Z)".
String calculatorSummary(BigInt current, BigInt next) {
  final diff = next - current;
  final sign = diff.isNegative ? '−' : '+';
  return 'Atual ${formatBrl(current)} → Novo ${formatBrl(next)} '
      '($sign${formatBrl(diff.abs())})';
}
