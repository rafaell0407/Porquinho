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
      dependsOnConfigurationId: changed ? applicable.id : null,
    );
  }

  /// Configuração em vigor hoje: a do período que contém [today] (ou a do
  /// último período, se o de hoje ainda não foi criado).
  Future<PeriodConfig?> currentConfig(CalendarDate today) async {
    final configs = await _repo.configurations();
    final periods = await _repo.periods();
    if (periods.isEmpty) return null;
    final current = periods.lastWhere(
      (p) => p.range.contains(today),
      orElse: () => periods.last,
    );
    return configs.firstWhere((c) => c.id == current.configurationId).config;
  }

  /// Períodos existentes, do mais recente ao mais antigo, cada um com a
  /// configuração que usou (períodos antigos nunca mudam, RN002).
  Future<List<PeriodHistoryItem>> history() async {
    final configs = await _repo.configurations();
    final periods = await _repo.periods();
    return [
      for (final p in periods.reversed)
        PeriodHistoryItem(
          p.id,
          p.range,
          configs.firstWhere((c) => c.id == p.configurationId).config,
        ),
    ];
  }

  /// Data em que começa o próximo período (fim do último existente), ou
  /// `null` se ainda não há período. É quando uma mudança passa a valer.
  Future<CalendarDate?> nextPeriodStart() async {
    final periods = await _repo.periods();
    return periods.isEmpty ? null : periods.last.range.end;
  }

  /// Mudança já agendada (diferente da configuração do último período), com a
  /// data em que começa, ou `null`.
  Future<ScheduledChange?> scheduledChange() async {
    final configs = await _repo.configurations();
    final periods = await _repo.periods();
    if (periods.isEmpty) return null;
    final last = periods.last;
    final scheduled = configs
        .where((c) => c.effectiveFrom == last.range.end)
        .firstOrNull;
    if (scheduled == null) return null;
    final lastConfig = configs.firstWhere((c) => c.id == last.configurationId);
    if (scheduled.config == lastConfig.config) return null;
    return ScheduledChange(scheduled.config, scheduled.effectiveFrom);
  }

  /// Agenda [config] para o próximo período (RN002; D2 e D3). A nova
  /// configuração começa quando termina o último período existente; períodos
  /// já criados não mudam. Reagendar troca a anterior; escolher a configuração
  /// atual cancela a mudança. Devolve a data de início da mudança, ou `null`
  /// se não há mudança agendada depois da chamada.
  Future<CalendarDate?> scheduleChange(
    PeriodConfig config,
    CalendarDate today,
  ) async {
    // Os períodos até hoje precisam existir antes; senão a mudança começaria
    // no passado e mudaria períodos que ainda vão ser criados.
    await ensureUpTo(today);
    final configs = await _repo.configurations();
    final periods = await _repo.periods();
    if (periods.isEmpty) return null;
    final last = periods.last;
    final lastConfig = configs.firstWhere((c) => c.id == last.configurationId);
    final startsOn = last.range.end;
    final scheduled = configs
        .where((c) => c.effectiveFrom == startsOn)
        .firstOrNull;
    final isCurrent = config == lastConfig.config;

    if (scheduled == null) {
      if (isCurrent) return null;
      await _repo.scheduleConfiguration(
        ScheduleDraft(
          configurationId: _newId(),
          config: config,
          effectiveFrom: startsOn,
          expectedVersion: 0,
          lastPeriodId: last.id,
        ),
      );
      return startsOn;
    }
    if (scheduled.config != config) {
      await _repo.scheduleConfiguration(
        ScheduleDraft(
          configurationId: scheduled.id,
          config: config,
          effectiveFrom: startsOn,
          expectedVersion: scheduled.version,
          lastPeriodId: last.id,
        ),
      );
    }
    return isCurrent ? null : startsOn;
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
