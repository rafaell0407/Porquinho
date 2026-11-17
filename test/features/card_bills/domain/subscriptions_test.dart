import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/deterministic_id.dart';
import 'package:porquinho/features/card_bills/domain/invoice_board.dart';
import 'package:porquinho/features/card_bills/domain/subscriptions.dart';

import 'card_bills_fixtures.dart';

/// GF1.7 assinaturas (spec §7).
void main() {
  final today = d('2026-11-18'); // novembro venceu dia 17: recebe dezembro
  final streaming = Subscription(
    id: 's1',
    cardId: 'card-1',
    description: 'Streaming',
    monthlyAmount: c(3990),
    startMonth: ym('2026-12'),
  );
  final base = CardBillsData(cards: const [nubank], subscriptions: [streaming]);

  test('gera só na fatura atual, nunca projetada nas seguintes', () {
    final charges = chargesToGenerate(base, today);
    expect(charges.single.month, ym('2026-12'));
    expect(charges.single.id, CardBillIds.charge('s1', ym('2026-12')));
    final data = applyChange(base, generateCharges(base, today));
    final board = CardBillsBoard.build(data, today);
    expect(board.pending[0].items.single.description, 'Streaming');
    expect(board.pending[1].items, isEmpty);
  });

  test(
    'fatura fechada e ainda não vencida segue recebendo; dezembro só depois',
    () {
      final early = streaming.copyWith(startMonth: ym('2026-11'));
      final data = CardBillsData(cards: const [nubank], subscriptions: [early]);
      // 16/11: novembro fechou dia 10, vence dia 17.
      expect(
        chargesToGenerate(data, d('2026-11-16')).map((c) => c.month.toKey()),
        ['2026-11'],
      );
      // 17/11 (dia do vencimento): ainda novembro.
      expect(
        chargesToGenerate(data, d('2026-11-17')).map((c) => c.month.toKey()),
        ['2026-11'],
      );
      // 18/11: novembro venceu; entra dezembro e novembro mantém a sua.
      expect(
        chargesToGenerate(data, d('2026-11-18')).map((c) => c.month.toKey()),
        ['2026-11', '2026-12'],
      );
    },
  );

  test('sem cobrança dupla: gerar de novo não muda nada', () {
    final once = applyChange(base, generateCharges(base, today));
    expect(chargesToGenerate(once, today), isEmpty);
  });

  test('app fechado por ciclos: inclui nas não pagas desde o início', () {
    var data = applyChange(base, generateCharges(base, today));
    // Três meses depois (fatura atual: março); janeiro foi pago.
    data = CardBillsData(
      cards: data.cards,
      subscriptions: data.subscriptions,
      charges: data.charges,
      invoices: [paidInvoice(nubank, '2027-01')],
    );
    final later = chargesToGenerate(data, d('2027-02-18'));
    expect(later.map((c) => c.month.toKey()), ['2027-02', '2027-03']);
  });

  test(
    'cobrança removida à mão não reaparece; fechada sem pagar mantém a sua',
    () {
      var data = applyChange(base, generateCharges(base, today));
      data = applyChange(data, removeCharge(data.charges.single));
      expect(chargesToGenerate(data, today), isEmpty);
      expect(CardBillsBoard.build(data, today).pending.first.items, isEmpty);

      final kept = applyChange(base, generateCharges(base, today));
      final next = applyChange(kept, generateCharges(kept, d('2026-12-18')));
      final board = CardBillsBoard.build(next, d('2026-12-18'));
      expect(board.pending.first.month.toKey(), '2026-12');
      expect(board.pending.first.items.single.amount, c(3990));
      expect(board.pending[1].month.toKey(), '2027-01');
      expect(board.pending[1].items.single.amount, c(3990));
    },
  );

  test('início futuro: cobrança e "ativa" só quando a fatura vira a atual', () {
    final future = streaming.copyWith(startMonth: ym('2027-01'));
    final data = CardBillsData(cards: const [nubank], subscriptions: [future]);
    expect(chargesToGenerate(data, today), isEmpty);
    expect(
      CardBillsBoard.build(data, today).activeSubscriptionsMonthly,
      BigInt.zero,
    );
    expect(
      chargesToGenerate(data, d('2026-12-18')).single.month,
      ym('2027-01'),
    );
  });

  test('mudança de preço vale da fatura atual pendente; fechadas mantêm', () {
    var data = applyChange(base, generateCharges(base, today));
    final cheaper = streaming.copyWith(monthlyAmount: c(4590));
    data = applyChange(
      data,
      editSubscription(
        existing: streaming,
        updated: cheaper,
        data: data,
        today: today,
      ),
    );
    expect(data.charges.single.amount, c(4590));
    // Um mês depois: dezembro fechou com R$ 45,90; novo preço só em janeiro.
    final jan = d('2026-12-18');
    data = applyChange(data, generateCharges(data, jan));
    final again = cheaper.copyWith(monthlyAmount: c(5000));
    data = applyChange(
      data,
      editSubscription(
        existing: cheaper,
        updated: again,
        data: data,
        today: jan,
      ),
    );
    final byMonth = {
      for (final ch in data.charges) ch.month.toKey(): ch.amount,
    };
    expect(byMonth, {'2026-12': c(4590), '2027-01': c(5000)});
  });

  test('cobrança editada à mão não é sobrescrita pela mudança de preço', () {
    var data = applyChange(base, generateCharges(base, today));
    data = applyChange(data, editCharge(data.charges.single, c(1000)));
    data = applyChange(
      data,
      editSubscription(
        existing: streaming,
        updated: streaming.copyWith(monthlyAmount: c(9999)),
        data: data,
        today: today,
      ),
    );
    expect(data.charges.single.amount, c(1000));
    expect(data.charges.single.manuallyEdited, isTrue);
  });

  test('cancelar: vale da seguinte; pergunta pela cobrança atual', () {
    final generated = applyChange(base, generateCharges(base, today));
    final keep = applyChange(
      generated,
      cancelSubscription(
        subscription: streaming,
        removeCurrentCharge: false,
        data: generated,
        today: today,
      ),
    );
    expect(keep.subscriptions, isEmpty);
    expect(keep.charges.single.removed, isFalse);
    expect(chargesToGenerate(keep, d('2026-12-18')), isEmpty);

    final remove = applyChange(
      generated,
      cancelSubscription(
        subscription: streaming,
        removeCurrentCharge: true,
        data: generated,
        today: today,
      ),
    );
    expect(remove.charges.single.removed, isTrue);
  });

  test('validação e opções de início', () {
    expect(
      validateSubscription(
        description: '',
        cardId: 'card-1',
        monthlyAmount: c(1),
        data: base,
      ),
      isNotNull,
    );
    expect(
      validateSubscription(
        description: 'x',
        cardId: 'card-1',
        monthlyAmount: c(0),
        data: base,
      ),
      isNotNull,
    );
    expect(
      validateSubscription(
        description: 'x',
        cardId: 'card-1',
        monthlyAmount: c(1),
        data: base,
      ),
      isNull,
    );
    final options = startMonthOptions('card-1', base, today);
    expect(options.first, ym('2026-12'));
    expect(options.length, 12);
  });
}
