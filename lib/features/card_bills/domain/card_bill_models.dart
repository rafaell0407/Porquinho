import 'dart:convert';

import '../../../core/domain/calendar_date.dart';
import 'year_month.dart';

/// Registros da Gestão de Faturas de Cartões (spec `docs/ferramentas/
/// gestao_de_faturas.md`). Valores em centavos ([BigInt]); datas civis.
///
/// `toRow`/`fromRow` usam o mesmo formato (snake_case, JSON) no banco local,
/// na fila de envio e no servidor, para que os dois lados guardem o mesmo.

/// Limite por compra, parcela, cobrança, valor informado e pagamento
/// (R$ 1.000.000,00, spec §15).
final BigInt maxBillAmount = BigInt.from(100000000);

/// Teto da reserva (R$ 10.000.000,00, spec §9).
final BigInt maxReserve = BigInt.from(1000000000);

const maxInstallments = 24;

BigInt _amount(Object? value) => BigInt.parse(value.toString());
BigInt? _amountOrNull(Object? value) =>
    value == null ? null : BigInt.parse(value.toString());
bool _bool(Object? value) => value == true || value == 1;
int _int(Object? value) => value is int ? value : int.parse(value.toString());

class CreditCard {
  const CreditCard({
    required this.id,
    required this.name,
    required this.closingDay,
    required this.dueDay,
  });

  final String id;
  final String name;
  final int closingDay;
  final int dueDay;

  CreditCard copyWith({String? name, int? closingDay, int? dueDay}) =>
      CreditCard(
        id: id,
        name: name ?? this.name,
        closingDay: closingDay ?? this.closingDay,
        dueDay: dueDay ?? this.dueDay,
      );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'closing_day': closingDay,
    'due_day': dueDay,
  };

  static CreditCard fromRow(Map<String, Object?> r) => CreditCard(
    id: r['id']! as String,
    name: r['name']! as String,
    closingDay: _int(r['closing_day']),
    dueDay: _int(r['due_day']),
  );
}

enum AmountMode {
  total('total'),
  installment('installment');

  const AmountMode(this.wire);
  final String wire;

  static AmountMode parse(Object? v) =>
      v == 'installment' ? AmountMode.installment : AmountMode.total;
}

class Purchase {
  const Purchase({
    required this.id,
    required this.cardId,
    required this.description,
    required this.purchasedOn,
    required this.installmentCount,
    this.amountMode = AmountMode.total,
  });

  final String id;
  final String cardId;
  final String description;
  final CalendarDate purchasedOn;
  final int installmentCount;
  final AmountMode amountMode;

  Purchase copyWith({
    String? cardId,
    String? description,
    CalendarDate? purchasedOn,
    int? installmentCount,
    AmountMode? amountMode,
  }) => Purchase(
    id: id,
    cardId: cardId ?? this.cardId,
    description: description ?? this.description,
    purchasedOn: purchasedOn ?? this.purchasedOn,
    installmentCount: installmentCount ?? this.installmentCount,
    amountMode: amountMode ?? this.amountMode,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'card_id': cardId,
    'description': description,
    'purchased_on': purchasedOn.toIso(),
    'installment_count': installmentCount,
    'amount_mode': amountMode.wire,
  };

  static Purchase fromRow(Map<String, Object?> r) => Purchase(
    id: r['id']! as String,
    cardId: r['card_id']! as String,
    description: r['description']! as String,
    purchasedOn: CalendarDate.parse(r['purchased_on']! as String),
    installmentCount: _int(r['installment_count']),
    amountMode: AmountMode.parse(r['amount_mode']),
  );
}

/// Parcela k de uma compra, na fatura do cartão [cardId] do mês [month].
/// [paidOutside]: compra antiga cuja parcela caiu em fatura já vencida ou paga
/// — tratada como paga fora da ferramenta (spec §6), não conta em fatura.
class Installment {
  const Installment({
    required this.id,
    required this.purchaseId,
    required this.number,
    required this.cardId,
    required this.month,
    required this.amount,
    this.manuallyEdited = false,
    this.paidOutside = false,
  });

  final String id;
  final String purchaseId;
  final int number;
  final String cardId;
  final YearMonth month;
  final BigInt amount;
  final bool manuallyEdited;
  final bool paidOutside;

