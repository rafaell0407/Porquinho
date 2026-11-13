import '../../core/domain/period_calendar.dart';
import 'entry_models.dart';

/// Receitas e despesas avulsas. Celular: banco local + fila de envio.
/// Web: servidor, somente online.
abstract interface class EntryRepository {
  /// Lançamentos (de ambos os tipos, inclusive cancelados) cuja data de
  /// competência está no intervalo do período, do mais recente para o mais
  /// antigo. Receita pendente entra pela data programada.
  Future<List<EntryRecord>> entriesInPeriod(PeriodRange range);

  Future<EntryRecord?> entry(EntryKind kind, String id);

  /// Grava as alterações de uma vez. No celular, tudo na mesma transação.
  Future<void> apply(List<EntryChange> changes);
}
