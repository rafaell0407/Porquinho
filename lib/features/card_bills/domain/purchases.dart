import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import 'card_bill_models.dart';
import 'card_calendar.dart';
import 'change_set.dart';
import 'deterministic_id.dart';
import 'year_month.dart';

/// Compras parceladas (spec §6).

/// Divide [total] em [count] parcelas: parte inteira em centavos; o resto vai
/// para a 1ª parcela.
List<BigInt> splitTotal(BigInt total, int count) {
  if (count < 1) throw ArgumentError('Pelo menos uma parcela.');
  final n = BigInt.from(count);
  final base = total ~/ n;
  final rest = total - base * n;
  return [for (var k = 0; k < count; k++) k == 0 ? base + rest : base];
}

/// Total no modo "Valor da parcela": parcela × n.
BigInt totalFromInstallment(BigInt installment, int count) =>
    installment * BigInt.from(count);

/// O que o usuário preencheu no formulário da compra.
class PurchaseDraft {
  const PurchaseDraft({
    required this.cardId,
    required this.description,
    required this.purchasedOn,
    required this.installmentCount,
    required this.amountMode,
    required this.amount,
    this.firstMonth,
  });

  final String? cardId;
  final String description;
  final CalendarDate purchasedOn;
  final int? installmentCount;
  final AmountMode amountMode;

  /// Total ou valor da parcela, conforme [amountMode].
  final BigInt? amount;

  /// Fatura da 1ª parcela escolhida; `null` = automática (§5.1).
  final YearMonth? firstMonth;

  BigInt get total => amountMode == AmountMode.total
      ? amount!
      : totalFromInstallment(amount!, installmentCount!);
}

/// Mensagens de erro por campo (vazio = válido).
Map<String, String> validatePurchaseDraft(
  PurchaseDraft d,
  CardBillsData data,
  CalendarDate today,
) {
  final errors = <String, String>{};
  if (d.description.trim().isEmpty) {
    errors['description'] = 'Informe a descrição.';
  }
  if (d.cardId == null || data.card(d.cardId!) == null) {
    errors['card'] = 'Escolha o cartão.';
  }
  if (d.purchasedOn.isAfter(today)) {
    errors['date'] = 'A data da compra não pode ser no futuro.';
  }
  final n = d.installmentCount;
  if (n == null || n < 1 || n > maxInstallments) {
    errors['count'] = 'O número de parcelas vai de 1 a $maxInstallments.';
  }
  final amount = d.amount;
  if (amount == null || amount <= BigInt.zero) {
    errors['amount'] = 'Informe um valor maior que zero.';
  } else if (!errors.containsKey('count') && d.total > maxBillAmount) {
    errors['amount'] = 'O valor total vai até ${formatBrl(maxBillAmount)}.';
  }
  return errors;
}

/// Resultado do cálculo de uma compra nova ou editada.
class PurchasePlan {
  const PurchasePlan({
    required this.purchase,
    required this.installments,
    required this.change,
    required this.firstMonth,
    required this.automaticFirstMonth,
    required this.warnings,
    this.paidOutsideCount = 0,
  });

  final Purchase purchase;

  /// Todas as parcelas depois da alteração.
  final List<Installment> installments;
  final CardBillsChange change;

  /// Fatura da 1ª parcela pendente (depois de pular faturas pagas).
  final YearMonth firstMonth;
  final YearMonth automaticFirstMonth;
  final List<String> warnings;

  /// Parcelas tratadas como pagas fora da ferramenta (compra antiga).
  final int paidOutsideCount;
}

/// Fatura automática da 1ª parcela (regra do fechamento, §5.1).
YearMonth automaticFirstMonth(
  CreditCard card,
  CardBillsData data,
  CalendarDate purchasedOn,
) => CardCalendar(card, data.invoices).monthFor(purchasedOn);

bool _isPaid(CardBillsData data, String cardId, YearMonth month) =>
    data.invoice(cardId, month)?.isPaid ?? false;

/// Coloca as parcelas a partir de [first]. Parcela em fatura paga ou já
/// vencida (quando [applyOldPurchaseRule]) é tratada como paga fora.
List<Installment> _place({
  required String purchaseId,
  required CreditCard card,
  required CardBillsData data,
  required CalendarDate today,
  required YearMonth first,
  required List<int> numbers,
  required List<BigInt> amounts,
  required bool applyOldPurchaseRule,
}) {
  final calendar = CardCalendar(card, data.invoices);
  return [
    for (final (i, number) in numbers.indexed)
      () {
        final month = first.add(number - 1);
        final paidOutside =
            _isPaid(data, card.id, month) ||
            (applyOldPurchaseRule && calendar.isPastDue(month, today));
        return Installment(
          id: CardBillIds.installment(purchaseId, number),
          purchaseId: purchaseId,
          number: number,
          cardId: card.id,
          month: month,
          amount: amounts[i],
          paidOutside: paidOutside,
        );
      }(),
  ];
}

