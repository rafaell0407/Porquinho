import 'investment_models.dart';

/// Investimentos. Celular: banco local + fila de envio. Web: servidor, online.
abstract interface class InvestmentRepository {
  /// Investimentos do período (inclusive cancelados), do mais recente ao mais
  /// antigo.
  Future<List<InvestmentRecord>> investmentsInPeriod(String periodId);

  Future<InvestmentRecord?> investment(String id);

  /// Grava as alterações de uma vez. No celular, tudo na mesma transação.
  Future<void> apply(List<InvestmentChange> changes);
}
