import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/period_gate_fake.dart';
import 'package:porquinho/app/app.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_providers.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/session_controller.dart';

const _user = AuthUser(id: 'u1', email: 'a@b.com');

class _FakeAuth implements AuthRepository {
  AuthUser? restored;
  AuthFailureCode? failWith;
  bool resetSent = false;
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
    if (failWith != null) throw AuthFailure(failWith!);
    return _user;
  }

  @override
  Future<AuthUser?> signUpWithEmail(String email, String password) async =>
      null;
  @override
  Future<void> sendPasswordReset(String email) async => resetSent = true;
  @override
  Future<void> updatePassword(String newPassword) async {}
  @override
  Future<AuthUser> signInWithGoogle() async => _user;
  @override
  Future<void> signOut() async {}
}

class _Pending implements PendingSyncCounter {
  _Pending(this.count);
  final int count;
  @override
  Future<int> countPending(String ownerId) async => count;
}

Future<_FakeAuth> _pump(
  WidgetTester tester, {
  AuthUser? restored,
  int pending = 0,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = _FakeAuth()..restored = restored;
  final session = SessionController(auth, _Pending(pending));
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
  return auth;
}

Future<void> _fill(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), password);
}

void main() {
  testWidgets('sem sessão mostra o login', (tester) async {
    await _pump(tester);
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.text('Dinheiro livre do período'), findsNothing);
  });

  testWidgets('com sessão restaurada vai direto ao marcador', (tester) async {
    await _pump(tester, restored: _user);
    expect(find.text('Dinheiro livre do período'), findsOneWidget);
  });

  testWidgets('valida e-mail e senha vazios', (tester) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
  });

  testWidgets('login correto abre a área logada', (tester) async {
    await _pump(tester);
    await _fill(tester, 'a@b.com', 'qualquer');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Dinheiro livre do período'), findsOneWidget);
  });

  testWidgets('senha incorreta mostra mensagem em português', (tester) async {
    final auth = await _pump(tester);
    auth.failWith = AuthFailureCode.invalidCredentials;
    await _fill(tester, 'a@b.com', 'errada');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.text('Dinheiro livre do período'), findsNothing);
  });

  testWidgets('criar conta pede confirmação de e-mail', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Não tenho conta. Criar conta'));
    await tester.pumpAndSettle();
    await _fill(tester, 'novo@b.com', 'senha-segura-123');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enviamos um e-mail de confirmação'), findsOne);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('esqueci a senha exige e-mail e envia o pedido', (tester) async {
    final auth = await _pump(tester);
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    expect(
      find.text('Informe seu e-mail para recuperar a senha.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'a@b.com',
    );
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    expect(auth.resetSent, isTrue);
  });

  testWidgets('sair com pendências avisa; cancelar mantém a sessão', (
    tester,
  ) async {
    await _pump(tester, restored: _user, pending: 2);
    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 operação(ões)'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar com Google'), findsNothing);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('sair mesmo assim descarta as pendências e volta ao login', (
    tester,
  ) async {
    await _pump(tester, restored: _user, pending: 2);
    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair mesmo assim'));
    await tester.pumpAndSettle();
    expect(find.text('Dinheiro livre do período'), findsNothing);
  });

  testWidgets('link de recuperação abre a tela de nova senha', (tester) async {
    final auth = await _pump(tester, restored: _user);
    auth.recovery.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Escolha a nova senha da sua conta.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nova senha'),
      'abc123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repita a nova senha'),
      'diferente',
    );
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pumpAndSettle();
    expect(find.text('As senhas não são iguais.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repita a nova senha'),
      'abc123',
    );
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pumpAndSettle();
    expect(find.text('Dinheiro livre do período'), findsOneWidget);
  });

  testWidgets('sair sem pendências volta ao login', (tester) async {
    await _pump(tester, restored: _user);
    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar com Google'), findsOneWidget);
  });
}
