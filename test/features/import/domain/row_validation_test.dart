import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/features/import/domain/column_mapping.dart';
import 'package:porquinho/features/import/domain/csv_reader.dart';
import 'package:porquinho/features/import/domain/date_parsing.dart';
import 'package:porquinho/features/import/domain/import_models.dart';
import 'package:porquinho/features/import/domain/norte_formats.dart';
import 'package:porquinho/features/import/domain/row_validation.dart';
import 'package:porquinho/features/import/domain/value_parsing.dart';

final today = CalendarDate(2026, 11, 18);

CsvTable _t(String text) => parseCsv(text, detectSeparator(text));

ImportMapping _generic(
  CsvTable t, {
  RowKind? kind = RowKind.expense,
  TypeSource source = TypeSource.fixed,
  Map<String, StatusMeaning> status = const {},
  Map<String, RowKind?> kinds = const {},
  bool markPaid = false,
  PaidDateSource paidSource = PaidDateSource.entryDate,
}) {
  final cols = <ImportField, int>{};
  for (var i = 0; i < t.header.length; i++) {
    cols[ImportField.fromKey(t.header[i])] = i;
  }
  return ImportMapping(
    columns: cols,
    valueFormat: ValueFormat.reaisComma,
    dateFormat: DateFormatKind.dmy,
    typeSource: source,
    fixedKind: kind,
    statusValues: status,
    kindValues: kinds,
    markExpensesPaid: markPaid,
    paidDateSource: paidSource,
  );
}

