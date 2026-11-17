import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/app/theme/norte_theme.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_providers.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/login_screen.dart';
import 'package:porquinho/features/auth/session_controller.dart';
import 'package:porquinho/features/auth/widgets/login_hero.dart';

class _Auth implements AuthRepository {
  final _changes = StreamController<AuthUser?>.broadcast();
  final _recovery = StreamController<void>.broadcast();
  @override
  Future<AuthUser?> restoreSession() async => null;
  @override
  Stream<void> get passwordRecovery => _recovery.stream;
  @override
  Stream<AuthUser?> get userChanges => _changes.stream;
  @override
  Future<AuthUser> signInWithEmail(String email, String password) =>
      Completer<AuthUser>().future; // fica carregando
  @override
  Future<AuthUser?> signUpWithEmail(String email, String password) async =>
      null;
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
  @override
  Future<AuthUser> signInWithGoogle() => Completer<AuthUser>().future;
  @override
  Future<void> signOut() async {}
}

class _NoPending implements PendingSyncCounter {
  @override
  Future<int> countPending(String ownerId) async => 0;
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  Brightness brightness = Brightness.dark,
  double keyboard = 0,
  double statusBar = 24,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: statusBar);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final auth = _Auth();
  final session = SessionController(auth, _NoPending());
  await session.start();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionControllerProvider.overrideWithValue(session),
      ],
      child: MaterialApp(
        theme: NorteTheme.light(),
        darkTheme: NorteTheme.dark(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LoginHeroMode _mode(WidgetTester tester) =>
    tester.widget<LoginHero>(find.byType(LoginHero)).layout.mode;

/// O botão está inteiro dentro da tela (depois de rolar até ele, se preciso).
Future<void> _expectReachable(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  final rect = tester.getRect(f);
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final keyboard = tester.view.viewInsets.bottom;
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(screen.height - keyboard + 0.5));
  expect(rect.height, greaterThanOrEqualTo(48));
}

void main() {
  const sizes = {
    'celular pequeno 320x568': Size(320, 568),
    'celular 360x640': Size(360, 640),
    'celular grande 411x914': Size(411, 914),
    'Web 1280x800': Size(1280, 800),
  };

  for (final brightness in Brightness.values) {
    for (final entry in sizes.entries) {
      testWidgets('${entry.key} (${brightness.name}) sem estouro e com '
          'campos e botões alcançáveis', (tester) async {
        await _pump(tester, entry.value, brightness: brightness);
        expect(tester.takeException(), isNull);
        expect(find.text('Bem-vindo ao Norte'), findsOneWidget);
        expect(find.text('Entre na sua conta para continuar.'), findsOneWidget);
        for (final f in [
          find.widgetWithText(TextFormField, 'E-mail'),
          find.widgetWithText(TextFormField, 'Senha'),
          find.widgetWithText(FilledButton, 'Entrar'),
          find.widgetWithText(OutlinedButton, 'Entrar com Google'),
          find.widgetWithText(TextButton, 'Esqueci minha senha'),
          find.widgetWithText(TextButton, 'Criar conta'),
        ]) {
          await _expectReachable(tester, f);
        }
      });
    }
  }

  testWidgets('celular grande mostra a cena completa com slogan', (
    tester,
  ) async {
    await _pump(tester, const Size(411, 914));
    expect(_mode(tester), LoginHeroMode.full);
    expect(find.text('Organize. Equilibre. Evolua.'), findsOneWidget);
    expect(find.textContaining('na direção certa.'), findsOneWidget);
    // Sem rolagem: o botão Entrar já aparece inteiro.
    final entrar = tester.getRect(find.widgetWithText(FilledButton, 'Entrar'));
    expect(entrar.bottom, lessThanOrEqualTo(914));
  });

  for (final size in const [Size(411, 891), Size(411, 914), Size(390, 844)]) {
    testWidgets('marca não encosta no "N" do arco em $size', (tester) async {
      await _pump(tester, size, statusBar: 40);
      expect(_mode(tester), LoginHeroMode.full);
      final scene = tester.getRect(find.byType(Image));
      final arcTop = scene.top + scene.height * 0.665;
      final tagline = tester.getRect(find.text('Organize. Equilibre. Evolua.'));
      expect(tagline.bottom, lessThanOrEqualTo(arcTop - 12));
    });
  }

  testWidgets('tela baixa usa a marca em linha', (tester) async {
    await _pump(tester, const Size(360, 640));
    expect(_mode(tester), isNot(LoginHeroMode.full));
  });

  testWidgets('teclado aberto: cena recolhe e o botão Entrar é alcançável', (
    tester,
  ) async {
    await _pump(tester, const Size(411, 914), keyboard: 330);
    expect(tester.takeException(), isNull);
    expect(_mode(tester), LoginHeroMode.compact);
    await _expectReachable(tester, find.widgetWithText(FilledButton, 'Entrar'));
  });

  testWidgets('mensagens de erro e carregamento não estouram a tela pequena', (
    tester,
  ) async {
    await _pump(tester, const Size(320, 568));
    final forgot = find.widgetWithText(TextButton, 'Esqueci minha senha');
    await tester.ensureVisible(forgot);
    await tester.pumpAndSettle();
    await tester.tap(forgot);
    await tester.pumpAndSettle();
    expect(find.text('Informe seu e-mail para recuperar a senha.'), findsOne);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'a@b.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'x');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Sem resposta, o limite de 15 s libera o botão com aviso de rede.
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('texto grande (acessibilidade) não estoura', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, const Size(360, 740));
    expect(tester.takeException(), isNull);
    await _expectReachable(tester, find.widgetWithText(FilledButton, 'Entrar'));
  });
}
