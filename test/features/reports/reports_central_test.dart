@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:porquinho/app/theme/norte_theme.dart';
import 'package:porquinho/core/data_access.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_providers.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/investments/investment_models.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/local_investment_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_providers.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/preferences/preferences_providers.dart';
import 'package:porquinho/features/reports/models/report_preferences.dart';
import 'package:porquinho/features/reports/report_routes.dart';
import 'package:porquinho/features/reports/reports_providers.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/reports/widgets/report_parts.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/periods/period_navigation.dart';
import 'package:porquinho/features/sync/sync_providers.dart';
import 'package:porquinho/features/sync/sync_status.dart';
import 'package:porquinho/features/tools/models/tool_preferences.dart';
import 'package:porquinho/shared/main_shell.dart' show NorteNavBar;

import '../../support/fake_preferences_repository.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

const _all = [
  'income_by_category',
  'expense_by_category',
  'investments_total',
  'free_money_evolution',
  'period_comparison',
];

/// Falha só na leitura da sequência (relatórios 3–5).
class _FailingSeries implements ReportsRepository {
  _FailingSeries(this._inner);
  final ReportsRepository _inner;
  bool fail = true;

  @override
  Future<PeriodReport> report(List<PeriodRange> ranges) async {
    if (fail && ranges.length > 1) throw StateError('falha');
    return _inner.report(ranges);
  }
}

class _Probe implements ConnectivityProbe {
  _Probe(this.online);
  final bool online;

  @override
  Future<bool> isOnline() async => online;
}

Finder _key(String k) => find.byKey(Key(k));

