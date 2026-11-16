import 'package:flutter/foundation.dart';

import '../../../core/domain/calendar_date.dart';
import 'business_calendar.dart';
import 'fixed_point.dart';
import 'investment_taxes.dart';

/// Motor da Calculadora à vista ou parcelado (spec
/// `docs/ferramentas/a_vista_ou_parcelado.md` §4–§8 e §12). Simulação pura
/// em memória: não grava nada e não cria lançamentos.

/// Onde a reserva fica aplicada.
enum InvestmentProduct {
  cdb('CDB liquidez diária', 'CDI'),
  treasurySelic('Tesouro Selic', 'Selic');

  const InvestmentProduct(this.label, this.indexName);
  final String label;

  /// Taxa de referência: "CDI" ou "Selic".
  final String indexName;
}

/// Uma parcela: vencimento e valor em centavos.
@immutable
class Installment {
  const Installment({required this.dueDate, required this.cents});
  final CalendarDate dueDate;
  final BigInt cents;
}

/// Entrada já validada do motor.
@immutable
class SimulationInput {
  SimulationInput({
    required this.today,
    required this.cashPriceCents,
    required List<Installment> installments,
    required this.product,
    required this.percentE2,
    required this.annualRateE2,
  }) : installments = List.unmodifiable(installments) {
    if (installments.isEmpty) {
      throw ArgumentError.value(installments, 'installments', 'vazio');
    }
    for (var i = 0; i < installments.length; i++) {
      final it = installments[i];
      if (it.cents <= BigInt.zero) {
        throw ArgumentError.value(it.cents, 'cents', 'parcela sem valor');
      }
      if (!it.dueDate.isAfter(today) ||
          (i > 0 && !it.dueDate.isAfter(installments[i - 1].dueDate))) {
        throw ArgumentError.value(it.dueDate, 'dueDate', 'fora de ordem');
      }
    }
    if (cashPriceCents <= BigInt.zero) {
      throw ArgumentError.value(cashPriceCents, 'cashPriceCents');
    }
  }

  final CalendarDate today;
  final BigInt cashPriceCents;
  final List<Installment> installments;
  final InvestmentProduct product;

  /// % do CDI em centésimos (10000 = 100%). Ignorado no Tesouro Selic.
  final int percentE2;

  /// Taxa anual (CDI ou Selic) em centésimos de % (1365 = 13,65%).
  final int annualRateE2;

  int get effectivePercentE2 =>
      product == InvestmentProduct.treasurySelic ? 10000 : percentE2;

  BigInt get totalInstallmentsCents =>
      installments.fold(BigInt.zero, (s, i) => s + i.cents);
}

/// Totais de um caminho, em centavos (já arredondados para exibição).
@immutable
class PathSummary {
  const PathSummary({
    required this.invested,
    required this.yieldCents,
    required this.incomeTax,
    required this.iof,
    required this.cash,
  });

  /// Quanto ficou aplicado no início.
  final BigInt invested;
  final BigInt yieldCents;
  final BigInt incomeTax;
  final BigInt iof;

  /// Em caixa no fim, depois de tudo pago e resgatado.
  final BigInt cash;

  BigInt get taxes => incomeTax + iof;
}

/// Linha "fatura a fatura" do caminho parcelado.
@immutable
class InstallmentRow {
  const InstallmentRow({
    required this.dueDate,
    required this.redeemDate,
    required this.paidFromReserve,
    required this.startBalance,
    required this.yieldCents,
    required this.taxes,
    required this.installment,
    required this.endBalance,
  });

  final CalendarDate dueDate;

  /// Dia do resgate (dia útil anterior quando o vencimento não é dia útil).
  final CalendarDate redeemDate;

  /// Paga direto da reserva (resgate no dia da aplicação ou antes).
  final bool paidFromReserve;
  final BigInt startBalance;
  final BigInt yieldCents;

  /// IR + IOF do resgate.
  final BigInt taxes;
  final BigInt installment;
  final BigInt endBalance;
}

/// Linha final: resgate do que sobrou.
@immutable
class FinalRedemption {
  const FinalRedemption({
    required this.startBalance,
    required this.taxes,
    required this.cash,
  });
  final BigInt startBalance;
  final BigInt taxes;
  final BigInt cash;
}

/// Ponto do gráfico (no dia do resgate de cada parcela): saldo aplicado
/// em cada caminho, em centavos.
@immutable
class ChartPoint {
  const ChartPoint({
    required this.date,
    required this.cashPath,
    required this.installmentPath,
  });
  final CalendarDate date;
  final BigInt cashPath;
  final BigInt installmentPath;
}

