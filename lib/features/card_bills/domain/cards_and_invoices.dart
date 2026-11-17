import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import 'card_bill_models.dart';
import 'card_calendar.dart';
import 'change_set.dart';
import 'deterministic_id.dart';
import 'invoice_board.dart';
import 'reserve.dart';
import 'year_month.dart';

/// Cartões (spec §4) e faturas: valor informado, datas, pagamento (§5, §8).

String? validateCard(String name, int? closingDay, int? dueDay) {
  if (name.trim().isEmpty) return 'Informe o nome do cartão.';
  return validateCardDays(closingDay, dueDay);
}

CardBillsChange createCard(CreditCard card) => CardBillsChange(
  writes: [RowWrite(CardBillTables.cards, card.toRow())],
  summary: 'Novo cartão: ${card.name}',
);

/// Meses do cartão com itens ou fatura gravada.
Set<YearMonth> _monthsWithContent(String cardId, CardBillsData data) => {
  for (final i in data.installments)
    if (i.cardId == cardId && !i.paidOutside) i.month,
  for (final c in data.charges)
    if (c.cardId == cardId && !c.removed) c.month,
};

/// Editar o cartão. Mudar o dia de fechamento ou vencimento só altera as
/// datas das faturas pendentes que ainda não fecharam, preservando as
/// corrigidas à mão; fechadas e pagas não mudam (as fechadas com itens são
/// gravadas com as datas antigas). Parcelas e cobranças não mudam de fatura.
CardBillsChange editCard({
  required CreditCard existing,
  required CreditCard updated,
  required CardBillsData data,
  required CalendarDate today,
}) {
  final writes = <RowWrite>[RowWrite(CardBillTables.cards, updated.toRow())];
  final daysChanged =
      existing.closingDay != updated.closingDay ||
      existing.dueDay != updated.dueDay;
  if (daysChanged) {
    final oldCalendar = CardCalendar(existing, data.invoices);
    for (final month in _monthsWithContent(existing.id, data)) {
      if (oldCalendar.stored(month) != null) continue;
      if (!oldCalendar.isClosed(month, today)) continue;
      writes.add(
        RowWrite.insertIfAbsent(
          CardBillTables.invoices,
          _newInvoice(existing.id, month, oldCalendar).toRow(),
        ),
      );
    }
    for (final i in data.invoices) {
      if (i.cardId != existing.id || i.isPaid || i.datesManual) continue;
      if (oldCalendar.isClosed(i.month, today)) continue;
      writes.add(
        RowWrite(
          CardBillTables.invoices,
          i
              .copyWith(
                closingOn: CardCalendar.defaultClosing(updated, i.month),
                dueOn: CardCalendar.defaultDue(updated, i.month),
              )
              .toRow(),
          updateColumns: const ['closing_on', 'due_on'],
        ),
      );
    }
  }
  return CardBillsChange(
    writes: writes,
    summary: 'Editar cartão: ${updated.name}',
  );
}

InvoiceRecord _newInvoice(
  String cardId,
  YearMonth month,
  CardCalendar calendar,
) => InvoiceRecord(
  id: _invoiceId(cardId, month, calendar),
  cardId: cardId,
  month: month,
  closingOn: calendar.closingOf(month),
  dueOn: calendar.dueOf(month),
);

String _invoiceId(String cardId, YearMonth month, CardCalendar calendar) =>
    calendar.stored(month)?.id ?? CardBillIds.invoice(cardId, month);

/// Valor que deixa de contar ao apagar o cartão (faturas pendentes dele).
BigInt cardCommitment(String cardId, CardBillsBoard board) => board.pending
    .where((v) => v.cardId == cardId)
    .fold(BigInt.zero, (s, v) => s + v.commitment);

/// Apagar o cartão: apaga compras, assinaturas, cobranças e faturas
/// pendentes dele. Faturas pagas ficam no histórico (§4, §10).
CardBillsChange deleteCard(CreditCard card, CardBillsData data) {
  final purchaseIds = {
    for (final p in data.purchases)
      if (p.cardId == card.id) p.id,
  };
  return CardBillsChange(
    deletes: [
      for (final i in data.installments)
        if (purchaseIds.contains(i.purchaseId) ||
            (i.cardId == card.id &&
                !(data.invoice(i.cardId, i.month)?.isPaid ?? false)))
          RowDelete(CardBillTables.installments, i.id),
      for (final id in purchaseIds) RowDelete(CardBillTables.purchases, id),
      for (final c in data.charges)
        if (c.cardId == card.id) RowDelete(CardBillTables.charges, c.id),
      for (final s in data.subscriptions)
        if (s.cardId == card.id) RowDelete(CardBillTables.subscriptions, s.id),
      for (final i in data.invoices)
        if (i.cardId == card.id && !i.isPaid)
          RowDelete(CardBillTables.invoices, i.id),
      RowDelete(CardBillTables.cards, card.id),
    ],
    summary: 'Apagar cartão: ${card.name}',
  );
}

