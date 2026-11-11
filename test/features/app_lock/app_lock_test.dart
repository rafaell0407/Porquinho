import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/period_gate_fake.dart';
import 'package:porquinho/app/app.dart';
import 'package:porquinho/core/local_database/stored_database_key_provider.dart';
import 'package:porquinho/features/app_lock/app_lock_controller.dart';
import 'package:porquinho/features/app_lock/app_lock_providers.dart';
import 'package:porquinho/features/app_lock/app_lock_service.dart';
import 'package:porquinho/features/app_lock/biometric_authenticator.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_providers.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/session_controller.dart';

class _Bio implements BiometricAuthenticator {
  _Bio({this.available = true, this.accepts = true});
  bool available;
  bool accepts;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate(String reason) async => accepts;
}

class _Clock {
  DateTime now = DateTime(2026, 11, 10, 12);
  DateTime call() => now;
}

AppLockService _service(InMemorySecureValueStore store, _Clock clock) =>
    AppLockService(store, now: clock.call, iterations: 1000);

void main() {
  late InMemorySecureValueStore store;
  late _Clock clock;
  late AppLockService service;

  setUp(() {
    store = InMemorySecureValueStore();
    clock = _Clock();
    service = _service(store, clock);
  });

  group('AppLockService', () {
    test('PIN só aceita 6 dígitos', () async {
      expect(AppLockService.isValidPin('123456'), isTrue);
      expect(AppLockService.isValidPin('12345'), isFalse);
      expect(AppLockService.isValidPin('12345a'), isFalse);
      await expectLater(
        service.enable('1234', biometric: false),
        throwsArgumentError,
      );
    });

    test('guarda só sal e derivação, nunca o PIN', () async {
      await service.enable('123456', biometric: false);
      final raw = (await store.read(AppLockService.entryName))!;
      expect(raw.contains('123456'), isFalse);
      expect((jsonDecode(raw) as Map)['hash'], isNotEmpty);
    });

    test('PIN correto libera e zera erros; errado conta tentativas', () async {
      await service.enable('123456', biometric: false);
      expect(await service.isEnabled(), isTrue);
      final wrong = await service.verifyPin('000000');
      expect((wrong as PinWrong).attemptsBeforeDelay, 4);
      expect(await service.verifyPin('123456'), isA<PinOk>());
      final again = await service.verifyPin('000000');
      expect((again as PinWrong).attemptsBeforeDelay, 4);
    });

    test('5 erros bloqueiam com espera crescente e nada é apagado', () async {
      await service.enable('123456', biometric: false);
      for (var i = 0; i < 4; i++) {
        expect(await service.verifyPin('000000'), isA<PinWrong>());
      }
      final fifth = await service.verifyPin('000000');
      expect(fifth, isA<PinLocked>());
      expect(
        (fifth as PinLocked).until,
        clock.now.add(AppLockService.delays[0]),
      );

      // Durante a espera nem o PIN certo é aceito.
      expect(await service.verifyPin('123456'), isA<PinLocked>());

      // Passada a espera, o PIN certo volta a funcionar.
      clock.now = clock.now.add(const Duration(seconds: 31));
      expect(await service.verifyPin('123456'), isA<PinOk>());
      expect(await service.isEnabled(), isTrue);
    });

    test('novo erro após a espera aumenta a espera', () async {
      await service.enable('123456', biometric: false);
      for (var i = 0; i < 5; i++) {
        await service.verifyPin('000000');
      }
      clock.now = clock.now.add(const Duration(seconds: 31));
      final sixth = await service.verifyPin('000000');
      expect(
        (sixth as PinLocked).until,
        clock.now.add(AppLockService.delays[1]),
      );
    });

    test('a contagem de erros sobrevive a reabrir o app', () async {
      await service.enable('123456', biometric: false);
      for (var i = 0; i < 5; i++) {
        await service.verifyPin('000000');
      }
      final reopened = _service(store, clock);
      expect(await reopened.verifyPin('123456'), isA<PinLocked>());
    });

    test('alterar e desativar exigem o PIN atual', () async {
      await service.enable('123456', biometric: true);
      expect(await service.changePin('999999', '111111'), isA<PinWrong>());
      expect(await service.changePin('123456', '111111'), isA<PinOk>());
      expect(await service.verifyPin('111111'), isA<PinOk>());
      expect(await service.biometricEnabled(), isTrue);

      expect(await service.disable('000000'), isA<PinWrong>());
      expect(await service.isEnabled(), isTrue);
      expect(await service.disable('111111'), isA<PinOk>());
      expect(await service.isEnabled(), isFalse);
    });

    test('valor corrompido no armazenamento conta como desativado', () async {
      await store.write(AppLockService.entryName, 'não é json');
      expect(await service.isEnabled(), isFalse);
    });
  });

  group('AppLockController', () {
    test('desativado: não bloqueia', () async {
      final c = AppLockController(service, _Bio());
      await c.start(signedIn: true);
      expect(c.locked, isFalse);
    });

    test('ativado e com sessão: abre bloqueado; PIN certo libera', () async {
      await service.enable('123456', biometric: false);
      final c = AppLockController(service, _Bio());
      await c.start(signedIn: true);
      expect(c.locked, isTrue);
      expect(await c.unlockWithPin('000000'), isA<PinWrong>());
      expect(c.locked, isTrue);
      expect(await c.unlockWithPin('123456'), isA<PinOk>());
      expect(c.locked, isFalse);
    });

    test('sem sessão não bloqueia e descarta configuração antiga', () async {
      await service.enable('123456', biometric: false);
      final c = AppLockController(service, _Bio());
      await c.start(signedIn: false);
      expect(c.locked, isFalse);
      expect(await service.isEnabled(), isFalse);
    });

    test('biometria libera só se ativada e disponível', () async {
      await service.enable('123456', biometric: false);
      var c = AppLockController(service, _Bio());
      await c.start(signedIn: true);
      expect(await c.unlockWithBiometric(), isFalse); // não ativada
      expect(c.locked, isTrue);

      await service.setBiometric(true);
      c = AppLockController(service, _Bio(available: false));
      await c.start(signedIn: true);
      expect(await c.unlockWithBiometric(), isFalse); // indisponível

      c = AppLockController(service, _Bio(accepts: false));
      await c.start(signedIn: true);
      expect(await c.unlockWithBiometric(), isFalse); // recusada
      expect(c.locked, isTrue);

      c = AppLockController(service, _Bio());
      await c.start(signedIn: true);
      expect(await c.unlockWithBiometric(), isTrue);
      expect(c.locked, isFalse);
    });

    test('logout (clear) remove o PIN', () async {
      await service.enable('123456', biometric: false);
      final c = AppLockController(service, _Bio());
      await c.start(signedIn: true);
      await c.clear();
      expect(c.locked, isFalse);
      expect(await service.isEnabled(), isFalse);
    });
  });

  group('telas', () {
    Future<AppLockController> pump(
      WidgetTester tester, {
      required bool enabled,
    }) async {
      final auth = _FakeAuth();
      final session = SessionController(auth, _NoPending());
      await session.start();
      final lock = AppLockController(service, _Bio(available: false));
      await tester.runAsync(() async {
        if (enabled) await service.enable('123456', biometric: false);
        await lock.start(signedIn: true);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            sessionControllerProvider.overrideWithValue(session),
            ...readyFinanceOverrides(),
            appLockControllerProvider.overrideWithValue(lock),
          ],
          child: const PorquinhoApp(),
        ),
      );
      await tester.pumpAndSettle();
      return lock;
    }

    testWidgets('com bloqueio ativo mostra a tela de PIN e libera', (
      tester,
    ) async {
      await pump(tester, enabled: true);
      expect(find.text('Digite seu PIN para continuar.'), findsOneWidget);
      expect(find.text('Sobra do período'), findsNothing);

      await tester.runAsync(() async {
        await tester.enterText(find.byType(TextField), '000000');
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('PIN incorreto'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.enterText(find.byType(TextField), '123456');
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text('Sobra do período'), findsOneWidget);
    });

    testWidgets('Esqueci o PIN sai da conta e volta ao login', (tester) async {
      await pump(tester, enabled: true);
      await tester.tap(find.text('Esqueci o PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Sair da conta'), findsOneWidget);
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      expect(find.text('Digite seu PIN para continuar.'), findsNothing);
      expect(find.text('Sobra do período'), findsNothing);
    });

    testWidgets('sem bloqueio vai direto ao marcador', (tester) async {
      await pump(tester, enabled: false);
      expect(find.text('Sobra do período'), findsOneWidget);
    });
  });
}

const _user = AuthUser(id: 'u1', email: 'a@b.com');

class _NoPending implements PendingSyncCounter {
  @override
  Future<int> countPending(String ownerId) async => 0;
}

class _FakeAuth implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => _user;
  @override
  Stream<void> get passwordRecovery => const Stream.empty();
  @override
  Stream<AuthUser?> get userChanges => const Stream.empty();
  @override
  Future<AuthUser> signInWithEmail(String email, String password) async =>
      _user;
  @override
  Future<AuthUser?> signUpWithEmail(String email, String password) async =>
      null;
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
  @override
  Future<AuthUser> signInWithGoogle() async => _user;
  @override
  Future<void> signOut() async {}
}
