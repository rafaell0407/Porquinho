/// Valores em BRL representados em centavos (RN045), sempre como [BigInt].
class MoneyFormatException implements Exception {
  const MoneyFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Maior valor de um lançamento: `BIGINT` assinado de 64 bits no servidor.
final BigInt maxCentavos = (BigInt.one << 63) - BigInt.one;

/// Converte texto digitado em reais ("1.234,56") para centavos.
///
/// Aceita prefixo "R$", ponto como separador de milhar (grupos de três) e
/// vírgula com até duas casas. Recusa negativos, mais de duas casas,
/// formatos ambíguos e valores acima de 64 bits. Zero é aceito.
BigInt parseBrlToCentavos(String input) {
  var text = input.trim();
  if (text.startsWith('R\$')) {
    text = text.substring(2).trim();
  }
  if (text.isEmpty) {
    throw const MoneyFormatException('Informe um valor.');
  }
  if (text.startsWith('-')) {
    throw const MoneyFormatException('O valor não pode ser negativo.');
  }
  final match = RegExp(r'^([0-9.]+)(?:,([0-9]*))?$').firstMatch(text);
  if (match == null) {
    throw const MoneyFormatException('Valor inválido.');
  }
  final integerPart = match.group(1)!;
  final decimalPart = match.group(2) ?? '';
  final validInteger =
      RegExp(r'^[0-9]+$').hasMatch(integerPart) ||
      RegExp(r'^[0-9]{1,3}(\.[0-9]{3})+$').hasMatch(integerPart);
  if (!validInteger) {
    throw const MoneyFormatException('Valor inválido.');
  }
  if (match.group(2) != null && decimalPart.isEmpty) {
    throw const MoneyFormatException('Valor inválido.');
  }
  if (decimalPart.length > 2) {
    throw const MoneyFormatException('Use no máximo duas casas decimais.');
  }
  final digits = integerPart.replaceAll('.', '');
  final centavos = BigInt.parse(digits + decimalPart.padRight(2, '0'));
  if (centavos > maxCentavos) {
    throw const MoneyFormatException('Valor acima do limite permitido.');
  }
  return centavos;
}

/// Formata centavos como "R$ 1.234,56"; negativos como "-R$ 1,00".
String formatBrl(BigInt centavos) {
  final negative = centavos.isNegative;
  final absolute = centavos.abs();
  final reais = (absolute ~/ BigInt.from(100)).toString();
  final cents = (absolute % BigInt.from(100)).toString().padLeft(2, '0');
  final grouped = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) {
      grouped.write('.');
    }
    grouped.write(reais[i]);
  }
  return '${negative ? '-' : ''}R\$ $grouped,$cents';
}
