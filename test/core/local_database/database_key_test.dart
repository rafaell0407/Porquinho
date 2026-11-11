// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/local_database/database_key.dart';

void main() {
  const valid =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('monta o PRAGMA key com chave bruta de 256 bits', () {
    expect(buildKeyPragma(valid), "PRAGMA key = \"x'$valid'\";");
    expect(buildKeyPragma(valid.toUpperCase()), contains(valid.toUpperCase()));
  });

  test('rejeita chave fora do formato, inclusive tentativa de injeção', () {
    for (final bad in [
      '',
      'abc',
      valid.substring(1),
      '${valid}0',
      "${valid.substring(2)}'; DROP TABLE t; --",
      valid.replaceRange(0, 1, 'g'),
    ]) {
      expect(() => buildKeyPragma(bad), throwsArgumentError, reason: bad);
    }
  });

  test('o erro não vaza o valor da chave', () {
    try {
      buildKeyPragma('segredo-invalido');
      fail('deveria lançar');
    } on ArgumentError catch (e) {
      expect(e.toString(), isNot(contains('segredo-invalido')));
    }
  });
}
