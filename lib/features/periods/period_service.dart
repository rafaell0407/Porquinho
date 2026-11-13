import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import 'period_models.dart';
import 'period_repository.dart';

/// Regras de período (RN001–RN004, RN036–RN037; reestruturação de
/// 13/11/2026): uma configuração única, trocável a qualquer momento e valendo
/// para todos os períodos; o período de uma data é calculado, nunca criado.
/// Não sabe onde os dados ficam: usa o [PeriodRepository] do celular ou da Web.
class PeriodService {
  PeriodService(this._repo);

  final PeriodRepository _repo;

  /// `true` se a conta ainda não tem configuração (primeiro acesso). Antes de
  /// perguntar, traz do servidor o que já existir, para que um segundo
  /// aparelho não pergunte de novo.
  Future<bool> needsSetup() async {
    if (await _repo.settings() != null) return false;
    await _repo.refreshFromServer();
    return await _repo.settings() == null;
  }

  /// Primeiro acesso: grava a configuração escolhida.
  Future<void> setup(PeriodConfig config) =>
      _repo.saveSettings(config, expectedVersion: 0);

  /// Configuração em vigor (`null` antes do primeiro acesso).
  Future<PeriodConfig?> currentConfig() async =>
      (await _repo.settings())?.config;

  /// Troca a configuração na hora (RN002): todos os períodos, passados e
  /// futuros, passam a ser calculados com a nova. Igual à atual = nada muda.
  Future<void> change(PeriodConfig config) async {
    final current = await _repo.settings();
    if (current == null) {
      throw const PeriodSettingsException(
        'Escolha primeiro como contar o seu período.',
      );
    }
    if (current.config == config) return;
    await _repo.saveSettings(config, expectedVersion: current.version);
  }

  /// Período que contém [date], pela configuração atual (RN004, RN036).
  Future<PeriodRange> periodFor(CalendarDate date) async =>
      PeriodCalendar.containing(await _requireConfig(), date);

  /// Limites da navegação (RN002): do período do lançamento mais antigo ao do
  /// mais distante no futuro, sempre incluindo o período de [today].
  Future<PeriodBounds> bounds(CalendarDate today) async {
    final config = await _requireConfig();
    final span = await _repo.entryDateSpan();
    return PeriodCalendar.bounds(
      config,
      today: today,
      oldest: span.oldest,
      newest: span.newest,
    );
  }

  Future<PeriodConfig> _requireConfig() async {
    final config = await currentConfig();
    if (config == null) {
      throw const PeriodSettingsException(
        'Escolha primeiro como contar o seu período.',
      );
    }
    return config;
  }
}
