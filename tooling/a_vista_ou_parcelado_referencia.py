"""Referência independente da Calculadora à vista ou parcelado.

Gera ``test/fixtures/cash_or_installments_cases.json``, que o teste Dart
compara ao centavo. Especificação: ``docs/ferramentas/a_vista_ou_parcelado.md``.

Independência em relação ao código do app (de propósito):
- feriados a partir de uma TABELA de datas da Páscoa (o app usa fórmula);
- conta por COTAS (valor de 1 real aplicado em cada data), não por posição
  com custo e saldo dia a dia como o app;
- ``Decimal`` com 50 dígitos (o app usa inteiros grandes em ponto fixo).

Uso (na raiz do repositório; só biblioteca padrão):
    python tooling/a_vista_ou_parcelado_referencia.py
    python tooling/a_vista_ou_parcelado_referencia.py --check   # só confere
"""

from __future__ import annotations

import calendar
import datetime as dt
import json
import random
import sys
from decimal import ROUND_HALF_UP, Decimal, getcontext
from pathlib import Path

getcontext().prec = 50

FIXTURE = Path(__file__).resolve().parent.parent / "test" / "fixtures" / (
    "cash_or_installments_cases.json"
)

# Domingo de Páscoa (datas publicadas; não calculadas).
EASTER = {
    2022: dt.date(2022, 4, 17),
    2023: dt.date(2023, 4, 9),
    2024: dt.date(2024, 3, 31),
    2025: dt.date(2025, 4, 20),
    2026: dt.date(2026, 4, 5),
    2027: dt.date(2027, 3, 28),
    2028: dt.date(2028, 4, 16),
    2029: dt.date(2029, 4, 1),
    2030: dt.date(2030, 4, 21),
    2031: dt.date(2031, 4, 13),
    2032: dt.date(2032, 3, 28),
}

IOF = [100, 96, 93, 90, 86, 83, 80, 76, 73, 70, 66, 63, 60, 56, 53, 50, 46,
       43, 40, 36, 33, 30, 26, 23, 20, 16, 13, 10, 6, 3]


# --------------------------------------------------------------- calendário
def holidays(year: int) -> list[dt.date]:
    e = EASTER[year]
    days = [
        dt.date(year, 1, 1),
        e - dt.timedelta(days=48),  # segunda de Carnaval
        e - dt.timedelta(days=47),  # terça de Carnaval
        e - dt.timedelta(days=2),   # Sexta-feira Santa
        dt.date(year, 4, 21),
        dt.date(year, 5, 1),
        e + dt.timedelta(days=60),  # Corpus Christi
        dt.date(year, 9, 7),
        dt.date(year, 10, 12),
        dt.date(year, 11, 2),
        dt.date(year, 11, 15),
        dt.date(year, 12, 25),
    ]
    if year >= 2024:
        days.append(dt.date(year, 11, 20))
    return sorted(days)


_HOLIDAYS: set[dt.date] = {d for y in EASTER for d in holidays(y)}


def is_business(d: dt.date) -> bool:
    return d.weekday() < 5 and d not in _HOLIDAYS


def next_business(d: dt.date) -> dt.date:
    while not is_business(d):
        d += dt.timedelta(days=1)
    return d


def prev_business(d: dt.date) -> dt.date:
    while not is_business(d):
        d -= dt.timedelta(days=1)
    return d


def business_days(start: dt.date, end: dt.date) -> int:
    """Dias úteis d com start <= d < end."""
    n = 0
    d = start
    while d < end:
        if is_business(d):
            n += 1
        d += dt.timedelta(days=1)
    return n


def day_in_month(year: int, month: int, day: int) -> dt.date:
    while month > 12:
        month -= 12
        year += 1
    last = calendar.monthrange(year, month)[1]
    return dt.date(year, month, min(day, last))


