import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool get canDownloadFiles => true;

/// Entrega o texto como arquivo para download, sem enviar nada a servidores.
void downloadTextFile(
  String fileName,
  String content, {
  String mimeType = 'text/csv;charset=utf-8',
}) {
  final blobConstructor = globalContext['Blob']! as JSFunction;
  final options = JSObject()..['type'] = mimeType.toJS;
  final blob = blobConstructor.callAsConstructor<JSObject>(
    <JSAny>[content.toJS].toJS,
    options,
  );
  final url = globalContext['URL']! as JSObject;
  final objectUrl = url
      .callMethod<JSString>('createObjectURL'.toJS, blob)
      .toDart;
  final document = globalContext['document']! as JSObject;
  final anchor = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS)
    ..['href'] = objectUrl.toJS
    ..['download'] = fileName.toJS;
  final body = document['body']! as JSObject;
  body.callMethod<JSAny?>('appendChild'.toJS, anchor);
  anchor.callMethod<JSAny?>('click'.toJS);
  body.callMethod<JSAny?>('removeChild'.toJS, anchor);
  url.callMethod<JSAny?>('revokeObjectURL'.toJS, objectUrl.toJS);
}
