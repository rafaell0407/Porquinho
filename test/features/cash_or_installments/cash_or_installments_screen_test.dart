import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:porquinho/app/theme/norte_theme.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/features/cash_or_installments/application/cash_or_installments_providers.dart';
import 'package:porquinho/features/cash_or_installments/data/reference_rates.dart';
import 'package:porquinho/features/cash_or_installments/screens/cash_or_installments_screen.dart';
import 'package:porquinho/features/periods/period_providers.dart';

Finder _key(String k) => find.byKey(Key(k));

/// Banco Central de mentira: CDI 13,65% e Selic 14,90% em 12/11/2026, ou
/// falha ([fail]).
http.Client _bcb({bool fail = false}) => MockClient((req) async {
  if (fail) return http.Response('erro', 503);
  final value = req.url.path.contains('4389') ? '13.65' : '14.90';
  return http.Response('[{"data":"12/11/2026","valor":"$value"}]', 200);
});

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(412, 900),
  ThemeData? theme,
  http.Client? client,
  RateCache? cache,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: CashOrInstallmentsScreen.route,
    routes: [
      GoRoute(
        path: CashOrInstallmentsScreen.route,
        builder: (_, _) => const CashOrInstallmentsScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Sábado, 14/11/2026, meio-dia em São Paulo.
        userClockProvider.overrideWithValue(
          UserClock(now: () => DateTime.utc(2026, 11, 14, 15)),
        ),
        cashOrInstallmentsRateRepositoryProvider.overrideWithValue(
          ReferenceRateRepository(
            client: BcbRateClient(client: client ?? _bcb()),
            cache: cache ?? MemoryRateCache(),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: theme ?? NorteTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_key(key));
  await tester.enterText(_key(key), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) {
  final w = tester.widget<Text>(_key(key));
  return w.textSpan?.toPlainText() ?? w.data!;
}

String _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(_key(key)).controller!.text;

/// Caso do esboço aprovado: R$ 1.000 com 5% de desconto ou 10x no cartão
/// com vencimento dia 10, CDB 100% do CDI a 13,65%.
Future<void> _fillSketch(WidgetTester tester) async {
  await _tap(tester, 'avp-modo-avista-discount');
  await _type(tester, 'avp-campo-preco', '1.000,00');
  await _type(tester, 'avp-campo-desconto', '5');
  await _type(tester, 'avp-campo-parcelas', '10');
  await _type(tester, 'avp-campo-vencimento', '10');
}

void main() {
  testWidgets('abre com a faixa de aviso, "Ler mais" e a taxa do Banco '
      'Central', (tester) async {
    await _pump(tester);
    expect(find.text('Calculadora à vista ou parcelado'), findsOneWidget);
    expect(_key('avp-faixa-aviso'), findsOneWidget);
    expect(
      find.text('Investir enquanto parcela exige disciplina financeira.'),
      findsOneWidget,
    );
    expect(find.text('CDI 13,65% ao ano'), findsOneWidget);
    expect(find.text('Taxa de 12/11/2026 · Banco Central'), findsOneWidget);

    await tester.tap(_key('avp-ler-mais'));
    await tester.pumpAndSettle();
    expect(_key('avp-ler-mais-sheet'), findsOneWidget);
    expect(find.textContaining('fatura inteira todo mês'), findsOneWidget);
    await tester.ensureVisible(find.text('Fechar'));
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(_key('avp-ler-mais-sheet'), findsNothing);
    // A faixa não fecha.
    expect(_key('avp-faixa-aviso'), findsOneWidget);

    await _tap(tester, 'avp-produto-treasurySelic');
    expect(find.text('Selic 14,9% ao ano'), findsOneWidget);
    expect(_key('avp-campo-cdi'), findsNothing);
  });

  testWidgets('caso do esboço: valor calculado, total pré-preenchido, '
      'faturas, veredito, lado a lado e tabela', (tester) async {
    await _pump(tester);
    await _fillSketch(tester);

    expect(_field(tester, 'avp-campo-total'), '1.000,00');
    expect(find.textContaining('R\$ 950,00'), findsOneWidget);
    expect(_text(tester, 'avp-resumo-parcelas'), '10x de R\$ 100,00');
    expect(find.textContaining('vence em 10/12/2026'), findsOneWidget);
    expect(find.textContaining('vence em 10/01/2027'), findsOneWidget);
    expect(find.text('Vencimentos: 10/12/2026 … 10/09/2027'), findsOneWidget);

    await _tap(tester, 'avp-ver-vencimentos');
    expect(find.text('10/01/2027 (domingo)'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await _tap(tester, 'avp-calcular');
    expect(_text(tester, 'avp-veredito-titulo'), 'À VISTA');
    expect(
      _text(tester, 'avp-veredito-diferenca'),
      'R\$ 7,85 a mais no seu bolso',
    );
    expect(find.textContaining('mais R\$ 54,38 em caixa'), findsOneWidget);
    expect(find.textContaining('mais R\$ 46,53 em caixa'), findsOneWidget);
    expect(find.textContaining('(10/09/2027)'), findsNWidgets(2));
    expect(find.text('Simulação de 14/11/2026'), findsOneWidget);
    expect(find.text('Aplicação em 16/11 (1º dia útil)'), findsOneWidget);
    expect(find.text('CDB 100% do CDI'), findsOneWidget);
    expect(find.text('CDI 13,65% a.a. · taxa de 12/11/2026'), findsOneWidget);
    expect(find.textContaining('R\$ 1.000,00 reservados'), findsOneWidget);

    await tester.ensureVisible(_key('avp-lado-a-lado'));
    expect(find.text('10x de 100,00'), findsOneWidget);
    expect(find.text('R\$ 54,38'), findsOneWidget);
    expect(find.text('R\$ 46,53'), findsOneWidget);

    await tester.ensureVisible(_key('avp-tabela'));
    await tester.pumpAndSettle();
    expect(find.text('908,34'), findsWidgets);
    expect(find.text('vence domingo; resgate em 08/01'), findsOneWidget);
    expect(find.text('46,53 em caixa'), findsOneWidget);
    expect(_key('avp-grafico'), findsOneWidget);
  });

  testWidgets('campos inválidos mostram o erro e não calculam', (tester) async {
    await _pump(tester);
    await _type(tester, 'avp-campo-parcelas', '30');
    await _type(tester, 'avp-campo-vencimento', '0');
    await _type(tester, 'avp-campo-cdi', '130');
    await _tap(tester, 'avp-calcular');
    expect(find.text('Informe um valor.'), findsNWidgets(2));
    expect(find.text('Use um número de 1 a 24.'), findsOneWidget);
    expect(find.text('Use um número de 1 a 31.'), findsOneWidget);
    expect(find.text('Use até 120%.'), findsOneWidget);
    expect(_key('avp-veredito'), findsNothing);
  });

  testWidgets('sem taxa do Banco Central: pede a taxa e marca "taxa '
      'informada"', (tester) async {
    await _pump(tester, client: _bcb(fail: true));
    expect(_key('avp-taxa-falhou'), findsOneWidget);
    await _type(tester, 'avp-campo-valor-a-vista', '950,00');
    await _type(tester, 'avp-campo-total', '1.000,00');
    await _type(tester, 'avp-campo-parcelas', '10');
    await _type(tester, 'avp-campo-vencimento', '10');
    await _tap(tester, 'avp-calcular');
    expect(find.text('Informe a taxa ao ano.'), findsOneWidget);
    await _type(tester, 'avp-campo-taxa', '13,65');
    await _tap(tester, 'avp-calcular');
    expect(_text(tester, 'avp-veredito-titulo'), 'À VISTA');
    expect(find.text('CDI 13,65% a.a. · taxa informada'), findsOneWidget);
  });

  testWidgets('falha usa a taxa guardada e avisa quando é antiga', (
    tester,
  ) async {
    final cache = MemoryRateCache();
    await cache.write(
      RateIndex.cdi,
      ReferenceRate(annualRateE2: 1050, date: CalendarDate(2026, 9, 1)),
    );
    await _pump(tester, client: _bcb(fail: true), cache: cache);
    expect(find.text('CDI 10,5% ao ano'), findsOneWidget);
    expect(find.textContaining('última taxa guardada'), findsOneWidget);
    expect(find.textContaining('mais de 30 dias'), findsOneWidget);
  });

  testWidgets('editar a taxa vale só para a simulação e pode voltar à do '
      'Banco Central', (tester) async {
    await _pump(tester);
    await _tap(tester, 'avp-taxa-editar');
    expect(_field(tester, 'avp-campo-taxa'), '13,65');
    await _type(tester, 'avp-campo-taxa', '0');
    await _type(tester, 'avp-campo-valor-a-vista', '950,00');
    await _type(tester, 'avp-campo-total', '1.000,00');
    await _type(tester, 'avp-campo-parcelas', '10');
    await _type(tester, 'avp-campo-vencimento', '10');
    await _tap(tester, 'avp-calcular');
    // Taxa zero: à vista sobra R$ 50, parcelado nada.
    expect(
      _text(tester, 'avp-veredito-diferenca'),
      'R\$ 50,00 a mais no seu bolso',
    );
    await _tap(tester, 'avp-taxa-usar-bc');
    expect(find.text('CDI 13,65% ao ano'), findsOneWidget);
  });

  testWidgets('valor da parcela e "DÁ NO MESMO"', (tester) async {
    await _pump(tester);
    await _type(tester, 'avp-campo-valor-a-vista', '997,00');
    await _tap(tester, 'avp-modo-parcelas-perInstallment');
    await _type(tester, 'avp-campo-parcela', '333,34');
    await _type(tester, 'avp-campo-parcelas', '3');
    await _type(tester, 'avp-campo-vencimento', '10');
    expect(
      _text(tester, 'avp-resumo-parcelas'),
      '3x de R\$ 333,34 · total R\$ 1.000,02',
    );
    await _tap(tester, 'avp-calcular');
    expect(_text(tester, 'avp-veredito-titulo'), isNotEmpty);
  });

  testWidgets('Limpar volta ao início e apaga o resultado', (tester) async {
    await _pump(tester);
    await _fillSketch(tester);
    await _tap(tester, 'avp-calcular');
    expect(_key('avp-veredito'), findsOneWidget);
    await _tap(tester, 'avp-limpar');
    expect(_key('avp-veredito'), findsNothing);
    expect(_key('avp-campo-valor-a-vista'), findsOneWidget);
    expect(_key('avp-campo-preco'), findsNothing);
  });

  for (final (name, theme, size) in [
    ('claro, celular estreito', NorteTheme.light(), const Size(320, 800)),
    ('escuro, celular', NorteTheme.dark(), const Size(412, 900)),
    ('claro, Web larga', NorteTheme.light(), const Size(1280, 900)),
  ]) {
    testWidgets('sem estouro de layout: $name', (tester) async {
      await _pump(tester, theme: theme, size: size);
      await _fillSketch(tester);
      await _tap(tester, 'avp-calcular');
      for (final k in [
        'avp-veredito',
        'avp-premissas',
        'avp-lado-a-lado',
        'avp-grafico',
        'avp-tabela',
      ]) {
        await tester.ensureVisible(_key(k));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
