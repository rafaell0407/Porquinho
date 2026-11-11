import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/period_gate_fake.dart';
import 'package:porquinho/app/app.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_providers.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/session_controller.dart';

const _user = AuthUser(id: 'u1', email: 'a@b.com');

class _Auth implements AuthRepository {
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

class _NoPending implements PendingSyncCounter {
  @override
  Future<int> countPending(String ownerId) async => 0;
}

void main() {
  testWidgets('três abas: Dashboard, Lançamentos e Mais', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _Auth();
    final session = SessionController(auth, _NoPending());
    await session.start();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sessionControllerProvider.overrideWithValue(session),
          ...readyFinanceOverrides(),
        ],
        child: const PorquinhoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Dinheiro livre do período'), findsOneWidget);

    await tester.tap(find.text('Lançamentos'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum lançamento neste período.'), findsOneWidget);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Itens que precisam de atenção'), findsOneWidget);
    expect(find.text('Segurança'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Dinheiro livre do período'), findsOneWidget);
  });
}