/// Primeira fatura pendente a partir de [month] (fatura paga → próxima, §6).
YearMonth _skipPaid(CardBillsData data, String cardId, YearMonth month) {
  var m = month;
  for (var guard = 0; guard < 120 && _isPaid(data, cardId, m); guard++) {
    m = m.add(1);
  }
  return m;
}

PurchasePlan planNewPurchase({
  required String id,
  required PurchaseDraft draft,
  required CardBillsData data,
  required CalendarDate today,
}) {
  final errors = validatePurchaseDraft(draft, data, today);
  if (errors.isNotEmpty) throw ArgumentError(errors.values.first);
  final card = data.card(draft.cardId!)!;
  final n = draft.installmentCount!;
  final automatic = automaticFirstMonth(card, data, draft.purchasedOn);
  final chosen = draft.firstMonth ?? automatic;
  final first = _skipPaid(data, card.id, chosen);
  final purchase = Purchase(
    id: id,
    cardId: card.id,
    description: draft.description.trim(),
    purchasedOn: draft.purchasedOn,
    installmentCount: n,
    amountMode: draft.amountMode,
  );
  final installments = _place(
    purchaseId: id,
    card: card,
    data: data,
    today: today,
    first: first,
    numbers: [for (var k = 1; k <= n; k++) k],
    amounts: splitTotal(draft.total, n),
    applyOldPurchaseRule: true,
  );
  final paidOutside = installments.where((i) => i.paidOutside).length;
  final warnings = <String>[
    if (first != chosen)
      'A fatura escolhida já foi paga; a 1ª parcela vai para a próxima '
          'fatura pendente.',
    if (paidOutside > 0) _paidOutsideWarning(paidOutside),
  ];
  return PurchasePlan(
    purchase: purchase,
    installments: installments,
    change: CardBillsChange(
      writes: [
        RowWrite(CardBillTables.purchases, purchase.toRow()),
        for (final i in installments)
          RowWrite(CardBillTables.installments, i.toRow()),
      ],
      summary: 'Nova compra: ${purchase.description}',
    ),
    firstMonth: first,
    automaticFirstMonth: automatic,
    warnings: warnings,
    paidOutsideCount: paidOutside,
  );
}

String _paidOutsideWarning(int count) => count == 1
    ? '1 parcela caiu em fatura já vencida e foi considerada paga.'
    : '$count parcelas caíram em faturas já vencidas e foram consideradas '
          'pagas.';

/// Parcela já "paga": em fatura paga ou paga fora da ferramenta.
bool isSettled(Installment i, CardBillsData data) =>
    i.paidOutside || _isPaid(data, i.cardId, i.month);

/// Editar a compra inteira (spec §6): recalcula só as parcelas de faturas
/// pendentes; as pagas ficam. Só a descrição mudou → parcelas intactas.
PurchasePlan planPurchaseEdit({
  required Purchase existing,
  required PurchaseDraft draft,
  required CardBillsData data,
  required CalendarDate today,
}) {
  final errors = validatePurchaseDraft(draft, data, today);
  if (errors.isNotEmpty) throw ArgumentError(errors.values.first);
  final card = data.card(draft.cardId!)!;
  final n = draft.installmentCount!;
  final current = data.installmentsOf(existing.id);
  final settled = current.where((i) => isSettled(i, data)).toList();
  final pending = current.where((i) => !isSettled(i, data)).toList();
  final settledSum = settled.fold(BigInt.zero, (s, i) => s + i.amount);
  final currentTotal = current.fold(BigInt.zero, (s, i) => s + i.amount);
  final automatic = automaticFirstMonth(card, data, draft.purchasedOn);
  final currentFirst = current.isEmpty
      ? automatic
      : current.first.month.add(1 - current.first.number);

  final purchase = existing.copyWith(
    cardId: card.id,
    description: draft.description.trim(),
    purchasedOn: draft.purchasedOn,
    installmentCount: n,
    amountMode: draft.amountMode,
  );

  final placementChanged =
      card.id != existing.cardId ||
      draft.purchasedOn != existing.purchasedOn ||
      (draft.firstMonth != null && draft.firstMonth != currentFirst);
  final valuesChanged =
      draft.total != currentTotal || n != existing.installmentCount;

  if (!placementChanged && !valuesChanged) {
    return PurchasePlan(
      purchase: purchase,
      installments: current,
      change: CardBillsChange(
        writes: [RowWrite(CardBillTables.purchases, purchase.toRow())],
        summary: 'Editar compra: ${purchase.description}',
      ),
      firstMonth: currentFirst,
      automaticFirstMonth: automatic,
      warnings: const [],
    );
  }

  if (n <= settled.length) {
    throw ArgumentError(
      'O número de parcelas precisa ser maior que o de parcelas já pagas '
      '(${settled.length}).',
    );
  }
  final lastSettled = settled.isEmpty
      ? 0
      : settled.map((i) => i.number).reduce((a, b) => a > b ? a : b);
  if (lastSettled > n) {
    throw ArgumentError(
      'O número de parcelas não pode ser menor que o da última parcela já '
      'paga ($lastSettled).',
    );
  }
  final remaining = draft.total - settledSum;
  if (remaining <= BigInt.zero) {
    throw ArgumentError(
      'O novo valor total precisa ser maior que o já pago '
      '(${formatBrl(settledSum)}).',
    );
  }

  final settledNumbers = settled.map((i) => i.number).toSet();
  final numbers = [
    for (var k = 1; k <= n; k++)
      if (!settledNumbers.contains(k)) k,
  ];
  // A 1ª parcela pendente vai para a fatura escolhida (ou a automática);
  // fatura paga → próxima pendente, e as demais andam junto.
  final chosenFirst =
      draft.firstMonth ?? (placementChanged ? automatic : currentFirst);
  final firstPendingMonth = _skipPaid(
    data,
    card.id,
    chosenFirst.add(numbers.first - 1),
  );
  final first = firstPendingMonth.add(1 - numbers.first);
  final placed = _place(
    purchaseId: existing.id,
    card: card,
    data: data,
    today: today,
    first: first,
    numbers: numbers,
    amounts: splitTotal(remaining, numbers.length),
    applyOldPurchaseRule: placementChanged,
  );
  final newIds = placed.map((i) => i.id).toSet();
  final manual = pending.any((i) => i.manuallyEdited);
  final paidOutside = placed.where((i) => i.paidOutside).length;
  return PurchasePlan(
    purchase: purchase,
    installments: [...settled, ...placed]
      ..sort((a, b) => a.number.compareTo(b.number)),
    change: CardBillsChange(
      writes: [
        RowWrite(CardBillTables.purchases, purchase.toRow()),
        for (final i in placed)
          RowWrite(CardBillTables.installments, i.toRow()),
      ],
      deletes: [
        for (final i in pending)
          if (!newIds.contains(i.id))
            RowDelete(CardBillTables.installments, i.id),
      ],
      summary: 'Editar compra: ${purchase.description}',
    ),
    firstMonth: first.add(numbers.first - 1),
    automaticFirstMonth: automatic,
    warnings: [
      if (manual) 'Os ajustes feitos à mão nas parcelas serão refeitos.',
      if (firstPendingMonth != chosenFirst.add(numbers.first - 1))
        'A fatura escolhida já foi paga; as parcelas vão para a próxima '
            'fatura pendente.',
      if (paidOutside > 0) _paidOutsideWarning(paidOutside),
    ],
    paidOutsideCount: paidOutside,
  );
}

