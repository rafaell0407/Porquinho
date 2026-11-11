@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/local_database_manager.dart';
import 'package:porquinho/core/local_database/stored_database_key_provider.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/drift_pending_sync_counter.dart';
import 'package:porquinho/features/auth/local_owner_binder.dart';
import 'package:porquinho/features/auth/session_controller.dart';

Future<void> _addPending(LocalDatabaseManager m, String owner) async {
  final db = await m.open();
  await db.customStatement(
    'INSERT INTO sync_outbox (owner_id, idempotency_key, entity_type, '
    'entity_id, expected_version, payload_json, state) '
    "VALUES ('$owner', 'k-$owner', 'income', 'e', 1, '{}', 'pending')",
  );
}

void main() {
  late Directory dir;
  late LocalDatabaseManager manager;
  late LocalOwnerBinder binder;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('porquinho_owner');
    manager = LocalDatabaseManager(
      store: InMemorySecureValueStore(),
      path: '${dir.path}/porquinho.db',
    );
    binder = ManagedLocalOwnerBinder(manager);
  });

  tearDown(() async {
    await manager.closeAndWipe();
    await dir.delete(recursive: true);
  });

  test('aparelho novo vincula à primeira conta', () async {
    expect(await binder.bind('u1'), isA<LocalBound>());
    expect(await manager.boundOwner(), 'u1');
  });

  test('mesma conta reabre e mantém os dados (mesmo com pendências)', () async {
    await binder.bind('u1');
    await _addPending(manager, 'u1');
    expect(await binder.bind('u1'), isA<LocalBound>());
    expect(await ManagedPendingSyncCounter(manager).countPending('u1'), 1);
  });

  test('outra conta sem pendências apaga os dados e vincula', () async {
    await binder.bind('u1');
    await manager.open();
    expect(await binder.bind('u2'), isA<LocalBound>());
    expect(await manager.boundOwner(), 'u2');
    expect(await ManagedPendingSyncCounter(manager).countPending('u1'), 0);
  });

  test(
    'outra conta com pendências da anterior é bloqueada sem apagar',
    () async {
      await binder.bind('u1');
      await _addPending(manager, 'u1');
      final result = await binder.bind('u2');
      expect(result, isA<LocalBlockedByPending>());
      expect((result as LocalBlockedByPending).pendingCount, 1);
      expect(await manager.boundOwner(), 'u1');
      expect(await ManagedPendingSyncCounter(manager).countPending('u1'), 1);
    },
  );

  test('sessão: conta bloqueada volta a deslogada com a contagem', () async {
    final auth = _Auth();
    final session = SessionController(
      auth,
      ManagedPendingSyncCounter(manager),
      binder: binder,
    );
    await binder.bind('u1');
    await _addPending(manager, 'u1');
    auth.restored = const AuthUser(id: 'u2', email: 'b@b.com');

    await session.start();

    final state = session.state;
    expect(state, isA<SessionSignedOut>());
    expect((state as SessionSignedOut).blockedPendingCount, 1);
    expect(auth.signOutCalled, isTrue);
    await session.dispose();
  });
}

class _Auth implements AuthRepository {
  AuthUser? restored;
  bool signOutCalled = false;

  @override
  Future<AuthUser?> restoreSession() async => restored;
  @override
  Stream<void> get passwordRecovery => const Stream.empty();
  @override
  Stream<AuthUser?> get userChanges => const Stream.empty();
  @override
  Future<AuthUser> signInWithEmail(String email, String password) async =>
      throw UnimplementedError();
  @override
  Future<AuthUser?> signUpWithEmail(String email, String password) async =>
      null;
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
  @override
  Future<AuthUser> signInWithGoogle() async => throw UnimplementedError();
  @override
  Future<void> signOut() async => signOutCalled = true;
}
