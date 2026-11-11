import 'package:local_auth/local_auth.dart';

/// Biometria do aparelho. O PIN continua sendo a alternativa sempre disponível.
abstract interface class BiometricAuthenticator {
  Future<bool> isAvailable();

  /// `true` só se o usuário se autenticou; qualquer falha ou cancelamento
  /// devolve `false` (o usuário usa o PIN).
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometric implements BiometricAuthenticator {
  LocalAuthBiometric([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      final enrolled = await _auth.getAvailableBiometrics();
      return await _auth.canCheckBiometrics && enrolled.isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on Object {
      return false;
    }
  }
}

/// Aparelho sem biometria (Web, testes).
class NoBiometric implements BiometricAuthenticator {
  const NoBiometric();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
