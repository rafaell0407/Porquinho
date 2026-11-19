import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/export/csv_export.dart';
import 'package:porquinho/features/import/domain/csv_reader.dart';
import 'package:porquinho/features/import/domain/norte_formats.dart';
import 'package:porquinho/features/import/domain/text_decoding.dart';

Uint8List _bytes(List<int> b) => Uint8List.fromList(b);

void main() {
  group('decodificação', () {
    test('UTF-8 com BOM remove o BOM', () {
      final r = decodeImportBytes(
        _bytes([0xEF, 0xBB, 0xBF, ...utf8.encode('a,b\r\nç,ã')]),
        ImportEncoding.utf8,
      );
      expect(r.ok, isTrue);
      expect(r.hadBom, isTrue);
      expect(r.text, 'a,b\r\nç,ã');
    });

    test('UTF-8 sem BOM', () {
      final r = decodeImportBytes(
        _bytes(utf8.encode('descrição')),
        ImportEncoding.utf8,
      );
      expect(r.text, 'descrição');
      expect(r.hadBom, isFalse);
    });

    test('UTF-8 inválido falha, sem trocar caracteres', () {
      // "Pão" em Windows-1252: 0xE3 sozinho não é UTF-8 válido.
      final r = decodeImportBytes(
        _bytes([0x50, 0xE3, 0x6F]),
        ImportEncoding.utf8,
      );
      expect(r.ok, isFalse);
      expect(r.failure, contains('Windows-1252'));
    });

    test('Windows-1252 explícito, inclusive € e aspas curvas', () {
      final r = decodeImportBytes(
        _bytes([0x50, 0xE3, 0x6F, 0x20, 0x80, 0x93, 0x94, 0x96]),
        ImportEncoding.windows1252,
      );
      expect(r.text, 'Pão €“”–');
    });

    test('Windows-1252 recusa byte indefinido', () {
      final r = decodeImportBytes(_bytes([0x81]), ImportEncoding.windows1252);
      expect(r.ok, isFalse);
    });
  });

  group('separador', () {
    test('vírgula por padrão e em empate', () {
      expect(detectSeparator('a,b,c\n1;2'), CsvSeparator.comma);
      expect(detectSeparator(''), CsvSeparator.comma);
      expect(detectSeparator('a;b,c'), CsvSeparator.comma);
    });

    test('ponto e vírgula quando predomina, ignorando aspas', () {
      expect(detectSeparator('a;b;"x,y,z"\n'), CsvSeparator.semicolon);
    });
  });

  group('RFC 4180', () {
    test('aspas, aspas duplicadas e quebra dentro do campo', () {
      final t = parseCsv(
        'desc,valor\r\n"Mercado, feira","10,00"\r\n"Disse ""oi""",5\r\n'
        '"linha 1\nlinha 2",7\r\nfim,8',
        CsvSeparator.comma,
      );
      expect(t.header, ['desc', 'valor']);
      expect(t.records.map((r) => r.fields).toList(), [
        ['Mercado, feira', '10,00'],
        ['Disse "oi"', '5'],
        ['linha 1\nlinha 2', '7'],
        ['fim', '8'],
      ]);
      // Linha física em que cada registro começa.
      expect(t.records.map((r) => r.line).toList(), [2, 3, 4, 6]);
    });

    test('LF e CRLF misturados, linhas vazias contadas', () {
      final t = parseCsv('a;b\n\n1;2\r\n\r\n3;4\n', CsvSeparator.semicolon);
      expect(t.records.map((r) => r.fields).toList(), [
        ['1', '2'],
        ['3', '4'],
      ]);
      expect(t.emptyLines, 2);
    });

    test('campos a mais ou a menos ficam como vieram', () {
      final t = parseCsv('a,b\n1\n1,2,3', CsvSeparator.comma);
      expect(t.records[0].fields, ['1']);
      expect(t.records[1].fields, ['1', '2', '3']);
    });

    test('campo vazio no fim', () {
      final t = parseCsv('a,b\n1,\n', CsvSeparator.comma);
      expect(t.records.single.fields, ['1', '']);
    });

    test('aspas sem fechamento marcam problema', () {
      final t = parseCsv('a,b\n"abc,1\n', CsvSeparator.comma);
      expect(t.records.single.problem, isNotNull);
    });

    test('texto depois das aspas fechadas marca problema', () {
      final t = parseCsv('a,b\n"abc"x,1\n', CsvSeparator.comma);
      expect(t.records.single.problem, isNotNull);
    });

    test('arquivo vazio', () {
      final t = parseCsv('', CsvSeparator.comma);
      expect(t.isEmpty, isTrue);
      expect(t.records, isEmpty);
    });

    test('só cabeçalho', () {
      final t = parseCsv('a,b\r\n', CsvSeparator.comma);
      expect(t.header, ['a', 'b']);
      expect(t.records, isEmpty);
    });
  });

  group('arquivos do Norte', () {
    final data = ExportData(
      incomes: [
        {
          'id': '1',
          'description': '=SOMA(A1)',
          'amount_centavos': 123456,
          'status': 'received',
          'received_on': '2026-01-05',
          'category_id': 'c1',
          'subcategory_id': null,
          'recurrence_template_id': null,
          'scheduled_for_date': null,
          'created_at': 'x',
          'updated_at': 'y',
        },
      ],
      expenses: const [],
      investments: const [],
      categories: [
        {'id': 'c1', 'kind': 'income', 'name': 'Salário', 'is_active': true},
      ],
      subcategories: const [],
    );

    test('reconhece os quatro cabeçalhos exportados', () {
      for (final kind in CsvKind.values) {
        final csv = buildCsv(kind, data);
        final decoded = decodeImportBytes(
          Uint8List.fromList(utf8.encode(csv)),
          ImportEncoding.utf8,
        );
        final t = parseCsv(decoded.text!, detectSeparator(decoded.text!));
        final expected = switch (kind) {
          CsvKind.incomes => NorteFileKind.incomes,
          CsvKind.expenses => NorteFileKind.expenses,
          CsvKind.investments => NorteFileKind.investments,
          CsvKind.categories => NorteFileKind.categories,
        };
        expect(recognizeNorteFile(t.header), expected, reason: kind.name);
      }
    });

    test('cabeçalho diferente não é do Norte', () {
      expect(recognizeNorteFile(['id', 'descricao']), isNull);
      expect(
        recognizeNorteFile([...NorteFileKind.investments.header, 'extra']),
        isNull,
      );
    });

    test('ida e volta da exportação preserva centavos e texto', () {
      final csv = buildCsv(CsvKind.incomes, data);
      final decoded = decodeImportBytes(
        Uint8List.fromList(utf8.encode(csv)),
        ImportEncoding.utf8,
      );
      final t = parseCsv(decoded.text!, CsvSeparator.comma);
      final row = t.records.single.fields;
      expect(row[2], '123456');
      expect(unguardNorteText(row[1]), '=SOMA(A1)');
      expect(row[5], 'Salário');
    });

    test('apóstrofo só sai antes de = + - @ tab CR', () {
      expect(unguardNorteText("'=1"), '=1');
      expect(unguardNorteText("'+1"), '+1');
      expect(unguardNorteText("'-1"), '-1');
      expect(unguardNorteText("'@x"), '@x');
      expect(unguardNorteText("'\tx"), '\tx');
      expect(unguardNorteText("'\rx"), '\rx');
      expect(unguardNorteText("'abc"), "'abc");
      expect(unguardNorteText("'"), "'");
      expect(unguardNorteText('abc'), 'abc');
    });
  });
}
