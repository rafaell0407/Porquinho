import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import 'card_bill_models.dart';
import 'card_calendar.dart';
import 'change_set.dart';
import 'deterministic_id.dart';
import 'year_month.dart';

/// Assinaturas: cobranças recorrentes no cartão (spec §7).

String? validateSubscription({
  required String description,
  required String? cardId,
  required BigInt? monthlyAmount,
  required CardBillsData data,
}) {
  if (description.trim().isEmpty) return 'Informe a descrição.';
  if (cardId == null || data.card(cardId) == null) return 'Escolha o cartão.';
  if (monthlyAmount == null || monthlyAmount <= BigInt.zero) {
    return 'Informe um valor mensal maior que zero.';
  }
  if (monthlyAmount > maxBillAmount) {
    return 'O valor mensal vai até ${formatBrl(maxBillAmount)}.';
  }
  return null;
}

/// Fatura que recebe as cobranças de assinaturas: a mais antiga cujo
/// vencimento ainda não passou (hoje ≤ vencimento). Fatura fechada e ainda não
/// vencida continua recebendo; a seguinte só entra depois do vencimento.
YearMonth? currentMonthOf(
  String cardId,
  CardBillsData data,
  CalendarDate today,
) {
  final card = data.card(cardId);
  if (card == null) return null;
  final calendar = CardCalendar(card, data.invoices);
  final cycle = calendar.currentMonth(today);
  for (var back = 3; back > 0; back--) {
    final month = cycle.add(-back);
    if (!calendar.isPastDue(month, today)) return month;
  }
  return cycle;
}

/// Fatura atual: a mais antiga fechada e **não paga** que tenha itens ou valor
/// informado; sem nenhuma, a fatura cujo ciclo contém hoje.
YearMonth currentInvoiceMonth(
  CreditCard card,
  CardBillsData data,
  CalendarDate today,
) {
  final calendar = CardCalendar(card, data.invoices);
  final cycle = calendar.currentMonth(today);
  final withContent = <YearMonth>{
    for (final i in data.installments)
      if (i.cardId == card.id && !i.paidOutside) i.month,
    for (final c in data.charges)
      if (c.cardId == card.id && !c.removed) c.month,
    for (final i in data.invoices)
      if (i.cardId == card.id && i.informedAmount != null) i.month,
  };
  YearMonth? oldest;
  for (final m in withContent) {
    if (!m.isBefore(cycle)) continue;
    if (calendar.stored(m)?.isPaid ?? false) continue;
    if (oldest == null || m.isBefore(oldest)) oldest = m;
  }
  return oldest ?? cycle;
}

/// Cobranças que faltam (spec §7): uma por fatura, só até a fatura atual
/// (nunca projetada nas seguintes). Depois de um ou mais ciclos com o app
/// fechado, inclui a cobrança nas faturas **não pagas** que ficaram sem ela
/// desde o início. Cobrança já existente — inclusive removida à mão — não é
/// recriada. O id é determinístico (assinatura + fatura).
List<SubscriptionCharge> chargesToGenerate(
  CardBillsData data,
  CalendarDate today,
) {
  final existing = {for (final c in data.charges) c.id};
  final result = <SubscriptionCharge>[];
  for (final s in data.subscriptions) {
    final current = currentMonthOf(s.cardId, data, today);
    if (current == null || s.startMonth.isAfter(current)) continue;
    // Limite de segurança: no máximo 24 faturas para trás.
    var month = s.startMonth;
    if (current.monthsSince(month) > 24) month = current.add(-24);
    for (; !month.isAfter(current); month = month.add(1)) {
      final id = CardBillIds.charge(s.id, month);
      if (existing.contains(id)) continue;
      if (data.invoice(s.cardId, month)?.isPaid ?? false) continue;
      result.add(
        SubscriptionCharge(
          id: id,
          subscriptionId: s.id,
          cardId: s.cardId,
          month: month,
          description: s.description,
          amount: s.monthlyAmount,
        ),
      );
    }
  }
  return result;
}

/// Gravação das cobranças que faltam: só insere (nunca sobrescreve uma
/// cobrança editada ou removida em outro aparelho).
CardBillsChange generateCharges(CardBillsData data, CalendarDate today) =>
    CardBillsChange(
      writes: [
        for (final c in chargesToGenerate(data, today))
          RowWrite.insertIfAbsent(CardBillTables.charges, c.toRow()),
      ],
      summary: 'Incluir cobranças de assinaturas',
    );

