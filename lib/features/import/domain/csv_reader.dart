import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Leitura de CSV (RN047, RFC 4180): separador vírgula ou ponto e vírgula,
/// campos entre aspas com `""` para aspas literais e quebras de linha dentro
/// do campo, fim de linha CRLF ou LF. Nada é corrigido em silêncio: linha com
/// aspas mal fechadas fica marcada com o problema e é rejeitada depois.
enum CsvSeparator {
  comma(',', 'vírgula (,)'),
  semicolon(';', 'ponto e vírgula (;)');

  const CsvSeparator(this.char, this.label);
  final String char;
  final String label;
}

/// Uma linha lida do arquivo. [line] é a linha física (1 = cabeçalho) em que
/// o registro começa, usada nas mensagens ao usuário.
class CsvRecord {
  const CsvRecord(this.line, this.fields, {this.problem});

  final int line;
  final List<String> fields;

  /// Defeito de leitura (ex.: aspas sem fechamento); `null` = bem formada.
  final String? problem;
}

class CsvTable {
  const CsvTable({
    required this.separator,
    required this.header,
    required this.records,
    required this.emptyLines,
  });

  final CsvSeparator separator;
  final List<String> header;
  final List<CsvRecord> records;

  /// Linhas vazias ignoradas (contadas no resultado).
  final int emptyLines;

  bool get isEmpty => header.isEmpty;
}

/// SHA-256 dos bytes do arquivo (identifica "arquivo já importado").
String fileSha256(Uint8List bytes) => sha256.convert(bytes).toString();

/// Separador provável: o que mais aparece fora de aspas na primeira linha.
/// Empate (ou nenhum) = vírgula. O usuário pode trocar.
CsvSeparator detectSeparator(String text) {
  var commas = 0;
  var semicolons = 0;
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      quoted = !quoted;
    } else if (!quoted) {
      if (c == '\n' || c == '\r') break;
      if (c == ',') commas++;
      if (c == ';') semicolons++;
    }
  }
  return semicolons > commas ? CsvSeparator.semicolon : CsvSeparator.comma;
}

/// Lê o texto inteiro com o [separator]. A primeira linha não vazia é o
/// cabeçalho. Linhas vazias (sem nenhum caractere) são ignoradas e contadas.
CsvTable parseCsv(String text, CsvSeparator separator) {
  final sep = separator.char;
  final records = <CsvRecord>[];
  var emptyLines = 0;

  var line = 1;
  var i = 0;
  final n = text.length;
  while (i < n) {
    final startLine = line;
    final fields = <String>[];
    final field = StringBuffer();
    String? problem;
    var recordHasContent = false;
    var atFieldStart = true;
    var inQuotes = false;
    var afterQuote = false;
    var ended = false;

    while (i < n && !ended) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < n && text[i + 1] == '"') {
            field.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          afterQuote = true;
          i++;
          continue;
        }
        if (c == '\n') line++;
        if (c == '\r') {
          if (!(i + 1 < n && text[i + 1] == '\n')) line++;
        }
        field.write(c);
        i++;
        continue;
      }
      if (c == sep) {
        fields.add(field.toString());
        field.clear();
        recordHasContent = true;
        atFieldStart = true;
        afterQuote = false;
        i++;
        continue;
      }
      if (c == '\r' || c == '\n') {
        if (c == '\r' && i + 1 < n && text[i + 1] == '\n') i++;
        i++;
        line++;
        ended = true;
        continue;
      }
      if (c == '"' && atFieldStart) {
        inQuotes = true;
        atFieldStart = false;
        recordHasContent = true;
        i++;
        continue;
      }
      if (afterQuote) {
        problem ??= 'Aspas mal fechadas.';
      }
      field.write(c);
      recordHasContent = true;
      atFieldStart = false;
      i++;
    }
    if (inQuotes) {
      problem = 'Aspas abertas e não fechadas até o fim do arquivo.';
    }
    if (!recordHasContent && field.isEmpty) {
      emptyLines++;
      continue;
    }
    fields.add(field.toString());
    records.add(CsvRecord(startLine, fields, problem: problem));
  }

  if (records.isEmpty) {
    return CsvTable(
      separator: separator,
      header: const [],
      records: const [],
      emptyLines: emptyLines,
    );
  }
  final header = [for (final h in records.first.fields) h.trim()];
  return CsvTable(
    separator: separator,
    header: header,
    records: records.sublist(1),
    emptyLines: emptyLines,
  );
}
