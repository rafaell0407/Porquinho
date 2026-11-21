import 'embedded_fixtures.g.dart';

String readFixture(String path) {
  final text = embeddedFixtures[path];
  if (text == null) {
    throw StateError(
      '$path não está embutido; rode dart run tooling/embed_test_fixtures.dart',
    );
  }
  return text;
}
