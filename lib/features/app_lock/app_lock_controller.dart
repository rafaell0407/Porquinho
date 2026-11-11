import 'dart:async';

import 'app_lock_service.dart';
import 'biometric_authenticator.dart';

/// Estado do bloqueio ao abrir o app. Só bloqueia na abertura do app do zero
/// (decisão de 10/11/2026), e somente com sessão ativa.
class AppLockController {
  AppLockController(this._service, this._biometric);

  final AppLockService _service;
  final BiometricAuthenticator _biometric;

  final _controller = StreamController<bool>.broadcast();
  bool _locked = false;

  bool get locked => _locked;
  Stream<bool> get changes => _controller.stream;
  AppLockService get service => _service;
  BiometricAuthenticator get biometric => _biometric;

  /// Chamar uma vez, na abertura. Sem sessão não há o que proteger, e uma
  /// configuração sobrando de sessão anterior é descartada.
  Future<void> start({required bool signedIn}) async {
    final enabled = await _service.isEnabled();
    if (enabled && !signedIn) {
      await _service.clear();
      _set(false);
      return;
    }
    _set(enabled);
  }

  Future<PinCheck> unlockWithPin(String pin) async {
    final check = await _service.verifyPin(pin);
    if (check is PinOk) _set(false);
    return check;
  }

  /// `true` se a biometria liberou o app.
  Future<bool> unlockWithBiometric() async {
    if (!await _service.biometricEnabled() || !await _biometric.isAvailable()) {
      return false;
    }
    final ok = await _biometric.authenticate('Desbloquear o Porquinho');
    if (ok) _set(false);
    return ok;
  }

  /// Logout: descarta o PIN junto com os dados locais.
  Future<void> clear() async {
    await _service.clear();
    _set(false);
  }

  void _set(bool value) {
    if (_locked == value) return;
    _locked = value;
    _controller.add(value);
  }
}
