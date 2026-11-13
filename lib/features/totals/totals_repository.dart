import 'package:drift/drift.dart';

import '../../core/domain/period_calendar.dart';
import '../../core/domain/surplus.dart';
import '../../core/local_database/app_database.dart';
import '../reports/reports_repository.dart';

/// Totais de um período (sobra) lidos de onde os dados estão. O período é um
/// intervalo de datas `[início, fim)`: soma os lançamentos cuja data de
/// competência está dentro dele (RN004, RN036; reestruturação P3).
abstract interface class TotalsRepository {
  Future<PeriodTotals> totalsFor(PeriodRange range);
}

BigInt? _big(Object? v) {
  if (v == null) return null;
  // JSON do servidor chega como número na Web (exato até 2^53 − 1).
  if (v is num) return BigInt.from(v);
  return BigInt.parse(v.toString());
}

/// Celular: lê o banco local e soma em `BigInt` (valores ficam como texto).
class LocalTotalsRepository implements TotalsRepository {
  LocalTotalsRepository(this._db, this._ownerId);

  final PorquinhoDatabase _db;
  final String _ownerId;

  @override
  Future<PeriodTotals> totalsFor(PeriodRange range) async {
    final vars = [
      Variable.withString(_ownerId),
      Variable.withString(range.start.toIso()),
      Variable.withString(range.end.toIso()),
    ];
    final incomes = await _db
        .customSelect(
          'SELECT status, amount_centavos FROM income_entries '
          'WHERE owner_id = ? AND received_on >= ? AND received_on < ? '
          "AND status = 'received'",
          variables: vars,
        )
        .get();
    final expenses = await _db
        .customSelect(
          'SELECT status, amount_centavos FROM expense_entries '
          'WHERE owner_id = ? AND competence_on >= ? AND competence_on < ? '
          "AND status IN ('pending', 'paid')",
          variables: vars,
        )
        .get();
    final investments = await _db
        .customSelect(
          'SELECT amount_centavos, cancelled_at FROM investment_allocations '
          'WHERE owner_id = ? AND allocated_on >= ? AND allocated_on < ? '
          'AND cancelled_at IS NULL',
          variables: vars,
        )
        .get();
    return computePeriodTotals(
      incomes: incomes.map(
        (r) => IncomeLine(
          status: r.read<String>('status'),
          amount: _big(r.data['amount_centavos']),
        ),
      ),
      expenses: expenses.map(
        (r) => ExpenseLine(
          status: r.read<String>('status'),
          amount: _big(r.data['amount_centavos']),
        ),
      ),
      investments: investments.map(
        (r) => InvestmentLine(amount: _big(r.data['amount_centavos'])!),
      ),
    );
  }
}

/// Web: o servidor soma por período (RPC de leitura agregada, sem o limite de
/// 1.000 linhas) e o app mostra o resultado (D11).
class RemoteTotalsRepository implements TotalsRepository {
  RemoteTotalsRepository(this._reports);

  final ReportsRepository _reports;

  @override
  Future<PeriodTotals> totalsFor(PeriodRange range) async =>
      (await _reports.report([range])).totalsOf(range);
}