  Installment copyWith({
    String? cardId,
    YearMonth? month,
    BigInt? amount,
    bool? manuallyEdited,
    bool? paidOutside,
  }) => Installment(
    id: id,
    purchaseId: purchaseId,
    number: number,
    cardId: cardId ?? this.cardId,
    month: month ?? this.month,
    amount: amount ?? this.amount,
    manuallyEdited: manuallyEdited ?? this.manuallyEdited,
    paidOutside: paidOutside ?? this.paidOutside,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'purchase_id': purchaseId,
    'number': number,
    'card_id': cardId,
    'invoice_month': month.toKey(),
    'amount_centavos': amount.toString(),
    'manually_edited': manuallyEdited,
    'paid_outside': paidOutside,
  };

  static Installment fromRow(Map<String, Object?> r) => Installment(
    id: r['id']! as String,
    purchaseId: r['purchase_id']! as String,
    number: _int(r['number']),
    cardId: r['card_id']! as String,
    month: YearMonth.parse(r['invoice_month']! as String),
    amount: _amount(r['amount_centavos']),
    manuallyEdited: _bool(r['manually_edited']),
    paidOutside: _bool(r['paid_outside']),
  );

  @override
  bool operator ==(Object other) =>
      other is Installment &&
      other.id == id &&
      other.purchaseId == purchaseId &&
      other.number == number &&
      other.cardId == cardId &&
      other.month == month &&
      other.amount == amount &&
      other.manuallyEdited == manuallyEdited &&
      other.paidOutside == paidOutside;

  @override
  int get hashCode => Object.hash(id, number, cardId, month, amount);
}

class Subscription {
  const Subscription({
    required this.id,
    required this.cardId,
    required this.description,
    required this.monthlyAmount,
    required this.startMonth,
  });

  final String id;
  final String cardId;
  final String description;
  final BigInt monthlyAmount;

  /// Mês de referência da fatura da primeira cobrança.
  final YearMonth startMonth;

  Subscription copyWith({
    String? cardId,
    String? description,
    BigInt? monthlyAmount,
    YearMonth? startMonth,
  }) => Subscription(
    id: id,
    cardId: cardId ?? this.cardId,
    description: description ?? this.description,
    monthlyAmount: monthlyAmount ?? this.monthlyAmount,
    startMonth: startMonth ?? this.startMonth,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'card_id': cardId,
    'description': description,
    'monthly_amount_centavos': monthlyAmount.toString(),
    'start_month': startMonth.toKey(),
  };

  static Subscription fromRow(Map<String, Object?> r) => Subscription(
    id: r['id']! as String,
    cardId: r['card_id']! as String,
    description: r['description']! as String,
    monthlyAmount: _amount(r['monthly_amount_centavos']),
    startMonth: YearMonth.parse(r['start_month']! as String),
  );
}

/// Cobrança de uma assinatura numa fatura: item próprio, editável ou
/// removível só nela. [removed] = removida à mão (não reaparece, spec §7).
class SubscriptionCharge {
  const SubscriptionCharge({
    required this.id,
    required this.subscriptionId,
    required this.cardId,
    required this.month,
    required this.description,
    required this.amount,
    this.manuallyEdited = false,
    this.removed = false,
  });

  final String id;
  final String subscriptionId;
  final String cardId;
  final YearMonth month;
  final String description;
  final BigInt amount;
  final bool manuallyEdited;
  final bool removed;

  SubscriptionCharge copyWith({
    String? description,
    BigInt? amount,
    bool? manuallyEdited,
    bool? removed,
  }) => SubscriptionCharge(
    id: id,
    subscriptionId: subscriptionId,
    cardId: cardId,
    month: month,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    manuallyEdited: manuallyEdited ?? this.manuallyEdited,
    removed: removed ?? this.removed,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'subscription_id': subscriptionId,
    'card_id': cardId,
    'invoice_month': month.toKey(),
    'description': description,
    'amount_centavos': amount.toString(),
    'manually_edited': manuallyEdited,
    'removed': removed,
  };

  static SubscriptionCharge fromRow(Map<String, Object?> r) =>
      SubscriptionCharge(
        id: r['id']! as String,
        subscriptionId: r['subscription_id']! as String,
        cardId: r['card_id']! as String,
        month: YearMonth.parse(r['invoice_month']! as String),
        description: r['description']! as String,
        amount: _amount(r['amount_centavos']),
        manuallyEdited: _bool(r['manually_edited']),
        removed: _bool(r['removed']),
      );
}

