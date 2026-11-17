import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/change_set.dart';
import 'package:porquinho/features/card_bills/domain/purchases.dart';

import 'card_bills_fixtures.dart';

/// GF1.3 divisão de parcelas e GF1.6 edição de compras (spec §6).
void main() {
  final today = d('2026-11-16');
  const base = CardBillsData(cards: [nubank]);

  PurchaseDraft draft({
    String date = '2026-11-16',
    int count = 3,
    int amount = 100000,
    AmountMode mode = AmountMode.total,
    String? firstMonth,
    String cardId = 'card-1',
    String description = 'Geladeira',
  }) => PurchaseDraft(
    cardId: cardId,
    description: description,
    purchasedOn: d(date),
    installmentCount: count,
    amountMode: mode,
    amount: c(amount),
    firstMonth: firstMonth == null ? null : ym(firstMonth),
  );

  group('divisão', () {
    test('parte inteira em centavos; o resto vai para a 1ª parcela', () {
      expect(splitTotal(c(100000), 3), [c(33334), c(33333), c(33333)]);
      expect(splitTotal(c(100), 3), [c(34), c(33), c(33)]);
      expect(splitTotal(c(1), 2), [c(1), c(0)]);
      expect(splitTotal(c(999), 1), [c(999)]);
      final parts = splitTotal(c(123457), 24);
      expect(parts.fold(BigInt.zero, (a, b) => a + b), c(123457));
    });

    test('modo valor da parcela: total = parcela × n', () {
      expect(totalFromInstallment(c(12550), 4), c(50200));
      final plan = planNewPurchase(
        id: 'p1',
        draft: draft(count: 4, amount: 12550, mode: AmountMode.installment),
        data: base,
        today: today,
      );
      expect(plan.installments.map((i) => i.amount), everyElement(c(12550)));
    });
  });

  group('compra nova', () {
    test('parcelas em faturas consecutivas a partir da automática', () {
      final plan = planNewPurchase(
        id: 'p1',
        draft: draft(),
        data: base,
        today: today,
      );
      expect(plan.automaticFirstMonth, ym('2026-12'));
      expect(plan.installments.map((i) => i.month), [
        ym('2026-12'),
        ym('2027-01'),
        ym('2027-02'),
      ]);
      expect(plan.installments.map((i) => i.number), [1, 2, 3]);
      expect(plan.warnings, isEmpty);
      expect(plan.change.writes.length, 4);
    });

    test('trocar para a fatura anterior ou a seguinte', () {
      final plan = planNewPurchase(
        id: 'p1',
        draft: draft(firstMonth: '2027-01'),
        data: base,
        today: today,
      );
      expect(plan.installments.first.month, ym('2027-01'));
    });

    test('fatura fechada e ainda não vencida recebe a parcela', () {
      final plan = planNewPurchase(
        id: 'p1',
        draft: draft(date: '2026-11-09', count: 1),
        data: base,
        today: today,
      );
      expect(plan.installments.single.month, ym('2026-11'));
      expect(plan.installments.single.paidOutside, isFalse);
    });

    test('compra antiga: parcelas em faturas vencidas contam como pagas', () {
      final plan = planNewPurchase(
        id: 'p1',
        draft: draft(date: '2026-08-20', count: 5, amount: 50000),
        data: base,
        today: today,
      );
      expect(plan.installments.map((i) => i.month.toKey()), [
        '2026-09',
        '2026-10',
        '2026-11',
        '2026-12',
        '2027-01',
      ]);
      expect(plan.installments.map((i) => i.paidOutside), [
        true,
        true,
        false,
        false,
        false,
      ]);
      expect(plan.paidOutsideCount, 2);
      expect(plan.warnings.single, contains('2 parcelas'));
    });

    test('1ª parcela em fatura já paga vai para a próxima pendente', () {
      final data = CardBillsData(
        cards: const [nubank],
        invoices: [paidInvoice(nubank, '2026-12')],
      );
      final plan = planNewPurchase(
        id: 'p1',
        draft: draft(),
        data: data,
        today: today,
      );
      expect(plan.installments.map((i) => i.month.toKey()), [
        '2027-01',
        '2027-02',
        '2027-03',
      ]);
      expect(plan.warnings.single, contains('já foi paga'));
    });

    test('validação: data futura, parcelas 1–24, valor e limite', () {
      expect(
        validatePurchaseDraft(draft(date: '2026-11-17'), base, today),
        contains('date'),
      );
      expect(
        validatePurchaseDraft(draft(count: 0), base, today),
        contains('count'),
      );
      expect(
        validatePurchaseDraft(draft(count: 25), base, today),
        contains('count'),
      );
      expect(validatePurchaseDraft(draft(count: 24), base, today), isEmpty);
      expect(
        validatePurchaseDraft(draft(amount: 0), base, today),
        contains('amount'),
      );
      expect(
        validatePurchaseDraft(draft(amount: 100000000, count: 1), base, today),
        isEmpty,
      );
      expect(
        validatePurchaseDraft(draft(amount: 100000001, count: 1), base, today),
        contains('amount'),
      );
      expect(
        validatePurchaseDraft(
          draft(amount: 50000000, count: 3, mode: AmountMode.installment),
          base,
          today,
        ),
        contains('amount'),
      );
      expect(
        validatePurchaseDraft(draft(description: ' '), base, today),
        contains('description'),
      );
      expect(
        validatePurchaseDraft(draft(cardId: 'x'), base, today),
        contains('card'),
      );
    });
  });

  group('edição', () {
    CardBillsData withPurchase({int count = 10, int amount = 1000000}) {
      final plan = planNewPurchase(
        id: 'p1',
        draft: draft(count: count, amount: amount),
        data: base,
        today: today,
      );
      return applyChange(base, plan.change);
    }

    test('só a descrição: parcelas intactas, inclusive ajustes à mão', () {
      var data = withPurchase(count: 3, amount: 30000);
      final first = data.installmentsOf('p1').first;
      data = applyChange(
        data,
        editInstallment(
          installment: first,
          amount: c(5000),
          andFollowing: false,
          data: data,
        ),
      );
      final plan = planPurchaseEdit(
        existing: data.purchase('p1')!,
        draft: draft(count: 3, amount: 25000, description: 'Fogão'),
        data: data,
        today: today,
      );
      expect(plan.change.writes.single.table, CardBillTables.purchases);
      final after = applyChange(data, plan.change);
      expect(after.installmentsOf('p1').first.amount, c(5000));
      expect(after.purchase('p1')!.description, 'Fogão');
    });

    test('3 de 10 pagas → 8: pagas ficam, restante dividido em 5', () {
      var data = withPurchase();
      // Fatura de dezembro paga e janeiro/fevereiro pagos fora (3 primeiras).
      final inst = data.installmentsOf('p1');
      data = CardBillsData(
        cards: data.cards,
        purchases: data.purchases,
        installments: [
          for (final i in inst)
            i.number <= 3 ? i.copyWith(paidOutside: true) : i,
        ],
      );
      final plan = planPurchaseEdit(
        existing: data.purchase('p1')!,
        draft: draft(count: 8, amount: 1000000),
        data: data,
        today: today,
      );
      final after = applyChange(data, plan.change).installmentsOf('p1');
      expect(after.length, 8);
      expect(after.take(3).map((i) => i.amount), everyElement(c(100000)));
      expect(after.skip(3).map((i) => i.amount), everyElement(c(140000)));
      expect(after.map((i) => i.month.toKey()).last, '2027-07');
      expect(plan.change.deletes.length, 2);
      expect(after.fold(BigInt.zero, (s, i) => s + i.amount), c(1000000));
    });

    test('nº de parcelas menor ou igual ao de pagas é recusado', () {
      var data = withPurchase();
      data = CardBillsData(
        cards: data.cards,
        purchases: data.purchases,
        installments: [
          for (final i in data.installmentsOf('p1'))
            i.number <= 3 ? i.copyWith(paidOutside: true) : i,
        ],
      );
      expect(
        () => planPurchaseEdit(
          existing: data.purchase('p1')!,
          draft: draft(count: 3, amount: 1000000),
          data: data,
          today: today,
        ),
        throwsArgumentError,
      );
      expect(
        () => planPurchaseEdit(
          existing: data.purchase('p1')!,
          draft: draft(count: 5, amount: 300000),
          data: data,
          today: today,
        ),
        throwsArgumentError,
        reason: 'novo total igual ao já pago',
      );
    });

    test(
      'compra inteira: recalcula só as de faturas pendentes; avisa ajustes',
      () {
        var data = withPurchase(count: 3, amount: 30000);
        data = CardBillsData(
          cards: data.cards,
          purchases: data.purchases,
          installments: data.installments,
          invoices: [paidInvoice(nubank, '2026-12', paid: 10000)],
        );
        final second = data.installmentsOf('p1')[1];
        data = applyChange(
          data,
          editInstallment(
            installment: second,
            amount: c(9000),
            andFollowing: false,
            data: data,
          ),
        );
        expect(hasManualPendingInstallments('p1', data), isTrue);
        final plan = planPurchaseEdit(
          existing: data.purchase('p1')!,
          draft: draft(count: 3, amount: 40000),
          data: data,
          today: today,
        );
        expect(plan.warnings.first, contains('à mão'));
        final after = applyChange(data, plan.change).installmentsOf('p1');
        expect(after.map((i) => i.amount), [c(10000), c(15000), c(15000)]);
        expect(after[1].manuallyEdited, isFalse);
      },
    );

    test('trocar o cartão move só as pendentes', () {
      const other = CreditCard(
        id: 'card-2',
        name: 'Inter',
        closingDay: 1,
        dueDay: 8,
      );
      var data = withPurchase(count: 2, amount: 20000);
      data = CardBillsData(
        cards: const [nubank, other],
        purchases: data.purchases,
        installments: data.installments,
        invoices: [paidInvoice(nubank, '2026-12', paid: 10000)],
      );
      final plan = planPurchaseEdit(
        existing: data.purchase('p1')!,
        draft: draft(count: 2, amount: 20000, cardId: 'card-2'),
        data: data,
        today: today,
      );
      final after = applyChange(data, plan.change).installmentsOf('p1');
      expect(after[0].cardId, 'card-1');
      expect(after[1].cardId, 'card-2');
    });

    test('editar esta e as próximas muda só as pendentes dali em diante', () {
      var data = withPurchase(count: 4, amount: 40000);
      final second = data.installmentsOf('p1')[1];
      data = applyChange(
        data,
        editInstallment(
          installment: second,
          amount: c(12000),
          andFollowing: true,
          data: data,
        ),
      );
      expect(data.installmentsOf('p1').map((i) => i.amount), [
        c(10000),
        c(12000),
        c(12000),
        c(12000),
      ]);
      expect(data.installmentsOf('p1').first.manuallyEdited, isFalse);
    });

    test('parcela paga não pode ser editada', () {
      var data = withPurchase(count: 2, amount: 20000);
      data = CardBillsData(
        cards: data.cards,
        purchases: data.purchases,
        installments: data.installments,
        invoices: [paidInvoice(nubank, '2026-12', paid: 10000)],
      );
      expect(
        () => editInstallment(
          installment: data.installmentsOf('p1').first,
          amount: c(1),
          andFollowing: false,
          data: data,
        ),
        throwsArgumentError,
      );
    });

    test('apagar a compra remove compra e parcelas', () {
      final data = withPurchase(count: 3, amount: 30000);
      final after = applyChange(
        data,
        deletePurchase(data.purchase('p1')!, data),
      );
      expect(after.purchases, isEmpty);
      expect(after.installments, isEmpty);
    });
  });
}