enum Verdict { cash, installments, tie }

/// Diferença abaixo disso dá "DÁ NO MESMO" (spec §8): R$ 1,00.
final BigInt tieThresholdCents = BigInt.from(100);

@immutable
class SimulationResult {
  const SimulationResult({
    required this.input,
    required this.reserve,
    required this.applicationDate,
    required this.endDate,
    required this.cashPath,
    required this.installmentPath,
    required this.rows,
    required this.finalRedemption,
    required this.chart,
  });

  final SimulationInput input;

  /// Maior valor entre o total parcelado e o valor à vista.
  final BigInt reserve;
  final CalendarDate applicationDate;

  /// Dia do resgate da última parcela (e do que sobrou).
  final CalendarDate endDate;
  final PathSummary cashPath;
  final PathSummary installmentPath;
  final List<InstallmentRow> rows;
  final FinalRedemption finalRedemption;
  final List<ChartPoint> chart;

  CalendarDate get lastDueDate => input.installments.last.dueDate;

  /// Em caixa à vista − em caixa parcelado (valores mostrados).
  BigInt get difference => cashPath.cash - installmentPath.cash;

  Verdict get verdict {
    final d = difference;
    if (d.abs() < tieThresholdCents) return Verdict.tie;
    return d.isNegative ? Verdict.installments : Verdict.cash;
  }
}

/// Posição única (mesma data de aplicação para todo o dinheiro): valor
/// bruto e custo, em ponto fixo; rende dia útil a dia útil.
class _Position {
  _Position(BigInt cents, this._rate, this._start)
    : value = Fixed.fromCents(cents),
      cost = Fixed.fromCents(cents),
      _cursor = _start;

  final DailyRate _rate;
  final CalendarDate _start;
  CalendarDate _cursor;
  BigInt value;
  BigInt cost;

  /// Rendimento bruto acumulado desde a aplicação (inclui o já resgatado).
  BigInt accruedYield = BigInt.zero;
  BigInt iof = BigInt.zero;
  BigInt incomeTax = BigInt.zero;

  /// Rende em cada dia útil d com cursor ≤ d < [date].
  void growUntil(CalendarDate date) {
    for (var d = _cursor; d.isBefore(date); d = d.addDays(1)) {
      if (BusinessCalendar.isBusinessDay(d)) {
        final y = _rate.dayYield(value);
        value += y;
        accruedYield += y;
      }
    }
    if (date.isAfter(_cursor)) _cursor = date;
  }

  ({int iofPercent, int irPermil}) _ratesOn(CalendarDate date) {
    final days = BusinessCalendar.calendarDaysBetween(_start, date);
    return (
      iofPercent: InvestmentTaxes.iofPercent(days),
      irPermil: InvestmentTaxes.irPermil(days),
    );
  }

  /// Resgata o bruto necessário para receber [netCents] líquidos (imposto
  /// "por dentro", proporcional ao rendimento da posição; spec §7).
  void redeemNet(BigInt netCents, CalendarDate date) {
    final net = Fixed.fromCents(netCents);
    final r = _ratesOn(date);
    final earned = value - cost;
    // τ = IOF + IR·(1 − IOF), denominador 100.000.
    final tauNum = BigInt.from(
      r.iofPercent * 1000 + r.irPermil * (100 - r.iofPercent),
    );
    final tauDen = BigInt.from(100000);
    final gross = Fixed.divHalfEven(
      net * value * tauDen,
      value * tauDen - earned * tauNum,
    );
    if (gross > value) {
      throw StateError('Resgate maior que a posição.');
    }
    final earnedPart = Fixed.divHalfEven(gross * earned, value);
    final iofPart = Fixed.divHalfEven(
      earnedPart * BigInt.from(r.iofPercent),
      BigInt.from(100),
    );
    iof += iofPart;
    incomeTax += gross - net - iofPart;
    cost -= gross - earnedPart;
    value -= gross;
  }

  /// Resgata tudo; devolve o líquido em ponto fixo.
  BigInt redeemAll(CalendarDate date) {
    final r = _ratesOn(date);
    final earned = value - cost;
    final iofPart = Fixed.divHalfEven(
      earned * BigInt.from(r.iofPercent),
      BigInt.from(100),
    );
    final irPart = Fixed.divHalfEven(
      (earned - iofPart) * BigInt.from(r.irPermil),
      BigInt.from(1000),
    );
    iof += iofPart;
    incomeTax += irPart;
    final net = value - iofPart - irPart;
    value = BigInt.zero;
    cost = BigInt.zero;
    return net;
  }
}

