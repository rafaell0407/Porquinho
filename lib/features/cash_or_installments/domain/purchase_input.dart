import 'package:flutter/foundation.dart';

import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import 'cash_or_installments_engine.dart';

/// Entradas da Calculadora à vista ou parcelado (spec §3 e §4.1): leitura
/// dos campos, valor à vista com desconto, divisão do total e vencimentos.

/// Como o preço à vista é informado.
enum CashPriceMode { value, discount }

/// Como o parcelamento é informado.
enum InstallmentMode { total, perInstallment }

/// Fatura em que vem a 1ª parcela.
enum FirstBill { next, following }

/// Campos do formulário (para mostrar o erro no lugar certo).
enum PurchaseField {
  cashValue,
  price,
  discount,
  total,
  installmentValue,
  count,
  dueDay,
  percent,
  rate,
}

/// Limites (spec §3 e §15a).
abstract final class PurchaseLimits {
  /// Maior valor em cada campo de dinheiro: R$ 1.000.000,00.
  static final BigInt maxMoneyCents = BigInt.from(100000000);
  static const int maxInstallments = 24;
  static const int maxDiscountE2 = 9999;
  static const int maxCdiPercentE2 = 12000;
  static const int maxAnnualRateE2 = 10000;
}

/// Mensagem de campo inválido.
class PurchaseInputException implements Exception {
  const PurchaseInputException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Valor à vista = preço × (1 − desconto), em centavos, meio para cima.
BigInt cashPriceFromDiscount(BigInt priceCents, int discountE2) {
  if (discountE2 < 0 || discountE2 > PurchaseLimits.maxDiscountE2) {
    throw ArgumentError.value(discountE2, 'discountE2');
  }
  final numerator = priceCents * BigInt.from(10000 - discountE2);
  final d = BigInt.from(10000);
  return (numerator * BigInt.two + d) ~/ (d * BigInt.two);
}

/// Divide o total em [count] parcelas iguais; o resto (em centavos) vai
/// para a 1ª parcela.
List<BigInt> splitInstallments(BigInt totalCents, int count) {
  if (count < 1) throw ArgumentError.value(count, 'count');
  final n = BigInt.from(count);
  final base = totalCents ~/ n;
  final rest = totalCents - base * n;
  return [base + rest, for (var i = 1; i < count; i++) base];
}

/// Vencimento da próxima fatura: o primeiro "dia [dueDay]" depois de hoje
/// (dia inexistente no mês = último dia do mês).
CalendarDate nextBillDueDate(CalendarDate today, int dueDay) {
  final thisMonth = CalendarDate.clamped(today.year, today.month, dueDay);
  return thisMonth.isAfter(today)
      ? thisMonth
      : CalendarDate.clamped(today.year, today.month + 1, dueDay);
}

/// Vencimentos das [count] parcelas, sempre a partir do dia [dueDay].
List<CalendarDate> installmentDueDates(
  CalendarDate today,
  int dueDay,
  FirstBill bill,
  int count,
) {
  final first = nextBillDueDate(today, dueDay);
  final offset = bill == FirstBill.following ? 1 : 0;
  return [
    for (var k = 0; k < count; k++)
      CalendarDate.clamped(first.year, first.month + offset + k, dueDay),
  ];
}

/// Valores numéricos já lidos do formulário.
@immutable
class PurchaseValues {
  const PurchaseValues({
    required this.today,
    required this.cashMode,
    required this.installmentMode,
    required this.count,
    required this.dueDay,
    required this.bill,
    required this.product,
    required this.annualRateE2,
    this.cashValueCents,
    this.priceCents,
    this.discountE2,
    this.totalCents,
    this.installmentCents,
    this.percentE2 = 10000,
  });

