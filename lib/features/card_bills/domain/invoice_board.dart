import '../../../core/domain/calendar_date.dart';
import 'card_bill_models.dart';
import 'card_calendar.dart';
import 'deterministic_id.dart';
import 'reserve.dart';
import 'subscriptions.dart';
import 'year_month.dart';

enum InvoiceItemKind { installment, charge }

/// Item de uma fatura (parcela ou cobrança de assinatura), gerado
/// automaticamente (spec §5.3).
class InvoiceItem {
  const InvoiceItem({
    required this.kind,
    required this.id,
    required this.description,
    required this.amount,
    required this.sourceId,
    this.manuallyEdited = false,
    this.isSinglePurchase = false,
  });

  final InvoiceItemKind kind;

  /// Compra à vista (1 parcela): o subtítulo mostra "Compra", não "Parcela".
  final bool isSinglePurchase;

  /// Id da parcela ou da cobrança.
  final String id;

  /// Descrição exibida ("Geladeira (2/10)" ou "Streaming").
  final String description;
  final BigInt amount;

  /// Compra ou assinatura de origem.
  final String sourceId;
  final bool manuallyEdited;
}

/// Uma fatura como a tela mostra (gravada ou calculada a partir do cartão).
class InvoiceView {
  InvoiceView({
    required this.id,
    required this.cardId,
    required this.cardName,
    required this.month,
    required this.closingOn,
    required this.dueOn,
    required this.datesManual,
    required this.items,
    required this.informedAmount,
    required this.payment,
    required this.isCurrent,
    required this.isNext,
    required this.isClosed,
    required this.isStored,
    required CalendarDate today,
  }) : itemsTotal = items.fold(BigInt.zero, (s, i) => s + i.amount),
       _today = today;

  final String id;
  final String cardId;
  final String cardName;
  final YearMonth month;
  final CalendarDate closingOn;
  final CalendarDate dueOn;
  final bool datesManual;
  final List<InvoiceItem> items;
  final BigInt itemsTotal;
  final BigInt? informedAmount;
  final InvoicePayment? payment;
  final bool isCurrent;
  final bool isNext;
  final bool isClosed;
  final bool isStored;
  final CalendarDate _today;

  bool get isPaid => payment != null;

  bool get hasContent => items.isNotEmpty || informedAmount != null;

  /// Valor da fatura: informado, se existir; senão, a soma dos itens. Nunca
  /// soma os dois. Paga: o valor pago é o definitivo (spec §5.3 e §8).
  BigInt get value => payment?.paidAmount ?? informedAmount ?? itemsTotal;

  /// Valor previsto antes do pagamento.
  BigInt get expectedValue =>
      payment?.expectedAmount ?? informedAmount ?? itemsTotal;

  /// Compromisso: pendente → valor; paga → zero.
  BigInt get commitment => isPaid ? BigInt.zero : value;

  /// Valor informado menor que a soma dos itens (aviso; vale o informado).
  bool get informedBelowItems =>
      informedAmount != null && informedAmount! < itemsTotal;

  /// "Outros gastos" quando há valor informado acima dos itens.
  BigInt get otherSpending => informedAmount == null || informedBelowItems
      ? BigInt.zero
      : informedAmount! - itemsTotal;

  /// Venceu: pendente, hoje depois do vencimento e com algo a pagar (fatura
  /// vazia sem valor informado não fica vencida, spec §5.2).
  bool get isOverdue => !isPaid && _today.isAfter(dueOn) && hasContent;
}

/// Painel da ferramenta: faturas pendentes, pagas e o indicador (spec §3).
class CardBillsBoard {
  CardBillsBoard._({
    required this.pending,
    required this.paid,
    required this.reserve,
    required this.committed,
    required this.activeSubscriptionsMonthly,
    required this.lastAutomaticChange,
  });

  /// Faturas a pagar, a de vencimento mais próximo primeiro.
  final List<InvoiceView> pending;

  /// Faturas pagas, a mais recente primeiro (seção "Pagas").
  final List<InvoiceView> paid;

  /// Dinheiro reservado (nunca negativo).
  final BigInt reserve;

  /// Soma das faturas pendentes de todos os cartões.
  final BigInt committed;

  /// Informativo: preço atual das assinaturas ativas por mês.
  final BigInt activeSubscriptionsMonthly;

  final ReserveEvent? lastAutomaticChange;

  /// Saldo não comprometido = reservado − comprometido (pode ser negativo).
  BigInt get uncommitted => reserve - committed;

  /// Quanto falta quando o saldo é negativo ("Faltam R$ X…").
  BigInt get shortfall => uncommitted.isNegative ? -uncommitted : BigInt.zero;

