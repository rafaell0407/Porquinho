import '../../../core/domain/calendar_date.dart';
import 'card_bill_models.dart';
import 'year_month.dart';

/// Calendário de faturas de um cartão (spec §4 e §5.1).
///
/// - Fatura do mês M: fechamento = dia de fechamento em M; dia inexistente =
///   último dia do mês, sem considerar dia útil.
/// - Vencimento no mesmo mês se o dia de vencimento for maior que o de
///   fechamento; senão (inclusive dias iguais), no mês seguinte. Se o ajuste ao
///   último dia do mês deixar o vencimento no dia do fechamento ou antes
///   (ex.: fecha 30 e vence 31 em fevereiro), vale o dia de vencimento do mês
///   seguinte (o vencimento precisa ser depois do fechamento, §5.1).
/// - Faturas gravadas usam as próprias datas (copiadas ou corrigidas à mão).
/// - Ciclo da fatura M: [fechamento de M−1, fechamento de M). Compra antes do
///   fechamento entra na fatura; no dia do fechamento ou depois, na seguinte.
class CardCalendar {
  CardCalendar(this.card, Iterable<InvoiceRecord> invoices)
    : _stored = {
        for (final i in invoices)
          if (i.cardId == card.id) i.month: i,
      };

  final CreditCard card;
  final Map<YearMonth, InvoiceRecord> _stored;

  static CalendarDate defaultClosing(CreditCard card, YearMonth month) =>
      month.dayClamped(card.closingDay);

  static CalendarDate defaultDue(CreditCard card, YearMonth month) {
    final closing = defaultClosing(card, month);
    var due = card.dueDay > card.closingDay
        ? month.dayClamped(card.dueDay)
        : month.add(1).dayClamped(card.dueDay);
    if (!due.isAfter(closing)) due = month.add(1).dayClamped(card.dueDay);
    return due;
  }

  InvoiceRecord? stored(YearMonth month) => _stored[month];

  CalendarDate closingOf(YearMonth month) =>
      _stored[month]?.closingOn ?? defaultClosing(card, month);

  CalendarDate dueOf(YearMonth month) =>
      _stored[month]?.dueOn ?? defaultDue(card, month);

  /// Primeiro dia do ciclo (o fechamento da fatura anterior).
  CalendarDate cycleStart(YearMonth month) => closingOf(month.add(-1));

  /// Fatura cujo ciclo contém [date].
  YearMonth monthFor(CalendarDate date) {
    var month = YearMonth.of(date);
    for (var guard = 0; guard < 48; guard++) {
      if (!date.isBefore(closingOf(month))) {
        month = month.add(1);
      } else if (date.isBefore(cycleStart(month))) {
        month = month.add(-1);
      } else {
        return month;
      }
    }
    throw StateError('Datas das faturas fora de ordem.');
  }

  /// Fatura atual: a que contém hoje (fuso America/Sao_Paulo, via UserClock).
  YearMonth currentMonth(CalendarDate today) => monthFor(today);

  /// Fechada: hoje ≥ fechamento.
  bool isClosed(YearMonth month, CalendarDate today) =>
      !today.isBefore(closingOf(month));

  /// Venceu: hoje > vencimento (o chamador confere se está pendente).
  bool isPastDue(YearMonth month, CalendarDate today) =>
      today.isAfter(dueOf(month));

  /// Valida a correção das datas de uma fatura. Devolve a mensagem de erro ou
  /// `null`. Além da regra da spec (§5.1), o fechamento precisa ficar entre
  /// os fechamentos das faturas vizinhas, para os ciclos não se sobreporem.
  String? validateCorrection(
    YearMonth month,
    CalendarDate closing,
    CalendarDate due,
  ) {
    if (!due.isAfter(closing)) {
      return 'O vencimento precisa ser depois do fechamento.';
    }
    if (!closing.isAfter(closingOf(month.add(-1)))) {
      return 'O fechamento precisa ser depois do fechamento da fatura '
          'anterior (${closingOf(month.add(-1)).toBr()}).';
    }
    if (!closing.isBefore(closingOf(month.add(1)))) {
      return 'O fechamento precisa ser antes do fechamento da fatura '
          'seguinte (${closingOf(month.add(1)).toBr()}).';
    }
    return null;
  }
}

/// Valida os dias do cartão (spec §4). Devolve a mensagem de erro ou `null`.
String? validateCardDays(int? closingDay, int? dueDay) {
  if (closingDay == null || closingDay < 1 || closingDay > 31) {
    return 'O dia de fechamento vai de 1 a 31.';
  }
  if (dueDay == null || dueDay < 1 || dueDay > 31) {
    return 'O dia de vencimento vai de 1 a 31.';
  }
  return null;
}