def due_dates(today: dt.date, due_day: int, bill: str, n: int) -> list[dt.date]:
    offset = 0
    if day_in_month(today.year, today.month, due_day) <= today:
        offset = 1
    if bill == "seguinte":
        offset += 1
    return [day_in_month(today.year, today.month + offset + k, due_day)
            for k in range(n)]


# ----------------------------------------------------------------- impostos
def iof_rate(days: int) -> Decimal:
    return Decimal(IOF[days]) / 100 if days < 30 else Decimal(0)


def ir_rate(days: int) -> Decimal:
    if days <= 180:
        return Decimal("0.225")
    if days <= 360:
        return Decimal("0.20")
    if days <= 720:
        return Decimal("0.175")
    return Decimal("0.15")


def half_up(x: Decimal) -> int:
    """Centavos (Decimal em centavos) → inteiro, meio para cima."""
    assert x >= 0, x
    return int(x.quantize(Decimal(1), rounding=ROUND_HALF_UP))


# --------------------------------------------------------------- simulação
class Quote:
    """Valor de 1 centavo aplicado em ``start``, por data de resgate."""

    def __init__(self, start: dt.date, annual_e2: int, percent_e2: int):
        self.start = start
        a = Decimal(annual_e2) / 10000
        daily = (1 + a) ** (Decimal(1) / Decimal(252)) - 1
        self.factor = 1 + daily * Decimal(percent_e2) / 10000

    def gross(self, d: dt.date) -> Decimal:
        return self.factor ** business_days(self.start, d)

    def taxes(self, d: dt.date) -> tuple[Decimal, Decimal]:
        days = (d - self.start).days
        return iof_rate(days), ir_rate(days)

    def net(self, d: dt.date) -> Decimal:
        g = self.gross(d)
        iof, ir = self.taxes(d)
        y = g - 1
        return 1 + y - y * iof - (y - y * iof) * ir


def derive_inputs(case: dict) -> tuple[int, list[int]]:
    av = case["a_vista"]
    if av["modo"] == "valor":
        cash = av["valor"]
    else:
        cash = half_up(Decimal(av["preco"]) * (10000 - av["desconto_e2"]) / 10000)
    pc = case["parcelado"]
    n = pc["n"]
    if pc["modo"] == "total":
        base, rest = divmod(pc["total"], n)
        values = [base + rest] + [base] * (n - 1)
    else:
        values = [pc["parcela"]] * n
    return cash, values


