import 'package:drift/drift.dart';

import '../../core/domain/surplus.dart';
import '../../core/local_database/app_database.dart';
import '../sync/remote_table_reader.dart';

/// Totais de um período (sobra) lidos de onde os dados estão.
abstract interface class TotalsRepository {
  Future<PeriodTotals> totalsFor(String periodId);
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
  Future<PeriodTotals> totalsFor(String periodId) async {
    final vars = [Variable.withString(_ownerId), Variable.withString(periodId)];
    final incomes = await _db
        .customSelect(
          'SELECT status, amount_centavos FROM income_entries '
          "WHERE owner_id = ? AND accounting_period_id = ? AND status = 'received'",
          variables: vars,
        )
        .get();
    final expenses = await _db
        .customSelect(
          'SELECT status, amount_centavos FROM expense_entries '
          'WHERE owner_id = ? AND accounting_period_id = ? '
          "AND status IN ('pending', 'paid')",
          variables: vars,
        )
        .get();
    final investments = await _db
        .customSelect(
          'SELECT amount_centavos, cancelled_at FROM investment_allocations '
          'WHERE owner_id = ? AND accounting_period_id = ? '
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

/// Web: lê do servidor (somente online) e soma no app com a mesma regra.
class RemoteTotalsRepository implements TotalsRepository {
  RemoteTotalsRepository(this._reader);

  final RemoteTableReader _reader;

  @override
  Future<PeriodTotals> totalsFor(String periodId) async {
    final filter = [RemoteFilter.eq('accounting_period_id', periodId)];
    final incomes = await _reader.select('income_entries', filters: filter);
    final expenses = await _reader.select('expense_entries', filters: filter);
    final investments = await _reader.select(
      'investment_allocations',
      filters: filter,
    );
    return computePeriodTotals(
      incomes: incomes.map(
        (r) => IncomeLine(
          status: r['status'] as String,
          amount: _big(r['amount_centavos']),
        ),
      ),
      expenses: expenses.map(
        (r) => ExpenseLine(
          status: r['status'] as String,
          amount: _big(r['amount_centavos']),
        ),
      ),
      investments: investments.map(
        (r) => InvestmentLine(
          amount: _big(r['amount_centavos'])!,
          cancelled: r['cancelled_at'] != null,
        ),
      ),
    );
  }
}
