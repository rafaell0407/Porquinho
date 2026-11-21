import 'fixture_text_io.dart'
    if (dart.library.js_interop) 'fixture_text_web.dart'
    as impl;

/// Conteúdo de uma tabela de casos (`test/fixtures/*.json`).
///
/// No celular/VM lê o arquivo; no navegador usa a cópia embutida em
/// `embedded_fixtures.g.dart` (T8), para as mesmas tabelas rodarem na Web.
String readFixture(String path) => impl.readFixture(path);
