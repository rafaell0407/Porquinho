import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/session_controller.dart';
import 'package:porquinho/features/sync/sync_scheduler.dart';

const _user = AuthUser(id: 'u1', email: 'a@b.com');

class _Auth implements AuthRepository {
  _Auth(this.restored);
  final AuthUser? restored;
  final changes = StreamController<AuthUser?>.broadcast();
  @override
  Future<AuthUser?> restoreSession() async => restored;
  @override
  Stream<void> get passwordRecovery => const Stream.empty();
  @override
  Stream<AuthUser?> get userChanges => changes.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _None implements PendingSyncCounter {
  @override
  Future<int> countPending(String ownerId) async => 0;
}

void main() {
  test('sincroniza ao entrar, não roda em paralelo e ignora erros', () async {
    final session = SessionController(_Auth(_user), _None());
    await session.start();
    final calls = <String>[];
    final gate = Completer<void>();
    final scheduler = SyncScheduler(session, (id) async {
      calls.add(id);
      await gate.future;
      throw StateError('falha qualquer');
    }, interval: const Duration(hours: 1))..start();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['u1']);

    scheduler.onResume(); // já em andamento: ignorado
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 1);

    gate.complete();
    await Future<void>.delayed(Duration.zero);
    await scheduler.tick(); // erro engolido; roda de novo
    expect(calls.length, 2);
    await scheduler.dispose();
    await session.dispose();
  });

  test('sem sessão não sincroniza', () async {
    final session = SessionController(_Auth(null), _None());
    await session.start();
    var calls = 0;
    final scheduler = SyncScheduler(session, (_) async => calls++)..start();
    await scheduler.tick();
    expect(calls, 0);
    await scheduler.dispose();
    await session.dispose();
  });
}
