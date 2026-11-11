@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// Prova de recuperação de chave na Web: a chave-mestra (KEK) é uma CryptoKey
/// AES-GCM NÃO extraível guardada em IndexedDB; ela embrulha a chave do banco.
void main() {
  final subtle = web.window.crypto.subtle;
  final dbName = 'kek_${DateTime.now().microsecondsSinceEpoch}';

  Future<web.IDBDatabase> abrirIdb() {
    final req = web.window.indexedDB.open(dbName, 1);
    req.onupgradeneeded = ((web.Event _) {
      (req.result! as web.IDBDatabase).createObjectStore('keys');
    }).toJS;
    return _await<web.IDBDatabase>(req);
  }

  tearDownAll(() => web.window.indexedDB.deleteDatabase(dbName));

  test(
    'KEK não extraível sobrevive a reabrir e protege a chave do banco',
    () async {
      final params = {'name': 'AES-GCM', 'length': 256}.jsify()! as JSObject;
      final kek =
          await subtle
                  .generateKey(
                    params,
                    false,
                    ['encrypt', 'decrypt'].jsify()! as JSArray<JSString>,
                  )
                  .toDart
              as web.CryptoKey;
      expect(kek.extractable, isFalse);

      // A exportação deve ser recusada.
      await expectLater(subtle.exportKey('raw', kek).toDart, throwsA(anything));

      // Guarda a CryptoKey (clone estruturado) em IndexedDB.
      var idb = await abrirIdb();
      await _await(
        idb
            .transaction('keys'.toJS, 'readwrite')
            .objectStore('keys')
            .put(kek, 'kek'.toJS),
      );
      idb.close();

      // Chave do banco (256 bits) cifrada com a KEK.
      final chaveBanco = Uint8List.fromList(
        List.generate(32, (i) => i * 7 % 256),
      );
      final iv = Uint8List.fromList(List.generate(12, (i) => i + 1));
      final aes = {'name': 'AES-GCM', 'iv': iv.toJS}.jsify()! as JSObject;
      final cifrada =
          (await subtle.encrypt(aes, kek, chaveBanco.toJS).toDart
                  as JSArrayBuffer)
              .toDart
              .asUint8List();
      expect(cifrada, isNot(equals(chaveBanco)));

      // "Nova sessão": reabre o IndexedDB e recupera a KEK.
      idb = await abrirIdb();
      final recuperada = await _await<web.CryptoKey>(
        idb.transaction('keys'.toJS).objectStore('keys').get('kek'.toJS),
      );
      idb.close();
      expect(recuperada.extractable, isFalse);

      final aberta =
          (await subtle.decrypt(aes, recuperada, cifrada.toJS).toDart
                  as JSArrayBuffer)
              .toDart
              .asUint8List();
      expect(aberta, equals(chaveBanco));
    },
  );
}

Future<T> _await<T extends JSAny?>(web.IDBRequest req) {
  final c = Completer<T>();
  req.onsuccess = ((web.Event _) => c.complete(req.result as T)).toJS;
  req.onerror = ((web.Event _) => c.completeError(req.error ?? 'idb')).toJS;
  return c.future;
}
