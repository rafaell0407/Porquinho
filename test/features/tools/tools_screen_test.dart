import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:porquinho/app/theme/norte_theme.dart';
import 'package:porquinho/core/data_access.dart';
import 'package:porquinho/features/preferences/preferences_providers.dart';
import 'package:porquinho/features/sync/sync_providers.dart';
import 'package:porquinho/features/sync/sync_status.dart';
import 'package:porquinho/features/tools/models/tool_definition.dart';
import 'package:porquinho/features/tools/models/tool_preferences.dart';
import 'package:porquinho/features/tools/registry/tool_registry.dart';
import 'package:porquinho/features/tools/screens/manage_tools_screen.dart';
import 'package:porquinho/features/tools/screens/tools_screen.dart';

import '../../support/fake_preferences_repository.dart';

/// Ferramentas só de teste (o app não tem ferramentas fictícias): uma com
/// explicação antes do primeiro uso em cada uma de duas categorias e uma em
/// destaque com explicação sob demanda.
ToolDefinition _tool(
  String id,
  String name,
  ToolCategory category, {
  ToolIntroMode intro = ToolIntroMode.onDemand,
  bool featured = false,
}) => ToolDefinition(
  id: id,
  name: name,
  shortDescription: 'Descrição de $name',
  icon: Icons.calculate_outlined,
  category: category,
  route: '/$id',
  introMode: intro,
  featured: featured,
  explanation: ToolExplanation(
    purpose: 'Serve para $name',
    howItWorks: 'Funciona assim',
    assumptions: const ['Premissa um'],
    disclaimer: 'Aviso de $name',
  ),
);

final _registry = ToolRegistry([
  reportsTool,
  _tool(
    'sim_b',
    'Simulador B',
    ToolCategories.planning,
    intro: ToolIntroMode.beforeFirstUse,
  ),
  _tool(
    'calc_c',
    'Calculadora C',
    ToolCategories.investments,
    intro: ToolIntroMode.beforeFirstUse,
  ),
  _tool('destaque', 'Destaque D', ToolCategories.others, featured: true),
]);

class _Probe implements ConnectivityProbe {
  _Probe(this.online);
  final bool online;

  @override
  Future<bool> isOnline() async => online;
}

