@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'embedded_fixtures.g.dart';

/// A cópia embutida (usada nos testes da Web) é igual às tabelas de casos.
/// Se falhar: dart run tooling/embed_test_fixtures.dart
void main() {
  final files = Directory('test/fixtures')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .map((f) => f.path.replaceAll(r'\', '/'))
      .toSet();

  test('todas as tabelas de casos estão embutidas', () {
    expect(embeddedFixtures.keys.toSet(), files);
  });

  // Quebra de linha não muda o JSON; o Dart e o Git podem trocar \r\n por \n.
  String lf(String? s) => (s ?? '').replaceAll('\r\n', '\n');

  for (final path in files) {
    test('$path igual à cópia embutida', () {
      expect(lf(embeddedFixtures[path]), lf(File(path).readAsStringSync()));
    });
  }
}