def simulate(case: dict, reserve_extra: int = 0) -> dict:
    today = dt.date.fromisoformat(case["hoje"])
    cash_price, values = derive_inputs(case)
    total = sum(values)
    reserve = max(total, cash_price) + reserve_extra
    percent = case["percentual_e2"] if case["produto"] == "cdb" else 10000
    apply_on = next_business(today)
    dues = due_dates(today, case["dia_vencimento"], case["fatura"], len(values))
    redeems = [prev_business(d) for d in dues]
    end = redeems[-1]
    q = Quote(apply_on, case["taxa_anual_e2"], percent)

    # ---- parcelado: cotas
    direct = [r <= apply_on for r in redeems]
    applied = reserve - sum(v for v, dd in zip(values, direct) if dd)
    units = Decimal(applied)          # cotas restantes (1 cota = 1 centavo)
    yield_done = Decimal(0)           # rendimento já resgatado
    iof_cum = Decimal(0)
    ir_cum = Decimal(0)
    paid = 0
    rows = []
    prev_final = reserve
    prev_y = prev_t = 0
    for v, due, red, dd in zip(values, dues, redeems, direct):
        if dd:
            accrued = yield_done  # paga direto da reserva: nada aplicado ainda
        else:
            g = q.gross(red)
            iof, ir = q.taxes(red)
            accrued = yield_done + units * (g - 1)
            u = Decimal(v) / q.net(red)
            y = u * (g - 1)
            t_iof = y * iof
            t_ir = (y - t_iof) * ir
            assert abs(u * g - t_iof - t_ir - v) < Decimal("1e-30")
            units -= u
            yield_done += y
            iof_cum += t_iof
            ir_cum += t_ir
        paid += v
        y_r = half_up(accrued)
        t_r = half_up(iof_cum) + half_up(ir_cum)
        final = reserve + y_r - t_r - paid
        rows.append({
            "vencimento": due.isoformat(),
            "resgate": red.isoformat(),
            "direto": dd,
            "saldo_inicial": prev_final,
            "rendimento": y_r - prev_y,
            "impostos": t_r - prev_t,
            "parcela": v,
            "saldo_final": final,
        })
        prev_final, prev_y, prev_t = final, y_r, t_r

    # resgate do que sobrou (no mesmo dia da última parcela)
    if end > apply_on:
        g = q.gross(end)
        iof, ir = q.taxes(end)
        y = units * (g - 1)
        t_iof = y * iof
        iof_cum += t_iof
        ir_cum += (y - t_iof) * ir
        exact_cash = units * q.net(end)
    else:
        exact_cash = units
    ap_y = half_up(yield_done + (units * (q.gross(end) - 1) if end > apply_on
                                 else 0))
    ap_iof = half_up(iof_cum)
    ap_ir = half_up(ir_cum)
    ap_cash = reserve + ap_y - ap_iof - ap_ir - total
    assert ap_y == prev_y, (ap_y, prev_y)
    final_row = {
        "saldo_inicial": prev_final,
        "impostos": ap_iof + ap_ir - prev_t,
        "caixa": ap_cash,
    }
    assert final_row["saldo_inicial"] - final_row["impostos"] == ap_cash

    # ---- à vista
    left = reserve - cash_price
    if left > 0 and end > apply_on:
        g = q.gross(end)
        iof, ir = q.taxes(end)
        y = left * (g - 1)
        av_iof_x = y * iof
        av_ir_x = (y - av_iof_x) * ir
        av_y, av_iof, av_ir = half_up(y), half_up(av_iof_x), half_up(av_ir_x)
        av_exact = left * q.net(end)
    else:
        av_y = av_iof = av_ir = 0
        av_exact = Decimal(left)
    av_cash = left + av_y - av_iof - av_ir

    chart = []
    for red, row in zip(redeems, rows):
        gross = left * q.gross(red) if red > apply_on else Decimal(left)
        chart.append({"a_vista": half_up(gross), "a_prazo": row["saldo_final"]})

    diff = av_cash - ap_cash
    verdict = "empate" if abs(diff) < 100 else ("a_vista" if diff > 0
                                                 else "a_prazo")
    return {
        "valor_a_vista": cash_price,
        "total_parcelado": total,
        "reserva": reserve,
        "aplicacao": apply_on.isoformat(),
        "fim": end.isoformat(),
        "a_vista": {"investido": left, "rendimento": av_y, "ir": av_ir,
                    "iof": av_iof, "caixa": av_cash},
        "a_prazo": {"investido": applied, "rendimento": ap_y, "ir": ap_ir,
                    "iof": ap_iof, "caixa": ap_cash, "linhas": rows,
                    "final": final_row},
        "grafico": chart,
        "diferenca": diff,
        "veredito": verdict,
        "_exato": av_exact - exact_cash,
    }


