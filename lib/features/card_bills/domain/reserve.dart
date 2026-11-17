import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import 'card_bill_models.dart';
import 'deterministic_id.dart';

/// Dinheiro reservado como soma de eventos (spec §9 e §12): ajustes (a
/// diferença digitada) e pagamentos (− parte da reserva). Os dois aparelhos
/// chegam sempre ao mesmo valor.

/// Soma bruta dos eventos. Pode ficar negativa só se dois aparelhos sem
/// conexão tirarem da reserva ao mesmo tempo; a tela nunca mostra negativo.
BigInt reserveRaw(Iterable<ReserveEvent> events) =>
    events.fold(BigInt.zero, (s, e) => s + e.signed);

/// Dinheiro reservado exibido (nunca negativo).
BigInt reserveShown(Iterable<ReserveEvent> events) {
  final raw = reserveRaw(events);
  return raw.isNegative ? BigInt.zero : raw;
}

/// Última mudança automática (pagamento ou desfazer), para o texto embaixo do
/// campo ("−R$ 1.237,50 pela fatura…").
ReserveEvent? latestAutomaticEvent(Iterable<ReserveEvent> events) {
  ReserveEvent? latest;
  for (final e in events) {
    if (!e.kind.isAutomatic) continue;
    if (latest == null || !e.occurredAt.isBefore(latest.occurredAt)) {
      latest = e;
    }
  }
  return latest;
}

/// Texto da mudança automática: "−R$ 1.237,50 pela fatura Nubank que vence
/// em 10/12".
String describeAutomaticEvent(ReserveEvent e) =>
    '${e.isIn ? '+' : '−'}${formatBrl(e.amount)} ${e.label ?? ''}'.trim();

/// Ajuste para levar a reserva ao novo valor digitado: grava a diferença em
/// relação à soma bruta. `null` se não mudar nada.
ReserveEvent? adjustmentTo(
  BigInt newValue,
  Iterable<ReserveEvent> events, {
  required String id,
  required DateTime now,
}) {
  final error = validateReserveValue(newValue);
  if (error != null) throw ArgumentError(error);
  final delta = newValue - reserveRaw(events);
  if (delta == BigInt.zero) return null;
  return ReserveEvent(
    id: id,
    kind: ReserveEventKind.adjustment,
    isIn: !delta.isNegative,
    amount: delta.abs(),
    occurredAt: now.toUtc(),
  );
}

String? validateReserveValue(BigInt value) {
  if (value.isNegative) return 'A reserva não pode ser negativa.';
  if (value > maxReserve) {
    return 'A reserva vai até ${formatBrl(maxReserve)}.';
  }
  return null;
}

/// Pagamento planejado (spec §8), antes de confirmar.
class PaymentPlan {
  const PaymentPlan({
    required this.paidAmount,
    required this.expectedAmount,
    required this.source,
    required this.reserveUsed,
    required this.warnings,
  });

  final BigInt paidAmount;
  final BigInt expectedAmount;
  final PaymentSource source;

  /// Quanto sai da reserva (o restante é tratado como de outras fontes).
  final BigInt reserveUsed;
  final List<String> warnings;
}

String? validatePaidAmount(BigInt? paid) {
  if (paid == null) return 'Informe o valor pago.';
  if (paid.isNegative) return 'O valor pago não pode ser negativo.';
  if (paid > maxBillAmount) {
    return 'O valor pago vai até ${formatBrl(maxBillAmount)}.';
  }
  return null;
}

PaymentPlan planPayment({
  required BigInt expectedAmount,
  required BigInt paidAmount,
  required PaymentSource source,
  required Iterable<ReserveEvent> events,
}) {
  final error = validatePaidAmount(paidAmount);
  if (error != null) throw ArgumentError(error);
  final available = reserveShown(events);
  final warnings = <String>[];
  if (paidAmount < expectedAmount) {
    warnings.add(
      '${formatBrl(expectedAmount - paidAmount)} deixarão de contar. Se '
      'ficarem para a próxima fatura, informe lá.',
    );
  }
  var reserveUsed = BigInt.zero;
  if (source == PaymentSource.reserve) {
    reserveUsed = paidAmount > available ? available : paidAmount;
    if (paidAmount > available) {
      warnings.add(
        'A reserva tem ${formatBrl(available)}; o pagamento vai deixá-la em '
        '${formatBrl(BigInt.zero)}.',
      );
    }
  }
  return PaymentPlan(
    paidAmount: paidAmount,
    expectedAmount: expectedAmount,
    source: source,
    reserveUsed: reserveUsed,
    warnings: warnings,
  );
}

/// Texto que acompanha os eventos automáticos de uma fatura.
String invoiceLabel(String cardName, CalendarDate dueOn) =>
    'pela fatura $cardName que vence em ${_ddMm(dueOn)}';

String _ddMm(CalendarDate d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Evento de saída da reserva pelo pagamento (só se algo saiu dela).
ReserveEvent? paymentEvent({
  required String paymentId,
  required String invoiceId,
  required BigInt reserveUsed,
  required String label,
  required DateTime now,
}) => reserveUsed == BigInt.zero
    ? null
    : ReserveEvent(
        id: CardBillIds.paymentEvent(paymentId),
        kind: ReserveEventKind.payment,
        isIn: false,
        amount: reserveUsed,
        occurredAt: now.toUtc(),
        invoiceId: invoiceId,
        label: label,
      );

/// Desfazer pagamento: a reserva recebe de volta só o que saiu dela.
ReserveEvent? undoEvent({
  required InvoicePayment payment,
  required String invoiceId,
  required String label,
  required DateTime now,
}) => payment.reserveUsed == BigInt.zero
    ? null
    : ReserveEvent(
        id: CardBillIds.undoEvent(payment.paymentId),
        kind: ReserveEventKind.paymentUndo,
        isIn: true,
        amount: payment.reserveUsed,
        occurredAt: now.toUtc(),
        invoiceId: invoiceId,
        label: label,
      );
