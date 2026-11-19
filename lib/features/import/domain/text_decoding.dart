import 'dart:convert';
import 'dart:typed_data';

/// Codificação do arquivo (RN047, D23): UTF-8 (com ou sem BOM) por padrão;
/// Windows-1252 só por escolha explícita do usuário quando o UTF-8 falhar.
enum ImportEncoding {
  utf8('UTF-8'),
  windows1252('Windows-1252');

  const ImportEncoding(this.label);
  final String label;
}

/// Resultado da decodificação: o texto ou o motivo da falha.
class DecodedText {
  const DecodedText._(this.text, this.hadBom, this.failure);

  const DecodedText.ok(String text, {bool hadBom = false})
    : this._(text, hadBom, null);

  const DecodedText.failed(String reason) : this._(null, false, reason);

  final String? text;
  final bool hadBom;
  final String? failure;

  bool get ok => text != null;
}

/// Bytes 0x80–0x9F do Windows-1252 (o `latin1` do Dart erra nessa faixa:
/// €, aspas curvas, travessão…). `null` = byte sem caractere definido.
const List<int?> _cp1252High = [
  0x20AC, null, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, null, 0x017D, null, //
  null, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, null, 0x017E, 0x0178, //
];

/// Decodifica [bytes] na [encoding] escolhida. UTF-8 é estrito: qualquer
/// sequência inválida falha (sem trocar caracteres em silêncio). O BOM
/// inicial é removido.
DecodedText decodeImportBytes(Uint8List bytes, ImportEncoding encoding) {
  switch (encoding) {
    case ImportEncoding.utf8:
      var start = 0;
      var bom = false;
      if (bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        start = 3;
        bom = true;
      }
      try {
        final text = const Utf8Decoder(
          allowMalformed: false,
        ).convert(bytes, start);
        return DecodedText.ok(text, hadBom: bom);
      } on FormatException {
        return const DecodedText.failed(
          'O arquivo não está em UTF-8. Se ele veio de um banco ou de uma '
          'planilha antiga, tente ler como Windows-1252.',
        );
      }
    case ImportEncoding.windows1252:
      final out = StringBuffer();
      for (final b in bytes) {
        if (b >= 0x80 && b <= 0x9F) {
          final code = _cp1252High[b - 0x80];
          if (code == null) {
            return const DecodedText.failed(
              'O arquivo tem bytes que não existem no Windows-1252.',
            );
          }
          out.writeCharCode(code);
        } else {
          out.writeCharCode(b);
        }
      }
      return DecodedText.ok(out.toString());
  }
}
