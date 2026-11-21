// Gera test/fixtures/embedded_fixtures.g.dart com o conteúdo das tabelas de
// casos (T8): no navegador os testes não leem arquivo do disco, então a Web
// usa esta cópia embutida. `test/fixtures/embedded_fixtures_test.dart` (no
// celular/VM) falha se a cópia ficar diferente dos JSONs.
//
// Uso: dart run tooling/embed_test_fixtures.dart
import 'dart:io';

const fixtures = [
  'test/fixtures/period_cases.json',
  'test/fixtures/monthly_recurrence_cases.json',
  'test/fixtures/cash_or_installments_cases.json',
];

void main() {
  final out = StringBuffer()
    ..writeln(
      '// GERADO por tooling/embed_test_fixtures.dart. Não editar à mão.',
    )
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln('const embeddedFixtures = <String, String>{');
  for (final path in fixtures) {
    final text = File(path).readAsStringSync().replaceAll('\r\n', '\n');
    if (text.contains("'''")) {
      stderr.writeln("$path contém ''' e não cabe em texto bruto.");
      exit(1);
    }
    out
      ..writeln("  '$path': r'''")
      ..write(text)
      ..writeln("''',");
  }
  out.writeln('};');
  File('test/fixtures/embedded_fixtures.g.dart').writeAsStringSync('$out');
  stdout.writeln('test/fixtures/embedded_fixtures.g.dart atualizado.');
}
