import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/infra_providers.dart';
import '../../core/local_database/stored_database_key_provider.dart';
import 'app_lock_controller.dart';
import 'app_lock_service.dart';
import 'biometric_authenticator.dart';

/// Bloqueio por PIN/biometria (RF003): só no aplicativo móvel. Na Web usa
/// memória e sem biometria (nunca bloqueia). Nos testes é sobrescrito.
final appLockControllerProvider = Provider<AppLockController>(
  (ref) => kIsWeb
      ? AppLockController(
          AppLockService(InMemorySecureValueStore()),
          const NoBiometric(),
        )
      : AppLockController(
          AppLockService(ref.watch(secureValueStoreProvider)),
          LocalAuthBiometric(),
        ),
);

/// `true` enquanto o app está bloqueado.
final appLockedProvider = StreamProvider<bool>((ref) async* {
  final controller = ref.watch(appLockControllerProvider);
  yield controller.locked;
  yield* controller.changes;
});

/// Texto em português para um PIN recusado.
String pinCheckMessage(PinCheck check) => switch (check) {
  PinOk() => '',
  PinWrong(:final attemptsBeforeDelay) =>
    'PIN incorreto. Restam $attemptsBeforeDelay tentativa(s) antes de uma '
        'espera.',
  PinLocked(:final until) => _lockedMessage(until),
};

String _lockedMessage(DateTime until) {
  final left = until.difference(DateTime.now());
  final text = left.inMinutes >= 1
      ? '${left.inMinutes + (left.inSeconds % 60 > 0 ? 1 : 0)} min'
      : '${left.inSeconds < 1 ? 1 : left.inSeconds} s';
  return 'Muitas tentativas. Tente de novo em $text.';
}
