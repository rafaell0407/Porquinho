import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/error_reporting.dart';

void main() {
  late FlutterExceptionHandler? savedFlutter;
  late ErrorCallback? savedPlatform;

  setUp(() {
    savedFlutter = FlutterError.onError;
    savedPlatform = PlatformDispatcher.instance.onError;
  });
  tearDown(() {
    FlutterError.onError = savedFlutter;
    PlatformDispatcher.instance.onError = savedPlatform;
  });

  test('erro do framework registra só o tipo, sem a mensagem', () {
    final lines = <String>[];
    installGlobalErrorHandlers(sink: lines.add);

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('saldo R\$ 1234,56')),
    );

    expect(lines, ['Erro não tratado [flutter]: StateError']);
    expect(lines.single, isNot(contains('1234')));
  });

  test('erro assíncrono é tratado e não vaza valores', () {
    final lines = <String>[];
    installGlobalErrorHandlers(sink: lines.add);

    final handled = PlatformDispatcher.instance.onError!(
      FormatException('user@example.com'),
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(lines, ['Erro não tratado [async]: FormatException']);
  });
}
