import 'package:flutter/foundation.dart';

/// Registra um erro não tratado **sem valores**: só o tipo da exceção e a
/// origem. Mensagens e pilhas podem conter valores financeiros, e-mails ou
/// nomes, por isso não são gravadas (Entrega 79, `arquitetura.md` §segurança).
typedef ErrorSink = void Function(String line);

String describeError(Object error, String origin) =>
    'Erro não tratado [$origin]: ${error.runtimeType}';

/// Instala os tratadores globais de erro (framework e assíncronos).
/// [sink] existe para teste; por padrão escreve em `debugPrint`.
void installGlobalErrorHandlers({ErrorSink? sink}) {
  final out = sink ?? debugPrint;

  FlutterError.onError = (details) {
    out(describeError(details.exception, 'flutter'));
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    out(describeError(error, 'async'));
    return true; // tratado: o app não cai
  };
}
