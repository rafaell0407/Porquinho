import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'picked_file.dart';

bool get canPickFiles => true;

/// Abre a escolha de **um** arquivo CSV e lê o conteúdo no navegador (nada é
/// enviado). `null` = o usuário cancelou.
Future<PickedFile?> pickCsvFile() {
  final completer = Completer<PickedFile?>();
  final document = globalContext['document']! as JSObject;
  final input =
      document.callMethod<JSObject>('createElement'.toJS, 'input'.toJS)
        ..['type'] = 'file'.toJS
        ..['accept'] = '.csv,text/csv,text/plain'.toJS
        ..['multiple'] = false.toJS;

  void finish(PickedFile? file) {
    if (!completer.isCompleted) completer.complete(file);
  }

  input['oncancel'] = ((JSAny? _) => finish(null)).toJS;
  input['onchange'] = ((JSAny? _) {
    final files = input['files'] as JSObject?;
    final length = (files?['length'] as JSNumber?)?.toDartInt ?? 0;
    if (files == null || length == 0) {
      finish(null);
      return;
    }
    final file = files.callMethod<JSObject>('item'.toJS, 0.toJS);
    final name = (file['name']! as JSString).toDart;
    final reader = globalContext['FileReader']! as JSFunction;
    final fileReader = reader.callAsConstructor<JSObject>();
    fileReader['onload'] = ((JSAny? _) {
      final buffer = fileReader['result']! as JSArrayBuffer;
      finish(PickedFile(name, Uint8List.view(buffer.toDart)));
    }).toJS;
    fileReader['onerror'] = ((JSAny? _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Não foi possível ler o arquivo.'));
      }
    }).toJS;
    fileReader.callMethod<JSAny?>('readAsArrayBuffer'.toJS, file);
  }).toJS;
  input.callMethod<JSAny?>('click'.toJS);
  return completer.future;
}
