import '../../core/domain/period_calendar.dart';
import 'period_models.dart';

/// Configuração de período. Celular: banco local + fila de envio. Web:
/// servidor. Períodos não são gravados: são calculados (RN002).
abstract interface class PeriodRepository {
  /// Configuração única do usuário, ou `null` no primeiro acesso.
  Future<PeriodSettingsRecord?> settings();

  /// Grava a configuração. [expectedVersion] 0 = primeiro acesso; senão, a
  /// versão lida (conflito por versão, nunca "última gravação vence").
  Future<void> saveSettings(
    PeriodConfig config, {
    required int expectedVersion,
  });

  /// Datas do lançamento mais antigo e do mais distante.
  Future<EntryDateSpan> entryDateSpan();

  /// Traz do servidor o que já existe, quando houver conexão (celular).
  /// Na Web é desnecessário: a leitura já é remota.
  Future<void> refreshFromServer();
}
