import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/app/app.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_providers.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/delete_account_flow.dart';
import 'package:porquinho/features/auth/session_controller.dart';

import '../../support/period_gate_fake.dart';

const _user = AuthUser(id: 'u1', email: 'a@b.com');

class _Auth implements AuthRepository {
  bool signedOut = false;
  bool failSignOut = false;
  final changes = StreamController<AuthUser?>.broadcast();
  @override
  Future<AuthUser?> restoreSession() async => _user;
  @override
  Stream<void> get passwordRecovery => const Stream.empty();
  @override
  Stream<AuthUser?> get userChanges => changes.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
  @override
  Future<void> signOut() async {
    signedOut = true;
    if (failSignOut) throw StateError('sessão já inexistente');
  }
}

class _Pending implements PendingSyncCounter {
  _Pending(this.count);
  final int count;
  @override
  Future<int> countPending(String ownerId) async => count;
}

Future<_Auth> _pump(
  WidgetTester tester, {
  int pending = 0,
  required Future<void> Function() rpc,
  bool failSignOut = false,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = _Auth()..failSignOut = failSignOut;
  final session = SessionController(auth, _Pending(pending));
  await session.start();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionControllerProvider.overrideWithValue(session),
        deleteAccountRpcProvider.overrideWithValue(rpc),
        ...readyFinanceOverrides(),
      ],
      child: const PorquinhoApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mais'));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _startDeletion(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('mais-excluir-conta')));
  await tester.tap(find.byKey(const Key('mais-excluir-conta')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('com pendências a exclusão é recusada e nada é chamado', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, pending: 3, rpc: () async => calls++);
    await _startDeletion(tester);
    expect(find.textContaining('3 operação(ões)'), findsOneWidget);
    expect(find.text('Excluir a conta?'), findsNothing);
    expect(calls, 0);
  });

  testWidgets('cancelar na primeira confirmação não apaga nada', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, rpc: () async => calls++);
    await _startDeletion(tester);
    expect(find.textContaining('não pode ser desfeita'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('segunda confirmação exige digitar EXCLUIR', (tester) async {
    var calls = 0;
    await _pump(tester, rpc: () async => calls++);
    await _startDeletion(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('excluir-conta-confirmar'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('excluir-conta-campo')), 'sim');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(calls, 0);
  });

  testWidgets('confirmada: exclui no servidor e volta ao login', (
    tester,
  ) async {
    var calls = 0;
    final auth = await _pump(
      tester,
      rpc: () async => calls++,
      failSignOut: true, // sessão remota já não existe: não pode travar
    );
    await _startDeletion(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('excluir-conta-campo')),
      'excluir',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('excluir-conta-confirmar')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(auth.signedOut, isTrue);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('falha no servidor mantém a conta e a sessão', (tester) async {
    await _pump(tester, rpc: () async => throw Exception('sem rede'));
    await _startDeletion(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('excluir-conta-campo')),
      'EXCLUIR',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('excluir-conta-confirmar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nada foi apagado'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsNothing);
  });
}