/// Simula os dois caminhos. Lança [ArgumentError] para entrada impossível
/// (a validação da tela evita).
///
/// [extraReserveCents] só existe para o teste de controle (spec §8: a
/// diferença não depende do tamanho da reserva); a tela nunca usa.
SimulationResult simulateCashOrInstallments(
  SimulationInput input, {
  @visibleForTesting BigInt? extraReserveCents,
}) {
  final total = input.totalInstallmentsCents;
  final cashPrice = input.cashPriceCents;
  final reserve =
      (total > cashPrice ? total : cashPrice) +
      (extraReserveCents ?? BigInt.zero);
  final rate = DailyRate(
    annualRateE2: input.annualRateE2,
    percentE2: input.effectivePercentE2,
  );
  final apply = BusinessCalendar.nextOrSame(input.today);
  final redeemDates = [
    for (final i in input.installments)
      BusinessCalendar.previousOrSame(i.dueDate),
  ];
  final end = redeemDates.last;
  final fromReserve = [for (final r in redeemDates) !r.isAfter(apply)];

  // ---- parcelado
  var applied = reserve;
  for (var k = 0; k < input.installments.length; k++) {
    if (fromReserve[k]) applied -= input.installments[k].cents;
  }
  final position = _Position(applied, rate, apply);
  final rows = <InstallmentRow>[];
  var paid = BigInt.zero;
  var prevEnd = reserve;
  var prevYield = BigInt.zero;
  var prevTaxes = BigInt.zero;
  BigInt shownTaxes() =>
      Fixed.toCentsHalfUp(position.iof) +
      Fixed.toCentsHalfUp(position.incomeTax);

  // ---- à vista (mesmo investimento, mesma data de aplicação)
  final left = reserve - cashPrice;
  final cashPosition = _Position(left, rate, apply);
  final chart = <ChartPoint>[];

  for (var k = 0; k < input.installments.length; k++) {
    final it = input.installments[k];
    final redeem = redeemDates[k];
    if (!fromReserve[k]) {
      position.growUntil(redeem);
      position.redeemNet(it.cents, redeem);
    }
    paid += it.cents;
    final y = Fixed.toCentsHalfUp(position.accruedYield);
    final t = shownTaxes();
    final endBalance = reserve + y - t - paid;
    rows.add(
      InstallmentRow(
        dueDate: it.dueDate,
        redeemDate: redeem,
        paidFromReserve: fromReserve[k],
        startBalance: prevEnd,
        yieldCents: y - prevYield,
        taxes: t - prevTaxes,
        installment: it.cents,
        endBalance: endBalance,
      ),
    );
    prevEnd = endBalance;
    prevYield = y;
    prevTaxes = t;

    if (redeem.isAfter(apply)) cashPosition.growUntil(redeem);
    chart.add(
      ChartPoint(
        date: redeem,
        cashPath: Fixed.toCentsHalfUp(cashPosition.value),
        installmentPath: endBalance,
      ),
    );
  }

  // Resgate do que sobrou, no dia da última parcela.
  if (end.isAfter(apply)) position.redeemAll(end);
  final apYield = Fixed.toCentsHalfUp(position.accruedYield);
  final apIof = Fixed.toCentsHalfUp(position.iof);
  final apIr = Fixed.toCentsHalfUp(position.incomeTax);
  final apCash = reserve + apYield - apIof - apIr - total;
  final finalRedemption = FinalRedemption(
    startBalance: prevEnd,
    taxes: apIof + apIr - prevTaxes,
    cash: apCash,
  );

  if (left > BigInt.zero && end.isAfter(apply)) {
    cashPosition.growUntil(end);
    cashPosition.redeemAll(end);
  }
  final avYield = Fixed.toCentsHalfUp(cashPosition.accruedYield);
  final avIof = Fixed.toCentsHalfUp(cashPosition.iof);
  final avIr = Fixed.toCentsHalfUp(cashPosition.incomeTax);

  return SimulationResult(
    input: input,
    reserve: reserve,
    applicationDate: apply,
    endDate: end,
    cashPath: PathSummary(
      invested: left,
      yieldCents: avYield,
      incomeTax: avIr,
      iof: avIof,
      cash: left + avYield - avIof - avIr,
    ),
    installmentPath: PathSummary(
      invested: applied,
      yieldCents: apYield,
      incomeTax: apIr,
      iof: apIof,
      cash: apCash,
    ),
    rows: List.unmodifiable(rows),
    finalRedemption: finalRedemption,
    chart: List.unmodifiable(chart),
  );
}