Future<void> _pump(
  WidgetTester tester,
  FakePreferencesRepository repo, {
  ToolRegistry? registry,
  DataAccessMode mode = DataAccessMode.local,
  bool online = true,
  String initial = '/ferramentas',
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(412, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget opened(String route) =>
      Scaffold(body: Center(child: Text('ABRIU $route')));
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/ferramentas',
        builder: (_, _) => const ToolsScreen(),
        routes: [
          GoRoute(
            path: 'personalizar',
            builder: (_, _) => const ManageToolsScreen(),
          ),
        ],
      ),
      for (final t in (registry ?? _registry).tools)
        GoRoute(path: t.route, builder: (_, _) => opened(t.route)),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesRepositoryProvider.overrideWith((ref) async => repo),
        toolRegistryProvider.overrideWithValue(registry ?? _registry),
        dataAccessModeProvider.overrideWithValue(mode),
        connectivityProbeProvider.overrideWithValue(_Probe(online)),
      ],
      child: MaterialApp.router(
        theme: theme ?? NorteTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  final context = tester.element(find.byType(Navigator).last);
  Navigator.of(context).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('padrão: cabeçalho, busca, destaque, Suas e Outras', (
    tester,
  ) async {
    await _pump(tester, FakePreferencesRepository());
    expect(find.text('Ferramentas'), findsOneWidget);
    expect(
      find.text('Simulações e análises para decisões financeiras melhores.'),
      findsOneWidget,
    );
    expect(_key('ferramentas-personalizar'), findsOneWidget);
    expect(_key('ferramentas-busca'), findsOneWidget);
    expect(_key('destaque-destaque'), findsOneWidget);
    expect(_key('ferramenta-reports'), findsOneWidget);
    expect(_key('ferramenta-adicionar-reports'), findsNothing);
    for (final id in ['sim_b', 'calc_c', 'destaque']) {
      await _scrollTo(tester, _key('ferramenta-adicionar-$id'));
      expect(_key('ferramenta-adicionar-$id'), findsOneWidget);
    }
    // Várias categorias: filtro e grupos aparecem.
    expect(_key('ferramentas-grupo-investments'), findsOneWidget);
    expect(_key('ferramentas-grupo-planning'), findsOneWidget);
  });

  testWidgets('catálogo real: Relatórios em Suas, sem destaque vazio', (
    tester,
  ) async {
    await _pump(
      tester,
      FakePreferencesRepository(),
      registry: norteToolRegistry,
    );
    expect(_key('ferramenta-reports'), findsOneWidget);
    expect(find.text('Em destaque'), findsNothing);
    expect(find.text('Outras ferramentas'), findsNothing);
    expect(_key('ferramentas-categoria-todas'), findsNothing);
  });

  testWidgets('adicionar: aparece em Suas na hora e sai de Outras', (
    tester,
  ) async {
    final repo = FakePreferencesRepository();
    await _pump(tester, repo);
    await _scrollTo(tester, _key('ferramenta-adicionar-calc_c'));
    await tester.tap(_key('ferramenta-adicionar-calc_c'));
    await tester.pumpAndSettle();
    expect(repo.tools_.selected, ['reports', 'calc_c']);
    expect(_key('ferramenta-adicionar-calc_c'), findsNothing);
    expect(
      find.text('Calculadora C está em Suas ferramentas.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      _key('ferramenta-calc_c'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(_key('ferramenta-calc_c'), findsOneWidget);
  });

  testWidgets('busca por nome e busca sem resultado', (tester) async {
    await _pump(tester, FakePreferencesRepository());
    await tester.enterText(_key('ferramentas-busca'), 'calculadora');
    await tester.pumpAndSettle();
    expect(_key('ferramenta-adicionar-calc_c'), findsOneWidget);
    expect(_key('ferramenta-reports'), findsNothing);
    expect(_key('ferramenta-adicionar-sim_b'), findsNothing);

    await tester.enterText(_key('ferramentas-busca'), 'carteira');
    await tester.pumpAndSettle();
    expect(_key('ferramentas-sem-resultado'), findsOneWidget);
    await tester.tap(find.text('Limpar busca'));
    await tester.pumpAndSettle();
    expect(_key('ferramenta-reports'), findsOneWidget);
  });

  testWidgets('filtro por categoria', (tester) async {
    await _pump(tester, FakePreferencesRepository());
    await tester.ensureVisible(_key('ferramentas-categoria-planning'));
    await tester.pumpAndSettle();
    await tester.tap(_key('ferramentas-categoria-planning'));
    await tester.pumpAndSettle();
    expect(_key('ferramenta-adicionar-sim_b'), findsOneWidget);
    expect(_key('ferramenta-adicionar-calc_c'), findsNothing);
    expect(_key('destaque-destaque'), findsNothing);
    expect(_key('ferramenta-reports'), findsNothing);
    await tester.ensureVisible(_key('ferramentas-categoria-todas'));
    await tester.pumpAndSettle();
    await tester.tap(_key('ferramentas-categoria-todas'));
    await tester.pumpAndSettle();
    expect(_key('ferramenta-reports'), findsOneWidget);
  });

  testWidgets('modalidade A: abre direto; informação sob demanda', (
    tester,
  ) async {
    await _pump(tester, FakePreferencesRepository());
    await tester.tap(_key('ferramenta-reports'));
    await tester.pumpAndSettle();
    expect(find.text('ABRIU /relatorios'), findsOneWidget);
    await _back(tester);

    await tester.tap(_key('ferramenta-info-reports'));
    await tester.pumpAndSettle();
    expect(_key('ferramenta-info-sheet-reports'), findsOneWidget);
    expect(find.text('Para que serve'), findsOneWidget);
    expect(find.text('Premissas e limitações'), findsOneWidget);
    expect(_key('ferramenta-aviso-reports'), findsOneWidget);
    await tester.tap(_key('ferramenta-info-abrir-reports'));
    await tester.pumpAndSettle();
    expect(find.text('ABRIU /relatorios'), findsOneWidget);
  });

  testWidgets(
    'modalidade B: explicação antes de abrir; "Não mostrar novamente" por '
    'ferramenta; informação continua disponível',
    (tester) async {
      final repo = FakePreferencesRepository(
        const ToolPreferences(selected: ['sim_b', 'calc_c']),
      );
      await _pump(tester, repo);

      // Fechar sem continuar não abre.
      await tester.tap(_key('ferramenta-sim_b'));
      await tester.pumpAndSettle();
      expect(_key('ferramenta-intro-sim_b'), findsOneWidget);
      expect(find.text('Como funciona'), findsOneWidget);
      expect(_key('ferramenta-aviso-sim_b'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('ABRIU /sim_b'), findsNothing);

      // Continuar sem marcar: abre, e a explicação volta na próxima vez.
      await tester.tap(_key('ferramenta-sim_b'));
      await tester.pumpAndSettle();
      await tester.tap(_key('ferramenta-intro-continuar'));
      await tester.pumpAndSettle();
      expect(find.text('ABRIU /sim_b'), findsOneWidget);
      expect(repo.tools_.dismissedIntros, isEmpty);
      await _back(tester);

      await tester.tap(_key('ferramenta-sim_b'));
      await tester.pumpAndSettle();
      expect(_key('ferramenta-intro-sim_b'), findsOneWidget);
      await tester.tap(_key('ferramenta-intro-nao-mostrar'));
      await tester.pumpAndSettle();
      await tester.tap(_key('ferramenta-intro-continuar'));
      await tester.pumpAndSettle();
      expect(find.text('ABRIU /sim_b'), findsOneWidget);
      expect(repo.tools_.dismissedIntros, {'sim_b'});
      await _back(tester);

      // Agora abre direto…
      await tester.tap(_key('ferramenta-sim_b'));
      await tester.pumpAndSettle();
      expect(_key('ferramenta-intro-sim_b'), findsNothing);
      expect(find.text('ABRIU /sim_b'), findsOneWidget);
      await _back(tester);

      // …mas só ela: a outra ferramenta continua com a explicação.
      await tester.tap(_key('ferramenta-calc_c'));
      await tester.pumpAndSettle();
      expect(_key('ferramenta-intro-calc_c'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      // O ícone de informação mostra a explicação completa e o aviso.
      await tester.tap(_key('ferramenta-info-sim_b'));
      await tester.pumpAndSettle();
      expect(_key('ferramenta-info-sheet-sim_b'), findsOneWidget);
      expect(find.text('Serve para Simulador B'), findsOneWidget);
      expect(find.text('Aviso de Simulador B'), findsOneWidget);
    },
  );

  testWidgets('remover deixa a lista vazia; ferramenta volta para Outras', (
    tester,
  ) async {
    final repo = FakePreferencesRepository();
    await _pump(tester, repo);
    await tester.tap(_key('ferramentas-personalizar'));
    await tester.pumpAndSettle();
    expect(find.text('Personalizar'), findsOneWidget);
    await tester.tap(_key('ferramenta-remover-reports'));
    await tester.pumpAndSettle();
    expect(repo.tools_.selected, isEmpty);
    expect(_key('personalizar-vazio'), findsOneWidget);
    expect(_key('ferramenta-adicionar-reports'), findsOneWidget);
    await _back(tester);
    expect(_key('ferramentas-nenhuma-escolhida'), findsOneWidget);
    await _scrollTo(tester, _key('ferramenta-adicionar-reports'));
    expect(_key('ferramenta-adicionar-reports'), findsOneWidget);
  });

  testWidgets('reordenar arrastando; a ordem fica salva', (tester) async {
    final repo = FakePreferencesRepository(
      const ToolPreferences(selected: ['reports', 'sim_b', 'calc_c']),
    );
    await _pump(tester, repo, initial: '/ferramentas/personalizar');
    final handle = _key('ferramenta-arrastar-reports');
    final start = tester.getCenter(handle);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.tools_.selected!.first, isNot('reports'));
    expect(repo.tools_.selected!.toSet(), {'reports', 'sim_b', 'calc_c'});
    final saved = [...repo.tools_.selected!];

    // Reabrir respeita a ordem.
    await _pump(tester, repo, initial: '/ferramentas/personalizar');
    final ys = [
      for (final id in saved)
        tester.getTopLeft(_key('ferramenta-arrastar-$id')).dy,
    ];
    expect(ys, [...ys]..sort());
  });

  testWidgets('restaurar padrão pede confirmação', (tester) async {
    final repo = FakePreferencesRepository(
      const ToolPreferences(selected: ['calc_c'], dismissedIntros: {'calc_c'}),
    );
    await _pump(tester, repo, initial: '/ferramentas/personalizar');
    await tester.tap(_key('ferramentas-restaurar'));
    await tester.pumpAndSettle();
    expect(find.text('Restaurar padrão?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.tools_.selected, ['calc_c']);

    await tester.tap(_key('ferramentas-restaurar'));
    await tester.pumpAndSettle();
    await tester.tap(_key('ferramentas-restaurar-confirmar'));
    await tester.pumpAndSettle();
    expect(repo.tools_.isDefault, isTrue);
    expect(repo.tools_.dismissedIntros, {'calc_c'});
    expect(_key('ferramenta-remover-reports'), findsOneWidget);
    expect(_key('ferramenta-remover-calc_c'), findsNothing);
    // Já no padrão: botão desabilitado.
    final button = tester.widget<TextButton>(_key('ferramentas-restaurar'));
    expect(button.onPressed, isNull);
  });

  testWidgets('escolhas salvas aparecem ao reabrir', (tester) async {
    final repo = FakePreferencesRepository(
      const ToolPreferences(selected: ['calc_c', 'reports']),
    );
    await _pump(tester, repo);
    expect(
      tester.getTopLeft(_key('ferramenta-calc_c')).dx,
      lessThan(tester.getTopLeft(_key('ferramenta-reports')).dx),
    );
  });

  testWidgets('Web sem conexão não grava e avisa', (tester) async {
    final repo = FakePreferencesRepository();
    await _pump(tester, repo, mode: DataAccessMode.remoteOnly, online: false);
    await _scrollTo(tester, _key('ferramenta-adicionar-calc_c'));
    await tester.tap(_key('ferramenta-adicionar-calc_c'));
    await tester.pumpAndSettle();
    expect(repo.writes, 0);
    expect(find.text(WriteGate.offlineMessage), findsOneWidget);
    expect(_key('ferramenta-adicionar-calc_c'), findsOneWidget);
  });

  testWidgets('tema escuro e tela estreita: uma coluna, sem estouro', (
    tester,
  ) async {
    final repo = FakePreferencesRepository(
      const ToolPreferences(selected: ['reports', 'sim_b']),
    );
    await _pump(tester, repo, theme: NorteTheme.dark());
    // Celular comum: duas colunas lado a lado.
    expect(
      tester.getTopLeft(_key('ferramenta-reports')).dy,
      tester.getTopLeft(_key('ferramenta-sim_b')).dy,
    );
    tester.view.physicalSize = const Size(300, 1600);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(_key('ferramenta-sim_b')).dy,
      greaterThan(tester.getTopLeft(_key('ferramenta-reports')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
