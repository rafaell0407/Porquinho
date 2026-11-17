import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/user_clock.dart';
import '../../sync/sync_models.dart';
import '../data/card_bills_repository.dart';
import '../domain/card_bill_models.dart';
import '../domain/cards_and_invoices.dart' as cards;
import '../domain/change_set.dart';
import '../domain/invoice_board.dart';
import '../domain/purchases.dart' as purchases;
import '../domain/purchases.dart' show PurchaseDraft, PurchasePlan;
import '../domain/reserve.dart';
import '../domain/subscriptions.dart' as subs;
import '../domain/year_month.dart';

/// Estado da ferramenta para a tela: dados, painel calculado e "hoje".
class CardBillsSnapshot {
  CardBillsSnapshot(this.data, this.today)
    : board = CardBillsBoard.build(data, today);

  final CardBillsData data;
  final CardBillsBoard board;
  final CalendarDate today;
}

/// Regras de aplicação da Gestão de Faturas (GF4.1, GF4.2): monta o painel,
/// gera as cobranças devidas ao abrir e grava cada ação pelo repositório.
/// Os cálculos ficam no domínio (`domain/`); aqui só a orquestração.
class CardBillsService {
  CardBillsService(
    this._repo, {
    UserClock clock = const UserClock(),
    String Function()? newId,
  }) : _clock = clock,
       _newId = newId ?? newUuid;

  final CardBillsRepository _repo;
  final UserClock _clock;
  final String Function() _newId;

  CalendarDate get today => _clock.today();
  DateTime get _now => _clock.nowUtc();

  Future<CardBillsSnapshot> snapshot() async =>
      CardBillsSnapshot(await _repo.load(), today);

  /// Ao abrir a ferramenta: inclui as cobranças de assinaturas que faltam
  /// (fatura atual e faturas não pagas que ficaram sem ela, spec §7).
  Future<CardBillsSnapshot> open() async {
    final data = await _repo.load();
    final change = subs.generateCharges(data, today);
    if (change.isEmpty) return CardBillsSnapshot(data, today);
    await _repo.apply(change);
    return snapshot();
  }

  Future<void> _apply(CardBillsChange change) => _repo.apply(change);

  // --- cartões ---------------------------------------------------------

  Future<void> createCard(String name, int closingDay, int dueDay) {
    final error = cards.validateCard(name, closingDay, dueDay);
    if (error != null) throw ArgumentError(error);
    return _apply(
      cards.createCard(
        CreditCard(
          id: _newId(),
          name: name.trim(),
          closingDay: closingDay,
          dueDay: dueDay,
        ),
      ),
    );
  }

  Future<void> editCard(
    CreditCard existing,
    String name,
    int closingDay,
    int dueDay,
  ) async {
    final error = cards.validateCard(name, closingDay, dueDay);
    if (error != null) throw ArgumentError(error);
    final data = await _repo.load();
    await _apply(
      cards.editCard(
        existing: existing,
        updated: existing.copyWith(
          name: name.trim(),
          closingDay: closingDay,
          dueDay: dueDay,
        ),
        data: data,
        today: today,
      ),
    );
  }

  Future<void> deleteCard(CreditCard card) async =>
      _apply(cards.deleteCard(card, await _repo.load()));

  // --- compras -----------------------------------------------------------

  Future<PurchasePlan> previewPurchase(
    PurchaseDraft draft, {
    Purchase? existing,
  }) async {
    final data = await _repo.load();
    return existing == null
        ? purchases.planNewPurchase(
            id: 'preview',
            draft: draft,
            data: data,
            today: today,
          )
        : purchases.planPurchaseEdit(
            existing: existing,
            draft: draft,
            data: data,
            today: today,
          );
  }

  Future<PurchasePlan> savePurchase(
    PurchaseDraft draft, {
    Purchase? existing,
  }) async {
    final data = await _repo.load();
    final plan = existing == null
        ? purchases.planNewPurchase(
            id: _newId(),
            draft: draft,
            data: data,
            today: today,
          )
        : purchases.planPurchaseEdit(
            existing: existing,
            draft: draft,
            data: data,
            today: today,
          );
    await _apply(plan.change);
    return plan;
  }

  Future<void> deletePurchase(Purchase purchase) async =>
      _apply(purchases.deletePurchase(purchase, await _repo.load()));

  Future<void> editInstallment(
    Installment installment,
    BigInt amount, {
    required bool andFollowing,
  }) async => _apply(
    purchases.editInstallment(
      installment: installment,
      amount: amount,
      andFollowing: andFollowing,
      data: await _repo.load(),
    ),
  );

  // --- assinaturas ------------------------------------------------------

  Future<void> createSubscription({
    required String description,
    required String cardId,
    required BigInt monthlyAmount,
    required String startMonthKey,
  }) async {
    final data = await _repo.load();
    final error = subs.validateSubscription(
      description: description,
      cardId: cardId,
      monthlyAmount: monthlyAmount,
      data: data,
    );
    if (error != null) throw ArgumentError(error);
    await _apply(
      subs.createSubscription(
        Subscription(
          id: _newId(),
          cardId: cardId,
          description: description.trim(),
          monthlyAmount: monthlyAmount,
          startMonth: YearMonth.parse(startMonthKey),
        ),
      ),
    );
    // A cobrança da fatura atual entra na hora, se a assinatura já começou.
    final after = await _repo.load();
    final charges = subs.generateCharges(after, today);
    if (!charges.isEmpty) await _apply(charges);
  }

