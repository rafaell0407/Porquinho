/// Valores da importação (RN045, RN048): centavos inteiros em [BigInt], nunca
/// `double`. O formato é declarado por coluna; nada ambíguo é interpretado
/// sem escolha do usuário.
enum ValueFormat {
  centavos('Centavos inteiros', '12345 = R\$ 123,45'),
  reaisComma('Reais com vírgula', '1.234,56'),
  reaisDot('Reais com ponto', '1,234.56');

  const ValueFormat(this.label, this.example);
  final String label;
  final String example;
}

/// Teto por lançamento (D34): R$ 10.000.000,00.
final BigInt maxImportCentavos = BigInt.from(1000000000);

/// Resultado da leitura de um valor: centavos com sinal ou o motivo da recusa.
class ValueParse {
  const ValueParse.ok(BigInt this.centavos) : error = null;
  const ValueParse.error(String this.error) : centavos = null;

  final BigInt? centavos;
  final String? error;

  bool get ok => centavos != null;
}

final _spaces = RegExp(r'[\s  ]+');

/// Remove "R$", espaços (inclusive não separáveis) e o sinal "-". Devolve o
/// corpo numérico e se havia sinal negativo.
(String, bool, bool) _strip(String raw) {
  var text = raw.replaceAll(_spaces, ' ').trim();
  var negative = false;
  var currency = false;
  if (text.startsWith('-')) {
    negative = true;
    text = text.substring(1).trim();
  }
  if (text.startsWith('R\$')) {
    currency = true;
    text = text.substring(2).trim();
  }
  if (text.startsWith('-')) {
    if (negative) return ('', false, currency);
    negative = true;
    text = text.substring(1).trim();
  }
  return (text, negative, currency);
}

/// Lê [raw] no [format] declarado. Aceita sinal "-" e prefixo "R$" (com
/// espaço comum ou não separável), salvo em centavos inteiros. Até duas casas
/// decimais; teto de R$ 10 milhões. O sinal é devolvido: quem chama decide se
/// negativo é aceito (regra "pelo sinal", RN047).
ValueParse parseImportValue(String raw, ValueFormat format) {
  final (body, negative, currency) = _strip(raw);
  if (body.isEmpty) return const ValueParse.error('Valor vazio ou inválido.');
  String integer;
  String decimals;
  switch (format) {
    case ValueFormat.centavos:
      if (currency || !RegExp(r'^[0-9]+$').hasMatch(body)) {
        return ValueParse.error(
          'Valor "$raw" não é um número inteiro de centavos.',
        );
      }
      integer = body;
      decimals = '';
    case ValueFormat.reaisComma:
    case ValueFormat.reaisDot:
      final thousands = format == ValueFormat.reaisComma ? r'\.' : ',';
      final decimal = format == ValueFormat.reaisComma ? ',' : r'\.';
      final match = RegExp(
        '^([0-9]+|[0-9]{1,3}(?:$thousands[0-9]{3})+)(?:$decimal([0-9]+))?\$',
      ).firstMatch(body);
      if (match == null) {
        return ValueParse.error(
          'Valor "$raw" não está no formato ${format.label.toLowerCase()} '
          '(${format.example}).',
        );
      }
      decimals = match.group(2) ?? '';
      if (decimals.length > 2) {
        return ValueParse.error(
          'Valor "$raw" tem mais de duas casas decimais.',
        );
      }
      integer = match.group(1)!.replaceAll(RegExp('[.,]'), '');
  }
  final digits = format == ValueFormat.centavos
      ? integer
      : integer + decimals.padRight(2, '0');
  final value = BigInt.parse(digits);
  if (value > maxImportCentavos) {
    return ValueParse.error('Valor "$raw" acima de R\$ 10.000.000,00.');
  }
  return ValueParse.ok(negative ? -value : value);
}

/// Formato sugerido para a coluna, só quando os valores não deixam dúvida
/// (RN048). `null` = ambíguo ou conflitante: o usuário precisa escolher.
/// Inteiros simples ("1234") valem o mesmo nos dois formatos de reais e levam
/// à sugestão "reais com vírgula"; "1.234" ou "1,234" sem outra pista são
/// ambíguos.
ValueFormat? suggestValueFormat(Iterable<String> values) {
  var comma = false;
  var dot = false;
  var groupedByDot = false;
  var groupedByComma = false;
  final commaDecimal = RegExp(r'^[0-9.]*[0-9],[0-9]{1,2}$');
  final dotDecimal = RegExp(r'^[0-9,]*[0-9]\.[0-9]{1,2}$');
  final groupedDot = RegExp(r'^[0-9]{1,3}(\.[0-9]{3})+$');
  final groupedComma = RegExp(r'^[0-9]{1,3}(,[0-9]{3})+$');
  for (final raw in values) {
    final (body, _, _) = _strip(raw);
    if (body.isEmpty) continue;
    if (commaDecimal.hasMatch(body)) {
      comma = true;
    } else if (dotDecimal.hasMatch(body)) {
      dot = true;
    } else if (groupedDot.hasMatch(body)) {
      groupedByDot = true;
    } else if (groupedComma.hasMatch(body)) {
      groupedByComma = true;
    }
  }
  if (comma && dot) return null;
  // "1,234" contradiz reais com vírgula; "1.234" contradiz reais com ponto.
  if (comma) return groupedByComma ? null : ValueFormat.reaisComma;
  if (dot) return groupedByDot ? null : ValueFormat.reaisDot;
  if (groupedByDot || groupedByComma) return null;
  return ValueFormat.reaisComma;
}