/// Linha da fatura com as datas atuais (para criá-la, se ainda não existir).
InvoiceRecord invoiceRecordOf(InvoiceView view, CardBillsData data) {
  final stored = data.invoiceById(view.id);
  return stored ??
      InvoiceRecord(
        id: view.id,
        cardId: view.cardId,
        month: view.month,
        closingOn: view.closingOn,
        dueOn: view.dueOn,
      );
}

String? validateInformedAmount(BigInt? amount) {
  if (amount == null) return 'Informe o valor da fatura.';
  if (amount.isNegative) return 'O valor não pode ser negativo.';
  if (amount > maxBillAmount) {
    return 'O valor da fatura vai até ${formatBrl(maxBillAmount)}.';
  }
  return null;
}

/// Preencher (ou apagar, com `null`) o valor informado (§5.3).
CardBillsChange setInformedAmount(
  InvoiceView view,
  BigInt? amount,
  CardBillsData data,
) {
  if (view.isPaid) throw ArgumentError('Fatura paga não muda.');
  if (amount != null) {
    final error = validateInformedAmount(amount);
    if (error != null) throw ArgumentError(error);
  }
  final record = invoiceRecordOf(
    view,
    data,
  ).copyWith(informedAmount: () => amount);
  return CardBillsChange(
    writes: [
      RowWrite(
        CardBillTables.invoices,
        record.toRow(),
        updateColumns: const ['informed_amount_centavos'],
      ),
    ],
    summary: amount == null
        ? 'Apagar valor informado: ${view.cardName}'
        : 'Valor informado: ${view.cardName} ${formatBrl(amount)}',
  );
}

/// Corrigir as datas de uma fatura (o banco mudou por feriado ou fim de
/// semana). Não move compras já cadastradas (§5.1).
CardBillsChange correctInvoiceDates({
  required InvoiceView view,
  required CalendarDate closing,
  required CalendarDate due,
  required CardBillsData data,
}) {
  if (view.isPaid) throw ArgumentError('Fatura paga não muda.');
  final card = data.card(view.cardId);
  if (card == null) throw ArgumentError('Cartão não encontrado.');
  final error = CardCalendar(
    card,
    data.invoices,
  ).validateCorrection(view.month, closing, due);
  if (error != null) throw ArgumentError(error);
  final record = invoiceRecordOf(
    view,
    data,
  ).copyWith(closingOn: closing, dueOn: due, datesManual: true);
  return CardBillsChange(
    writes: [
      RowWrite(
        CardBillTables.invoices,
        record.toRow(),
        updateColumns: const ['closing_on', 'due_on', 'dates_manual'],
      ),
    ],
    summary: 'Corrigir datas: ${view.cardName}',
  );
}

/// Pagar a fatura inteira (§8): o valor pago passa a ser o definitivo, os
/// itens são copiados como texto e a reserva perde só o que saiu dela.
PayInvoiceCommand buildPayment({
  required InvoiceView view,
  required PaymentPlan plan,
  required CalendarDate paidOn,
  required String paymentId,
  required DateTime now,
  required CardBillsData data,
}) {
  if (view.isPaid) throw ArgumentError('Esta fatura já foi paga.');
  final payment = InvoicePayment(
    paymentId: paymentId,
    paidAmount: plan.paidAmount,
    paidOn: paidOn,
    source: plan.source,
    reserveUsed: plan.reserveUsed,
    expectedAmount: plan.expectedAmount,
    cardName: view.cardName,
    items: [for (final i in view.items) SnapshotItem(i.description, i.amount)],
  );
  final invoice = invoiceRecordOf(view, data).copyWith(payment: () => payment);
  return PayInvoiceCommand(
    invoice: invoice,
    reserveEvent: paymentEvent(
      paymentId: paymentId,
      invoiceId: view.id,
      reserveUsed: plan.reserveUsed,
      label: invoiceLabel(view.cardName, view.dueOn),
      now: now,
    ),
  );
}

/// Desfazer o pagamento: a fatura volta a pendente e a reserva recebe de
/// volta só o que saiu dela.
UndoPaymentCommand buildUndo(InvoiceRecord invoice, DateTime now) {
  final payment = invoice.payment;
  if (payment == null) throw ArgumentError('Esta fatura não está paga.');
  return UndoPaymentCommand(
    invoiceId: invoice.id,
    paymentId: payment.paymentId,
    reserveEvent: undoEvent(
      payment: payment,
      invoiceId: invoice.id,
      label:
          'ao desfazer o pagamento da fatura ${payment.cardName} que '
          'vence em ${invoice.dueOn.day.toString().padLeft(2, '0')}/'
          '${invoice.dueOn.month.toString().padLeft(2, '0')}',
      now: now,
    ),
  );
}
