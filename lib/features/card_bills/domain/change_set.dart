import 'card_bill_models.dart';

/// Tabelas da ferramenta, na ordem de dependência (cada uma só referencia as
/// anteriores). Mesmos nomes e colunas no aparelho e no servidor.
abstract final class CardBillTables {
  static const cards = 'card_bill_cards';
  static const purchases = 'card_bill_purchases';
  static const installments = 'card_bill_installments';
  static const subscriptions = 'card_bill_subscriptions';
  static const charges = 'card_bill_charges';
  static const invoices = 'card_bill_invoices';
  static const reserveEvents = 'card_bill_reserve_events';

  static const ordered = [
    cards,
    purchases,
    installments,
    subscriptions,
    charges,
    invoices,
    reserveEvents,
  ];

  /// Colunas de cada tabela (além de `owner_id`, `created_at`, `updated_at`).
  static const columns = <String, List<String>>{
    cards: ['id', 'name', 'closing_day', 'due_day'],
    purchases: [
      'id',
      'card_id',
      'description',
      'purchased_on',
      'installment_count',
      'amount_mode',
    ],
    installments: [
      'id',
      'purchase_id',
      'number',
      'card_id',
      'invoice_month',
      'amount_centavos',
      'manually_edited',
      'paid_outside',
    ],
    subscriptions: [
      'id',
      'card_id',
      'description',
      'monthly_amount_centavos',
      'start_month',
    ],
    charges: [
      'id',
      'subscription_id',
      'card_id',
      'invoice_month',
      'description',
      'amount_centavos',
      'manually_edited',
      'removed',
    ],
    invoices: [
      'id',
      'card_id',
      'invoice_month',
      'closing_on',
      'due_on',
      'dates_manual',
      'informed_amount_centavos',
      'status',
      'payment_id',
      'paid_amount_centavos',
      'paid_on',
      'payment_source',
      'reserve_used_centavos',
      'expected_amount_centavos',
      'card_name',
      'items_snapshot',
    ],
    reserveEvents: [
      'id',
      'kind',
      'direction',
      'amount_centavos',
      'invoice_id',
      'label',
      'occurred_at',
    ],
  };

  static const booleanColumns = {
    'manually_edited',
    'paid_outside',
    'removed',
    'dates_manual',
  };

  static const jsonColumns = {'items_snapshot'};

  /// Colunas do pagamento: só as RPCs de pagamento as gravam.
  static const paymentColumns = [
    'status',
    'payment_id',
    'paid_amount_centavos',
    'paid_on',
    'payment_source',
    'reserve_used_centavos',
    'expected_amount_centavos',
    'card_name',
    'items_snapshot',
  ];
}

/// Gravação de uma linha.
///
/// - [updateColumns] `null`: insere ou substitui todas as colunas
///   (última gravação vence, spec §12).
/// - [updateColumns] vazio: insere só se ainda não existir (cobranças geradas
///   e eventos — nunca sobrescreve, ex.: cobrança removida à mão).
/// - [updateColumns] com nomes: insere se não existir; se existir, troca só
///   essas colunas (ex.: valor informado sem mexer nas datas).
class RowWrite {
  const RowWrite(this.table, this.row, {this.updateColumns});

  const RowWrite.insertIfAbsent(this.table, this.row)
    : updateColumns = const [];

  final String table;
  final Map<String, Object?> row;
  final List<String>? updateColumns;

  String get id => row['id']! as String;

  Map<String, Object?> toJson() => {
    'table': table,
    'row': row,
    'update_columns': updateColumns,
  };

  static RowWrite fromJson(Map<String, dynamic> j) => RowWrite(
    j['table'] as String,
    Map<String, Object?>.from(j['row'] as Map),
    updateColumns: (j['update_columns'] as List?)?.cast<String>(),
  );
}

class RowDelete {
  const RowDelete(this.table, this.id);

  final String table;
  final String id;

  Map<String, Object?> toJson() => {'table': table, 'id': id};

  static RowDelete fromJson(Map<String, dynamic> j) =>
      RowDelete(j['table'] as String, j['id'] as String);
}

/// Alteração de cadastros produzida pelo domínio: aplicada igual no banco
/// local e no servidor (RPC `card_bills_apply`). Gravações primeiro (na
/// ordem das tabelas), depois exclusões (na ordem inversa).
class CardBillsChange {
  const CardBillsChange({
    this.writes = const [],
    this.deletes = const [],
    required this.summary,
  });

  final List<RowWrite> writes;
  final List<RowDelete> deletes;

  /// Resumo em português (aparece em "Precisam de atenção" se for recusada).
  final String summary;

  bool get isEmpty => writes.isEmpty && deletes.isEmpty;

  /// Gravações ordenadas por tabela e exclusões na ordem inversa.
  List<RowWrite> get orderedWrites {
    final order = CardBillTables.ordered;
    return [
      ...writes,
    ]..sort((a, b) => order.indexOf(a.table).compareTo(order.indexOf(b.table)));
  }

  List<RowDelete> get orderedDeletes {
    final order = CardBillTables.ordered;
    return [
      ...deletes,
    ]..sort((a, b) => order.indexOf(b.table).compareTo(order.indexOf(a.table)));
  }

  CardBillsChange merge(CardBillsChange other, {String? summary}) =>
      CardBillsChange(
        writes: [...writes, ...other.writes],
        deletes: [...deletes, ...other.deletes],
        summary: summary ?? this.summary,
      );

  Map<String, Object?> toJson() => {
    'writes': [for (final w in orderedWrites) w.toJson()],
    'deletes': [for (final d in orderedDeletes) d.toJson()],
  };

  static CardBillsChange fromJson(Map<String, dynamic> j, String summary) =>
      CardBillsChange(
        writes: [
          for (final w in (j['writes'] as List? ?? const []))
            RowWrite.fromJson(Map<String, dynamic>.from(w as Map)),
        ],
        deletes: [
          for (final d in (j['deletes'] as List? ?? const []))
            RowDelete.fromJson(Map<String, dynamic>.from(d as Map)),
        ],
        summary: summary,
      );
}

/// Pagamento da fatura inteira (RPC `card_bills_pay_invoice`): a fatura com as
/// datas (para criá-la se ainda não existir no servidor), o pagamento e a
/// saída da reserva. [replacePaymentId]: ao manter este pagamento num
/// pagamento duplicado, o do outro aparelho é desfeito antes (spec §12).
class PayInvoiceCommand {
  const PayInvoiceCommand({
    required this.invoice,
    required this.reserveEvent,
    this.replacePaymentId,
    this.replaceUndoEvent,
  });

  final InvoiceRecord invoice;
  final ReserveEvent? reserveEvent;
  final String? replacePaymentId;

  /// Devolução à reserva do pagamento substituído.
  final ReserveEvent? replaceUndoEvent;

  InvoicePayment get payment => invoice.payment!;
}

/// Desfazer pagamento (RPC `card_bills_undo_payment`).
class UndoPaymentCommand {
  const UndoPaymentCommand({
    required this.invoiceId,
    required this.paymentId,
    required this.reserveEvent,
  });

  final String invoiceId;
  final String paymentId;
  final ReserveEvent? reserveEvent;
}
