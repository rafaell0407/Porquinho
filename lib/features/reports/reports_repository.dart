import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/reports.dart';
import '../../core/domain/surplus.dart';
import '../../core/local_database/app_database.dart';
import '../sync/sync_models.dart';

/// Dados dos relatórios de uma lista de períodos (Entrega 62). Cada
/// lançamento pertence a um único período, então nada é contado duas vezes.
class PeriodReport {
  const PeriodReport({
    required this.periods,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  /// Totais de cada período pedido, na ordem pedida (zero se vazio).
  final List<PeriodSummary> periods;
  final Map<String, CategoryBreakdown> incomeByCategory;
  final Map<String, CategoryBreakdown> expenseByCategory;

  PeriodTotals totalsOf(String periodId) => periods
      .firstWhere(
        (p) => p.periodId == periodId,
        orElse: () =>
            PeriodSummary(periodId: periodId, totals: PeriodTotals.zero),
      )
      .totals;

  CategoryBreakdown incomeOf(String periodId) =>
      incomeByCategory[periodId] ?? breakdownFromTotals(const []);

  CategoryBreakdown expenseOf(String periodId) =>
      expenseByCategory[periodId] ?? breakdownFromTotals(const []);
}

/// Onde os dados estão: banco local (celular) ou servidor (Web).
abstract interface class ReportsRepository {
  Future<PeriodReport> report(List<String> periodIds);
}

BigInt _big(Object? v) {
  if (v is num) return BigInt.from(v);
  return BigInt.parse(v.toString());
}

BigInt? _bigOrNull(Object? v) => v == null ? null : _big(v);

/// Celular: lê o banco local e soma em `BigInt` com as regras do domínio.
class LocalReportsRepository implements ReportsRepository {
  LocalReportsRepository(this._db, this._ownerId);

  final PorquinhoDatabase _db;
  final String _ownerId;

  @override
  Future<PeriodReport> report(List<String> periodIds) async {
    if (periodIds.isEmpty) {
      return const PeriodReport(
        periods: [],
        incomeByCategory: {},
        expenseByCategory: {},
      );
    }
    final marks = List.filled(periodIds.length, '?').join(', ');
    final vars = [
      Variable.withString(_ownerId),
      for (final id in periodIds) Variable.withString(id),
    ];
    final incomes = await _db
        .customSelect(
          'SELECT accounting_period_id AS pid, status, amount_centavos, '
          'category_id FROM income_entries WHERE owner_id = ? '
          "AND accounting_period_id IN ($marks) AND status = 'received'",
          variables: vars,
        )
        .get();
    final expenses = await _db
        .customSelect(
          'SELECT accounting_period_id AS pid, status, amount_centavos, '
          'category_id FROM expense_entries WHERE owner_id = ? '
          'AND accounting_period_id IN ($marks) '
          "AND status IN ('pending', 'paid')",
          variables: vars,
        )
        .get();
    final investments = await _db
        .customSelect(
          'SELECT accounting_period_id AS pid, amount_centavos '
          'FROM investment_allocations WHERE owner_id = ? '
          'AND accounting_period_id IN ($marks) AND cancelled_at IS NULL',
          variables: vars,
        )
        .get();

    final incomeBy = <String, List<IncomeLine>>{};
    for (final r in incomes) {
      incomeBy
          .putIfAbsent(r.read<String>('pid'), () => [])
          .add(
            IncomeLine(
              status: r.read<String>('status'),
              amount: _bigOrNull(r.data['amount_centavos']),
              categoryId: r.data['category_id'] as String?,
            ),
          );
    }
    final expenseBy = <String, List<ExpenseLine>>{};
    for (final r in expenses) {
      expenseBy
          .putIfAbsent(r.read<String>('pid'), () => [])
          .add(
            ExpenseLine(
              status: r.read<String>('status'),
              amount: _bigOrNull(r.data['amount_centavos']),
              categoryId: r.data['category_id'] as String?,
            ),
          );
    }
    final investmentBy = <String, List<InvestmentLine>>{};
    for (final r in investments) {
      investmentBy
          .putIfAbsent(r.read<String>('pid'), () => [])
          .add(InvestmentLine(amount: _big(r.data['amount_centavos'])));
    }
    return PeriodReport(
      periods: summarizePeriods([
        for (final id in periodIds)
          PeriodLines(
            periodId: id,
            incomes: incomeBy[id] ?? const [],
            expenses: expenseBy[id] ?? const [],
            investments: investmentBy[id] ?? const [],
          ),
      ]),
      incomeByCategory: {
        for (final e in incomeBy.entries) e.key: incomeByCategory(e.value),
      },
      expenseByCategory: {
        for (final e in expenseBy.entries) e.key: expenseByCategory(e.value),
      },
    );
  }
}

/// Fonte da leitura agregada do servidor (RPC `get_period_report`).
abstract interface class RemoteReportSource {
  Future<Map<String, dynamic>> fetch(List<String> periodIds);
}

class SupabaseReportSource implements RemoteReportSource {
  SupabaseReportSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> fetch(List<String> periodIds) async {
    try {
      final result = await _client.rpc(
        'get_period_report',
        params: {'p_period_ids': periodIds},
      );
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw SyncTransientError(e.message);
    } catch (e) {
      throw SyncTransientError(e.toString());
    }
  }
}

/// Web: o servidor soma (valores exatos, em texto), sem o limite de 1.000
/// linhas por consulta (D11).
class RemoteReportsRepository implements ReportsRepository {
  RemoteReportsRepository(this._source);

  final RemoteReportSource _source;

  /// Períodos por chamada (limite do servidor: 60).
  static const batchSize = 60;

  @override
  Future<PeriodReport> report(List<String> periodIds) async {
    final totals = <String, PeriodTotals>{};
    final income = <String, List<CategoryTotal>>{};
    final expense = <String, List<CategoryTotal>>{};

    void collect(
      Map<String, dynamic> json,
      String key,
      Map<String, List<CategoryTotal>> into,
    ) {
      for (final r in (json[key] as List).cast<Map>()) {
        into
            .putIfAbsent(r['period_id'] as String, () => [])
            .add(
              CategoryTotal(
                categoryId: r['category_id'] as String?,
                amount: _big(r['amount']),
              ),
            );
      }
    }

    for (var i = 0; i < periodIds.length; i += batchSize) {
      final end = i + batchSize > periodIds.length
          ? periodIds.length
          : i + batchSize;
      final json = await _source.fetch(periodIds.sublist(i, end));
      for (final p in (json['periods'] as List).cast<Map>()) {
        totals[p['period_id'] as String] = PeriodTotals(
          income: _big(p['income']),
          expense: _big(p['expense']),
          investment: _big(p['investment']),
        );
      }
      collect(json, 'income_by_category', income);
      collect(json, 'expense_by_category', expense);
    }
    return PeriodReport(
      periods: [
        for (final id in periodIds)
          PeriodSummary(periodId: id, totals: totals[id] ?? PeriodTotals.zero),
      ],
      incomeByCategory: {
        for (final e in income.entries) e.key: breakdownFromTotals(e.value),
      },
      expenseByCategory: {
        for (final e in expense.entries) e.key: breakdownFromTotals(e.value),
      },
    );
  }
}
