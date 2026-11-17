import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/card_calendar.dart';
import 'package:porquinho/features/card_bills/domain/deterministic_id.dart';

import 'card_bills_fixtures.dart';

/// GF1.1 calendário do cartão e GF1.2 ciclo e fatura da compra (spec §4, §5.1).
void main() {
  group('datas da fatura', () {
    test('dia 31 em mês curto = último dia do mês, sem dia útil', () {
      const card = CreditCard(id: 'a', name: 'A', closingDay: 31, dueDay: 10);
      expect(CardCalendar.defaultClosing(card, ym('2027-04')), d('2027-04-30'));
      expect(CardCalendar.defaultClosing(card, ym('2027-02')), d('2027-02-28'));
      expect(CardCalendar.defaultClosing(card, ym('2028-02')), d('2028-02-29'));
      // 30/04/2027 é sexta; 28/02/2027 é domingo: não muda para dia útil.
      expect(
        CardCalendar.defaultClosing(card, ym('2027-02')).isBusinessDay,
        isFalse,
      );
    });

    test('vencimento maior que o fechamento: mesmo mês', () {
      expect(CardCalendar.defaultDue(nubank, ym('2026-11')), d('2026-11-17'));
    });

    test('vencimento menor que o fechamento: mês seguinte', () {
      const card = CreditCard(id: 'b', name: 'B', closingDay: 28, dueDay: 5);
      expect(CardCalendar.defaultClosing(card, ym('2026-11')), d('2026-11-28'));
      expect(CardCalendar.defaultDue(card, ym('2026-11')), d('2026-12-05'));
      expect(CardCalendar.defaultDue(card, ym('2026-12')), d('2027-01-05'));
    });

    test(
      'fechamento e vencimento no mesmo dia: aceito, vence no mês seguinte',
      () {
        const card = CreditCard(id: 'c', name: 'C', closingDay: 10, dueDay: 10);
        expect(validateCardDays(10, 10), isNull);
        expect(CardCalendar.defaultDue(card, ym('2026-11')), d('2026-12-10'));
      },
    );

    test('ajuste ao fim do mês nunca deixa o vencimento no fechamento', () {
      const card = CreditCard(id: 'd', name: 'D', closingDay: 30, dueDay: 31);
      expect(CardCalendar.defaultDue(card, ym('2027-01')), d('2027-01-31'));
      // Novembro: 30 e 31→30 cairiam no mesmo dia → vence em 31/12.
      expect(CardCalendar.defaultDue(card, ym('2026-11')), d('2026-12-31'));
      expect(CardCalendar.defaultClosing(card, ym('2027-02')), d('2027-02-28'));
      expect(CardCalendar.defaultDue(card, ym('2027-02')), d('2027-03-31'));
    });

    test('dias fora de 1–31 são recusados', () {
      expect(validateCardDays(0, 10), isNotNull);
      expect(validateCardDays(10, 32), isNotNull);
      expect(validateCardDays(null, 10), isNotNull);
      expect(validateCardDays(31, 1), isNull);
    });
  });

  group('ciclo e fatura da compra', () {
    final calendar = CardCalendar(nubank, const []);

    test(
      'antes do fechamento entra na fatura; no dia ou depois, na seguinte',
      () {
        expect(calendar.monthFor(d('2026-11-09')), ym('2026-11'));
        expect(calendar.monthFor(d('2026-11-10')), ym('2026-12'));
        expect(calendar.monthFor(d('2026-11-16')), ym('2026-12'));
        expect(calendar.monthFor(d('2026-12-09')), ym('2026-12'));
        expect(calendar.monthFor(d('2026-12-10')), ym('2027-01'));
        expect(calendar.monthFor(d('2026-12-31')), ym('2027-01'));
      },
    );

    test('ciclo = [fechamento anterior, fechamento)', () {
      expect(calendar.cycleStart(ym('2026-12')), d('2026-11-10'));
      expect(calendar.closingOf(ym('2026-12')), d('2026-12-10'));
    });

    test('fatura atual contém hoje; fechada e vencida pelas datas', () {
      final today = d('2026-11-16');
      expect(calendar.currentMonth(today), ym('2026-12'));
      expect(calendar.isClosed(ym('2026-11'), today), isTrue);
      expect(calendar.isPastDue(ym('2026-11'), today), isFalse);
      expect(calendar.isPastDue(ym('2026-11'), d('2026-11-18')), isTrue);
      expect(calendar.isClosed(ym('2026-12'), today), isFalse);
    });

    test('dias 29–31 e ano bissexto', () {
      const card = CreditCard(id: 'e', name: 'E', closingDay: 30, dueDay: 8);
      final cal = CardCalendar(card, const []);
      // Fevereiro/2028 fecha em 29 (bissexto): 29/02 já é da fatura de março.
      expect(cal.closingOf(ym('2028-02')), d('2028-02-29'));
      expect(cal.monthFor(d('2028-02-28')), ym('2028-02'));
      expect(cal.monthFor(d('2028-02-29')), ym('2028-03'));
      expect(cal.monthFor(d('2028-03-29')), ym('2028-03'));
      expect(cal.monthFor(d('2028-03-30')), ym('2028-04'));
    });

    test('datas corrigidas à mão mudam o ciclo das compras novas', () {
      final dec = ym('2026-12');
      final corrected = InvoiceRecord(
        id: CardBillIds.invoice(nubank.id, dec),
        cardId: nubank.id,
        month: dec,
        closingOn: d('2026-12-08'),
        dueOn: d('2026-12-15'),
        datesManual: true,
      );
      final cal = CardCalendar(nubank, [corrected]);
      expect(cal.monthFor(d('2026-12-07')), dec);
      expect(cal.monthFor(d('2026-12-08')), ym('2027-01'));
      expect(cal.cycleStart(ym('2027-01')), d('2026-12-08'));
      expect(cal.dueOf(dec), d('2026-12-15'));
    });

    test(
      'correção recusa vencimento no fechamento ou antes e ciclos sobrepostos',
      () {
        final dec = ym('2026-12');
        expect(
          calendar.validateCorrection(dec, d('2026-12-08'), d('2026-12-08')),
          'O vencimento precisa ser depois do fechamento.',
        );
        expect(
          calendar.validateCorrection(dec, d('2026-12-08'), d('2026-12-07')),
          isNotNull,
        );
        expect(
          calendar.validateCorrection(dec, d('2026-11-10'), d('2026-12-17')),
          isNotNull,
        );
        expect(
          calendar.validateCorrection(dec, d('2027-01-10'), d('2027-01-17')),
          isNotNull,
        );
        expect(
          calendar.validateCorrection(dec, d('2026-12-08'), d('2026-12-15')),
          isNull,
        );
      },
    );
  });

  test('ids determinísticos: mesma fatura, mesmo id em qualquer aparelho', () {
    final a = CardBillIds.invoice('card-1', ym('2026-12'));
    expect(a, CardBillIds.invoice('card-1', ym('2026-12')));
    expect(a, isNot(CardBillIds.invoice('card-1', ym('2027-01'))));
    expect(
      a,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(
      CardBillIds.charge('s', ym('2026-12')),
      isNot(CardBillIds.installment('s', 1)),
    );
  });
}
