import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/change_set.dart';
import 'package:porquinho/features/card_bills/domain/deterministic_id.dart';
import 'package:porquinho/features/card_bills/domain/year_month.dart';

CalendarDate d(String iso) => CalendarDate.parse(iso);
YearMonth ym(String key) => YearMonth.parse(key);
BigInt c(int centavos) => BigInt.from(centavos);

/// Cartão de referência dos testes: fecha dia 10, vence dia 17.
const nubank = CreditCard(
  id: 'card-1',
  name: 'Nubank',
  closingDay: 10,
  dueDay: 17,
);

InvoiceRecord paidInvoice(
  CreditCard card,
  String month, {
  int paid = 0,
  int reserveUsed = 0,
  String paymentId = 'pay-1',
  CalendarDate? paidOn,
}) {
  final m = ym(month);
  return InvoiceRecord(
    id: CardBillIds.invoice(card.id, m),
    cardId: card.id,
    month: m,
    closingOn: m.dayClamped(card.closingDay),
    dueOn: m.dayClamped(card.dueDay),
    payment: InvoicePayment(
      paymentId: paymentId,
      paidAmount: c(paid),
      paidOn: paidOn ?? m.dayClamped(card.dueDay),
      source: reserveUsed > 0 ? PaymentSource.reserve : PaymentSource.other,
      reserveUsed: c(reserveUsed),
      expectedAmount: c(paid),
      cardName: card.name,
    ),
  );
}

/// Aplica uma alteração aos dados em memória (mesma semântica do banco local
/// e do servidor), para encadear operações nos testes.
CardBillsData applyChange(CardBillsData data, CardBillsChange change) {
  final tables = <String, Map<String, Map<String, Object?>>>{
    CardBillTables.cards: {for (final x in data.cards) x.id: x.toRow()},
    CardBillTables.purchases: {for (final x in data.purchases) x.id: x.toRow()},
    CardBillTables.installments: {
      for (final x in data.installments) x.id: x.toRow(),
    },
    CardBillTables.subscriptions: {
      for (final x in data.subscriptions) x.id: x.toRow(),
    },
    CardBillTables.charges: {for (final x in data.charges) x.id: x.toRow()},
    CardBillTables.invoices: {for (final x in data.invoices) x.id: x.toRow()},
    CardBillTables.reserveEvents: {
      for (final x in data.reserveEvents) x.id: x.toRow(),
    },
  };
  for (final w in change.orderedWrites) {
    final table = tables[w.table]!;
    final existing = table[w.id];
    if (existing == null) {
      table[w.id] = Map.of(w.row);
    } else if (w.updateColumns == null) {
      table[w.id] = Map.of(w.row);
    } else {
      for (final col in w.updateColumns!) {
        existing[col] = w.row[col];
      }
    }
  }
  for (final del in change.orderedDeletes) {
    tables[del.table]!.remove(del.id);
  }
  return CardBillsData(
    cards: tables[CardBillTables.cards]!.values
        .map(CreditCard.fromRow)
        .toList(),
    purchases: tables[CardBillTables.purchases]!.values
        .map(Purchase.fromRow)
        .toList(),
    installments: tables[CardBillTables.installments]!.values
        .map(Installment.fromRow)
        .toList(),
    subscriptions: tables[CardBillTables.subscriptions]!.values
        .map(Subscription.fromRow)
        .toList(),
    charges: tables[CardBillTables.charges]!.values
        .map(SubscriptionCharge.fromRow)
        .toList(),
    invoices: tables[CardBillTables.invoices]!.values
        .map(InvoiceRecord.fromRow)
        .toList(),
    reserveEvents: tables[CardBillTables.reserveEvents]!.values
        .map(ReserveEvent.fromRow)
        .toList(),
  );
}
