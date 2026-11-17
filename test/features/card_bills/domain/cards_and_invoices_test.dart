import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/cards_and_invoices.dart';
import 'package:porquinho/features/card_bills/domain/invoice_board.dart';
import 'package:porquinho/features/card_bills/domain/purchases.dart';
import 'package:porquinho/features/card_bills/domain/subscriptions.dart';

import 'card_bills_fixtures.dart';

/// Cartões e faturas: mudança de dias, apagar cartão, valor informado,
/// datas corrigidas (spec §4, §5).
void main() {
  final today = d('2026-11-16');

  CardBillsData withPurchase(CardBillsData data, String date, int count) {
    final plan = planNewPurchase(
      id: 'p-$date',
      draft: PurchaseDraft(
        cardId: 'card-1',
        description: 'Compra',
        purchasedOn: d(date),
        installmentCount: count,
        amountMode: AmountMode.total,
        amount: c(10000 * count),
      ),
      data: data,
      today: today,
    );
    return applyChange(data, plan.change);
  }

  test('validação do cartão', () {
    expect(validateCard('', 10, 17), isNotNull);
    expect(validateCard('Nubank', 10, 17), isNull);
    expect(validateCard('Nubank', 32, 17), isNotNull);
  });

  test('mudar o dia só mexe nas pendentes não fechadas, sem mover compras', () {
    var data = withPurchase(
      const CardBillsData(cards: [nubank]),
      '2026-11-09',
      3,
    );
    // Novembro fechado (com parcela); dezembro com valor informado; janeiro
    // com datas corrigidas à mão.
    var board = CardBillsBoard.build(data, today);
    data = applyChange(
      data,
      setInformedAmount(board.pending[1], c(5000), data),
    );
    board = CardBillsBoard.build(data, today);
    final jan = board.pending.firstWhere((v) => v.month.toKey() == '2027-01');
    data = applyChange(
      data,
      correctInvoiceDates(
        view: jan,
        closing: d('2027-01-08'),
        due: d('2027-01-15'),
        data: data,
      ),
    );
    final updated = nubank.copyWith(closingDay: 5, dueDay: 12);
    data = applyChange(
      data,
      editCard(existing: nubank, updated: updated, data: data, today: today),
    );
    final byMonth = {for (final i in data.invoices) i.month.toKey(): i};
    expect(
      byMonth['2026-11']!.closingOn,
      d('2026-11-10'),
      reason: 'fechada: datas antigas',
    );
    expect(byMonth['2026-12']!.closingOn, d('2026-12-05'));
    expect(byMonth['2026-12']!.dueOn, d('2026-12-12'));
    expect(
      byMonth['2027-01']!.closingOn,
      d('2027-01-08'),
      reason: 'corrigida à mão',
    );
    expect(
      data.installments.map((i) => i.month.toKey()),
      containsAll(['2026-11', '2026-12', '2027-01']),
    );
    expect(data.card('card-1')!.closingDay, 5);
  });

  test('apagar o cartão: some tudo dele, menos as faturas pagas', () {
    final afterDue = d('2026-11-18'); // novembro venceu dia 17
    var data = withPurchase(
      const CardBillsData(cards: [nubank]),
      '2026-11-16',
      2,
    );
    data = CardBillsData(
      cards: data.cards,
      purchases: data.purchases,
      installments: data.installments,
      subscriptions: [
        Subscription(
          id: 's1',
          cardId: 'card-1',
          description: 'Streaming',
          monthlyAmount: c(3990),
          startMonth: ym('2026-12'),
        ),
      ],
      invoices: [paidInvoice(nubank, '2026-10', paid: 5000)],
    );
    data = applyChange(data, generateCharges(data, afterDue));
    final board = CardBillsBoard.build(data, afterDue);
    expect(cardCommitment('card-1', board), c(23990));
    data = applyChange(data, deleteCard(nubank, data));
    expect(data.cards, isEmpty);
    expect(data.purchases, isEmpty);
    expect(data.installments, isEmpty);
    expect(data.subscriptions, isEmpty);
    expect(data.charges, isEmpty);
    expect(data.invoices.single.isPaid, isTrue);
    expect(CardBillsBoard.build(data, afterDue).paid.single.cardName, 'Nubank');
  });

  test(
    'corrigir datas recusa vencimento antes do fechamento; paga não muda',
    () {
      const data = CardBillsData(cards: [nubank]);
      final dec = CardBillsBoard.build(data, today).pending.first;
      expect(
        () => correctInvoiceDates(
          view: dec,
          closing: d('2026-12-10'),
          due: d('2026-12-09'),
          data: data,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'msg',
            'O vencimento precisa ser depois do fechamento.',
          ),
        ),
      );
      final ok = applyChange(
        data,
        correctInvoiceDates(
          view: dec,
          closing: d('2026-12-09'),
          due: d('2026-12-16'),
          data: data,
        ),
      );
      final view = CardBillsBoard.build(ok, today).pending.first;
      expect(view.dueOn, d('2026-12-16'));
      expect(view.datesManual, isTrue);
    },
  );

  test('valor informado: limites', () {
    expect(validateInformedAmount(BigInt.zero), isNull);
    expect(validateInformedAmount(maxBillAmount + BigInt.one), isNotNull);
    expect(validateInformedAmount(c(-1)), isNotNull);
  });
}
