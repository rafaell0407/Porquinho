import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';

void main() {
  test('preserva centavos acima da precisão segura do JavaScript', () async {
    final parsed = BigInt.parse('9007199254740993');
    final converter = const BigIntTextConverter();

    expect(converter.toSql(parsed), '9007199254740993');
    expect(converter.fromSql('9007199254740993'), parsed);
    expect(converter.toSql(BigInt.zero), '0');
    expect(
      converter.toSql(BigInt.parse('9223372036854775807')),
      '9223372036854775807',
    );
    expect(() => converter.toSql(BigInt.from(-1)), throwsRangeError);
    expect(
      () => converter.toSql(BigInt.parse('9223372036854775808')),
      throwsRangeError,
    );
  });
}
