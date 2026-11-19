import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/period_calendar.dart';
import '../../../core/domain/recurrence_schedule.dart';
import 'import_models.dart';
import 'series_detection.dart';

/// Ocorrência que o servidor vai gerar entre a âncora e hoje (RN052).
class BackfillOccurrence {
  const BackfillOccurrence({
    required this.seriesId,
    required this.kind,
    required this.date,
    required this.amount,
  });

  final String seriesId;
  final RowKind kind;
  final CalendarDate date;

  /// `null` = despesa ou receita variável (sem valor até o usuário informar).
  final BigInt? amount;

  /// Conta no dinheiro livre ao gerar: despesa fixa e investimento. Receita
  /// fica pendente (só conta ao confirmar); variável, sem valor.
  bool get counts =>
      amount != null && (kind == RowKind.expense || kind == RowKind.investment);
}

/// Datas que `generate_due_recurrence_occurrences` criará para a série, pela
/// mesma regra (`RecurrenceCalendar.monthlyUntil`), sem o mês da âncora.
/// Âncora futura não gera atrasadas.
List<BackfillOccurrence> backfillFor(SeriesCandidate s, CalendarDate today) {
  final anchorMonth = s.anchor.date.monthIndex;
  return [
    for (final d in RecurrenceCalendar.monthlyUntil(s.schedule, today))
      if (d.monthIndex != anchorMonth)
        BackfillOccurrence(
          seriesId: s.id,
          kind: s.kind,
          date: d,
          amount: s.defaultAmount,
        ),
  ];
}

/// Efeito da importação num período: o que passa a contar no dinheiro livre.
class PeriodEffect {
  PeriodEffect(this.range);
  final PeriodRange range;
  BigInt income = BigInt.zero;
  BigInt expense = BigInt.zero;
  BigInt investment = BigInt.zero;
  int entries = 0;

  /// Variação do dinheiro livre do período.
  BigInt get delta => income - expense - investment;
}

/// Como cada linha conta (RN005–RN007): receita recebida; despesa com valor
/// (pendente ou paga); investimento. Receita pendente e valor em branco não.
bool rowCounts(ImportRow r) => switch (r.kind) {
  RowKind.income => r.state == EntryState.received && r.amount != null,
  RowKind.expense => r.amount != null,
  RowKind.investment => r.amount != null,
  RowKind.category => false,
};

/// Efeito por período (configuração atual do usuário), em ordem de data.
List<PeriodEffect> effectByPeriod(
  Iterable<ImportRow> rows,
  Iterable<BackfillOccurrence> backfill,
  PeriodConfig config,
) {
  final byRange = <PeriodRange, PeriodEffect>{};
  void add(RowKind kind, CalendarDate date, BigInt? amount, bool counts) {
    final range = PeriodCalendar.containing(config, date);
    final e = byRange.putIfAbsent(range, () => PeriodEffect(range));
    e.entries++;
    if (!counts || amount == null) return;
    switch (kind) {
      case RowKind.income:
        e.income += amount;
      case RowKind.expense:
        e.expense += amount;
      case RowKind.investment:
        e.investment += amount;
      case RowKind.category:
        break;
    }
  }

  for (final r in rows) {
    add(r.kind, r.date, r.amount, rowCounts(r));
  }
  for (final b in backfill) {
    add(b.kind, b.date, b.amount, b.counts);
  }
  return byRange.values.toList()
    ..sort((a, b) => a.range.start.compareTo(b.range.start));
}

/// Contagens que a prévia informa (RN052).
class BackfillCounts {
  const BackfillCounts({
    required this.overdueExpenses,
    required this.pendingIncomes,
    required this.unpricedExpenses,
  });

  /// Despesas que nascem pendentes e vencidas (alerta diário, RF023).
  final int overdueExpenses;

  /// Receitas que ficam pendentes (só contam ao confirmar).
  final int pendingIncomes;

  /// Despesas variáveis sem valor (contam ao receber valor).
  final int unpricedExpenses;
}

/// [anchors] = âncoras das séries confirmadas. Despesa avulsa só tem
/// vencimento se a coluna foi associada; âncora e ocorrências têm vencimento
/// = data (o servidor preenche).
BackfillCounts countPending(
  Iterable<ImportRow> rows,
  Set<ImportRow> anchors,
  Iterable<BackfillOccurrence> backfill,
  CalendarDate today,
) {
  var overdue = 0;
  var pendingIncome = 0;
  var unpriced = 0;
  for (final r in rows) {
    if (r.kind == RowKind.expense && r.state == EntryState.pending) {
      final due = anchors.contains(r) ? (r.dueOn ?? r.date) : r.dueOn;
      if (due != null && due.isBefore(today)) overdue++;
      if (r.amount == null) unpriced++;
    }
    if (r.kind == RowKind.income && r.state == EntryState.pending) {
      pendingIncome++;
    }
  }
  for (final b in backfill) {
    if (b.kind == RowKind.expense) {
      if (b.date.isBefore(today)) overdue++;
      if (b.amount == null) unpriced++;
    }
    if (b.kind == RowKind.income) pendingIncome++;
  }
  return BackfillCounts(
    overdueExpenses: overdue,
    pendingIncomes: pendingIncome,
    unpricedExpenses: unpriced,
  );
}