  final CalendarDate today;
  final CashPriceMode cashMode;
  final BigInt? cashValueCents;
  final BigInt? priceCents;
  final int? discountE2;
  final InstallmentMode installmentMode;
  final BigInt? totalCents;
  final BigInt? installmentCents;
  final int count;
  final int dueDay;
  final FirstBill bill;
  final InvestmentProduct product;
  final int percentE2;
  final int annualRateE2;

  BigInt get cashPrice => cashMode == CashPriceMode.value
      ? cashValueCents!
      : cashPriceFromDiscount(priceCents!, discountE2!);

  List<BigInt> get installmentValues => installmentMode == InstallmentMode.total
      ? splitInstallments(totalCents!, count)
      : List.filled(count, installmentCents!);

  SimulationInput toSimulationInput() {
    final values = installmentValues;
    final dates = installmentDueDates(today, dueDay, bill, count);
    return SimulationInput(
      today: today,
      cashPriceCents: cashPrice,
      installments: [
        for (var k = 0; k < count; k++)
          Installment(dueDate: dates[k], cents: values[k]),
      ],
      product: product,
      percentE2: percentE2,
      annualRateE2: annualRateE2,
    );
  }
}

/// Dinheiro maior que zero, até [PurchaseLimits.maxMoneyCents].
BigInt parsePurchaseMoney(String text) {
  if (text.trim().isEmpty) {
    throw const PurchaseInputException('Informe um valor.');
  }
  final BigInt cents;
  try {
    cents = parseBrlToCentavos(text);
  } on MoneyFormatException catch (e) {
    throw PurchaseInputException(e.message);
  }
  if (cents == BigInt.zero) {
    throw const PurchaseInputException('Informe um valor maior que zero.');
  }
  if (cents > PurchaseLimits.maxMoneyCents) {
    throw const PurchaseInputException('Use um valor de até R\$ 1.000.000,00.');
  }
  return cents;
}

final _percentPattern = RegExp(r'^(\d{1,3})(?:[.,](\d{1,2}))?$');

/// Percentual com até 2 casas ("13,65", "100", "5 %"), em centésimos.
int parsePurchasePercent(String text, {required int maxE2, String? label}) {
  var t = text.trim();
  if (t.endsWith('%')) t = t.substring(0, t.length - 1).trim();
  if (t.isEmpty) {
    throw PurchaseInputException('Informe ${label ?? 'o percentual'}.');
  }
  if (t.startsWith('-')) {
    throw const PurchaseInputException('Não pode ser negativo.');
  }
  final m = _percentPattern.firstMatch(t);
  if (m == null) {
    if (RegExp(r'^\d+[.,]\d{3,}$').hasMatch(t)) {
      throw const PurchaseInputException('Use no máximo 2 casas decimais.');
    }
    throw const PurchaseInputException('Percentual inválido. Exemplo: 13,65');
  }
  final e2 =
      int.parse(m.group(1)!) * 100 +
      int.parse((m.group(2) ?? '').padRight(2, '0'));
  if (e2 > maxE2) {
    throw PurchaseInputException('Use até ${formatPercentE2(maxE2)}.');
  }
  return e2;
}

/// Inteiro de [min] a [max].
int parsePurchaseInt(String text, {required int min, required int max}) {
  final t = text.trim();
  if (t.isEmpty) throw const PurchaseInputException('Informe um número.');
  if (!RegExp(r'^\d{1,4}$').hasMatch(t)) {
    throw const PurchaseInputException('Use um número inteiro.');
  }
  final v = int.parse(t);
  if (v < min || v > max) {
    throw PurchaseInputException('Use um número de $min a $max.');
  }
  return v;
}

/// "13,65%", "100%", "5,5%".
String formatPercentE2(int e2) {
  final whole = e2 ~/ 100;
  final frac = (e2 % 100)
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? '$whole%' : '$whole,$frac%';
}

/// Textos digitados no formulário.
@immutable
class PurchaseForm {
  const PurchaseForm({
    required this.cashMode,
    required this.installmentMode,
    required this.bill,
    required this.product,
    this.cashValue = '',
    this.price = '',
    this.discount = '',
    this.total = '',
    this.installmentValue = '',
    this.count = '',
    this.dueDay = '',
    this.percent = '100',
    this.rate = '',
  });

