@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';
import 'package:test/test.dart';

const marcador = 'SEGREDO-FINANCEIRO-9223372036854775807';
const chaveA =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const chaveB =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
String pragmaKey(String hex) => "PRAGMA key = \"x'$hex'\";";

void main() {
  late WasmSqlite3 sqlite3;
  late IndexedDbFileSystem fs;
  var n = 0;
  late String dbName;

  setUpAll(() async {
    sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3mc.wasm'));
  });

  setUp(() async {
    dbName = 'porquinho_crypto_${DateTime.now().microsecondsSinceEpoch}_${n++}';
    fs = await IndexedDbFileSystem.open(dbName: dbName);
    sqlite3.registerVirtualFileSystem(fs);
  });

  tearDown(() async {
    sqlite3.unregisterVirtualFileSystem(fs);
    await fs.close();
    await IndexedDbFileSystem.deleteDatabase(dbName);
  });

  CommonDatabase abrir(String hex) {
    final db = sqlite3.open('/t.db', vfs: 'multipleciphers-${fs.name}');
    db.execute(pragmaKey(hex));
    return db;
  }

  Uint8List bytesDoArquivo() {
    final (file: f, outFlags: _) = fs.xOpen(Sqlite3Filename('/t.db'), 0x02);
    final size = f.xFileSize();
    final out = Uint8List(size);
    f.xRead(out, 0);
    f.xClose();
    return out;
  }

  test('o módulo carregado é SQLite3MultipleCiphers', () {
    final db = sqlite3.openInMemory();
    final r = db.select('PRAGMA cipher;');
    expect(r, isNotEmpty);
    // ignore: avoid_print
    print('cipher Web: ${r.first.values.first}');
    db.close();
  });

  test('IndexedDB guarda o arquivo cifrado e sobrevive a reabrir', () async {
    var db = abrir(chaveA);
    db.execute('CREATE TABLE t(v TEXT);');
    db.execute("INSERT INTO t VALUES ('$marcador');");
    db.close();
    await fs.flush();

    final bytes = bytesDoArquivo();
    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes).contains(marcador), isFalse);
    expect(latin1.decode(bytes).startsWith('SQLite format 3'), isFalse);

    // Reabre o IndexedDB como uma nova "sessão" (nova instância do FS).
    sqlite3.unregisterVirtualFileSystem(fs);
    await fs.close();
    fs = await IndexedDbFileSystem.open(dbName: dbName);
    sqlite3.registerVirtualFileSystem(fs);

    db = abrir(chaveA);
    expect(db.select('SELECT v FROM t').first['v'], marcador);
    db.close();
  });

  test('chave errada e ausência de chave falham', () async {
    var db = abrir(chaveA);
    db.execute('CREATE TABLE t(v TEXT);');
    db.execute("INSERT INTO t VALUES ('$marcador');");
    db.close();
    await fs.flush();

    db = abrir(chaveB);
    expect(() => db.select('SELECT v FROM t'), throwsA(isA<SqliteException>()));
    db.close();
    db = sqlite3.open('/t.db', vfs: 'multipleciphers-${fs.name}');
    expect(() => db.select('SELECT v FROM t'), throwsA(isA<SqliteException>()));
    db.close();
  });

  test('rotação de chave na Web', () async {
    var db = abrir(chaveA);
    db.execute('CREATE TABLE t(v TEXT);');
    db.execute("INSERT INTO t VALUES ('$marcador');");
    db.execute("PRAGMA rekey = \"x'$chaveB'\";");
    db.close();
    await fs.flush();
    db = abrir(chaveB);
    expect(db.select('SELECT v FROM t').first['v'], marcador);
    db.close();
  });
}
