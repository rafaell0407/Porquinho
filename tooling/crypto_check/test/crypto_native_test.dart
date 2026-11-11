@TestOn('vm')
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

const marcador = 'SEGREDO-FINANCEIRO-9223372036854775807';
const chaveA =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const chaveB =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

/// Chave bruta em hexadecimal (256 bits), sem derivação por senha.
String pragmaKey(String hex) => "PRAGMA key = \"x'$hex'\";";

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('porquinho_crypto_');
    path = '${dir.path}${Platform.pathSeparator}t.db';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Database abrir(String hex) {
    final db = sqlite3.open(path);
    db.execute(pragmaKey(hex));
    return db;
  }

  test('a biblioteca carregada é SQLite3MultipleCiphers', () {
    final db = sqlite3.openInMemory();
    final r = db.select('PRAGMA cipher;');
    expect(r, isNotEmpty);
    // ignore: avoid_print
    print(
      'cipher padrão: ${r.first.values.first}; '
      'sqlite ${sqlite3.version}',
    );
    db.close();
  });

  test('o arquivo não contém texto puro nem o cabeçalho SQLite', () {
    final db = abrir(chaveA);
    db.execute('CREATE TABLE t(v TEXT);');
    db.execute("INSERT INTO t VALUES ('$marcador');");
    db.close();
    final bytes = File(path).readAsBytesSync();
    final texto = String.fromCharCodes(bytes);
    expect(texto.contains(marcador), isFalse);
    expect(texto.startsWith('SQLite format 3'), isFalse);
    expect(bytes.length, greaterThan(0));
  });

  test('chave correta lê; chave errada e ausência de chave falham', () {
    var db = abrir(chaveA);
    db.execute('CREATE TABLE t(v TEXT);');
    db.execute("INSERT INTO t VALUES ('$marcador');");
    db.close();

    db = abrir(chaveA);
    expect(db.select('SELECT v FROM t').first['v'], marcador);
    db.close();

    db = abrir(chaveB);
    expect(() => db.select('SELECT v FROM t'), throwsA(isA<SqliteException>()));
    db.close();

    db = sqlite3.open(path);
    expect(() => db.select('SELECT v FROM t'), throwsA(isA<SqliteException>()));
    db.close();
  });

  test('rotação de chave (rekey) mantém os dados e invalida a antiga', () {
    var db = abrir(chaveA);
    db.execute('CREATE TABLE t(v TEXT);');
    db.execute("INSERT INTO t VALUES ('$marcador');");
    db.execute("PRAGMA rekey = \"x'$chaveB'\";");
    db.close();

    db = abrir(chaveB);
    expect(db.select('SELECT v FROM t').first['v'], marcador);
    db.close();
    db = abrir(chaveA);
    expect(() => db.select('SELECT v FROM t'), throwsA(isA<SqliteException>()));
    db.close();
  });

  test('Drift (NativeDatabase) usa a chave via setup e persiste', () async {
    NativeDatabase abrirDrift(String hex) =>
        NativeDatabase(File(path), setup: (raw) => raw.execute(pragmaKey(hex)));

    var db = _Db(abrirDrift(chaveA));
    await db.customStatement('CREATE TABLE c(centavos TEXT NOT NULL)');
    await db.customStatement("INSERT INTO c VALUES ('9223372036854775807')");
    await db.close();

    db = _Db(abrirDrift(chaveA));
    final linha = await db.customSelect('SELECT centavos FROM c').getSingle();
    expect(
      BigInt.parse(linha.read<String>('centavos')),
      BigInt.parse('9223372036854775807'),
    );
    await db.close();

    db = _Db(abrirDrift(chaveB));
    await expectLater(
      db.customSelect('SELECT centavos FROM c').get(),
      throwsA(anything),
    );
    await db.close();
  });
}

class _Db extends GeneratedDatabase {
  _Db(super.e);
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  int get schemaVersion => 1;
  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];
}
