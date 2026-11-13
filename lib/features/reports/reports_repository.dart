import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../../core/domain/reports.dart';
import '../../core/domain/surplus.dart';
import '../../core/local_database/app_database.dart';
import '../sync/sync_models.dart';

/// Dados dos relatórios de uma lista de períodos (Entrega 62). Cada período é
/// um intervalo de datas `[início, fim)` (RN036) e soma os lançamentos cuja
/// data de competência está dentro dele (RN004; reestruturação P3).
class PeriodReport {
  const PeriodReport({
    required this.periods,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  /// Totais de cada período pedido, na ordem pedida (zero se vazio).
  final List<PeriodSummary> periods;
  final Map<PeriodRange, CategoryBreakdown> incomeByCategory;
  final Map<PeriodRange, CategoryBreakdown> expenseByCategory;

  PeriodTotals totalsOf(PeriodRange range) => periods
      .firstWhere(
        (p) => p.range == range,
        orElse: () => PeriodSummary(range: range, totals: PeriodTotals.zero),
      )
      .totals;

  CategoryBreakdown incomeOf(PeriodRange range) =>
      incomeByCategory[range] ?? breakdownFromTotals(const []);

  CategoryBreakdown expenseOf(PeriodRange range) =>
      expenseByCategory[range] ?? breakdownFromTotals(const []);
}

/// Onde os dados estão: banco local (celular) ou servidor (Web).
abstract interface class ReportsRepository {
  Future<PeriodReport> report(List<PeriodRange> ranges);
}

BigInt _big(Object? v) {
  if (v is num) return BigInt.from(v);
  return BigInt.parse(v.toString());
}

BigInt? _bigOrNull(Object? v) => v == null ? null : _big(v);

/// Celular: lê o banco local e soma em `BigInt` com as regras do domínio.
/// Filtra pelas datas de competência, nunca pelo vínculo com o período.
class LocalReportsRepository implements ReportsRepository {
  LocalReportsRepository(this._db, this._ownerId);

  final PorquinhoDatabase _db;
  final String _ownerId;

  @override
  Future<PeriodReport> report(List<PeriodRange> ranges) async {
    if (ranges.isEmpty) {
      return const PeriodReport(
        periods: [],
        incomeByCategory: {},
        expenseByCategory: {},
      );
    }
    // Uma consulta por tabela cobrindo todos os intervalos; cada linha vai
    // para cada intervalo que contém a sua data (intervalos podem se cruzar).
    var from = ranges.first.start;
    var to = ranges.first.end;
    for (final r in ranges) {
      if (r.start.isBefore(from)) from = r.start;
      if (r.end.isAfter(to)) to = r.end;
    }
    final vars = [
      Variable.withString(_ownerId),
      Variable.withString(from.toIso()),
      Variable.withString(to.toIso()),
    ];
    final incomes = await _db
        .customSelect(
          'SELECT received_on AS d, status, amount_centavos, category_id '
          'FROM income_entries WHERE owner_id = ? '
          'AND received_on >= ? AND received_on < ? '
          "AND status = 'received'",
          variables: vars,
        )
        .get();
    final expenses = await _db
        .customSelect(
          'SELECT competence_on AS d, status, amount_centavos, category_id '
          'FROM expense_entries WHERE owner_id = ? '
          'AND competence_on >= ? AND competence_on < ? '
          "AND status IN ('pending', 'paid')",
          variables: vars,
        )
        .get();
    final investments = await _db
        .customSelect(
          'SELECT allocated_on AS d, amount_centavos '
          'FROM investment_allocations WHERE owner_id = ? '
          'AND allocated_on >= ? AND allocated_on < ? '
          'AND cancelled_at IS NULL',
          variables: vars,
        )
        .get();

    Map<PeriodRange, List<T>> bucket<T>(
      List<QueryRow> rows,
      T Function(QueryRow) line,
    ) {
      final by = <PeriodRange, List<T>>{};
      for (final row in rows) {
        final date = CalendarDate.parse(row.read<String>('d'));
        for (final r in ranges) {
          if (r.contains(date)) by.putIfAbsent(r, () => []).add(line(row));
        }
      }
      return by;
    }

    final incomeBy = bucket(
      incomes,
      (r) => IncomeLine(
        status: r.read<String>('status'),
        amount: _bigOrNull(r.data['amount_centavos']),
        categoryId: r.data['category_id'] as String?,
      ),
    );
    final expenseBy = bucket(
      expenses,
      (r) => ExpenseLine(
        status: r.read<String>('status'),
        amount: _bigOrNull(r.data['amount_centavos']),
        categoryId: r.data['category_id'] as String?,
      ),
    );
    final investmentBy = bucket(
      investments,
      (r) => InvestmentLine(amount: _big(r.data['amount_centavos'])),
    );
    return PeriodReport(
      periods: summarizePeriods([
        for (final r in ranges)
          PeriodLines(
            range: r,
            incomes: incomeBy[r] ?? const [],
            expenses: expenseBy[r] ?? const [],
            investments: investmentBy[r] ?? const [],
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

/// Fonte da leitura agregada do servidor (RPC `get_range_report`).
abstract interface class RemoteReportSource {
  Future<Map<String, dynamic>> fetch(List<PeriodRange> ranges);
}

class SupabaseReportSource implements RemoteReportSource {
  SupabaseReportSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> fetch(List<PeriodRange> ranges) async {
    try {
      final result = await _client.rpc(
        'get_range_report',
        params: {
          'p_starts': [for (final r in ranges) r.start.toIso()],
          'p_ends': [for (final r in ranges) r.end.toIso()],
        },
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

  /// Intervalos por chamada (limite do servidor: 60).
  static const batchSize = 60;

  @override
  Future<PeriodReport> report(List<PeriodRange> ranges) async {
    final totals = <PeriodRange, PeriodTotals>{};
    final income = <PeriodRange, List<CategoryTotal>>{};
    final expense = <PeriodRange, List<CategoryTotal>>{};

    for (var i = 0; i < ranges.length; i += batchSize) {
      final end = i + batchSize > ranges.length ? ranges.length : i + batchSize;
      final batch = ranges.sublist(i, end);
      final json = await _source.fetch(batch);
      // O servidor identifica cada intervalo pela posição no pedido (1…n).
      PeriodRange rangeAt(Map r) => batch[(r['index'] as num).toInt() - 1];

      void collect(String key, Map<PeriodRange, List<CategoryTotal>> into) {
        for (final r in (json[key] as List).cast<Map>()) {
          into
              .putIfAbsent(rangeAt(r), () => [])
              .add(
                CategoryTotal(
                  categoryId: r['category_id'] as String?,
                  amount: _big(r['amount']),
                ),
              );
        }
      }

      for (final p in (json['ranges'] as List).cast<Map>()) {
        totals[rangeAt(p)] = PeriodTotals(
          income: _big(p['income']),
          expense: _big(p['expense']),
          investment: _big(p['investment']),
        );
      }
      collect('income_by_category', income);
      collect('expense_by_category', expense);
    }
    return PeriodReport(
      periods: [
        for (final r in ranges)
          PeriodSummary(range: r, totals: totals[r] ?? PeriodTotals.zero),
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
