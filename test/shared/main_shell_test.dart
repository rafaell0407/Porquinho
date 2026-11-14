import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../support/fake_preferences_repository.dart';
import '../support/period_gate_fake.dart';
import 'package:porquinho/app/app.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_providers.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/session_controller.dart';
import 'package:porquinho/features/preferences/preferences_providers.dart';
import 'package:porquinho/features/reports/reports_screen.dart';
import 'package:porquinho/shared/main_shell.dart';

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
  testWidgets('barra: Home, Ferramentas, Adicionar, Lançamentos e Mais', (
    tester,
  ) async {
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
          preferencesRepositoryProvider.overrideWith(
            (ref) async => FakePreferencesRepository(),
          ),
        ],
        child: const PorquinhoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav-home')), findsOneWidget);
    expect(find.byKey(const Key('nav-ferramentas')), findsOneWidget);
    expect(find.byKey(const Key('nav-relatorios')), findsNothing);
    expect(find.byKey(const Key('nav-adicionar')), findsOneWidget);
    expect(find.byKey(const Key('nav-lancamentos')), findsOneWidget);
    expect(find.byKey(const Key('nav-mais')), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Dinheiro livre do período'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-adicionar')));
    await tester.pumpAndSettle();
    expect(find.text('O que você quer registrar?'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Relatórios'), findsNothing); // não está mais em Mais

    // Ferramentas: aba de verdade, selecionada; Relatórios é uma ferramenta.
    await tester.tap(find.byKey(const Key('nav-ferramentas')));
    await tester.pumpAndSettle();
    expect(
      find.text('Simulações e análises para decisões financeiras melhores.'),
      findsOneWidget,
    );
    expect(
      tester.widget<NorteNavBar>(find.byType(NorteNavBar)).currentIndex,
      1,
    );

    await tester.tap(find.byKey(const Key('ferramenta-reports')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
    // Na tela de relatórios, a barra continua com Ferramentas selecionada.
    final bar = tester.widget<NorteNavBar>(
      find.descendant(
        of: find.byType(ReportsScreen),
        matching: find.byType(NorteNavBar),
      ),
    );
    expect(bar.currentIndex, 1);

    // A rota antiga continua abrindo os relatórios.
    await tester.tap(
      find.descendant(
        of: find.byType(ReportsScreen),
        matching: find.byKey(const Key('nav-home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dinheiro livre do período'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(MainShell))).push('/relatorios');
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
  });
}
