import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/recurrence_schedule.dart';
import 'category_resolution.dart';
import 'existing_data.dart';
import 'import_models.dart';

/// Situação de uma série encontrada no arquivo (RN051, D32, D33).
enum SeriesStatus {
  /// Pode ser confirmada (caixa desmarcada).
  suggested,

  /// Âncora antes do mês anterior: parece encerrada, entra só como avulsos.
  ended,

  /// Âncora em mês futuro: não é oferecida.
  future,

  /// Colide com modelo ou lançamento existente: só avulsos, com aviso.
  collision,
}

class SeriesCandidate {
  const SeriesCandidate({
    required this.id,
    required this.kind,
    required this.rows,
    required this.category,
    required this.habitualDay,
    required this.fixed,
    required this.status,
    this.description,
    this.collisionReason,
  });

  /// Identidade estável da série (vai no plano quando confirmada).
  final String id;
  final RowKind kind;
  final String? description;

  /// Linhas da série em ordem de data; a última é a âncora.
  final List<ImportRow> rows;
  final CategoryRef category;

  /// Dia mais frequente na série.
  final int habitualDay;

  /// Todos os valores iguais (investimento: sempre).
  final bool fixed;
  final SeriesStatus status;
  final String? collisionReason;

  ImportRow get anchor => rows.last;

  /// Dia de referência = dia da âncora (D20).
  int get referenceDay => anchor.date.day;

  /// Aviso quando o dia da âncora difere do habitual.
  bool get dayDiffers => referenceDay != habitualDay;

  BigInt? get defaultAmount => fixed ? anchor.amount : null;

  RecurrenceSchedule get schedule =>
      RecurrenceSchedule.monthly(startsOn: anchor.date, day: referenceDay);
}

const seriesMinMonths = 3;
const seriesDayTolerance = 3;

String _seriesKey(ImportRow r, CategoryRef category) =>
    r.kind == RowKind.investment
    ? '${r.kind.key}|${r.amount}'
    : '${r.kind.key}|${normalizeKey(r.description)}|${category.identity}';

/// Encontra séries mensais no arquivo: mesmo tipo, descrição (não vazia) e
/// categoria escolhida — investimento, pelo valor igual —, pelo menos 3 meses
/// seguidos com uma ocorrência por mês e dia consistente (tolerância de 3
/// dias, com o ajuste de fim de mês e dia útil). Só a sequência que termina
/// no lançamento mais recente do grupo é considerada. [existing] alimenta as
/// travas de colisão; [today] a de série encerrada.
List<SeriesCandidate> detectSeries(
  List<ImportRow> rows,
  Map<String, CategoryChoice> choices,
  CalendarDate today,
  ExistingData existing,
) {
  final groups = <String, List<(ImportRow, CategoryRef)>>{};
  for (final r in rows) {
    if (r.kind != RowKind.investment && normalizeKey(r.description).isEmpty) {
      continue;
    }
    if (r.kind == RowKind.investment && r.amount == null) continue;
    final ref = resolveCategory(r, choices);
    groups.putIfAbsent(_seriesKey(r, ref), () => []).add((r, ref));
  }

  final result = <SeriesCandidate>[];
  for (final entry in groups.entries) {
    final list = [...entry.value]
      ..sort((a, b) {
        final c = a.$1.date.compareTo(b.$1.date);
        return c != 0 ? c : a.$1.sourceRow.compareTo(b.$1.sourceRow);
      });
    final last = list.last.$1;
    // Linhas que só entram como âncora valem apenas na última posição.
    final usable = [
      for (final e in list)
        if (!e.$1.anchorOnly || identical(e.$1, last)) e.$1,
    ];
    final byMonth = <int, List<ImportRow>>{};
    for (final r in usable) {
      byMonth.putIfAbsent(r.date.monthIndex, () => []).add(r);
    }
    final run = <ImportRow>[];
    var month = last.date.monthIndex;
    while (byMonth[month]?.length == 1) {
      run.insert(0, byMonth[month]!.single);
      month--;
    }
    if (run.length < seriesMinMonths || !identical(run.last, last)) continue;

    final dayCount = <int, int>{};
    for (final r in run) {
      dayCount[r.date.day] = (dayCount[r.date.day] ?? 0) + 1;
    }
    final habitual = dayCount.entries
        .reduce(
          (a, b) => b.value > a.value || (b.value == a.value && b.key > a.key)
              ? b
              : a,
        )
        .key;
    // Mantém a parte final consistente com o dia habitual.
    var start = run.length;
    for (var i = run.length - 1; i >= 0; i--) {
      final d = run[i].date;
      final expected = RecurrenceCalendar.monthlyDate(
        d.year,
        d.month,
        habitual,
      );
      final diff =
          (DateTime.utc(d.year, d.month, d.day)
                  .difference(
                    DateTime.utc(expected.year, expected.month, expected.day),
                  )
                  .inDays)
              .abs();
      if (diff > seriesDayTolerance) break;
      start = i;
    }
    final series = run.sublist(start);
    if (series.length < seriesMinMonths || !identical(series.last, last)) {
      continue;
    }

    final kind = last.kind;
    final fixed =
        kind == RowKind.investment ||
        (series.every((r) => r.amount != null) &&
            series.every((r) => r.amount == last.amount));
    final ref = list.last.$2;

    var status = SeriesStatus.suggested;
    String? reason;
    final diffMonths = today.monthIndex - last.date.monthIndex;
    if (diffMonths > 1) {
      status = SeriesStatus.ended;
    } else if (diffMonths < 0) {
      status = SeriesStatus.future;
    } else {
      reason = _collision(kind, last, ref, today, existing);
      if (reason != null) status = SeriesStatus.collision;
    }

    result.add(
      SeriesCandidate(
        id: entry.key,
        kind: kind,
        description: kind == RowKind.investment ? null : last.description,
        rows: series,
        category: ref,
        habitualDay: habitual,
        fixed: fixed,
        status: status,
        collisionReason: reason,
      ),
    );
  }
  result.sort((a, b) => a.anchor.sourceRow.compareTo(b.anchor.sourceRow));
  return result;
}

/// Trava D32: modelo ativo parecido ou lançamento existente nos meses que a
/// recorrência geraria (do mês seguinte ao da âncora até hoje).
String? _collision(
  RowKind kind,
  ImportRow anchor,
  CategoryRef ref,
  CalendarDate today,
  ExistingData existing,
) {
  bool similarDescription(String? d) =>
      normalizeKey(d) == normalizeKey(anchor.description);
  for (final t in existing.templates) {
    if (!t.active || t.kind != kind) continue;
    final same = kind == RowKind.investment
        ? t.amount == anchor.amount
        : similarDescription(t.description) &&
              (t.categoryId ?? '') == (ref.categoryId ?? '') &&
              ref.newCategoryKey == null;
    if (same) {
      return 'Já existe uma recorrência parecida. Os lançamentos entram só '
          'como avulsos.';
    }
  }
  final firstMonth = anchor.date.monthIndex + 1;
  for (final e in existing.entries) {
    if (e.cancelled || e.kind != kind) continue;
    final m = e.date.monthIndex;
    if (m < firstMonth || m > today.monthIndex) continue;
    final same = kind == RowKind.investment
        ? e.amount == anchor.amount
        : similarDescription(e.description);
    if (same) {
      return 'Já existe lançamento parecido em ${e.date.toBr()}, mês que a '
          'recorrência geraria. Os lançamentos entram só como avulsos.';
    }
  }
  return null;
}
