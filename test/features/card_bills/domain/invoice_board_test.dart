import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/cards_and_invoices.dart';
import 'package:porquinho/features/card_bills/domain/invoice_board.dart';
import 'package:porquinho/features/card_bills/domain/purchases.dart';

import 'card_bills_fixtures.dart';

/// GF1.4 valor da fatura e indicador; GF1.9 faturas visíveis (spec §3, §5).
void main() {
  final today = d('2026-11-18'); // Nov (vence 17/11) já venceu: a atual é Dez

  CardBillsData withPurchase(
    CardBillsData data, {
    required String id,
    String date = '2026-11-16',
    int count = 1,
    int amount = 10000,
    String? firstMonth,
    String? on,
  }) {
    final plan = planNewPurchase(
      id: id,
      draft: PurchaseDraft(
        cardId: 'card-1',
        description: 'Compra $id',
        purchasedOn: d(date),
        installmentCount: count,
        amountMode: AmountMode.total,
        amount: c(amount),
        firstMonth: firstMonth == null ? null : ym(firstMonth),
      ),
      data: data,
      today: on == null ? today : d(on),
    );
    return applyChange(data, plan.change);
  }

  test('sem nada: a fatura atual e a seguinte aparecem vazias, R\$ 0,00', () {
    final board = CardBillsBoard.build(
      const CardBillsData(cards: [nubank]),
      today,
    );
    expect(board.pending.map((v) => v.month.toKey()), ['2026-12', '2027-01']);
    expect(board.pending.first.isCurrent, isTrue);
    expect(board.pending.first.value, BigInt.zero);
    expect(board.pending.first.isOverdue, isFalse);
    expect(board.committed, BigInt.zero);
    expect(board.uncommitted, BigInt.zero);
  });

  test('cartão novo: fechada e ainda não vencida é a atual', () {
    final board = CardBillsBoard.build(
      const CardBillsData(cards: [nubank]),
      d('2026-11-16'),
    );
    expect(board.pending.map((v) => v.month.toKey()), ['2026-11', '2026-12']);
    expect(board.pending.first.isCurrent, isTrue);
    expect(board.pending.first.isOverdue, isFalse);
  });

  test('fatura distante só aparece com parcelas ou valor informado', () {
    var data = const CardBillsData(cards: [nubank]);
    data = withPurchase(data, id: 'p1', count: 6, amount: 60000);
    final board = CardBillsBoard.build(data, today);
    expect(board.pending.map((v) => v.month.toKey()), [
      '2026-12',
      '2027-01',
      '2027-02',
      '2027-03',
      '2027-04',
      '2027-05',
    ]);
    expect(board.committed, c(60000));
    expect(board.pending[2].items.single.description, 'Compra p1 (3/6)');
  });

  test('valor informado substitui os itens, nunca soma os dois', () {
    var data = withPurchase(
      const CardBillsData(cards: [nubank]),
      id: 'p1',
      amount: 45000,
    );
    var board = CardBillsBoard.build(data, today);
    final dec = board.pending.first;
    data = applyChange(data, setInformedAmount(dec, c(120000), data));
    board = CardBillsBoard.build(data, today);
    final view = board.pending.first;
    expect(view.itemsTotal, c(45000));
    expect(view.value, c(120000));
    expect(view.otherSpending, c(75000));
    expect(view.informedBelowItems, isFalse);
    expect(board.committed, c(120000));

    data = applyChange(data, setInformedAmount(view, c(30000), data));
    final below = CardBillsBoard.build(data, today).pending.first;
    expect(below.value, c(30000));
    expect(below.informedBelowItems, isTrue);

    // Apagar o valor informado volta à soma dos itens; nada se perde.
    data = applyChange(data, setInformedAmount(below, null, data));
    expect(CardBillsBoard.build(data, today).pending.first.value, c(45000));
  });

  test('fechada e não paga continua; vencida com destaque', () {
    final data = withPurchase(
      const CardBillsData(cards: [nubank]),
      id: 'p1',
      date: '2026-11-09',
      on: '2026-11-16',
    );
    final onTime = CardBillsBoard.build(data, d('2026-11-16')).pending.first;
    expect(onTime.month.toKey(), '2026-11');
    expect(onTime.isClosed, isTrue);
    expect(onTime.isOverdue, isFalse);
    final late = CardBillsBoard.build(data, d('2026-11-18')).pending.first;
    expect(late.isOverdue, isTrue);
    expect(late.dueOn, d('2026-11-17'));
  });

  test(
    'fatura vazia não fica vencida e sai quando deixa de ser atual/seguinte',
    () {
      final board = CardBillsBoard.build(
        const CardBillsData(cards: [nubank]),
        d('2027-01-20'),
      );
      expect(board.pending.map((v) => v.month.toKey()), ['2027-02', '2027-03']);
    },
  );

  test('paga vai para "Pagas" e o compromisso dela é zero', () {
    var data = withPurchase(
      const CardBillsData(cards: [nubank]),
      id: 'p1',
      amount: 50000,
    );
    data = CardBillsData(
      cards: data.cards,
      purchases: data.purchases,
      installments: data.installments,
      invoices: [paidInvoice(nubank, '2026-12', paid: 50000)],
    );
    final board = CardBillsBoard.build(data, today);
    expect(board.paid.single.month.toKey(), '2026-12');
    expect(board.paid.single.commitment, BigInt.zero);
    expect(board.pending.map((v) => v.month.toKey()), ['2027-01']);
    expect(board.committed, BigInt.zero);
  });

  test('saldo não comprometido e "Faltam R\$ X"', () {
    var data = withPurchase(
      const CardBillsData(cards: [nubank]),
      id: 'p1',
      amount: 150000,
    );
    data = CardBillsData(
      cards: data.cards,
      purchases: data.purchases,
      installments: data.installments,
      reserveEvents: [
        ReserveEvent(
          id: 'e1',
          kind: ReserveEventKind.adjustment,
          isIn: true,
          amount: c(100000),
          occurredAt: DateTime.utc(2026, 11, 1),
        ),
      ],
    );
    final board = CardBillsBoard.build(data, today);
    expect(board.reserve, c(100000));
    expect(board.committed, c(150000));
    expect(board.uncommitted, c(-50000));
    expect(board.shortfall, c(50000));
  });

  test('assinaturas ativas: só as que já começaram', () {
    final data = CardBillsData(
      cards: const [nubank],
      subscriptions: [
        Subscription(
          id: 's1',
          cardId: 'card-1',
          description: 'Streaming',
          monthlyAmount: c(3990),
          startMonth: ym('2026-12'),
        ),
        Subscription(
          id: 's2',
          cardId: 'card-1',
          description: 'Música',
          monthlyAmount: c(2190),
          startMonth: ym('2027-01'),
        ),
      ],
    );
    expect(
      CardBillsBoard.build(data, today).activeSubscriptionsMonthly,
      c(3990),
    );
  });

  test('cartão apagado: a fatura paga continua no histórico com o nome', () {
    final data = CardBillsData(
      invoices: [paidInvoice(nubank, '2026-10', paid: 777)],
    );
    final board = CardBillsBoard.build(data, today);
    expect(board.pending, isEmpty);
    expect(board.paid.single.cardName, 'Nubank');
    expect(board.paid.single.value, c(777));
  });

  test('ordem: vencimento mais próximo primeiro, entre cartões', () {
    const inter = CreditCard(
      id: 'card-2',
      name: 'Inter',
      closingDay: 1,
      dueDay: 8,
    );
    final board = CardBillsBoard.build(
      const CardBillsData(cards: [nubank, inter]),
      today,
    );
    expect(board.pending.map((v) => '${v.cardName} ${v.dueOn.toIso()}'), [
      'Inter 2026-12-08',
      'Nubank 2026-12-17',
      'Inter 2027-01-08',
      'Nubank 2027-01-17',
    ]);
  });
}
