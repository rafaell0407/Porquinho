import 'dart:convert';

import '../domain/card_bill_models.dart';
import '../domain/change_set.dart';

/// Conversão entre o formato comum das linhas (JSON do domínio/servidor) e o
/// banco local (SQLite): booleanos 0/1, centavos e JSON como texto.
Object? toSqlValue(String column, Object? value) {
  if (value == null) return null;
  if (CardBillTables.booleanColumns.contains(column)) {
    return value == true || value == 1 ? 1 : 0;
  }
  if (CardBillTables.jsonColumns.contains(column)) {
    return value is String ? value : jsonEncode(value);
  }
  if (column.endsWith('_centavos')) return value.toString();
  return value;
}

/// Monta os dados a partir das linhas de cada tabela.
CardBillsData dataFromRows(Map<String, List<Map<String, Object?>>> rows) {
  List<Map<String, Object?>> of(String t) => rows[t] ?? const [];
  return CardBillsData(
    cards: of(CardBillTables.cards).map(CreditCard.fromRow).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    purchases: of(CardBillTables.purchases).map(Purchase.fromRow).toList()
      ..sort((a, b) => b.purchasedOn.compareTo(a.purchasedOn)),
    installments: of(
      CardBillTables.installments,
    ).map(Installment.fromRow).toList(),
    subscriptions: of(
      CardBillTables.subscriptions,
    ).map(Subscription.fromRow).toList(),
    charges: of(
      CardBillTables.charges,
    ).map(SubscriptionCharge.fromRow).toList(),
    invoices: of(CardBillTables.invoices).map(InvoiceRecord.fromRow).toList(),
    reserveEvents: of(
      CardBillTables.reserveEvents,
    ).map(ReserveEvent.fromRow).toList(),
  );
}

/// Só as colunas conhecidas (o servidor devolve também `owner_id` e datas).
Map<String, Object?> knownColumns(String table, Map<String, Object?> row) => {
  for (final c in CardBillTables.columns[table]!) c: row[c],
};
