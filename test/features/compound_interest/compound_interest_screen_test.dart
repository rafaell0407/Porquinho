import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:porquinho/app/theme/norte_theme.dart';
import 'package:porquinho/features/compound_interest/screens/compound_interest_screen.dart';
import 'package:porquinho/features/compound_interest/screens/withdrawal_screen.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(412, 900),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: CompoundInterestScreen.route,
    routes: [
      GoRoute(
        path: CompoundInterestScreen.route,
        builder: (_, _) => const CompoundInterestScreen(),
      ),
      GoRoute(
        path: CompoundInterestScreen.withdrawalsRoute,
        builder: (_, _) => const WithdrawalScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: theme ?? NorteTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _shown(WidgetTester tester, String key) {
  final widget = tester.widget<Text>(_key(key));
  return widget.textSpan?.toPlainText() ?? widget.data!;
}

Future<void> _choose(
  WidgetTester tester,
  String selector,
  String option,
) async {
  await tester.ensureVisible(_key(selector));
  await tester.tap(_key(selector));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String prefix = 'juros',
  String? initial,
  String? monthly,
  String? withdrawal,
  String? rate,
  String? term,
}) async {
  Future<void> type(String key, String? text) async {
    if (text == null) return;
    await tester.ensureVisible(_key(key));
    await tester.enterText(_key(key), text);
  }

  await type('$prefix-campo-inicial', initial);
  await type('$prefix-campo-mensal', monthly);
  await type('$prefix-campo-retirada', withdrawal);
  await type('$prefix-campo-taxa', rate);
  await type('$prefix-campo-periodo', term);
  await tester.pump();
}

Future<void> _calculate(WidgetTester tester) async {
  await tester.ensureVisible(_key('simulacao-calcular').first);
  await tester.tap(_key('simulacao-calcular').first);
  await tester.pumpAndSettle();
}

List<String> _rowTexts(WidgetTester tester, int i) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(
      of: _key('simulacao-tabela-linha-$i'),
      matching: find.byType(Text),
    ),
  ))
    t.data!,
];

