import 'period_models.dart';

/// Acesso aos períodos. Celular: banco local + fila de envio. Web: servidor.
abstract interface class PeriodRepository {
  Future<List<PeriodConfigRecord>> configurations();

  /// Ordenados pelo início, do mais antigo ao mais recente.
  Future<List<PeriodRecord>> periods();

  Future<void> createPeriod(PeriodDraft draft);

  /// Grava a configuração que vale a partir do fim do último período
  /// (Entrega 59): cria ou altera a configuração agendada.
  Future<void> scheduleConfiguration(ScheduleDraft draft);

  /// Traz do servidor o que já existe, quando houver conexão (celular).
  /// Na Web é desnecessário: a leitura já é remota.
  Future<void> refreshFromServer();
}