enum PaymentSource {
  reserve('reserve'),
  other('other');

  const PaymentSource(this.wire);
  final String wire;

  static PaymentSource parse(Object? v) =>
      v == 'reserve' ? PaymentSource.reserve : PaymentSource.other;
}

/// Item copiado como texto no momento do pagamento (histórico, spec §10).
class SnapshotItem {
  const SnapshotItem(this.description, this.amount);

  final String description;
  final BigInt amount;

  Map<String, Object?> toJson() => {
    'description': description,
    'amount_centavos': amount.toString(),
  };

  static SnapshotItem fromJson(Map<String, dynamic> j) => SnapshotItem(
    j['description'] as String,
    BigInt.parse(j['amount_centavos'].toString()),
  );
}

/// Pagamento da fatura inteira (spec §8). [reserveUsed] = quanto saiu da
/// reserva (o restante veio de outras fontes).
class InvoicePayment {
  const InvoicePayment({
    required this.paymentId,
    required this.paidAmount,
    required this.paidOn,
    required this.source,
    required this.reserveUsed,
    required this.expectedAmount,
    required this.cardName,
    this.items = const [],
  });

  final String paymentId;
  final BigInt paidAmount;
  final CalendarDate paidOn;
  final PaymentSource source;
  final BigInt reserveUsed;
  final BigInt expectedAmount;
  final String cardName;
  final List<SnapshotItem> items;
}

enum InvoiceStatus { pending, paid }

/// Fatura gravada. Só existe quando precisa guardar algo próprio (valor
/// informado, datas corrigidas, pagamento ou datas anteriores a uma mudança
/// do cartão); as demais são calculadas a partir do cartão.
class InvoiceRecord {
  const InvoiceRecord({
    required this.id,
    required this.cardId,
    required this.month,
    required this.closingOn,
    required this.dueOn,
    this.datesManual = false,
    this.informedAmount,
    this.payment,
  });

  final String id;
  final String cardId;
  final YearMonth month;
  final CalendarDate closingOn;
  final CalendarDate dueOn;
  final bool datesManual;
  final BigInt? informedAmount;
  final InvoicePayment? payment;

  InvoiceStatus get status =>
      payment == null ? InvoiceStatus.pending : InvoiceStatus.paid;
  bool get isPaid => payment != null;

  InvoiceRecord copyWith({
    CalendarDate? closingOn,
    CalendarDate? dueOn,
    bool? datesManual,
    BigInt? Function()? informedAmount,
    InvoicePayment? Function()? payment,
  }) => InvoiceRecord(
    id: id,
    cardId: cardId,
    month: month,
    closingOn: closingOn ?? this.closingOn,
    dueOn: dueOn ?? this.dueOn,
    datesManual: datesManual ?? this.datesManual,
    informedAmount: informedAmount == null
        ? this.informedAmount
        : informedAmount(),
    payment: payment == null ? this.payment : payment(),
  );

  Map<String, Object?> toRow() {
    final p = payment;
    return {
      'id': id,
      'card_id': cardId,
      'invoice_month': month.toKey(),
      'closing_on': closingOn.toIso(),
      'due_on': dueOn.toIso(),
      'dates_manual': datesManual,
      'informed_amount_centavos': informedAmount?.toString(),
      'status': p == null ? 'pending' : 'paid',
      'payment_id': p?.paymentId,
      'paid_amount_centavos': p?.paidAmount.toString(),
      'paid_on': p?.paidOn.toIso(),
      'payment_source': p?.source.wire,
      'reserve_used_centavos': p?.reserveUsed.toString(),
      'expected_amount_centavos': p?.expectedAmount.toString(),
      'card_name': p?.cardName,
      'items_snapshot': p == null
          ? null
          : [for (final i in p.items) i.toJson()],
    };
  }