# ------------------------------------------------------------------- casos
def named_cases() -> list[dict]:
    def case(cid, hoje, due, bill, av, pc, prod="cdb", pct=10000, rate=1365):
        return {"id": cid, "hoje": hoje, "dia_vencimento": due, "fatura": bill,
                "a_vista": av, "parcelado": pc, "produto": prod,
                "percentual_e2": pct, "taxa_anual_e2": rate}

    v = lambda c: {"modo": "valor", "valor": c}  # noqa: E731
    d = lambda p, e2: {"modo": "desconto", "preco": p, "desconto_e2": e2}  # noqa
    t = lambda c, n: {"modo": "total", "total": c, "n": n}  # noqa: E731
    p = lambda c, n: {"modo": "parcela", "parcela": c, "n": n}  # noqa: E731
    return [
        case("esboco_1000_5pct_10x", "2026-11-14", 10, "proxima",
             d(100000, 500), t(100000, 10)),
        case("sem_desconto_vence_parcelado", "2026-11-16", 10, "proxima",
             v(100000), t(100000, 10)),
        case("desconto_grande_vence_a_vista", "2026-11-16", 10, "proxima",
             d(100000, 1500), t(100000, 10)),
        case("uma_parcela", "2026-11-16", 5, "proxima", v(99000), t(100000, 1)),
        case("vinte_e_quatro_parcelas_seguinte", "2026-11-16", 31, "seguinte",
             d(500000, 300), t(500000, 24), "tesouro_selic", 10000, 1490),
        case("dia_31_fevereiro", "2027-01-05", 31, "proxima",
             v(120000), t(123457, 7)),
        case("vencimento_hoje_vai_para_o_mes_seguinte", "2026-12-10", 10,
             "proxima", v(50000), t(51000, 3)),
        case("compra_no_sabado_vencimento_domingo", "2026-11-14", 15,
             "proxima", v(30000), t(30000, 3)),
        case("compra_no_feriado", "2026-11-20", 25, "proxima", v(80000),
             p(8500, 10)),
        case("taxa_zero", "2026-11-16", 10, "proxima", v(95000),
             t(100000, 10), "cdb", 10000, 0),
        case("cdi_zero_por_cento", "2026-11-16", 10, "proxima", v(95000),
             t(100000, 10), "cdb", 0, 1365),
        case("cdb_120", "2026-11-16", 10, "proxima", v(95000), t(100000, 10),
             "cdb", 12000, 1490),
        case("a_vista_maior_que_parcelado", "2026-11-16", 10, "proxima",
             v(105000), t(100000, 5)),
        case("iof_primeira_parcela", "2026-11-03", 10, "proxima", v(98000),
             t(100000, 4)),
        case("valor_da_parcela", "2027-02-10", 20, "proxima",
             d(299990, 1000), p(29999, 10)),
        case("centavos_resto_na_primeira", "2026-11-16", 7, "proxima",
             v(9999), t(10000, 3)),
        case("taxa_cem_por_cento", "2026-11-16", 10, "seguinte", v(900000),
             t(1000000, 12), "cdb", 11000, 10000),
        case("valor_maximo", "2026-11-16", 10, "proxima", v(100000000),
             t(100000000, 24), "cdb", 12000, 10000),
        case("empate_proximo", "2026-11-16", 10, "proxima", v(99700),
             t(100000, 3)),
        case("carnaval_2027", "2027-01-20", 9, "proxima", v(60000),
             t(60000, 2)),
        case("natal_e_ano_novo", "2026-12-01", 25, "proxima", v(70000),
             t(72000, 2), "tesouro_selic", 10000, 1490),
        case("ir_mais_de_720_dias", "2026-11-16", 30, "seguinte", v(2000000),
             t(2400000, 24), "cdb", 10500, 1365),
    ]