CardBillsChange createSubscription(Subscription s) => CardBillsChange(
  writes: [RowWrite(CardBillTables.subscriptions, s.toRow())],
  summary: 'Nova assinatura: ${s.description}',
);

/// Editar a assinatura. Preço ou descrição novos valem para a fatura atual
/// pendente e as próximas: a cobrança da fatura atual (se pendente, não
/// removida e não editada à mão) acompanha. Faturas fechadas ou pagas mantêm
/// o valor antigo.
CardBillsChange editSubscription({
  required Subscription existing,
  required Subscription updated,
  required CardBillsData data,
  required CalendarDate today,
}) {
  final writes = <RowWrite>[
    RowWrite(CardBillTables.subscriptions, updated.toRow()),
  ];
  final current = currentMonthOf(existing.cardId, data, today);
  if (current != null) {
    final charge = data.charges
        .where((c) => c.id == CardBillIds.charge(existing.id, current))
        .firstOrNull;
    final invoicePaid = data.invoice(existing.cardId, current)?.isPaid ?? false;
    if (charge != null &&
        !charge.removed &&
        !charge.manuallyEdited &&
        !invoicePaid &&
        updated.cardId == existing.cardId) {
      writes.add(
        RowWrite(
          CardBillTables.charges,
          charge
              .copyWith(
                amount: updated.monthlyAmount,
                description: updated.description,
              )
              .toRow(),
          updateColumns: const ['amount_centavos', 'description'],
        ),
      );
    }
  }
  return CardBillsChange(
    writes: writes,
    summary: 'Editar assinatura: ${updated.description}',
  );
}

/// Cobrança da assinatura na fatura atual (se existir e não estiver removida).
SubscriptionCharge? currentCharge(
  Subscription s,
  CardBillsData data,
  CalendarDate today,
) {
  final current = currentMonthOf(s.cardId, data, today);
  if (current == null) return null;
  return data.charges
      .where((c) => c.id == CardBillIds.charge(s.id, current) && !c.removed)
      .firstOrNull;
}

/// Cancelar: apaga a assinatura e vale a partir da fatura seguinte. A
/// cobrança da fatura atual continua, salvo se [removeCurrentCharge].
CardBillsChange cancelSubscription({
  required Subscription subscription,
  required bool removeCurrentCharge,
  required CardBillsData data,
  required CalendarDate today,
}) {
  final charge = removeCurrentCharge
      ? currentCharge(subscription, data, today)
      : null;
  return CardBillsChange(
    writes: [
      if (charge != null)
        RowWrite(
          CardBillTables.charges,
          charge.copyWith(removed: true).toRow(),
          updateColumns: const ['removed'],
        ),
    ],
    deletes: [RowDelete(CardBillTables.subscriptions, subscription.id)],
    summary: 'Cancelar assinatura: ${subscription.description}',
  );
}

/// Editar o valor de uma cobrança só naquela fatura.
CardBillsChange editCharge(SubscriptionCharge charge, BigInt amount) {
  if (amount <= BigInt.zero || amount > maxBillAmount) {
    throw ArgumentError(
      'Informe um valor maior que zero e até ${formatBrl(maxBillAmount)}.',
    );
  }
  return CardBillsChange(
    writes: [
      RowWrite(
        CardBillTables.charges,
        charge.copyWith(amount: amount, manuallyEdited: true).toRow(),
        updateColumns: const ['amount_centavos', 'manually_edited'],
      ),
    ],
    summary: 'Editar cobrança: ${charge.description}',
  );
}

/// Remover a cobrança só naquela fatura (não reaparece).
CardBillsChange removeCharge(SubscriptionCharge charge) => CardBillsChange(
  writes: [
    RowWrite(
      CardBillTables.charges,
      charge.copyWith(removed: true).toRow(),
      updateColumns: const ['removed'],
    ),
  ],
  summary: 'Remover cobrança: ${charge.description}',
);

/// Faturas oferecidas como início: a atual e as 11 seguintes.
List<YearMonth> startMonthOptions(
  String cardId,
  CardBillsData data,
  CalendarDate today,
) {
  final card = data.card(cardId);
  if (card == null) return const [];
  final current = currentInvoiceMonth(card, data, today);
  return [for (var k = 0; k < 12; k++) current.add(k)];
}