  static InvoiceRecord fromRow(Map<String, Object?> r) {
    InvoicePayment? payment;
    if (r['status'] == 'paid') {
      var snapshot = r['items_snapshot'];
      if (snapshot is String) snapshot = jsonDecode(snapshot);
      payment = InvoicePayment(
        paymentId: r['payment_id']! as String,
        paidAmount: _amount(r['paid_amount_centavos']),
        paidOn: CalendarDate.parse(r['paid_on']! as String),
        source: PaymentSource.parse(r['payment_source']),
        reserveUsed: _amount(r['reserve_used_centavos']),
        expectedAmount: _amount(r['expected_amount_centavos']),
        cardName: (r['card_name'] as String?) ?? '',
        items: [
          for (final i in (snapshot as List?) ?? const [])
            SnapshotItem.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
      );
    }
    return InvoiceRecord(
      id: r['id']! as String,
      cardId: r['card_id']! as String,
      month: YearMonth.parse(r['invoice_month']! as String),
      closingOn: CalendarDate.parse(r['closing_on']! as String),
      dueOn: CalendarDate.parse(r['due_on']! as String),
      datesManual: _bool(r['dates_manual']),
      informedAmount: _amountOrNull(r['informed_amount_centavos']),
      payment: payment,
    );
  }
}

enum ReserveEventKind {
  adjustment('adjustment'),
  payment('payment'),
  paymentUndo('payment_undo');

  const ReserveEventKind(this.wire);
  final String wire;

  static ReserveEventKind parse(Object? v) => switch (v) {
    'payment' => ReserveEventKind.payment,
    'payment_undo' => ReserveEventKind.paymentUndo,
    _ => ReserveEventKind.adjustment,
  };

  bool get isAutomatic => this != ReserveEventKind.adjustment;
}

/// Evento da reserva (spec §12): a reserva é a soma deles, nunca sobrescrita.
/// [amount] é sempre positivo; [isIn] diz se entra (true) ou sai.
class ReserveEvent {
  const ReserveEvent({
    required this.id,
    required this.kind,
    required this.isIn,
    required this.amount,
    required this.occurredAt,
    this.invoiceId,
    this.label,
  });

  final String id;
  final ReserveEventKind kind;
  final bool isIn;
  final BigInt amount;
  final DateTime occurredAt;
  final String? invoiceId;

  /// Texto da mudança automática ("pela fatura Nubank que vence em 10/12").
  final String? label;

  BigInt get signed => isIn ? amount : -amount;

  Map<String, Object?> toRow() => {
    'id': id,
    'kind': kind.wire,
    'direction': isIn ? 'in' : 'out',
    'amount_centavos': amount.toString(),
    'invoice_id': invoiceId,
    'label': label,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };

  static ReserveEvent fromRow(Map<String, Object?> r) => ReserveEvent(
    id: r['id']! as String,
    kind: ReserveEventKind.parse(r['kind']),
    isIn: r['direction'] == 'in',
    amount: _amount(r['amount_centavos']),
    occurredAt: DateTime.parse(r['occurred_at']! as String).toUtc(),
    invoiceId: r['invoice_id'] as String?,
    label: r['label'] as String?,
  );
}

/// Tudo o que a ferramenta guarda de um usuário.
class CardBillsData {
  const CardBillsData({
    this.cards = const [],
    this.purchases = const [],
    this.installments = const [],
    this.subscriptions = const [],
    this.charges = const [],
    this.invoices = const [],
    this.reserveEvents = const [],
  });

  static const empty = CardBillsData();

  final List<CreditCard> cards;
  final List<Purchase> purchases;
  final List<Installment> installments;
  final List<Subscription> subscriptions;
  final List<SubscriptionCharge> charges;
  final List<InvoiceRecord> invoices;
  final List<ReserveEvent> reserveEvents;

  CreditCard? card(String id) => cards.where((c) => c.id == id).firstOrNull;
  Purchase? purchase(String id) =>
      purchases.where((p) => p.id == id).firstOrNull;
  Subscription? subscription(String id) =>
      subscriptions.where((s) => s.id == id).firstOrNull;

  InvoiceRecord? invoice(String cardId, YearMonth month) =>
      invoices.where((i) => i.cardId == cardId && i.month == month).firstOrNull;

  InvoiceRecord? invoiceById(String id) =>
      invoices.where((i) => i.id == id).firstOrNull;

  List<Installment> installmentsOf(String purchaseId) =>
      installments.where((i) => i.purchaseId == purchaseId).toList()
        ..sort((a, b) => a.number.compareTo(b.number));
}