void main() {
  testWidgets('calcula: cartões, gráfico e tabela batem com o domínio', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Simulador de juros compostos'), findsOneWidget);
    expect(find.text('Resultado'), findsNothing);
    await _fill(tester, initial: '8.000,00', rate: '12', term: '2');
    await _calculate(tester);

    expect(_shown(tester, 'juros-valor-final'), 'R\$ 10.035,20');
    expect(_shown(tester, 'juros-valor-investido'), 'R\$ 8.000,00');
    expect(_shown(tester, 'juros-valor-juros'), 'R\$ 2.035,20');
    expect(_key('juros-grafico'), findsOneWidget);
    expect(find.text('Total acumulado'), findsWidgets);
    expect(
      find.textContaining('12% ao ano (≈ 0,9489% ao mês)'),
      findsOneWidget,
    );

    await tester.ensureVisible(_key('juros-tabela'));
    await tester.pumpAndSettle();
    expect(_rowTexts(tester, 0), [
      '0',
      'R\$ 0,00',
      'R\$ 8.000,00',
      'R\$ 0,00',
      'R\$ 8.000,00',
    ]);
    expect(_rowTexts(tester, 1), [
      '1',
      'R\$ 75,91',
      'R\$ 8.000,00',
      'R\$ 75,91',
      'R\$ 8.075,91',
    ]);
    // Última linha (mês 24) igual aos cartões.
    await tester.scrollUntilVisible(
      _key('simulacao-tabela-linha-24'),
      200,
      scrollable: find.descendant(
        of: _key('simulacao-tabela-lista'),
        matching: find.byType(Scrollable),
      ),
    );
    expect(_rowTexts(tester, 24), [
      '24',
      // 10.035,20 − 9.940,87: a coluna soma exatamente o total em juros.
      'R\$ 94,33',
      'R\$ 8.000,00',
      'R\$ 2.035,20',
      'R\$ 10.035,20',
    ]);
    expect(_key('simulacao-tabela-linha-25'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validação: campos vazios e período zero mostram mensagens', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, term: '0');
    await _calculate(tester);
    expect(find.text('Informe o valor inicial ou o valor mensal.'), findsOne);
    expect(find.text('Informe a taxa de juros.'), findsOneWidget);
    expect(
      find.text('O período precisa ser de pelo menos 1 mês.'),
      findsOneWidget,
    );
    expect(find.text('Resultado'), findsNothing);

    await _fill(tester, initial: '-5', rate: 'abc', term: '1');
    await _calculate(tester);
    expect(find.text('O valor não pode ser negativo.'), findsOneWidget);
    expect(find.text('Taxa inválida. Exemplo: 0,85'), findsOneWidget);
    expect(find.text('Resultado'), findsNothing);
  });

  testWidgets('recalcula ao mudar parâmetros; taxa mensal e meses', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, initial: '8.000,00', rate: '12', term: '1');
    await _calculate(tester);
    expect(_shown(tester, 'juros-valor-final'), 'R\$ 8.960,00');

    await _fill(
      tester,
      initial: '1.000',
      monthly: '100',
      rate: '1',
      term: '12',
    );
    await _choose(tester, 'juros-taxa-periodo', 'mensal');
    await _choose(tester, 'juros-periodo-unidade', 'meses');
    await _calculate(tester);
    expect(_shown(tester, 'juros-valor-final'), 'R\$ 2.395,08');
    expect(_shown(tester, 'juros-valor-investido'), 'R\$ 2.200,00');
    expect(_shown(tester, 'juros-valor-juros'), 'R\$ 195,08');

    // Taxa zero: total = investido.
    await _fill(tester, rate: '0');
    await _calculate(tester);
    expect(_shown(tester, 'juros-valor-final'), 'R\$ 2.200,00');
    expect(_shown(tester, 'juros-valor-juros'), 'R\$ 0,00');
  });

  testWidgets('Limpar restaura os campos e remove o resultado', (tester) async {
    await _pump(tester);
    await _fill(tester, initial: '8.000,00', rate: '1', term: '10');
    await _choose(tester, 'juros-taxa-periodo', 'mensal');
    await _calculate(tester);
    expect(find.text('Resultado'), findsOneWidget);

    await tester.ensureVisible(_key('juros-limpar'));
    await tester.tap(_key('juros-limpar'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado'), findsNothing);
    for (final k in ['inicial', 'mensal', 'taxa', 'periodo']) {
      expect(
        tester.widget<TextField>(_key('juros-campo-$k')).controller!.text,
        isEmpty,
      );
    }
    expect(find.text('anual'), findsOneWidget);
    expect(find.text('anos'), findsOneWidget);
  });

  testWidgets('valores muito altos viram mensagem, sem quebrar', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, initial: '1.000.000.000,00', rate: '1000', term: '50');
    await _choose(tester, 'juros-taxa-periodo', 'mensal');
    await _calculate(tester);
    expect(_key('simulacao-erro'), findsOneWidget);
    expect(find.text('Resultado'), findsNothing);

    await _fill(tester, initial: '1.000.000.000,01');
    await _calculate(tester);
    expect(find.text('Use um valor de até R\$ 1.000.000.000,00.'), findsOne);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size) in [
    ('celular estreito', const Size(320, 800)),
    ('Web larga', const Size(1280, 900)),
  ]) {
    testWidgets('layout $name: 600 meses sem estouro', (tester) async {
      await _pump(tester, size: size);
      await _fill(
        tester,
        initial: '1.000.000.000,00',
        monthly: '1.000.000.000,00',
        rate: '12',
        term: '50',
      );
      await _calculate(tester);
      expect(tester.takeException(), isNull);
      expect(_shown(tester, 'juros-valor-final'), 'R\$ 30.640.827.950.548,52');
      await tester.ensureVisible(_key('juros-tabela'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Rolagem horizontal só dentro da tabela, e só no celular.
      expect(
        _key('simulacao-tabela-horizontal'),
        size.width < 600 ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('tema escuro renderiza resultado sem erro', (tester) async {
    await _pump(tester, theme: NorteTheme.dark());
    await _fill(tester, initial: '500', monthly: '50', rate: '10', term: '3');
    await _calculate(tester);
    expect(find.text('Resultado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('informação da calculadora abre a explicação', (tester) async {
    await _pump(tester);
    await tester.tap(_key('juros-info'));
    await tester.pumpAndSettle();
    expect(_key('ferramenta-info-sheet-compound_interest'), findsOneWidget);
    expect(find.textContaining('mensal equivalente'), findsOneWidget);
  });

  testWidgets('retiradas: sugestão, esgotamento e principal preservada', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, initial: '8.000,00', rate: '12', term: '2');
    await _calculate(tester);
    expect(_shown(tester, 'juros-valor-final'), 'R\$ 10.035,20');

    await tester.ensureVisible(_key('juros-simular-retiradas'));
    await tester.tap(_key('juros-simular-retiradas'));
    await tester.pumpAndSettle();
    expect(find.text('Simular retiradas mensais'), findsOneWidget);
    final initial = tester.widget<TextField>(_key('retiradas-campo-inicial'));
    expect(initial.controller!.text, '10.035,20');

    // Premissas acessíveis pelo ícone de informação.
    await tester.tap(_key('retiradas-premissas'));
    await tester.pumpAndSettle();
    expect(_key('retiradas-premissas-sheet'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    await _fill(
      tester,
      prefix: 'retiradas',
      initial: '10.000,00',
      withdrawal: '1.500,00',
      rate: '1',
      term: '24',
    );
    await _choose(tester, 'retiradas-taxa-periodo', 'mensal');
    await _choose(tester, 'retiradas-periodo-unidade', 'meses');
    await _calculate(tester);
    expect(_key('retiradas-esgotou'), findsOneWidget);
    expect(find.textContaining('acaba no mês 7'), findsOneWidget);
    expect(_shown(tester, 'retiradas-valor-saldo'), 'R\$ 0,00');
    expect(_shown(tester, 'retiradas-valor-retirado'), 'R\$ 10.401,05');
    expect(_shown(tester, 'retiradas-valor-juros'), 'R\$ 401,05');
    await tester.ensureVisible(_key('retiradas-tabela'));
    await tester.pumpAndSettle();
    expect(_key('simulacao-tabela-linha-7'), findsOneWidget);
    expect(_key('simulacao-tabela-linha-8'), findsNothing);
    expect(_rowTexts(tester, 7).last, 'R\$ 0,00');

    // Limpar volta à sugestão.
    await tester.ensureVisible(_key('retiradas-limpar'));
    await tester.tap(_key('retiradas-limpar'));
    await tester.pumpAndSettle();
    expect(initial.controller!.text, '10.035,20');
    expect(_key('retiradas-esgotou'), findsNothing);

    // Voltar: a simulação principal continua igual.
    final context = tester.element(find.byType(Navigator).last);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(_shown(tester, 'juros-valor-final'), 'R\$ 10.035,20');
  });

  testWidgets('retiradas sem simulação principal: campo vazio e premissa '
      'de retirada zero', (tester) async {
    await _pump(tester);
    await tester.ensureVisible(_key('juros-simular-retiradas'));
    await tester.tap(_key('juros-simular-retiradas'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(_key('retiradas-campo-inicial'))
          .controller!
          .text,
      isEmpty,
    );
    await _fill(
      tester,
      prefix: 'retiradas',
      initial: '8.000',
      rate: '12',
      term: '2',
    );
    await _calculate(tester);
    expect(_key('retiradas-durou'), findsOneWidget);
    expect(_shown(tester, 'retiradas-valor-saldo'), 'R\$ 10.035,20');
    expect(_shown(tester, 'retiradas-valor-retirado'), 'R\$ 0,00');
  });
}
