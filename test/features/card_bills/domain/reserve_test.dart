import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/cards_and_invoices.dart';
import 'package:porquinho/features/card_bills/domain/change_set.dart';
import 'package:porquinho/features/card_bills/domain/invoice_board.dart';
import 'package:porquinho/features/card_bills/domain/purchases.dart';
import 'package:porquinho/features/card_bills/domain/reserve.dart';

import 'card_bills_fixtures.dart';

/// GF1.5 reserva por eventos e pagamento (spec §8, §9, §12).
void main() {
  final now = DateTime.utc(2026, 11, 16, 15);
  ReserveEvent adj(String id, int amount, {bool isIn = true}) => ReserveEvent(
    id: id,
    kind: ReserveEventKind.adjustment,
    isIn: isIn,
    amount: c(amount),
    occurredAt: now,
  );

  test('reserva = soma dos eventos; o app grava só a diferença', () {
    final events = <ReserveEvent>[];
    expect(reserveShown(events), BigInt.zero);
    final first = adjustmentTo(c(100000), events, id: 'a', now: now)!;
    expect(first.isIn, isTrue);
    expect(first.amount, c(100000));
    events.add(first);
    final down = adjustmentTo(c(80000), events, id: 'b', now: now)!;
    expect(down.isIn, isFalse);
    expect(down.amount, c(20000));
    events.add(down);
    expect(reserveShown(events), c(80000));
    expect(adjustmentTo(c(80000), events, id: 'c', now: now), isNull);
  });

  test('nunca negativa na tela; ajuste parte da soma bruta', () {
    final events = [adj('a', 100), adj('b', 300, isIn: false)];
    expect(reserveRaw(events), c(-200));
    expect(reserveShown(events), BigInt.zero);
    final fix = adjustmentTo(c(1000), events, id: 'c', now: now)!;
    expect(fix.amount, c(1200));
    expect(reserveShown([...events, fix]), c(1000));
  });

  test('limites da reserva', () {
    expect(validateReserveValue(maxReserve), isNull);
    expect(validateReserveValue(maxReserve + BigInt.one), isNotNull);
    expect(validateReserveValue(c(-1)), isNotNull);
    expect(
      () => adjustmentTo(c(-1), const [], id: 'x', now: now),
      throwsArgumentError,
    );
  });

  group('pagamento', () {
    final today = d('2026-11-16');
    CardBillsData scenario() {
      const base = CardBillsData(cards: [nubank]);
      final plan = planNewPurchase(
        id: 'p1',
        draft: PurchaseDraft(
          cardId: 'card-1',
          description: 'TV',
          purchasedOn: today,
          installmentCount: 1,
          amountMode: AmountMode.total,
          amount: c(120000),
        ),
        data: base,
        today: today,
      );
      final data = applyChange(base, plan.change);
      return CardBillsData(
        cards: data.cards,
        purchases: data.purchases,
        installments: data.installments,
        reserveEvents: [adj('r', 100000)],
      );
    }

    CardBillsData pay(CardBillsData data, PayInvoiceCommand cmd) =>
        CardBillsData(
          cards: data.cards,
          purchases: data.purchases,
          installments: data.installments,
          invoices: [
            ...data.invoices.where((i) => i.id != cmd.invoice.id),
            cmd.invoice,
          ],
          reserveEvents: [...data.reserveEvents, ?cmd.reserveEvent],
        );

    test('pela reserva com valor maior que ela: reserva vai a zero', () {
      final data = scenario();
      final view = CardBillsBoard.build(data, today).pending.first;
      final plan = planPayment(
        expectedAmount: view.value,
        paidAmount: c(123750),
        source: PaymentSource.reserve,
        events: data.reserveEvents,
      );
      expect(plan.reserveUsed, c(100000));
      expect(plan.warnings.single, contains('R\$ 1.000,00'));
      final cmd = buildPayment(
        view: view,
        plan: plan,
        paidOn: today,
        paymentId: 'pay-1',
        now: now,
        data: data,
      );
      expect(cmd.payment.items.single.description, 'TV');
      expect(cmd.payment.expectedAmount, c(120000));
      final paid = pay(data, cmd);
      final board = CardBillsBoard.build(paid, today);
      expect(board.reserve, BigInt.zero);
      expect(board.paid.single.value, c(123750));
      expect(board.paid.single.expectedValue, c(120000));
      expect(board.committed, BigInt.zero);
      expect(
        describeAutomaticEvent(board.lastAutomaticChange!),
        startsWith('−R\$ 1.000,00 pela fatura Nubank'),
      );

      // Desfazer: volta só o que saiu da reserva (R$ 1.000,00).
      final undo = buildUndo(paid.invoiceById(view.id)!, now);
      expect(undo.reserveEvent!.amount, c(100000));
      expect(undo.reserveEvent!.isIn, isTrue);
      expect(
        reserveShown([...paid.reserveEvents, undo.reserveEvent!]),
        c(100000),
      );
    });

    test('outras fontes: a reserva não muda', () {
      final data = scenario();
      final plan = planPayment(
        expectedAmount: c(120000),
        paidAmount: c(120000),
        source: PaymentSource.other,
        events: data.reserveEvents,
      );
      expect(plan.reserveUsed, BigInt.zero);
      expect(plan.warnings, isEmpty);
      final view = CardBillsBoard.build(data, today).pending.first;
      final cmd = buildPayment(
        view: view,
        plan: plan,
        paidOn: today,
        paymentId: 'p',
        now: now,
        data: data,
      );
      expect(cmd.reserveEvent, isNull);
    });

    test('valor menor que o previsto avisa o que deixa de contar', () {
      final plan = planPayment(
        expectedAmount: c(120000),
        paidAmount: c(100000),
        source: PaymentSource.reserve,
        events: [adj('r', 500000)],
      );
      expect(plan.reserveUsed, c(100000));
      expect(plan.warnings.single, startsWith('R\$ 200,00 deixarão de contar'));
    });

    test('R\$ 0,00 = sem valor a pagar; limites do valor pago', () {
      expect(validatePaidAmount(BigInt.zero), isNull);
      expect(validatePaidAmount(maxBillAmount), isNull);
      expect(validatePaidAmount(maxBillAmount + BigInt.one), isNotNull);
      expect(validatePaidAmount(null), isNotNull);
    });

    test('fatura paga fica congelada: editar compra não a altera', () {
      final data = scenario();
      final view = CardBillsBoard.build(data, today).pending.first;
      final plan = planPayment(
        expectedAmount: view.value,
        paidAmount: view.value,
        source: PaymentSource.other,
        events: data.reserveEvents,
      );
      final paid = pay(
        data,
        buildPayment(
          view: view,
          plan: plan,
          paidOn: today,
          paymentId: 'p',
          now: now,
          data: data,
        ),
      );
      final edited = applyChange(
        paid,
        CardBillsChange(
          writes: [
            RowWrite(
              CardBillTables.installments,
              paid.installments.single.copyWith(amount: c(1)).toRow(),
            ),
          ],
          summary: 'x',
        ),
      );
      expect(CardBillsBoard.build(edited, today).paid.single.value, c(120000));
      expect(
        () => setInformedAmount(
          CardBillsBoard.build(edited, today).paid.single,
          c(1),
          edited,
        ),
        throwsArgumentError,
      );
    });
  });
}
