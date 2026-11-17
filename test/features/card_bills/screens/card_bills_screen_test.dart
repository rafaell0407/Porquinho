import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:porquinho/app/theme/norte_theme.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/card_bills/application/card_bills_providers.dart';
import 'package:porquinho/features/card_bills/application/card_bills_service.dart';
import 'package:porquinho/features/card_bills/data/local_card_bills_repository.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/purchases.dart';
import 'package:porquinho/features/card_bills/screens/card_bills_screen.dart';
import 'package:porquinho/features/periods/period_providers.dart';

import '../domain/card_bills_fixtures.dart';

Finder _key(String k) => find.byKey(Key(k));

/// Segunda, 16/11/2026, meio-dia em São Paulo.
final _clock = UserClock(now: () => DateTime.utc(2026, 11, 18, 15));

late PorquinhoDatabase _db;

CardBillsService _service() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  _db = PorquinhoDatabase(NativeDatabase.memory());
  return CardBillsService(LocalCardBillsRepository(_db, 'u1'), clock: _clock);
}

Future<void> _pump(
  WidgetTester tester,
  CardBillsService service, {
  Size size = const Size(412, 900),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: CardBillsScreen.route,
    routes: [
      GoRoute(
        path: CardBillsScreen.route,
        builder: (_, _) => const CardBillsScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userClockProvider.overrideWithValue(_clock),
        cardBillsServiceProvider.overrideWith((ref) async => service),
      ],
      child: MaterialApp.router(
        theme: theme ?? NorteTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_key(key));
  await tester.enterText(_key(key), text);
  await tester.pump();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

Future<CardBillsService> _withCardAndPurchase() async {
  final service = _service();
  await service.createCard('Nubank', 10, 17);
  final card = (await service.snapshot()).data.cards.single;
  await service.savePurchase(
    PurchaseDraft(
      cardId: card.id,
      description: 'TV',
      purchasedOn: d('2026-11-16'),
      installmentCount: 2,
      amountMode: AmountMode.total,
      amount: c(200000),
    ),
  );
  await service.setReserve(c(150000));
  return service;
}

void main() {
  tearDown(() => _db.close());

  testWidgets('sem cartão: estado vazio convida a cadastrar o primeiro', (
    tester,
  ) async {
    await _pump(tester, _service());
    expect(find.text('Comece pelo seu primeiro cartão'), findsOneWidget);
    await _tap(tester, 'cb-primeiro-cartao');
    await _type(tester, 'cb-cartao-nome', 'Nubank');
    await _type(tester, 'cb-cartao-fechamento', '10');
    await _type(tester, 'cb-cartao-vencimento', '17');
    expect(find.textContaining('vence em 17/12/2026'), findsOneWidget);
    await _tap(tester, 'cb-cartao-salvar');
    expect(find.text('Nubank · vence 17/12'), findsOneWidget);
    expect(find.text('Nubank · vence 17/01'), findsOneWidget);
    expect(_text(tester, 'cb-saldo'), 'R\$ 0,00');
  });

  testWidgets('cartão: dias inválidos mostram erro e não salvam', (
    tester,
  ) async {
    await _pump(tester, _service());
    await _tap(tester, 'cb-primeiro-cartao');
    await _type(tester, 'cb-cartao-nome', 'Nubank');
    await _type(tester, 'cb-cartao-fechamento', '32');
    await _type(tester, 'cb-cartao-vencimento', '17');
    await _tap(tester, 'cb-cartao-salvar');
    expect(
      _text(tester, 'cb-cartao-erro'),
      'O dia de fechamento vai de 1 a 31.',
    );
  });

  testWidgets('topo: saldo, faltam, comprometido e calculadora da reserva', (
    tester,
  ) async {
    await _pump(tester, await _withCardAndPurchase());
    expect(_text(tester, 'cb-saldo'), 'R\$ 500,00 para cobrir as faturas');
    expect(find.text('Faltam'), findsOneWidget);
    await _tap(tester, 'cb-reservado');
    expect(_text(tester, 'cb-calc-visor'), '1.500');
    await _tap(tester, 'cb-calc-+');
    for (final k in ['1', '0', '0', '0']) {
      await _tap(tester, 'cb-calc-$k');
    }
    await _tap(tester, 'cb-calc-=');
    expect(_text(tester, 'cb-calc-visor'), '1.500 + 1.000 = 2.500,00');
    expect(
      _text(tester, 'cb-calc-resumo'),
      'Atual R\$ 1.500,00 → Novo R\$ 2.500,00 (+R\$ 1.000,00)',
    );
    await _tap(tester, 'cb-calc-confirmar');
    expect(_text(tester, 'cb-saldo'), 'R\$ 500,00');
    expect(find.text('Saldo não comprometido'), findsOneWidget);
  });

  testWidgets('calculadora: divisão por zero mostra erro e não confirma', (
    tester,
  ) async {
    await _pump(tester, await _withCardAndPurchase());
    await _tap(tester, 'cb-reservado');
    await _tap(tester, 'cb-calc-÷');
    await _tap(tester, 'cb-calc-0');
    await _tap(tester, 'cb-calc-=');
    expect(_text(tester, 'cb-calc-resumo'), 'Não é possível dividir por zero.');
    final confirm = tester.widget<FilledButton>(_key('cb-calc-confirmar'));
    expect(confirm.onPressed, isNull);
  });

  testWidgets('nova compra pelo +: 1ª parcela, troca de fatura e resumo', (
    tester,
  ) async {
    final service = _service();
    await service.createCard('Nubank', 10, 17);
    await _pump(tester, service);
    await _tap(tester, 'cb-adicionar');
    await _tap(tester, 'cb-adicionar-compra');
    await _type(tester, 'cb-compra-descricao', 'Geladeira');
    await _type(tester, 'cb-compra-valor', '1000');
    await _type(tester, 'cb-compra-parcelas', '3');
    expect(
      _text(tester, 'cb-compra-primeira-fatura'),
      '1ª parcela na fatura que vence em 17/12/2026',
    );
    expect(
      _text(tester, 'cb-compra-resumo'),
      '1ª de R\$ 333,34 + 2 × R\$ 333,33 = R\$ 1.000,00',
    );
    await _tap(tester, 'cb-compra-fatura-seguinte');
    expect(
      _text(tester, 'cb-compra-primeira-fatura'),
      '1ª parcela na fatura que vence em 17/01/2027',
    );
    await _tap(tester, 'cb-compra-fatura-anterior');
    await _tap(tester, 'cb-compra-salvar');
    // Permanece na tela, com o formulário limpo para a próxima compra.
    expect(find.text('Nova compra'), findsOneWidget);
    expect(find.text('Compra adicionada.'), findsOneWidget);
    expect(find.text('Geladeira'), findsNothing);
    final data = (await service.snapshot()).data;
    expect(data.installments.length, 3);
  });

  testWidgets('pagar pela reserva e desfazer no detalhe', (tester) async {
    final service = await _withCardAndPurchase();
    await _pump(tester, service);
    final dec = (await service.snapshot()).board.pending.first;
    await _tap(tester, 'cb-pagar-${dec.id}');
    expect(find.text('Sairão R\$ 1.000,00 da reserva.'), findsOneWidget);
    await _tap(tester, 'cb-pagar-confirmar');
    expect(find.text('Pagas (1)'), findsOneWidget);
    expect(
      find.textContaining('R\$ 1.000,00 pela fatura Nubank'),
      findsOneWidget,
    );
    await _tap(tester, 'cb-pagas');
    await _tap(tester, 'cb-paga-${dec.id}');
    expect(
      _text(tester, 'cb-fatura-previsto-pago'),
      'previsto R\$ 1.000,00 · pago R\$ 1.000,00',
    );
    await _tap(tester, 'cb-fatura-desfazer');
    await _tap(tester, 'cb-confirmar-sim');
    expect(_text(tester, 'cb-fatura-situacao'), 'atual · vence em 17/12');
    final s = await service.snapshot();
    expect(s.board.reserve, c(150000));
    expect(s.board.paid, isEmpty);
  });

  testWidgets('pagamento com valor menor e outras fontes: avisos', (
    tester,
  ) async {
    final service = await _withCardAndPurchase();
    await _pump(tester, service);
    final dec = (await service.snapshot()).board.pending.first;
    await _tap(tester, 'cb-pagar-${dec.id}');
    await _type(tester, 'cb-pagar-valor', '900');
    expect(
      find.textContaining('R\$ 100,00 deixarão de contar'),
      findsOneWidget,
    );
    await _tap(tester, 'cb-pagar-origem-outras');
    await _tap(tester, 'cb-pagar-confirmar');
    final s = await service.snapshot();
    expect(s.board.reserve, c(150000));
    expect(s.board.paid.single.value, c(90000));
  });

  testWidgets('valor informado: detalhe e aviso de valor menor que itens', (
    tester,
  ) async {
    final service = await _withCardAndPurchase();
    await _pump(tester, service);
    final dec = (await service.snapshot()).board.pending.first;
    await _tap(tester, 'cb-fatura-${dec.id}');
    await _tap(tester, 'cb-fatura-informar');
    await _type(tester, 'cb-informado-valor', '1200');
    await _tap(tester, 'cb-informado-salvar');
    expect(_text(tester, 'cb-fatura-valor'), 'R\$ 1.200,00');
    expect(
      _text(tester, 'cb-fatura-detalhe-informado'),
      'R\$ 1.200,00 informados, dos quais R\$ 1.000,00 em parcelas e '
      'despesas recorrentes e R\$ 200,00 em outros gastos',
    );
    await _tap(tester, 'cb-fatura-informar');
    await _type(tester, 'cb-informado-valor', '500');
    await _tap(tester, 'cb-informado-salvar');
    expect(find.textContaining('menor que a soma dos itens'), findsOneWidget);
    await _tap(tester, 'cb-fatura-apagar-informado');
    expect(_text(tester, 'cb-fatura-valor'), 'R\$ 1.000,00');
  });

  testWidgets('corrigir datas recusa vencimento antes do fechamento', (
    tester,
  ) async {
    final service = await _withCardAndPurchase();
    await _pump(tester, service);
    final dec = (await service.snapshot()).board.pending.first;
    await _tap(tester, 'cb-fatura-${dec.id}');
    await _tap(tester, 'cb-fatura-corrigir-datas');
    expect(_key('cb-datas-erro'), findsNothing);
    final save = tester.widget<FilledButton>(_key('cb-datas-salvar'));
    expect(save.onPressed, isNotNull);
  });

  testWidgets('assinatura: cobrança na fatura atual e total por mês', (
    tester,
  ) async {
    final service = _service();
    await service.createCard('Nubank', 10, 17);
    await _pump(tester, service);
    await _tap(tester, 'cb-adicionar');
    await _tap(tester, 'cb-adicionar-assinatura');
    await _type(tester, 'cb-assinatura-descricao', 'Streaming');
    await _type(tester, 'cb-assinatura-valor', '39,90');
    await _tap(tester, 'cb-assinatura-salvar');
    expect(
      _text(tester, 'cb-assinaturas-ativas'),
      'Despesas recorrentes ativas: R\$ 39,90 por mês',
    );
    final s = await service.snapshot();
    expect(s.board.committed, c(3990));
    // Cancelar perguntando pela cobrança atual.
    await _tap(tester, 'cb-assinatura-${s.data.subscriptions.single.id}');
    await _tap(tester, 'cb-assinatura-cancelar');
    await _tap(tester, 'cb-assinatura-remover-cobranca');
    final after = await service.snapshot();
    expect(after.data.subscriptions, isEmpty);
    expect(after.board.committed, BigInt.zero);
  });

  testWidgets('apagar cartão avisa o valor que deixa de contar', (
    tester,
  ) async {
    final service = await _withCardAndPurchase();
    await _pump(tester, service);
    final card = (await service.snapshot()).data.cards.single;
    await _tap(tester, 'cb-cartao-${card.id}');
    await _tap(tester, 'cb-cartao-apagar');
    expect(
      find.textContaining('R\$ 2.000,00 deixarão de contar'),
      findsOneWidget,
    );
    await _tap(tester, 'cb-confirmar-sim');
    expect(find.text('Comece pelo seu primeiro cartão'), findsOneWidget);
  });

  testWidgets('tema escuro e tela estreita: sem estouro', (tester) async {
    final service = await _withCardAndPurchase();
    await _pump(
      tester,
      service,
      size: const Size(320, 640),
      theme: NorteTheme.dark(),
    );
    expect(tester.takeException(), isNull);
    final dec = (await service.snapshot()).board.pending.first;
    await _tap(tester, 'cb-fatura-${dec.id}');
    expect(tester.takeException(), isNull);
  });
}
