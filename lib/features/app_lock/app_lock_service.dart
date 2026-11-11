import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/local_database/stored_database_key_provider.dart';

/// PBKDF2-HMAC-SHA256. O PIN nunca é guardado em texto: só sal + derivação.
Uint8List derivePinHash(String pin, Uint8List salt, int iterations) {
  final hmac = Hmac(sha256, utf8.encode(pin));
  final block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  var u = block;
  final result = List<int>.of(block);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= u[j];
    }
  }
  return Uint8List.fromList(result);
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Resultado da conferência de um PIN.
sealed class PinCheck {
  const PinCheck();
}

class PinOk extends PinCheck {
  const PinOk();
}

/// PIN incorreto; [attemptsBeforeDelay] tentativas restam antes da espera.
class PinWrong extends PinCheck {
  const PinWrong(this.attemptsBeforeDelay);

  final int attemptsBeforeDelay;
}

/// Tentativas bloqueadas até [until]; o PIN nem foi conferido.
class PinLocked extends PinCheck {
  const PinLocked(this.until);

  final DateTime until;
}

/// Configuração do bloqueio do app (RF003): PIN de 6 dígitos e biometria
/// opcional como atalho. Guardado no armazenamento seguro do aparelho.
///
/// Após [freeAttempts] erros seguidos, cada novo erro exige uma espera maior
/// (30 s, 1 min, 5 min, 15 min, 1 h). Nada é apagado por errar o PIN.
class AppLockService {
  AppLockService(
    this._store, {
    DateTime Function()? now,
    Random? random,
    this.iterations = 100000,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  static const entryName = 'porquinho.app_lock';
  static const pinLength = 6;
  static const freeAttempts = 5;
  static const delays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
  ];

  final SecureValueStore _store;
  final DateTime Function() _now;
  final Random _random;
  final int iterations;

  static bool isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  Future<Map<String, dynamic>?> _load() async {
    final raw = await _store.read(entryName);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> _save(Map<String, dynamic> data) =>
      _store.write(entryName, jsonEncode(data));

  Future<bool> isEnabled() async => (await _load()) != null;

  Future<bool> biometricEnabled() async =>
      (await _load())?['biometric'] == true;

  Future<void> setBiometric(bool enabled) async {
    final data = await _load();
    if (data == null) return;
    await _save({...data, 'biometric': enabled});
  }

  Future<void> enable(String pin, {required bool biometric}) async {
    if (!isValidPin(pin)) throw ArgumentError('O PIN deve ter 6 dígitos.');
    await _save(_newRecord(pin, biometric: biometric));
  }

  Map<String, dynamic> _newRecord(String pin, {required bool biometric}) {
    final salt = Uint8List.fromList(
      List.generate(16, (_) => _random.nextInt(256)),
    );
    return {
      'salt': base64Encode(salt),
      'hash': base64Encode(derivePinHash(pin, salt, iterations)),
      'iterations': iterations,
      'failed': 0,
      'lockedUntil': 0,
      'biometric': biometric,
    };
  }

  /// Confere o PIN, contando erros e aplicando a espera crescente.
  Future<PinCheck> verifyPin(String pin) async {
    final data = await _load();
    if (data == null) return const PinOk();
    final now = _now();
    final until = DateTime.fromMillisecondsSinceEpoch(
      data['lockedUntil'] as int,
    );
    if (until.isAfter(now)) return PinLocked(until);

    final salt = base64Decode(data['salt'] as String);
    final expected = base64Decode(data['hash'] as String);
    final actual = derivePinHash(pin, salt, data['iterations'] as int);
    if (_constantTimeEquals(expected, actual)) {
      await _save({...data, 'failed': 0, 'lockedUntil': 0});
      return const PinOk();
    }

    final failed = (data['failed'] as int) + 1;
    var lockedUntil = 0;
    if (failed >= freeAttempts) {
      final step = min(failed - freeAttempts, delays.length - 1);
      lockedUntil = now.add(delays[step]).millisecondsSinceEpoch;
    }
    await _save({...data, 'failed': failed, 'lockedUntil': lockedUntil});
    if (lockedUntil > 0) {
      return PinLocked(DateTime.fromMillisecondsSinceEpoch(lockedUntil));
    }
    return PinWrong(freeAttempts - failed);
  }

  /// Troca o PIN exigindo o atual. Devolve a conferência do PIN atual.
  Future<PinCheck> changePin(String currentPin, String newPin) async {
    if (!isValidPin(newPin)) throw ArgumentError('O PIN deve ter 6 dígitos.');
    final check = await verifyPin(currentPin);
    if (check is! PinOk) return check;
    final data = await _load();
    await _save(_newRecord(newPin, biometric: data?['biometric'] == true));
    return const PinOk();
  }

  /// Desativa o bloqueio exigindo o PIN.
  Future<PinCheck> disable(String pin) async {
    final check = await verifyPin(pin);
    if (check is PinOk) await _store.delete(entryName);
    return check;
  }

  /// Remove a configuração sem pedir PIN (logout: os dados locais são apagados).
  Future<void> clear() => _store.delete(entryName);
}
