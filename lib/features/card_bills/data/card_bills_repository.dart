import '../../../core/domain/money.dart';
import '../domain/card_bill_models.dart';
import '../domain/change_set.dart';

/// RPCs da ferramenta (migration `20261116000100_card_bills.sql`).
abstract final class CardBillsRpc {
  static const apply = 'card_bills_apply';
  static const pay = 'card_bills_pay_invoice';
  static const undo = 'card_bills_undo_payment';
}

/// Tipos de entidade na fila de envio. Cadastros seguem numa fila única
/// (ordem preservada); pagamentos e desfazer, por fatura.
abstract final class CardBillsEntity {
  static const cadastros = 'card_bills';
  static const invoice = 'card_bill_invoice';

  static bool isCardBills(String entityType) =>
      entityType == cadastros || entityType == invoice;
}

/// A fatura já foi paga por outro pagamento (outro aparelho). Na Web aparece
/// na hora para o usuário escolher; no celular, em "Precisam de atenção".
class DuplicatePaymentException implements Exception {
  const DuplicatePaymentException(this.remote);

  /// A fatura como está no servidor (com o pagamento já gravado).
  final InvoiceRecord remote;

  @override
  String toString() => 'Esta fatura já foi paga em outro aparelho.';
}

/// Dados da Gestão de Faturas. Celular: banco local + fila de envio
/// (funciona sem conexão). Web: direto no servidor (somente online).
abstract interface class CardBillsRepository {
  Future<CardBillsData> load();

  /// Grava cadastros (última gravação vence).
  Future<void> apply(CardBillsChange change);

  /// Paga a fatura inteira. Na Web, lança [DuplicatePaymentException] se
  /// outro pagamento já existir.
  Future<void> pay(PayInvoiceCommand command);

  Future<void> undo(UndoPaymentCommand command);
}

/// Parâmetros das RPCs (os mesmos na fila local e na Web).
Map<String, dynamic> applyParams(CardBillsChange change) => {
  'p_changes': change.toJson(),
  'p_summary': change.summary,
};

Map<String, dynamic> payParams(PayInvoiceCommand c) => {
  'p_invoice': c.invoice.toRow(),
  'p_reserve_event': c.reserveEvent?.toRow(),
  'p_replace_payment_id': c.replacePaymentId,
  'p_replace_undo_event': c.replaceUndoEvent?.toRow(),
  'p_summary':
      'Pagar a fatura ${c.payment.cardName} '
      '(${formatBrl(c.payment.paidAmount)})',
};

Map<String, dynamic> undoParams(UndoPaymentCommand c) => {
  'p_invoice_id': c.invoiceId,
  'p_payment_id': c.paymentId,
  'p_reserve_event': c.reserveEvent?.toRow(),
  'p_summary': 'Desfazer pagamento',
};