def random_cases(count: int) -> list[dict]:
    rnd = random.Random(20261114)
    start = dt.date(2026, 11, 1)
    out = []
    for i in range(count):
        hoje = start + dt.timedelta(days=rnd.randrange(0, 760))
        n = rnd.randint(1, 24)
        total = rnd.randint(n, 2000000)
        if rnd.random() < 0.3:
            pc = {"modo": "parcela", "parcela": max(1, total // n), "n": n}
            total = pc["parcela"] * n
        else:
            pc = {"modo": "total", "total": total, "n": n}
        if rnd.random() < 0.5:
            av = {"modo": "desconto", "preco": total,
                  "desconto_e2": rnd.choice([0, 1, 250, 500, 1000, 3333, 9999])}
        else:
            av = {"modo": "valor",
                  "valor": max(1, total - rnd.randint(0, total // 5))}
        prod = rnd.choice(["cdb", "tesouro_selic"])
        out.append({
            "id": f"aleatorio_{i:03d}",
            "hoje": hoje.isoformat(),
            "dia_vencimento": rnd.randint(1, 31),
            "fatura": rnd.choice(["proxima", "seguinte"]),
            "a_vista": av,
            "parcelado": pc,
            "produto": prod,
            "percentual_e2": (rnd.choice([0, 8500, 9000, 10000, 10250, 12000])
                              if prod == "cdb" else 10000),
            "taxa_anual_e2": rnd.choice([0, 1050, 1365, 1490, 2500, 10000]),
        })
    return out


def build() -> dict:
    cases = []
    for c in named_cases() + random_cases(80):
        res = simulate(c)
        # propriedade de controle: diferença exata não depende da reserva
        more = simulate(c, reserve_extra=12345)
        assert abs(res["_exato"] - more["_exato"]) < Decimal("1e-25"), c["id"]
        assert abs(res["diferenca"] - more["diferenca"]) <= 2, c["id"]
        assert res["a_prazo"]["caixa"] >= 0 and res["a_vista"]["caixa"] >= 0
        res.pop("_exato")
        cases.append({"entrada": c, "esperado": res})

    years = range(2024, 2031)
    calendar_section = {
        "feriados": {str(y): [d.isoformat() for d in holidays(y)]
                     for y in years},
        "dias_uteis_no_ano": {
            str(y): business_days(dt.date(y, 1, 1), dt.date(y + 1, 1, 1))
            for y in years},
        "dia_util_anterior": {
            s: prev_business(dt.date.fromisoformat(s)).isoformat()
            for s in ["2026-11-15", "2026-11-20", "2026-11-22", "2027-01-10",
                      "2027-02-09", "2027-03-26", "2026-12-25", "2027-01-01",
                      "2027-05-27", "2026-11-16"]},
        "proximo_dia_util": {
            s: next_business(dt.date.fromisoformat(s)).isoformat()
            for s in ["2026-11-14", "2026-11-20", "2026-12-24", "2026-12-25",
                      "2027-02-08", "2027-02-06", "2027-03-25", "2026-11-16"]},
    }
    taxes_section = {
        "iof_por_dia": [IOF[d] if d < 30 else 0 for d in range(0, 31)],
        "ir_permil": {str(d): int(ir_rate(d) * 1000)
                      for d in [0, 1, 180, 181, 360, 361, 720, 721, 800]},
    }
    # Fórmula fechada: 252 dias úteis a 100% rendem exatamente a taxa anual.
    q = Quote(dt.date(2027, 1, 4), 1365, 10000)
    g = q.factor ** 252
    assert abs(g - Decimal("1.1365")) < Decimal("1e-40")
    # Conferência manual na Calculadora do Cidadão (BCB): CDI 13,65% fixo.
    s, e = dt.date(2022, 9, 1), dt.date(2023, 8, 1)
    du = business_days(s, e)
    cidadao = Decimal(100000) * (Decimal("1.1365") ** (Decimal(du) / 252))
    return {
        "_sobre": "Gerado por tooling/a_vista_ou_parcelado_referencia.py. "
                  "Não editar à mão. Valores em centavos.",
        "calendario": calendar_section,
        "impostos": taxes_section,
        "conferencia_cidadao": {
            "inicio": s.isoformat(), "fim": e.isoformat(),
            "dias_uteis": du, "valor_inicial": 100000,
            "valor_corrigido": half_up(cidadao),
        },
        "casos": cases,
    }


def main() -> int:
    data = build()
    text = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
    if "--check" in sys.argv:
        same = FIXTURE.exists() and FIXTURE.read_text("utf-8") == text
        print("fixture em dia" if same else "fixture DESATUALIZADA")
        return 0 if same else 1
    FIXTURE.write_text(text, "utf-8")
    print(f"{len(data['casos'])} casos gravados em {FIXTURE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