  final CashPriceMode cashMode;
  final InstallmentMode installmentMode;
  final FirstBill bill;
  final InvestmentProduct product;
  final String cashValue;
  final String price;
  final String discount;
  final String total;
  final String installmentValue;
  final String count;
  final String dueDay;
  final String percent;
  final String rate;
}

typedef PurchaseValidation = ({
  SimulationInput? input,
  Map<PurchaseField, String> errors,
});

/// Lê e valida o formulário; [today] é a data da compra (hoje).
PurchaseValidation validatePurchase(PurchaseForm f, CalendarDate today) {
  final errors = <PurchaseField, String>{};
  T? read<T>(PurchaseField field, T Function() parse) {
    try {
      return parse();
    } on PurchaseInputException catch (e) {
      errors[field] = e.message;
      return null;
    }
  }

  BigInt? cashValue, price, total, installment;
  int? discount;
  if (f.cashMode == CashPriceMode.value) {
    cashValue = read(
      PurchaseField.cashValue,
      () => parsePurchaseMoney(f.cashValue),
    );
  } else {
    price = read(PurchaseField.price, () => parsePurchaseMoney(f.price));
    discount = read(
      PurchaseField.discount,
      () => f.discount.trim().isEmpty
          ? 0
          : parsePurchasePercent(
              f.discount,
              maxE2: PurchaseLimits.maxDiscountE2,
              label: 'o desconto',
            ),
    );
    if (price != null &&
        discount != null &&
        cashPriceFromDiscount(price, discount) == BigInt.zero) {
      errors[PurchaseField.discount] = 'Com esse desconto, o valor fica zero.';
    }
  }
  final count = read(
    PurchaseField.count,
    () =>
        parsePurchaseInt(f.count, min: 1, max: PurchaseLimits.maxInstallments),
  );
  if (f.installmentMode == InstallmentMode.total) {
    total = read(PurchaseField.total, () => parsePurchaseMoney(f.total));
    if (total != null && count != null && total < BigInt.from(count)) {
      errors[PurchaseField.total] =
          'O total precisa dar pelo menos R\$ 0,01 '
          'por parcela.';
    }
  } else {
    installment = read(
      PurchaseField.installmentValue,
      () => parsePurchaseMoney(f.installmentValue),
    );
    if (installment != null &&
        count != null &&
        installment * BigInt.from(count) > PurchaseLimits.maxMoneyCents) {
      errors[PurchaseField.installmentValue] =
          'O total parcelado passa de R\$ 1.000.000,00.';
    }
  }
  final dueDay = read(
    PurchaseField.dueDay,
    () => parsePurchaseInt(f.dueDay, min: 1, max: 31),
  );
  final percent = f.product == InvestmentProduct.cdb
      ? read(
          PurchaseField.percent,
          () => parsePurchasePercent(
            f.percent,
            maxE2: PurchaseLimits.maxCdiPercentE2,
            label: 'o % do CDI',
          ),
        )
      : 10000;
  final rate = read(
    PurchaseField.rate,
    () => parsePurchasePercent(
      f.rate,
      maxE2: PurchaseLimits.maxAnnualRateE2,
      label: 'a taxa ao ano',
    ),
  );
  if (errors.isNotEmpty) return (input: null, errors: errors);
  final values = PurchaseValues(
    today: today,
    cashMode: f.cashMode,
    cashValueCents: cashValue,
    priceCents: price,
    discountE2: discount,
    installmentMode: f.installmentMode,
    totalCents: total,
    installmentCents: installment,
    count: count!,
    dueDay: dueDay!,
    bill: f.bill,
    product: f.product,
    percentE2: percent!,
    annualRateE2: rate!,
  );
  return (input: values.toSimulationInput(), errors: const {});
}
