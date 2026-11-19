import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/features/import/domain/date_parsing.dart';
import 'package:porquinho/features/import/domain/value_parsing.dart';

BigInt? _v(String raw, ValueFormat f) => parseImportValue(raw, f).centavos;

void main() {
  group('valor', () {
    test('três formatos', () {
      expect(_v('123456', ValueFormat.centavos), BigInt.from(123456));
      expect(_v('1.234,56', ValueFormat.reaisComma), BigInt.from(123456));
      expect(_v('1234,5', ValueFormat.reaisComma), BigInt.from(123450));
      expect(_v('1,234.56', ValueFormat.reaisDot), BigInt.from(123456));
      expect(_v('1234.56', ValueFormat.reaisDot), BigInt.from(123456));
      expect(_v('10', ValueFormat.reaisDot), BigInt.from(1000));
    });

    test('"1.234" muda de sentido conforme o formato declarado', () {
      expect(_v('1.234', ValueFormat.reaisComma), BigInt.from(123400));
      final dot = parseImportValue('1.234', ValueFormat.reaisDot);
      expect(dot.ok, isFalse);
      expect(dot.error, contains('duas casas'));
    });

    test('"1234.56" não é reais com vírgula', () {
      expect(parseImportValue('1234.56', ValueFormat.reaisComma).ok, isFalse);
    });

    test('R\$ com espaço comum ou não separável', () {
      expect(_v('R\$ 10,00', ValueFormat.reaisComma), BigInt.from(1000));
      expect(_v('R\$ 10,00', ValueFormat.reaisComma), BigInt.from(1000));
      expect(_v('R\$ 1.000,00', ValueFormat.reaisComma), BigInt.from(100000));
      expect(_v('R\$10', ValueFormat.reaisComma), BigInt.from(1000));
    });

    test('três casas decimais recusadas', () {
      expect(parseImportValue('10,123', ValueFormat.reaisComma).ok, isFalse);
      expect(parseImportValue('10.123', ValueFormat.reaisDot).ok, isFalse);
    });

    test('sinal negativo é lido; quem chama decide', () {
      expect(_v('-10,50', ValueFormat.reaisComma), BigInt.from(-1050));
      expect(_v('-R\$ 10,50', ValueFormat.reaisComma), BigInt.from(-1050));
      expect(_v('R\$ -10,50', ValueFormat.reaisComma), BigInt.from(-1050));
      expect(_v('-150', ValueFormat.centavos), BigInt.from(-150));
      expect(parseImportValue('--1', ValueFormat.reaisComma).ok, isFalse);
    });

    test('zero aceito', () {
      expect(_v('0', ValueFormat.centavos), BigInt.zero);
      expect(_v('0,00', ValueFormat.reaisComma), BigInt.zero);
    });

    test('teto de R\$ 10 milhões', () {
      expect(
        _v('10.000.000,00', ValueFormat.reaisComma),
        BigInt.from(1000000000),
      );
      expect(
        parseImportValue('10.000.000,01', ValueFormat.reaisComma).ok,
        isFalse,
      );
      expect(parseImportValue('1000000001', ValueFormat.centavos).ok, isFalse);
      expect(
        parseImportValue('99999999999999999999999', ValueFormat.centavos).ok,
        isFalse,
      );
    });

    test('centavos do Norte exatos e sem R\$', () {
      expect(_v('999999999', ValueFormat.centavos), BigInt.from(999999999));
      expect(parseImportValue('R\$ 10', ValueFormat.centavos).ok, isFalse);
      expect(parseImportValue('10,5', ValueFormat.centavos).ok, isFalse);
    });

    test('lixo e vazio recusados', () {
      for (final raw in [
        '',
        'abc',
        '1,2,3',
        '(10,00)',
        '10,',
        ',5',
        '1.23.4',
      ]) {
        expect(
          parseImportValue(raw, ValueFormat.reaisComma).ok,
          isFalse,
          reason: raw,
        );
      }
    });

    test('sugestão de formato', () {
      expect(suggestValueFormat(['10,50', '1.234,00']), ValueFormat.reaisComma);
      expect(suggestValueFormat(['10.50', '1,234.00']), ValueFormat.reaisDot);
      expect(suggestValueFormat(['1.234']), isNull);
      expect(suggestValueFormat(['1,234']), isNull);
      expect(suggestValueFormat(['10,50', '10.50']), isNull);
      expect(suggestValueFormat(['10,50', '1,234']), isNull);
      expect(suggestValueFormat(['100', '-25']), ValueFormat.reaisComma);
    });
  });

  group('data', () {
    final today = CalendarDate(2026, 11, 18);

    CalendarDate? d(String raw, DateFormatKind f) =>
        parseImportDate(raw, f, today).date;

    test('ISO, DD/MM e MM/DD', () {
      expect(d('2026-01-31', DateFormatKind.iso), CalendarDate(2026, 1, 31));
      expect(d('31/01/2026', DateFormatKind.dmy), CalendarDate(2026, 1, 31));
      expect(d('01/31/2026', DateFormatKind.mdy), CalendarDate(2026, 1, 31));
      expect(d('5/3/2026', DateFormatKind.dmy), CalendarDate(2026, 3, 5));
      expect(d('05.03.2026', DateFormatKind.dmy), CalendarDate(2026, 3, 5));
    });

    test('29/02 só em ano bissexto', () {
      expect(d('29/02/2024', DateFormatKind.dmy), CalendarDate(2024, 2, 29));
      final r = parseImportDate('29/02/2025', DateFormatKind.dmy, today);
      expect(r.ok, isFalse);
      expect(r.error, contains('não existe'));
    });

    test('ano com 2 dígitos recusado', () {
      final r = parseImportDate('05/03/26', DateFormatKind.dmy, today);
      expect(r.ok, isFalse);
      expect(r.error, contains('4 dígitos'));
    });

    test('data com hora usa só a data, com aviso', () {
      final r = parseImportDate(
        '2026-01-05T23:59:00-03:00',
        DateFormatKind.iso,
        today,
      );
      expect(r.date, CalendarDate(2026, 1, 5));
      expect(r.hadTime, isTrue);
      final r2 = parseImportDate('05/01/2026 10:30', DateFormatKind.dmy, today);
      expect(r2.date, CalendarDate(2026, 1, 5));
      expect(r2.hadTime, isTrue);
      final r3 = parseImportDate(
        '2026-11-13T10:00:00.123456+00',
        DateFormatKind.iso,
        today,
      );
      expect(r3.ok, isTrue);
    });

    test('texto a mais recusado', () {
      expect(
        parseImportDate('2026-01-05x', DateFormatKind.iso, today).ok,
        isFalse,
      );
    });

    test('faixa: 01/01/2000 até hoje + 5 anos', () {
      expect(d('2000-01-01', DateFormatKind.iso), isNotNull);
      expect(d('1999-12-31', DateFormatKind.iso), isNull);
      expect(d('2031-11-18', DateFormatKind.iso), isNotNull);
      expect(d('2031-11-19', DateFormatKind.iso), isNull);
    });

    test('sugestão: coluna ambígua bloqueia', () {
      expect(suggestDateFormat(['2026-01-05']), DateFormatKind.iso);
      expect(
        suggestDateFormat(['31/01/2026', '05/02/2026']),
        DateFormatKind.dmy,
      );
      expect(
        suggestDateFormat(['01/31/2026', '02/05/2026']),
        DateFormatKind.mdy,
      );
      expect(suggestDateFormat(['05/02/2026', '03/04/2026']), isNull);
      expect(suggestDateFormat(['31/01/2026', '01/31/2026']), isNull);
      expect(suggestDateFormat(['01/01/2026']), DateFormatKind.dmy);
      expect(suggestDateFormat(['2026-01-05', '05/01/2026']), isNull);
    });
  });
}
