@TestOn('vm')
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/drift_pending_sync_counter.dart';
import 'package:porquinho/features/auth/session_controller.dart';

const _user = AuthUser(id: 'u1', email: 'a@b.com');

class FakeAuth implements AuthRepository {
  AuthUser? restored;
  bool signOutCalled = false;
  final changes = StreamController<AuthUser?>.broadcast();

  @override
  Future<AuthUser?> restoreSession() async => restored;
  final recovery = StreamController<void>.broadcast();
  @override
  Stream<void> get passwordRecovery => recovery.stream;
  @override
  Stream<AuthUser?> get userChanges => changes.stream;
  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    if (password != 'ok') {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
    return _user;
  }

  @override
  Future<AuthUser?> signUpWithEmail(String email, String password) async =>
      null;
  @override
  Future<void> sendPasswordReset(String email) async {}
  String? newPassword;
  @override
  Future<void> updatePassword(String newPassword) async =>
      this.newPassword = newPassword;
  @override
  Future<AuthUser> signInWithGoogle() async => _user;
  @override
  Future<void> signOut() async => signOutCalled = true;
}

class FakePending implements PendingSyncCounter {
  FakePending(this.count);
  int count;
  @override
  Future<int> countPending(String ownerId) async => count;
}

void main() {
  late FakeAuth auth;

  setUp(() => auth = FakeAuth());

  test('restaura sessão existente', () async {
    auth.restored = _user;
    final c = SessionController(auth, FakePending(0));
    await c.start();
    expect(c.state, isA<SessionSignedIn>());
    await c.dispose();
  });

  test('sem sessão fica deslogado; login com senha errada falha', () async {
    final c = SessionController(auth, FakePending(0));
    await c.start();
    expect(c.state, isA<SessionSignedOut>());
    await expectLater(
      c.signInWithEmail('a@b.com', 'x'),
      throwsA(isA<AuthFailure>()),
    );
    expect(c.state, isA<SessionSignedOut>());
    await c.dispose();
  });

  test('perda de sessão pelo backend desloga', () async {
    auth.restored = _user;
    final c = SessionController(auth, FakePending(0));
    await c.start();
    auth.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(c.state, isA<SessionSignedOut>());
    await c.dispose();
  });

  test(
    'logout bloqueado com pendências: nada é encerrado nem apagado',
    () async {
      auth.restored = _user;
      var cleaned = false;
      final c = SessionController(
        auth,
        FakePending(3),
        onSignedOut: (_) async => cleaned = true,
      );
      await c.start();
      final r = await c.signOut();
      expect(r, isA<LogoutBlockedByPending>());
      expect((r as LogoutBlockedByPending).pendingCount, 3);
      expect(auth.signOutCalled, isFalse);
      expect(cleaned, isFalse);
      expect(c.state, isA<SessionSignedIn>());
      await c.dispose();
    },
  );

  test('logout sem pendências encerra e executa a limpeza', () async {
    auth.restored = _user;
    String? cleanedOwner;
    final c = SessionController(
      auth,
      FakePending(0),
      onSignedOut: (id) async => cleanedOwner = id,
    );
    await c.start();
    expect(await c.signOut(), isA<LogoutDone>());
    expect(auth.signOutCalled, isTrue);
    expect(cleanedOwner, 'u1');
    expect(c.state, isA<SessionSignedOut>());
    await c.dispose();
  });

  test(
    'link de recuperação leva à nova senha e depois à área logada',
    () async {
      auth.restored = null;
      final c = SessionController(auth, FakePending(0));
      await c.start();
      final seen = <SessionState>[];
      c.states.listen(seen.add);

      auth.changes.add(_user);
      auth.recovery.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.state, isA<SessionPasswordRecovery>());

      auth.changes.add(_user); // evento repetido não tira da recuperação
      await Future<void>.delayed(Duration.zero);
      expect(c.state, isA<SessionPasswordRecovery>());

      await c.completePasswordRecovery('nova-senha');
      expect(auth.newPassword, 'nova-senha');
      expect(c.state, isA<SessionSignedIn>());
      await c.dispose();
    },
  );

  test('recuperação anunciada antes do usuário também é respeitada', () async {
    final c = SessionController(auth, FakePending(0));
    await c.start();
    auth.recovery.add(null);
    await Future<void>.delayed(Duration.zero);
    auth.changes.add(_user);
    await Future<void>.delayed(Duration.zero);
    expect(c.state, isA<SessionPasswordRecovery>());
    await c.dispose();
  });

  test('logout tenta sincronizar antes e sai se a fila esvaziar', () async {
    auth.restored = _user;
    final pending = FakePending(2);
    var flushed = 0;
    final c = SessionController(
      auth,
      pending,
      flushPending: (_) async {
        flushed++;
        pending.count = 0;
      },
    );
    await c.start();
    expect(await c.signOut(), isA<LogoutDone>());
    expect(flushed, 1);
    expect(auth.signOutCalled, isTrue);
    await c.dispose();
  });

  test(
    'falha ao sincronizar mantém o bloqueio; descartar sai e limpa',
    () async {
      auth.restored = _user;
      var wiped = false;
      final c = SessionController(
        auth,
        FakePending(3),
        flushPending: (_) async => throw StateError('sem rede'),
        onSignedOut: (_) async => wiped = true,
      );
      await c.start();
      final blocked = await c.signOut();
      expect(blocked, isA<LogoutBlockedByPending>());
      expect((blocked as LogoutBlockedByPending).pendingCount, 3);
      expect(auth.signOutCalled, isFalse);
      expect(wiped, isFalse);

      expect(await c.signOut(discardPending: true), isA<LogoutDone>());
      expect(auth.signOutCalled, isTrue);
      expect(wiped, isTrue);
      expect(c.state, isA<SessionSignedOut>());
      await c.dispose();
    },
  );

  group('DriftPendingSyncCounter', () {
    late PorquinhoDatabase db;
    setUp(() => db = PorquinhoDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('conta outbox do próprio usuário apenas', () async {
      Future<void> add(String owner, String key) => db.customStatement(
        'INSERT INTO sync_outbox (owner_id, idempotency_key, entity_type, '
        "entity_id, expected_version, payload_json, state) "
        "VALUES (?, ?, 'income', 'e', 1, '{}', 'queued')",
        [owner, key],
      );
      final counter = DriftPendingSyncCounter(db);
      expect(await counter.countPending('u1'), 0);
      await add('u1', 'k1');
      await add('u1', 'k2');
      await add('u2', 'k3');
      expect(await counter.countPending('u1'), 2);
      expect(await counter.countPending('u2'), 1);
    });
  });
}