/// Avisos antes de salvar a edição (sem gravar nada).
bool hasManualPendingInstallments(String purchaseId, CardBillsData data) => data
    .installmentsOf(purchaseId)
    .any((i) => i.manuallyEdited && !isSettled(i, data));

String? validateItemAmount(BigInt? amount) {
  if (amount == null || amount <= BigInt.zero) {
    return 'Informe um valor maior que zero.';
  }
  if (amount > maxBillAmount) {
    return 'O valor vai até ${formatBrl(maxBillAmount)}.';
  }
  return null;
}

/// Editar uma parcela, ou "esta e as próximas" (só as pendentes, §6).
CardBillsChange editInstallment({
  required Installment installment,
  required BigInt amount,
  required bool andFollowing,
  required CardBillsData data,
}) {
  final error = validateItemAmount(amount);
  if (error != null) throw ArgumentError(error);
  if (isSettled(installment, data)) {
    throw ArgumentError('Esta parcela já foi paga.');
  }
  final targets = andFollowing
      ? data
            .installmentsOf(installment.purchaseId)
            .where((i) => i.number >= installment.number && !isSettled(i, data))
      : [installment];
  final updated = [
    for (final i in targets) i.copyWith(amount: amount, manuallyEdited: true),
  ];
  final others = data
      .installmentsOf(installment.purchaseId)
      .where((i) => !updated.any((u) => u.id == i.id));
  final total = [
    ...others,
    ...updated,
  ].fold(BigInt.zero, (s, i) => s + i.amount);
  if (total > maxBillAmount) {
    throw ArgumentError(
      'O total da compra vai até ${formatBrl(maxBillAmount)}.',
    );
  }
  final purchase = data.purchase(installment.purchaseId);
  return CardBillsChange(
    writes: [
      for (final i in updated)
        RowWrite(
          CardBillTables.installments,
          i.toRow(),
          updateColumns: const ['amount_centavos', 'manually_edited'],
        ),
    ],
    summary: 'Editar parcela: ${purchase?.description ?? ''}'.trim(),
  );
}

/// Apagar a compra: some a compra e as parcelas (as de faturas pagas ficam
/// só como texto no histórico da fatura, §6 e §10).
CardBillsChange deletePurchase(Purchase purchase, CardBillsData data) =>
    CardBillsChange(
      deletes: [
        for (final i in data.installmentsOf(purchase.id))
          RowDelete(CardBillTables.installments, i.id),
        RowDelete(CardBillTables.purchases, purchase.id),
      ],
      summary: 'Apagar compra: ${purchase.description}',
    );
