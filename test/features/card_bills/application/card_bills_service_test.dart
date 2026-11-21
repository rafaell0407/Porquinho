@TestOn('vm')
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/card_bills/application/card_bills_service.dart';
import 'package:porquinho/features/card_bills/data/local_card_bills_repository.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/purchases.dart';

import '../domain/card_bills_fixtures.dart';

/// GF4.1 serviço do painel e GF4.2 geração de cobranças.
void main() {
  late PorquinhoDatabase db;
  late CardBillsService service;
  var now = DateTime.utc(2026, 11, 18, 15); // 12h em São Paulo
  var ids = 0;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = PorquinhoDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 18, 15);
    ids = 0;
    service = CardBillsService(
      LocalCardBillsRepository(db, 'u1'),
      clock: UserClock(now: () => now),
      newId: () => 'id-${ids++}',
    );
  });
  tearDown(() => db.close());

  test('sem nada: painel vazio e nada a gerar', () async {
    final s = await service.open();
    expect(s.data.cards, isEmpty);
    expect(s.board.pending, isEmpty);
    expect(s.board.uncommitted, BigInt.zero);
  });

  test('ao abrir gera as cobranças devidas, uma vez só', () async {
    await service.createCard('Nubank', 10, 17);
    final card = (await service.snapshot()).data.cards.single;
    await service.createSubscription(
      description: 'Streaming',
      cardId: card.id,
      monthlyAmount: c(3990),
      startMonthKey: '2026-12',
    );
    expect((await service.snapshot()).data.charges.length, 1);
    // Um mês depois (app fechado): a fatura de janeiro recebe a sua.
    now = DateTime.utc(2026, 12, 18, 15);
    var s = await service.open();
    expect(s.data.charges.map((ch) => ch.month.toKey()).toList()..sort(), [
      '2026-12',
      '2027-01',
    ]);
    s = await service.open();
    expect(s.data.charges.length, 2);
  });

  test('fluxo: compra, reserva, pagar, desfazer', () async {
    await service.createCard('Nubank', 10, 17);
    final card = (await service.snapshot()).data.cards.single;
    final plan = await service.savePurchase(
      PurchaseDraft(
        cardId: card.id,
        description: 'TV',
        purchasedOn: d('2026-11-16'),
        installmentCount: 2,
        amountMode: AmountMode.total,
        amount: c(200000),
      ),
    );
    expect(plan.installments.length, 2);
    await service.setReserve(c(150000));
    var s = await service.snapshot();
    expect(s.board.committed, c(200000));
    expect(s.board.uncommitted, c(-50000));

    final dec = s.board.pending.first;
    final preview = await service.planPay(
      dec,
      dec.value,
      PaymentSource.reserve,
    );
    expect(preview.reserveUsed, c(100000));
    await service.pay(dec, dec.value, PaymentSource.reserve, d('2026-12-15'));
    s = await service.snapshot();
    expect(s.board.reserve, c(50000));
    expect(s.board.committed, c(100000));
    expect(s.board.uncommitted, c(-50000));

    await service.undoPayment(s.board.paid.single);
    s = await service.snapshot();
    expect(s.board.reserve, c(150000));
    expect(s.board.paid, isEmpty);

    // Ajustar a reserva para o mesmo valor não grava nada.
    final before = s.data.reserveEvents.length;
    await service.setReserve(c(150000));
    expect((await service.snapshot()).data.reserveEvents.length, before);
  });

  test('erros de validação chegam como mensagem', () async {
    expect(() => service.createCard('', 10, 17), throwsA(isA<ArgumentError>()));
    expect(() => service.setReserve(c(-1)), throwsA(isA<ArgumentError>()));
  });
}