  Future<void> editSubscription(
    Subscription existing, {
    required String description,
    required String cardId,
    required BigInt monthlyAmount,
  }) async {
    final data = await _repo.load();
    final error = subs.validateSubscription(
      description: description,
      cardId: cardId,
      monthlyAmount: monthlyAmount,
      data: data,
    );
    if (error != null) throw ArgumentError(error);
    await _apply(
      subs.editSubscription(
        existing: existing,
        updated: existing.copyWith(
          description: description.trim(),
          cardId: cardId,
          monthlyAmount: monthlyAmount,
        ),
        data: data,
        today: today,
      ),
    );
  }

  Future<void> cancelSubscription(
    Subscription subscription, {
    required bool removeCurrentCharge,
  }) async => _apply(
    subs.cancelSubscription(
      subscription: subscription,
      removeCurrentCharge: removeCurrentCharge,
      data: await _repo.load(),
      today: today,
    ),
  );

  Future<void> editCharge(SubscriptionCharge charge, BigInt amount) =>
      _apply(subs.editCharge(charge, amount));

  Future<void> removeCharge(SubscriptionCharge charge) =>
      _apply(subs.removeCharge(charge));

  // --- faturas ----------------------------------------------------------

  Future<void> setInformedAmount(InvoiceView view, BigInt? amount) async =>
      _apply(cards.setInformedAmount(view, amount, await _repo.load()));

  Future<void> correctDates(
    InvoiceView view,
    CalendarDate closing,
    CalendarDate due,
  ) async => _apply(
    cards.correctInvoiceDates(
      view: view,
      closing: closing,
      due: due,
      data: await _repo.load(),
    ),
  );

  Future<PaymentPlan> planPay(
    InvoiceView view,
    BigInt paidAmount,
    PaymentSource source,
  ) async => planPayment(
    expectedAmount: view.value,
    paidAmount: paidAmount,
    source: source,
    events: (await _repo.load()).reserveEvents,
  );

  /// Paga a fatura inteira. Na Web, pagamento duplicado lança
  /// [DuplicatePaymentException].
  Future<void> pay(
    InvoiceView view,
    BigInt paidAmount,
    PaymentSource source,
    CalendarDate paidOn,
  ) async {
    final data = await _repo.load();
    final plan = planPayment(
      expectedAmount: view.value,
      paidAmount: paidAmount,
      source: source,
      events: data.reserveEvents,
    );
    await _repo.pay(
      cards.buildPayment(
        view: view,
        plan: plan,
        paidOn: paidOn,
        paymentId: _newId(),
        now: _now,
        data: data,
      ),
    );
  }

  /// Web: o usuário escolheu manter este pagamento no lugar do já gravado.
  Future<void> replacePayment(
    InvoiceView view,
    InvoiceRecord remote,
    BigInt paidAmount,
    PaymentSource source,
    CalendarDate paidOn,
  ) async {
    final data = await _repo.load();
    final remotePayment = remote.payment!;
    // A reserva sem o pagamento que será desfeito.
    final events = [
      ...data.reserveEvents,
      ?undoEvent(
        payment: remotePayment,
        invoiceId: remote.id,
        label: '',
        now: _now,
      ),
    ];
    final plan = planPayment(
      expectedAmount: view.value,
      paidAmount: paidAmount,
      source: source,
      events: events,
    );
    final command = cards.buildPayment(
      view: view,
      plan: plan,
      paidOn: paidOn,
      paymentId: _newId(),
      now: _now,
      data: data,
    );
    await _repo.pay(
      PayInvoiceCommand(
        invoice: command.invoice,
        reserveEvent: command.reserveEvent,
        replacePaymentId: remotePayment.paymentId,
        replaceUndoEvent: undoEvent(
          payment: remotePayment,
          invoiceId: remote.id,
          label:
              'ao manter o outro pagamento da fatura '
              '${remotePayment.cardName}',
          now: _now,
        ),
      ),
    );
  }

  Future<void> undoPayment(InvoiceView view) async {
    final data = await _repo.load();
    final record = data.invoiceById(view.id);
    if (record == null || !record.isPaid) {
      throw ArgumentError('Esta fatura não está paga.');
    }
    await _repo.undo(cards.buildUndo(record, _now));
  }

  // --- reserva ----------------------------------------------------------

  Future<void> setReserve(BigInt newValue) async {
    final data = await _repo.load();
    final event = adjustmentTo(
      newValue,
      data.reserveEvents,
      id: _newId(),
      now: _now,
    );
    if (event == null) return;
    await _apply(
      CardBillsChange(
        writes: [RowWrite(CardBillTables.reserveEvents, event.toRow())],
        summary: 'Dinheiro reservado',
      ),
    );
  }
}
