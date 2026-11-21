import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/exact_money_columns.dart';

/// T8 (RN045): valores em centavos lidos das tabelas chegam exatos na Web.
void main() {
  test('tabelas com dinheiro sem teto pedem também o texto', () {
    expect(
      exactSelect('income_entries'),
      '*,exact_text__amount_centavos:amount_centavos::text',
    );
    expect(
      exactSelect('investment_recurrence_templates'),
      '*,exact_text__default_amount_centavos:default_amount_centavos::text',
    );
    expect(exactSelect('categories'), '*');
    expect(exactSelect('sync_conflicts'), contains('remote_snapshot->>'));
  });

  test('o texto exato substitui o número e o apelido some', () {
    // Como o servidor responde: o número (impreciso na Web) e o texto.
    final row =
        jsonDecode(
              '{"id":"a","amount_centavos":9223372036854775807,'
              '"exact_text__amount_centavos":"9223372036854775807"}',
            )
            as Map<String, dynamic>;
    if (kIsWeb) {
      // No navegador o número já chegou arredondado.
      expect('${row['amount_centavos']}', isNot('9223372036854775807'));
    }
    final exact = applyExactMoney('income_entries', row);
    expect(exact, {'id': 'a', 'amount_centavos': '9223372036854775807'});
    expect(
      BigInt.parse(exact['amount_centavos'] as String),
      BigInt.parse('9223372036854775807'),
    );
  });

  test('valor nulo continua nulo', () {
    final exact = applyExactMoney('expense_recurrence_templates', {
      'default_amount_centavos': null,
      'exact_text__default_amount_centavos': null,
    });
    expect(exact, {'default_amount_centavos': null});
  });

  test('conflito: o retrato do servidor recebe o valor exato', () {
    final exact = applyExactMoney('sync_conflicts', {
      'id': 'c',
      'remote_snapshot': {'amount_centavos': 9007199254740992, 'id': 'e'},
      'exact_snapshot__amount_centavos': '9007199254740993',
      'exact_snapshot__default_amount_centavos': null,
    });
    expect(exact, {
      'id': 'c',
      'remote_snapshot': {'amount_centavos': '9007199254740993', 'id': 'e'},
    });
  });
}