  static CardBillsBoard build(CardBillsData data, CalendarDate today) {
    final pending = <InvoiceView>[];
    final paid = <InvoiceView>[];
    final purchases = {for (final p in data.purchases) p.id: p};
    var subscriptionsMonthly = BigInt.zero;

    for (final card in data.cards) {
      final calendar = CardCalendar(card, data.invoices);
      final current = currentInvoiceMonth(card, data, today);
      final next = current.add(1);
      final itemsByMonth = <YearMonth, List<InvoiceItem>>{};
      for (final i in data.installments) {
        if (i.cardId != card.id || i.paidOutside) continue;
        final purchase = purchases[i.purchaseId];
        if (purchase == null) continue;
        itemsByMonth
            .putIfAbsent(i.month, () => [])
            .add(
              InvoiceItem(
                kind: InvoiceItemKind.installment,
                id: i.id,
                description: purchase.installmentCount == 1
                    ? purchase.description
                    : '${purchase.description} '
                          '(${i.number}/${purchase.installmentCount})',
                amount: i.amount,
                sourceId: purchase.id,
                manuallyEdited: i.manuallyEdited,
                isSinglePurchase: purchase.installmentCount == 1,
              ),
            );
      }
      for (final c in data.charges) {
        if (c.cardId != card.id || c.removed) continue;
        itemsByMonth
            .putIfAbsent(c.month, () => [])
            .add(
              InvoiceItem(
                kind: InvoiceItemKind.charge,
                id: c.id,
                description: c.description,
                amount: c.amount,
                sourceId: c.subscriptionId,
                manuallyEdited: c.manuallyEdited,
              ),
            );
      }
      final months = <YearMonth>{
        current,
        next,
        ...itemsByMonth.keys,
        for (final i in data.invoices)
          if (i.cardId == card.id) i.month,
      };
      for (final month in months) {
        final stored = calendar.stored(month);
        if (stored?.isPaid ?? false) continue; // listadas abaixo
        final items = itemsByMonth[month] ?? const <InvoiceItem>[];
        final view = InvoiceView(
          id: stored?.id ?? CardBillIds.invoice(card.id, month),
          cardId: card.id,
          cardName: card.name,
          month: month,
          closingOn: calendar.closingOf(month),
          dueOn: calendar.dueOf(month),
          datesManual: stored?.datesManual ?? false,
          items: items,
          informedAmount: stored?.informedAmount,
          payment: null,
          isCurrent: month == current,
          isNext: month == next,
          isClosed: calendar.isClosed(month, today),
          isStored: stored != null,
          today: today,
        );
        // Sempre a atual e a seguinte; as demais só com itens ou valor
        // informado (spec §5.2).
        if (view.isCurrent || view.isNext || view.hasContent) {
          pending.add(view);
        }
      }
      for (final s in data.subscriptions) {
        if (s.cardId == card.id && !s.startMonth.isAfter(current)) {
          subscriptionsMonthly += s.monthlyAmount;
        }
      }
    }

    // Pagas: congeladas, inclusive de cartões já apagados (histórico §10).
    for (final i in data.invoices.where((i) => i.isPaid)) {
      final card = data.card(i.cardId);
      final p = i.payment!;
      paid.add(
        InvoiceView(
          id: i.id,
          cardId: i.cardId,
          cardName: p.cardName.isNotEmpty ? p.cardName : (card?.name ?? ''),
          month: i.month,
          closingOn: i.closingOn,
          dueOn: i.dueOn,
          datesManual: i.datesManual,
          items: [
            for (final (n, s) in p.items.indexed)
              InvoiceItem(
                kind: InvoiceItemKind.installment,
                id: '${i.id}:$n',
                description: s.description,
                amount: s.amount,
                sourceId: '',
              ),
          ],
          informedAmount: i.informedAmount,
          payment: p,
          isCurrent: false,
          isNext: false,
          isClosed: true,
          isStored: true,
          today: today,
        ),
      );
    }

    pending.sort((a, b) {
      final byDue = a.dueOn.compareTo(b.dueOn);
      return byDue != 0 ? byDue : a.cardName.compareTo(b.cardName);
    });
    paid.sort((a, b) {
      final byPaid = b.payment!.paidOn.compareTo(a.payment!.paidOn);
      return byPaid != 0 ? byPaid : b.dueOn.compareTo(a.dueOn);
    });

    return CardBillsBoard._(
      pending: pending,
      paid: paid,
      reserve: reserveShown(data.reserveEvents),
      committed: pending.fold(BigInt.zero, (s, v) => s + v.commitment),
      activeSubscriptionsMonthly: subscriptionsMonthly,
      lastAutomaticChange: latestAutomaticEvent(data.reserveEvents),
    );
  }

  /// Fatura (pendente ou paga) pelo id.
  InvoiceView? invoice(String id) =>
      pending.where((v) => v.id == id).firstOrNull ??
      paid.where((v) => v.id == id).firstOrNull;
}
