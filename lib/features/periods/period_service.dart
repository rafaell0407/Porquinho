import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../sync/sync_models.dart';
import 'period_models.dart';
import 'period_repository.dart';

/// Regras de criação de períodos (RN001–RN003, RN036–RN037, RN002). Não sabe
/// onde os dados ficam: usa o [PeriodRepository] do celular ou da Web.
class PeriodService {
  PeriodService(this._repo, {String Function()? newId})
    : _newId = newId ?? newUuid;

  final PeriodRepository _repo;
  final String Function() _newId;

  /// `true` se a conta ainda não tem configuração de período (primeiro acesso).
  /// Antes de perguntar, traz do servidor o que já existir, para que um
  /// segundo aparelho não pergunte de novo.
  Future<bool> needsSetup() async {
    if ((await _repo.configurations()).isNotEmpty) return false;
    await _repo.refreshFromServer();
    return (await _repo.configurations()).isEmpty;
  }

  /// Primeiro acesso: grava a configuração e o período que contém [today].
  Future<PeriodRange> setup(PeriodConfig config, CalendarDate today) async {
    final range = PeriodCalendar.containing(config, today);
    await _repo.createPeriod(
      PeriodDraft(
        id: _newId(),
        configurationId: _newId(),
        config: config,
        range: range,
        newConfiguration: true,
      ),
    );
    return range;
  }

  /// Garante que existam períodos consecutivos até o que contém [today].
  /// Devolve os períodos criados agora.
  Future<List<PeriodRange>> ensureUpTo(CalendarDate today) async {
    final configs = await _repo.configurations();
    final periods = await _repo.periods();
    if (configs.isEmpty || periods.isEmpty) return const [];
    final created = <PeriodRange>[];
    var last = periods.last;
    while (!today.isBefore(last.range.end)) {
      final draft = _next(configs, last);
      await _repo.createPeriod(draft);
      created.add(draft.range);
      last = PeriodRecord(
        id: draft.id,
        configurationId: draft.configurationId,
        range: draft.range,
        version: 1,
      );
    }
    return created;
  }

  PeriodDraft _next(List<PeriodConfigRecord> configs, PeriodRecord last) {
    final start = last.range.end;
    final applicable = configs.lastWhere(
      (c) => !c.effectiveFrom.isAfter(start),
      orElse: () => configs.firstWhere((c) => c.id == last.configurationId),
    );
    final changed = applicable.id != last.configurationId;
    final range = changed
        ? PeriodCalendar.transition(applicable.config, start)
        : PeriodCalendar.containing(applicable.config, start);
    return PeriodDraft(
      id: _newId(),
      configurationId: applicable.id,
      config: applicable.config,
      range: range,
      newConfiguration: false,
      dependsOnPeriodId: last.id,
    );
  }

  /// Período existente que contém [date], ou `null` se ainda não foi criado.
  Future<PeriodRecord?> periodFor(CalendarDate date) async {
    for (final p in await _repo.periods()) {
      if (p.range.contains(date)) return p;
    }
    return null;
  }

  /// Períodos que faltam para cobrir [date] (RN002), ou `null` se já existe.
  /// Não grava nada: serve para perguntar ao usuário antes de criar.
  Future<PeriodPlan?> planFor(CalendarDate date) async {
    final configs = await _repo.configurations();
    final periods = await _repo.periods();
    if (configs.isEmpty || periods.isEmpty) return null;
    return _plan(date, configs, periods);
  }

  PeriodPlan? _plan(
    CalendarDate date,
    List<PeriodConfigRecord> configs,
    List<PeriodRecord> periods,
  ) {
    final first = periods.first;
    final last = periods.last;
    if (date.isBefore(first.range.start)) {
      final config = configs
          .firstWhere((c) => c.id == first.configurationId)
          .config;
      final ranges = <PeriodRange>[];
      var current = first.range;
      while (date.isBefore(current.start)) {
        current = PeriodCalendar.previous(config, current);
        ranges.add(current);
        if (ranges.length > maxPeriodsPerRequest) {
          throw const PeriodTooFarException();
        }
      }
      return PeriodPlan(ranges, earlier: true);
    }
    if (!date.isBefore(last.range.end)) {
      final ranges = <PeriodRange>[];
      var current = last;
      while (!date.isBefore(current.range.end)) {
        final draft = _next(configs, current);
        ranges.add(draft.range);
        current = PeriodRecord(
          id: draft.id,
          configurationId: draft.configurationId,
          range: draft.range,
          version: 1,
        );
        if (ranges.length > maxPeriodsPerRequest) {
          throw const PeriodTooFarException();
        }
      }
      return PeriodPlan(ranges, earlier: false);
    }
    return null;
  }

  /// Cria os períodos necessários para cobrir [date], depois da confirmação do
  /// usuário. Para trás, cria do mais próximo ao mais distante (cada período
  /// termina onde começa o anterior criado).
  Future<List<PeriodRange>> createCovering(CalendarDate date) async {
    final configs = await _repo.configurations();
    final periods = await _repo.periods();
    if (configs.isEmpty || periods.isEmpty) return const [];
    final plan = _plan(date, configs, periods);
    if (plan == null) return const [];
    if (!plan.earlier) return ensureUpTo(date);

    final first = periods.first;
    final config = configs.firstWhere((c) => c.id == first.configurationId);
    var dependsOn = first.id;
    for (final range in plan.ranges) {
      final draft = PeriodDraft(
        id: _newId(),
        configurationId: first.configurationId,
        config: config.config,
        range: range,
        newConfiguration: false,
        dependsOnPeriodId: dependsOn,
        earlier: true,
      );
      await _repo.createPeriod(draft);
      dependsOn = draft.id;
    }
    return plan.ranges;
  }
}

/// Máximo de períodos criados de uma vez (20 anos); acima disso a data é
/// considerada distante demais e o usuário deve conferi-la.
const maxPeriodsPerRequest = 240;

class PeriodTooFarException implements Exception {
  const PeriodTooFarException();
  @override
  String toString() =>
      'A data está muito distante dos seus períodos. Confira o ano.';
}

/// Períodos a criar para cobrir uma data, mostrados ao usuário para confirmar.
class PeriodPlan {
  const PeriodPlan(this.ranges, {required this.earlier});

  /// Em ordem de criação: para trás, do mais próximo ao mais distante.
  final List<PeriodRange> ranges;
  final bool earlier;

  int get count => ranges.length;

  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  /// Ex.: "Criar os períodos de julho a outubro de 2026?".
  String get question {
    final ordered = earlier ? ranges.reversed.toList() : ranges;
    String label(PeriodRange r) =>
        '${_months[r.start.month - 1]} de ${r.start.year}';
    if (ordered.length == 1) {
      final r = ordered.single;
      return 'Criar o período de ${r.start.toBr()} a '
          '${r.end.addDays(-1).toBr()}?';
    }
    return 'Criar os ${ordered.length} períodos de ${label(ordered.first)} '
        'a ${label(ordered.last)}?';
  }
}