void main() {
  test('linha com campos a mais ou a menos é rejeitada com o motivo', () {
    final t = _t('descricao;valor;data\nA;"10,00"\nB;5;01/01/2026;x\n');
    final r = validateRows(t, _generic(t), today);
    expect(r.rows, isEmpty);
    expect(r.rejected.map((e) => e.sourceRow), [2, 3]);
    expect(r.rejected.first.reason, contains('campos'));
  });

  test('despesa entra pendente; marcar como pagas usa a data da despesa', () {
    final t = _t('descricao;valor;data\nLuz;"100,00";05/01/2026\n');
    final pending = validateRows(t, _generic(t), today).rows.single;
    expect(pending.state, EntryState.pending);
    expect(pending.amount, BigInt.from(10000));
    expect(pending.paidOn, isNull);

    final paid = validateRows(
      t,
      _generic(t, markPaid: true),
      today,
    ).rows.single;
    expect(paid.state, EntryState.paid);
    expect(paid.paidOn, CalendarDate(2026, 1, 5));
  });

  test('paga sem data de pagamento é rejeitada', () {
    final t = _t('descricao;valor;data;status\nLuz;10;05/01/2026;Pago\n');
    final r = validateRows(
      t,
      _generic(t, status: {'pago': StatusMeaning.paid}),
      today,
    );
    expect(r.rejected.single.reason, contains('sem data de pagamento'));
  });

  test('pagamento futuro ou antes da competência: aceito com aviso', () {
    final t = _t(
      'descricao;valor;data;data_pagamento;status\n'
      'A;10;05/01/2026;20/12/2026;pago\n'
      'B;10;05/01/2026;01/01/2026;pago\n',
    );
    final r = validateRows(
      t,
      _generic(t, status: {'pago': StatusMeaning.paid}),
      today,
    );
    expect(r.rows, hasLength(2));
    expect(r.rows[0].warnings.single, contains('futura'));
    expect(r.rows[1].warnings.single, contains('antes da competência'));
    expect(r.rows[1].date, CalendarDate(2026, 1, 5));
  });

  test('parcial e valor pago diferente são rejeitados', () {
    final t = _t(
      'descricao;valor;data;data_pagamento;valor_pago;status\n'
      'A;10;05/01/2026;05/01/2026;5;pago\n'
      'B;10;05/01/2026;;;parcial\n'
      'C;10;05/01/2026;05/01/2026;10;pago\n',
    );
    final r = validateRows(
      t,
      _generic(
        t,
        status: {'pago': StatusMeaning.paid, 'parcial': StatusMeaning.partial},
      ),
      today,
    );
    expect(r.rejected.map((e) => e.sourceRow), [2, 3]);
    expect(r.rows.single.description, 'C');
  });

  test('canceladas não entram e são contadas', () {
    final t = _t(
      'descricao;valor;data;status\nA;10;05/01/2026;cancelada\n'
      'B;10;05/01/2026;ok\n',
    );
    final r = validateRows(
      t,
      _generic(
        t,
        status: {
          'cancelada': StatusMeaning.cancelled,
          'ok': StatusMeaning.normal,
        },
      ),
      today,
    );
    expect(r.cancelled, 1);
    expect(r.rows.single.description, 'B');
  });

  test('negativo recusado sem a regra; com a regra vira despesa/receita', () {
    final t = _t(
      'descricao;valor;data\nMercado;-50,00;05/01/2026\n'
      'Salário;3000;05/01/2026\nZero;0;05/01/2026\n',
    );
    final without = validateRows(t, _generic(t), today);
    expect(without.rejected.single.reason, contains('negativo'));
    expect(without.rows, hasLength(2));

    final bySign = validateRows(
      t,
      _generic(t, kind: null, source: TypeSource.sign),
      today,
    );
    expect(bySign.rows.map((r) => r.kind), [RowKind.expense, RowKind.income]);
    expect(bySign.rows.first.amount, BigInt.from(5000));
    expect(bySign.rows.last.state, EntryState.received);
    expect(bySign.rejected.single.reason, contains('zero'));
  });

  test('coluna de tipo com valores associados e linhas ignoradas', () {
    final t = _t(
      'tipo;descricao;valor;data\nR;Sal;10;05/01/2026\nD;Luz;5;05/01/2026\n'
      'I;;7;05/01/2026\nX;;1;05/01/2026\n',
    );
    final r = validateRows(
      t,
      _generic(
        t,
        kind: null,
        source: TypeSource.column,
        kinds: {
          'r': RowKind.income,
          'd': RowKind.expense,
          'i': RowKind.investment,
          'x': null,
        },
      ),
      today,
    );
    expect(r.rows.map((e) => e.kind), [
      RowKind.income,
      RowKind.expense,
      RowKind.investment,
    ]);
    expect(r.ignoredByKind, 1);
  });

  test('investimento com colunas extras: ignoradas com aviso', () {
    final t = _t(
      'descricao;valor;data;categoria\nCDB;100;05/01/2026;Reserva\n',
    );
    final r = validateRows(t, _generic(t, kind: RowKind.investment), today);
    final row = r.rows.single;
    expect(row.description, isNull);
    expect(row.categoryName, isNull);
    expect(row.warnings.single, contains('descrição, categoria'));
  });

  test('limites de texto, data fora da faixa e subcategoria sem categoria', () {
    final longDesc = 'x' * 121;
    final longName = 'y' * 61;
    final t = _t(
      'descricao;valor;data;categoria;subcategoria\n'
      '$longDesc;1;05/01/2026;;\n'
      'ok;1;05/01/2026;$longName;\n'
      'ok;1;05/01/1999;;\n'
      'ok;1;05/01/2026;;Sub\n'
      '${'z' * 120};1;05/01/2026;${'w' * 60};\n',
    );
    final r = validateRows(t, _generic(t), today);
    expect(r.rejected.map((e) => e.sourceRow), [2, 3, 4, 5]);
    expect(r.rejected[0].reason, contains('120'));
    expect(r.rejected[1].reason, contains('60'));
    expect(r.rejected[2].reason, contains('faixa'));
    expect(r.rejected[3].reason, contains('Subcategoria sem categoria'));
    expect(r.rows, hasLength(1));
  });

  test('data com hora gera aviso', () {
    final t = _t('descricao;valor;data\nA;1;05/01/2026 10:00\n');
    final r = validateRows(t, _generic(t), today);
    expect(r.rows.single.warnings.single, contains('hora'));
  });

  group('arquivos do Norte', () {
    test('receitas: pendente vira só âncora; apóstrofo removido', () {
      final header = NorteFileKind.incomes.header.join(',');
      final t = _t(
        '$header\n'
        "a1,'=Bônus,150000,received,2026-10-05,Salário,,nao,,x,y\n"
        'a2,Aluguel,80000,pending,,Aluguel,,sim,2026-11-10,x,y\n'
        'a3,Velho,100,cancelled,2026-01-01,,,nao,,x,y\n',
      );
      final m = norteMapping(NorteFileKind.incomes);
      expect(mappingProblems(m, t), isEmpty);
      final r = validateRows(t, m, today);
      expect(r.cancelled, 1);
      expect(r.rows, hasLength(2));
      expect(r.rows[0].description, '=Bônus');
      expect(r.rows[0].amount, BigInt.from(150000));
      expect(r.rows[0].anchorOnly, isFalse);
      expect(r.rows[0].norteId, 'a1');
      expect(r.rows[1].state, EntryState.pending);
      expect(r.rows[1].anchorOnly, isTrue);
      expect(r.rows[1].date, CalendarDate(2026, 11, 10));
    });

    test('outra origem mantém o apóstrofo', () {
      final t = _t("descricao;valor;data\n'=x;1;05/01/2026\n");
      expect(
        validateRows(t, _generic(t), today).rows.single.description,
        "'=x",
      );
    });

    test('despesas: paga usa a data do arquivo; variável sem valor', () {
      final header = NorteFileKind.expenses.header.join(',');
      final t = _t(
        '$header\n'
        'b1,Luz,12345,paid,2026-10-05,2026-10-10,2026-10-09,Casa,Luz,nao,,x,y\n'
        'b2,Água,,pending,2026-11-05,2026-11-05,,Casa,,sim,2026-11-05,x,y\n',
      );
      final m = norteMapping(NorteFileKind.expenses);
      final r = validateRows(t, m, today);
      expect(r.rejected, isEmpty);
      expect(r.rows[0].state, EntryState.paid);
      expect(r.rows[0].paidOn, CalendarDate(2026, 10, 9));
      expect(r.rows[0].dueOn, CalendarDate(2026, 10, 10));
      expect(r.rows[0].subcategoryName, 'Luz');
      expect(r.rows[1].amount, isNull);
      expect(r.rows[1].anchorOnly, isTrue);
    });

    test('investimentos: active e cancelled', () {
      final header = NorteFileKind.investments.header.join(',');
      final t = _t(
        '$header\nc1,50000,2026-10-05,active,nao,,x,y\n'
        'c2,100,2026-10-06,cancelled,nao,,x,y\n',
      );
      final r = validateRows(t, norteMapping(NorteFileKind.investments), today);
      expect(r.rows.single.amount, BigInt.from(50000));
      expect(r.cancelled, 1);
    });

    test('categorias: inativas ignoradas, subcategoria com pai', () {
      final header = NorteFileKind.categories.header.join(',');
      final t = _t(
        '$header\n'
        'k1,expense,Casa,sim,,\n'
        'k2,income,Antiga,nao,,\n'
        'k3,expense,Luz,sim,k1,Casa\n',
      );
      final m = norteMapping(NorteFileKind.categories);
      expect(mappingProblems(m, t), isEmpty);
      final r = validateRows(t, m, today);
      expect(r.inactiveCategories, 1);
      expect(r.categoryRows.map((c) => c.name), ['Casa', 'Luz']);
      expect(r.categoryRows.last.parentName, 'Casa');
      expect(r.categoryRows.first.kind, CategoryKind.expense);
    });
  });

  group('pendências de associação', () {
    test('formato de valor e data, tipo e situação sem associação', () {
      final t = _t('tipo;valor;data;status\nR;10;05/01/2026;ok\n');
      final m = ImportMapping(
        columns: const {
          ImportField.kind: 0,
          ImportField.amount: 1,
          ImportField.date: 2,
          ImportField.status: 3,
        },
        typeSource: TypeSource.column,
      );
      final p = mappingProblems(m, t);
      expect(p.join('|'), contains('coluna de tipo'));
      expect(p.join('|'), contains('formato do valor'));
      expect(p.join('|'), contains('formato da data'));
      expect(p.join('|'), contains('cada situação'));
    });

    test('mesma coluna em dois campos', () {
      final t = _t('a;b\n1;2\n');
      final m = ImportMapping(
        columns: const {ImportField.amount: 0, ImportField.date: 0},
        valueFormat: ValueFormat.reaisComma,
        dateFormat: DateFormatKind.iso,
        fixedKind: RowKind.expense,
      );
      expect(mappingProblems(m, t).join(), contains('dois campos'));
    });

    test('ida e volta em JSON', () {
      final m = norteMapping(NorteFileKind.expenses).copyWith(
        markExpensesPaid: true,
        kindValues: {'x': null, 'r': RowKind.income},
      );
      final back = ImportMapping.fromJson(m.toJson());
      expect(back.toJson(), m.toJson());
    });

    test('sugestão de colunas pelo cabeçalho', () {
      final s = suggestColumns(['Data', 'Histórico', 'Valor', 'Categoria']);
      expect(s[ImportField.date], 0);
      expect(s[ImportField.description], 1);
      expect(s[ImportField.amount], 2);
      expect(s[ImportField.category], 3);
    });
  });
}