void main() {
  late PorquinhoDatabase db;
  late PeriodService periods;
  late EntryService entries;
  late InvestmentService investments;
  late CategoryService categories;
  late FakePreferencesRepository prefs;
  late GoRouter router;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    final recorder = LocalChangeRecorder(db, newId: () => 'a${++ids}');
    periods = PeriodService(LocalPeriodRepository(db, 'u1', recorder));
    final catRepo = LocalCategoryRepository(db, 'u1', recorder);
    categories = CategoryService(catRepo, newId: () => 'c${++ids}');
    entries = EntryService(
      LocalEntryRepository(db, 'u1', recorder),
      catRepo,
      newId: () => 'e${++ids}',
    );
    investments = InvestmentService(
      LocalInvestmentRepository(db, 'u1', recorder),
      newId: () => 'i${++ids}',
    );
    await periods.setup(PeriodConfig.calendarMonth());
    prefs = FakePreferencesRepository(
      ToolPreferences.empty,
      const ReportPreferences(setup: ReportSetupStatus.done),
    );
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    String initial = '/relatorios',
    Size size = const Size(412, 2400),
    ThemeData? theme,
    DataAccessMode mode = DataAccessMode.local,
    bool online = true,
    ReportsRepository? reports,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: initial,
      routes: [
        reportsRoute(),
        GoRoute(
          path: '/ferramentas',
          builder: (_, _) => const Scaffold(body: Text('FERRAMENTAS')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userClockProvider.overrideWithValue(
            UserClock(now: () => DateTime.utc(2026, 11, 10, 15)),
          ),
          periodServiceProvider.overrideWith((ref) async => periods),
          categoryServiceProvider.overrideWith((ref) async => categories),
          reportsRepositoryProvider.overrideWith(
            (ref) async => reports ?? LocalReportsRepository(db, 'u1'),
          ),
          preferencesRepositoryProvider.overrideWith((ref) async => prefs),
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

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(_key(key)).data!;

  Future<String> category(CategoryKind kind, String name) async {
    await categories.createCategory(kind, name);
    return (await categories.load()).categories
        .firstWhere((x) => x.name == name)
        .id;
  }

  Future<void> add(
    EntryKind kind,
    int cents,
    CalendarDate date, [
    String? cat,
  ]) => entries.create(
    EntryDraft(kind: kind, amount: c(cents), date: date, categoryId: cat),
  );

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(_key(key));
    await tester.tap(_key(key));
    await tester.pumpAndSettle();
  }

  group('configuração guiada (RL5)', () {
    testWidgets('primeiro acesso: os cinco marcados, na ordem do RF025', (
      tester,
    ) async {
      prefs.reports_ = ReportPreferences.empty;
      await pump(tester);
      expect(_key('configuracao-relatorios'), findsOneWidget);
      final tops = [
        for (final id in _all) tester.getTopLeft(_key('configuracao-$id')).dy,
      ];
      expect([...tops]..sort(), tops);
      for (final id in _all) {
        expect(
          tester
              .widget<Checkbox>(
                find.descendant(
                  of: _key('configuracao-$id'),
                  matching: find.byType(Checkbox),
                ),
              )
              .value,
          isTrue,
        );
      }
      expect(
        find.text('Você pode mudar isso depois em Personalizar.'),
        findsOneWidget,
      );
      // Sem prévia: nenhum valor de relatório na configuração.
      expect(find.textContaining('R\$'), findsNothing);
    });

    testWidgets('Concluir exige ao menos um; grava a escolha na ordem', (
      tester,
    ) async {
      prefs.reports_ = ReportPreferences.empty;
      await pump(tester);
      for (final id in _all) {
        await tap(tester, 'configuracao-$id');
      }
      expect(_key('configuracao-aviso'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_key('configuracao-concluir')).onPressed,
        isNull,
      );
      await tap(tester, 'configuracao-period_comparison');
      await tap(tester, 'configuracao-income_by_category');
      expect(_key('configuracao-aviso'), findsNothing);
      await tap(tester, 'configuracao-concluir');
      expect(prefs.reports_.setup, ReportSetupStatus.done);
      expect(prefs.reports_.selected, [
        'income_by_category',
        'period_comparison',
      ]);
      expect(_key('relatorio-card-income_by_category'), findsOneWidget);
      expect(_key('relatorio-card-period_comparison'), findsOneWidget);
      expect(_key('relatorio-card-investments_total'), findsNothing);
    });

    testWidgets('os cinco marcados: continua a lista sugerida', (tester) async {
      prefs.reports_ = ReportPreferences.empty;
      await pump(tester);
      await tap(tester, 'configuracao-concluir');
      expect(prefs.reports_.setup, ReportSetupStatus.done);
      expect(prefs.reports_.isSuggested, isTrue);
      expect(prefs.writes, 1);
    });

    testWidgets('Pular: marca como pulada e mostra a lista sugerida', (
      tester,
    ) async {
      prefs.reports_ = ReportPreferences.empty;
      await pump(tester);
      await tap(tester, 'configuracao-investments_total');
      await tap(tester, 'configuracao-pular');
      expect(prefs.reports_.setup, ReportSetupStatus.skipped);
      expect(prefs.reports_.isSuggested, isTrue);
      for (final id in _all) {
        expect(_key('relatorio-card-$id'), findsOneWidget);
      }
    });

    testWidgets('quem já fez não vê de novo', (tester) async {
      await pump(tester);
      expect(_key('configuracao-relatorios'), findsNothing);
      expect(find.text('Meus relatórios'), findsOneWidget);
    });

    testWidgets('Web sem conexão: não grava e avisa', (tester) async {
      prefs.reports_ = ReportPreferences.empty;
      await pump(tester, mode: DataAccessMode.remoteOnly, online: false);
      await tap(tester, 'configuracao-concluir');
      expect(prefs.writes, 0);
      expect(_key('configuracao-relatorios'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Meus relatórios e níveis (RL3/RL4)', () {
    testWidgets('cartões compactos com os valores do período', (tester) async {
      final salary = await category(CategoryKind.income, 'Salário');
      final extra = await category(CategoryKind.income, 'Renda extra');
      await add(EntryKind.income, 300000, d(2026, 11, 1), salary);
      await add(EntryKind.income, 100000, d(2026, 11, 2), extra);
      await add(EntryKind.income, 100000, d(2026, 10, 5));
      await add(EntryKind.expense, 120000, d(2026, 11, 3));
      await investments.create(
        InvestmentDraft(amount: c(30000), date: d(2026, 11, 4)),
      );
      await pump(tester);
      // Período selecionado no topo, igual à Home.
      expect(_key('periodo-atual'), findsOneWidget);
      expect(text(tester, 'income_by_category-total'), 'R\$ 4.000,00');
      expect(
        text(tester, 'income_by_category-maior'),
        'Maior: Salário · 75,0%',
      );
      expect(text(tester, 'expense_by_category-total'), 'R\$ 1.200,00');
      expect(
        text(tester, 'expense_by_category-maior'),
        'Maior: Sem categoria · 100,0%',
      );
      expect(text(tester, 'investments_total-total'), 'R\$ 300,00');
      // Livre: nov = 4.000 − 1.200 − 300 = 2.500; out = 1.000.
      expect(text(tester, 'free_money_evolution-valor'), 'R\$ 2.500,00');
      expect(
        text(tester, 'free_money_evolution-variacao'),
        'R\$ 1.500,00 a mais que o período anterior',
      );
      expect(text(tester, 'period_comparison-receitas'), 'R\$ 4.000,00');
      expect(text(tester, 'period_comparison-despesas'), 'R\$ 1.200,00');
      expect(text(tester, 'period_comparison-investimentos'), 'R\$ 300,00');
      // Barras divididas desenhadas de verdade (partes com altura e largura).
      final parts = find.descendant(
        of: find.byType(SegmentedBar),
        matching: find.byType(ColoredBox),
      );
      expect(parts, findsWidgets);
      for (final e in parts.evaluate()) {
        final size = (e.renderObject! as RenderBox).size;
        expect(size.height, 10);
        expect(size.width, greaterThan(0));
      }
      // Tudo recolhido ao entrar.
      expect(_key('relatorio-ver-tudo-income_by_category'), findsNothing);
    });

    testWidgets('variação negativa e sem período anterior', (tester) async {
      await add(EntryKind.income, 100000, d(2026, 10, 5));
      await add(EntryKind.expense, 30000, d(2026, 11, 6));
      await pump(tester);
      expect(text(tester, 'free_money_evolution-valor'), '-R\$ 300,00');
      expect(
        text(tester, 'free_money_evolution-variacao'),
        'R\$ 1.300,00 a menos que o período anterior',
      );
      // Voltando para outubro (primeiro período), não há anterior.
      await tap(tester, 'periodo-anterior');
      expect(text(tester, 'free_money_evolution-valor'), 'R\$ 1.000,00');
      expect(_key('free_money_evolution-variacao'), findsNothing);
    });

    testWidgets('período sem lançamentos: frase, sem gráfico zerado', (
      tester,
    ) async {
      await pump(tester);
      expect(
        text(tester, 'income_by_category-vazio'),
        'Nenhuma receita recebida neste período.',
      );
      expect(
        text(tester, 'expense_by_category-vazio'),
        'Nenhuma despesa neste período.',
      );
      expect(_key('investments_total-vazio'), findsOneWidget);
      expect(_key('free_money_evolution-vazio'), findsOneWidget);
      expect(_key('period_comparison-vazio'), findsOneWidget);
      expect(find.byType(MiniBars), findsNothing);
      expect(find.byType(SegmentedBar), findsNothing);
      expect(_key('income_by_category-total'), findsNothing);
    });

    testWidgets('expandir na lista: 5 maiores e "+N categorias"; vários '
        'abertos; recolher', (tester) async {
      for (var i = 1; i <= 7; i++) {
        final id = await category(CategoryKind.expense, 'Cat $i');
        await add(EntryKind.expense, 1000 * i, d(2026, 11, 2), id);
      }
      await add(EntryKind.income, 500000, d(2026, 11, 1));
      await pump(tester);
      await tap(tester, 'relatorio-expandir-expense_by_category');
      expect(_key('relatorio-ver-tudo-expense_by_category'), findsOneWidget);
      for (final n in [7, 6, 5, 4, 3]) {
        expect(find.text('Cat $n'), findsOneWidget);
      }
      expect(find.text('Cat 2'), findsNothing);
      expect(
        text(tester, 'expense_by_category-mais-categorias'),
        '+2 categorias',
      );
      await tap(tester, 'relatorio-expandir-period_comparison');
      expect(_key('relatorio-ver-tudo-expense_by_category'), findsOneWidget);
      expect(_key('relatorio-ver-tudo-period_comparison'), findsOneWidget);
      await tap(tester, 'relatorio-recolher-expense_by_category');
      expect(_key('relatorio-ver-tudo-expense_by_category'), findsNothing);
      expect(find.text('Cat 7'), findsNothing);
    });

    testWidgets('expandido dos relatórios 3, 4 e 5', (tester) async {
      await add(EntryKind.income, 100000, d(2026, 9, 5));
      await add(EntryKind.income, 200000, d(2026, 10, 5));
      await add(EntryKind.income, 300000, d(2026, 11, 5));
      await investments.create(
        InvestmentDraft(amount: c(5000), date: d(2026, 11, 4)),
      );
      await pump(tester);
      for (final id in [
        'investments_total',
        'free_money_evolution',
        'period_comparison',
      ]) {
        await tap(tester, 'relatorio-expandir-$id');
      }
      expect(text(tester, 'investments_total-total'), 'R\$ 50,00');
      // Evolução: só os 3 períodos mais recentes no expandido.
      for (final start in ['2026-09-01', '2026-10-01', '2026-11-01']) {
        expect(_key('free_money_evolution-evolucao-$start'), findsOneWidget);
      }
      expect(find.textContaining('Últimos 3 períodos'), findsOneWidget);
    });

    testWidgets('"Ver tudo" abre a tela completa; Voltar retorna à lista', (
      tester,
    ) async {
      await add(EntryKind.income, 10000, d(2026, 11, 1));
      await pump(tester);
      await tap(tester, 'relatorio-expandir-income_by_category');
      await tap(tester, 'relatorio-ver-tudo-income_by_category');
      expect(router.state.matchedLocation, '/relatorios/income_by_category');
      expect(text(tester, 'total-relatorio'), 'R\$ 100,00');
      expect(find.text('Receitas por categoria'), findsOneWidget);
      // Ferramentas segue selecionada; seletor de período no topo.
      expect(
        tester.widget<NorteNavBar>(find.byType(NorteNavBar)).currentIndex,
        1,
      );
      expect(_key('periodo-atual'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/relatorios');
      // Ao voltar, o que estava aberto continua (mesma visita).
      expect(_key('relatorio-ver-tudo-income_by_category'), findsOneWidget);
    });

    testWidgets('trocar o período aqui troca o período global', (tester) async {
      await add(EntryKind.income, 10000, d(2026, 10, 1));
      await pump(tester);
      await tap(tester, 'periodo-anterior');
      expect(text(tester, 'income_by_category-total'), 'R\$ 100,00');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      expect(container.read(periodAnchorProvider), d(2026, 10, 31));
    });

    testWidgets('ID inexistente volta para a lista, sem erro', (tester) async {
      await pump(tester, initial: '/relatorios/nao_existe');
      expect(router.state.matchedLocation, '/relatorios');
      expect(find.text('Meus relatórios'), findsOneWidget);
    });

    testWidgets('relatório removido da lista ainda abre pela tela completa', (
      tester,
    ) async {
      prefs.reports_ = const ReportPreferences(
        setup: ReportSetupStatus.done,
        selected: ['income_by_category'],
      );
      await pump(tester, initial: '/relatorios/investments_total');
      expect(_key('total-investimentos'), findsOneWidget);
    });

    testWidgets('erro em um cartão: "Tentar de novo" só nele', (tester) async {
      await add(EntryKind.income, 10000, d(2026, 11, 1));
      await add(EntryKind.income, 10000, d(2026, 10, 1));
      final failing = _FailingSeries(LocalReportsRepository(db, 'u1'));
      await pump(tester, reports: failing);
      for (final id in [
        'investments_total',
        'free_money_evolution',
        'period_comparison',
      ]) {
        expect(_key('$id-tentar-de-novo'), findsOneWidget);
      }
      expect(_key('income_by_category-tentar-de-novo'), findsNothing);
      expect(text(tester, 'income_by_category-total'), 'R\$ 100,00');
      failing.fail = false;
      await tap(tester, 'free_money_evolution-tentar-de-novo');
      expect(_key('free_money_evolution-tentar-de-novo'), findsNothing);
      expect(text(tester, 'free_money_evolution-valor'), 'R\$ 100,00');
    });

    testWidgets('Web larga: duas colunas; expandido ocupa a largura', (
      tester,
    ) async {
      await add(EntryKind.income, 10000, d(2026, 11, 1));
      await pump(tester, size: const Size(1280, 2400));
      final a = tester.getRect(_key('relatorio-card-income_by_category'));
      final b = tester.getRect(_key('relatorio-card-expense_by_category'));
      expect(a.top, b.top);
      expect(b.left, greaterThan(a.right));
      await tap(tester, 'relatorio-expandir-income_by_category');
      final wide = tester.getRect(_key('relatorio-card-income_by_category'));
      expect(wide.width, greaterThan(a.width * 1.8));
    });

    testWidgets('tema escuro e tela estreita: sem estouro', (tester) async {
      final cat = await category(
        CategoryKind.expense,
        'Um nome bem comprido de categoria',
      );
      await add(EntryKind.expense, 123456789, d(2026, 11, 2), cat);
      await add(EntryKind.income, 987654321, d(2026, 11, 1));
      await pump(tester, size: const Size(320, 2400), theme: NorteTheme.dark());
      for (final id in _all) {
        await tap(tester, 'relatorio-expandir-$id');
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('catálogo e Personalizar (RL6)', () {
    testWidgets('catálogo: grupos, prévia real, já escolhido e adicionar', (
      tester,
    ) async {
      final salary = await category(CategoryKind.income, 'Salário');
      await add(EntryKind.income, 300000, d(2026, 11, 1), salary);
      prefs.reports_ = const ReportPreferences(
        setup: ReportSetupStatus.done,
        selected: ['period_comparison'],
      );
      await pump(tester);
      await tap(tester, 'relatorios-adicionar');
      expect(router.state.matchedLocation, '/relatorios/catalogo');
      final groups = [
        'catalogo-grupo-overview',
        'catalogo-grupo-incomeAndExpenses',
        'catalogo-grupo-investments',
      ];
      final tops = [for (final g in groups) tester.getTopLeft(_key(g)).dy];
      expect([...tops]..sort(), tops);
      expect(find.text('Barras por categoria'), findsNothing);
      expect(
        find.text('Receitas e despesas · Barras por categoria'),
        findsNWidgets(2),
      );
      // Prévia com os dados reais do período.
      expect(
        find.descendant(
          of: _key('catalogo-previa-income_by_category'),
          matching: find.text('R\$ 3.000,00'),
        ),
        findsOneWidget,
      );
      // Período vazio: ícone e descrição, sem gráfico zerado.
      expect(_key('expense_by_category-previa-vazia'), findsOneWidget);
      expect(_key('catalogo-escolhido-period_comparison'), findsOneWidget);
      expect(_key('catalogo-adicionar-period_comparison'), findsNothing);
      await tap(tester, 'catalogo-adicionar-investments_total');
      expect(prefs.reports_.selected, [
        'period_comparison',
        'investments_total',
      ]);
      expect(_key('catalogo-escolhido-investments_total'), findsOneWidget);
      await tap(tester, 'catalogo-ver-income_by_category');
      expect(router.state.matchedLocation, '/relatorios/income_by_category');
      expect(_key('total-relatorio'), findsOneWidget);
    });

    testWidgets('Personalizar: remover, ordenar e restaurar com confirmação', (
      tester,
    ) async {
      await pump(tester, initial: '/relatorios/personalizar');
      expect(
        tester.widget<TextButton>(_key('relatorios-restaurar')).onPressed,
        isNull,
      );
      await tap(tester, 'relatorio-remover-investments_total');
      expect(prefs.reports_.selected, isNot(contains('investments_total')));
      expect(
        find.textContaining('Seus dados não foram apagados'),
        findsOneWidget,
      );
      // Arrastar o primeiro para o fim.
      final handle = _key('relatorio-arrastar-income_by_category');
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(kLongPressTimeout);
      await gesture.moveBy(const Offset(0, 500));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(prefs.reports_.selected!.last, 'income_by_category');
      expect(prefs.reports_.setup, ReportSetupStatus.done);
      // Restaurar: pede confirmação; não reabre a configuração guiada.
      await tap(tester, 'relatorios-restaurar');
      expect(find.text('Restaurar configuração inicial?'), findsOneWidget);
      await tap(tester, 'relatorios-restaurar-confirmar');
      expect(prefs.reports_.isSuggested, isTrue);
      expect(prefs.reports_.setup, ReportSetupStatus.done);
    });

    testWidgets('lista vazia: convite para o catálogo', (tester) async {
      prefs.reports_ = const ReportPreferences(
        setup: ReportSetupStatus.done,
        selected: [],
      );
      await pump(tester);
      expect(_key('relatorios-vazio'), findsOneWidget);
      await tap(tester, 'relatorios-vazio-catalogo');
      expect(router.state.matchedLocation, '/relatorios/catalogo');
    });

    testWidgets('IDs de outra versão do app não aparecem nem somem', (
      tester,
    ) async {
      prefs.reports_ = const ReportPreferences(
        setup: ReportSetupStatus.done,
        selected: ['futuro', 'period_comparison'],
      );
      await pump(tester, initial: '/relatorios/personalizar');
      expect(find.textContaining('futuro'), findsNothing);
      await tap(tester, 'relatorios-personalizar-catalogo');
      await tap(tester, 'catalogo-adicionar-income_by_category');
      expect(prefs.reports_.selected, [
        'period_comparison',
        'income_by_category',
        'futuro',
      ]);
    });
  });
}
