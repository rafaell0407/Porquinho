import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/features/cash_or_installments/domain/cash_or_installments_engine.dart';

/// Tabela de casos gerada pela referência independente
/// (`tooling/a_vista_ou_parcelado_referencia.py`). Não editar à mão.
Map<String, dynamic> loadCashOrInstallmentsFixture() =>
    jsonDecode(
          File(
            'test/fixtures/cash_or_installments_cases.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

BigInt fixtureCents(Object? v) => BigInt.from(v! as int);

InvestmentProduct productFromFixture(String id) =>
    id == 'cdb' ? InvestmentProduct.cdb : InvestmentProduct.treasurySelic;

/// Monta a entrada do motor só com os dados já derivados pela referência
/// (parcelas e valor à vista), para testar o motor isolado das entradas.
SimulationInput engineInputFromFixture(
  Map<String, dynamic> entrada,
  Map<String, dynamic> esperado,
) {
  final rows = (esperado['a_prazo']['linhas'] as List)
      .cast<Map<String, dynamic>>();
  return SimulationInput(
    today: CalendarDate.parse(entrada['hoje'] as String),
    cashPriceCents: fixtureCents(esperado['valor_a_vista']),
    installments: [
      for (final r in rows)
        Installment(
          dueDate: CalendarDate.parse(r['vencimento'] as String),
          cents: fixtureCents(r['parcela']),
        ),
    ],
    product: productFromFixture(entrada['produto'] as String),
    percentE2: entrada['percentual_e2'] as int,
    annualRateE2: entrada['taxa_anual_e2'] as int,
  );
}

/// Compara o resultado do app com o esperado da referência, ao centavo.
void expectMatchesReference(SimulationResult r, Map<String, dynamic> e) {
  void path(PathSummary p, Map<String, dynamic> x, String name) {
    expect(p.invested, fixtureCents(x['investido']), reason: '$name investido');
    expect(
      p.yieldCents,
      fixtureCents(x['rendimento']),
      reason: '$name rendimento',
    );
    expect(p.incomeTax, fixtureCents(x['ir']), reason: '$name IR');
    expect(p.iof, fixtureCents(x['iof']), reason: '$name IOF');
    expect(p.cash, fixtureCents(x['caixa']), reason: '$name caixa');
  }

  expect(r.reserve, fixtureCents(e['reserva']), reason: 'reserva');
  expect(r.applicationDate.toIso(), e['aplicacao'], reason: 'aplicação');
  expect(r.endDate.toIso(), e['fim'], reason: 'fim');
  path(r.cashPath, e['a_vista'] as Map<String, dynamic>, 'à vista');
  path(r.installmentPath, e['a_prazo'] as Map<String, dynamic>, 'a prazo');
  final rows = (e['a_prazo']['linhas'] as List).cast<Map<String, dynamic>>();
  expect(r.rows.length, rows.length);
  for (var i = 0; i < rows.length; i++) {
    final a = r.rows[i];
    final x = rows[i];
    final why = 'linha ${i + 1}';
    expect(a.dueDate.toIso(), x['vencimento'], reason: why);
    expect(a.redeemDate.toIso(), x['resgate'], reason: why);
    expect(a.paidFromReserve, x['direto'], reason: why);
    expect(
      a.startBalance,
      fixtureCents(x['saldo_inicial']),
      reason: '$why inicial',
    );
    expect(
      a.yieldCents,
      fixtureCents(x['rendimento']),
      reason: '$why rendimento',
    );
    expect(a.taxes, fixtureCents(x['impostos']), reason: '$why impostos');
    expect(a.installment, fixtureCents(x['parcela']), reason: '$why parcela');
    expect(a.endBalance, fixtureCents(x['saldo_final']), reason: '$why final');
  }
  final f = e['a_prazo']['final'] as Map<String, dynamic>;
  expect(r.finalRedemption.startBalance, fixtureCents(f['saldo_inicial']));
  expect(r.finalRedemption.taxes, fixtureCents(f['impostos']));
  expect(r.finalRedemption.cash, fixtureCents(f['caixa']));
  final chart = (e['grafico'] as List).cast<Map<String, dynamic>>();
  for (var i = 0; i < chart.length; i++) {
    expect(
      r.chart[i].cashPath,
      fixtureCents(chart[i]['a_vista']),
      reason: 'gráfico $i',
    );
    expect(r.chart[i].installmentPath, fixtureCents(chart[i]['a_prazo']));
  }
  expect(r.difference, fixtureCents(e['diferenca']), reason: 'diferença');
  const verdicts = {
    'a_vista': Verdict.cash,
    'a_prazo': Verdict.installments,
    'empate': Verdict.tie,
  };
  expect(r.verdict, verdicts[e['veredito']], reason: 'veredito');
}
