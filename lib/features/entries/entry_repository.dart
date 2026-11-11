import 'entry_models.dart';

/// Receitas e despesas avulsas. Celular: banco local + fila de envio.
/// Web: servidor, somente online.
abstract interface class EntryRepository {
  /// Lançamentos (de ambos os tipos, inclusive cancelados) do período, do mais
  /// recente para o mais antigo.
  Future<List<EntryRecord>> entriesInPeriod(String periodId);

  Future<EntryRecord?> entry(EntryKind kind, String id);

  /// Grava as alterações de uma vez. No celular, tudo na mesma transação.
  Future<void> apply(List<EntryChange> changes);
}
