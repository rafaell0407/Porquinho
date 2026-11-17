import 'package:drift/drift.dart';

import '../../../core/local_database/app_database.dart';
import '../domain/change_set.dart';
import 'card_bills_repository.dart';
import 'card_bills_rows.dart';
import 'remote_card_bills_repository.dart';

/// Download da Gestão de Faturas (spec §12, GF3.6).
///
/// Como nada é guardado ao apagar (sem marca de exclusão, decisão de
/// 16/11/2026), a cada sincronização o aparelho compara com o servidor: baixa
/// a lista completa da ferramenta e apaga localmente o que não existe mais lá.
/// Enquanto houver envio pendente da ferramenta (a enviar, enviando ou
/// aguardando nova tentativa), nada é substituído: o aparelho espera a fila
/// chegar ao servidor. Alteração recusada ou pagamento duplicado não seguram
/// o download: o aparelho volta a mostrar o que está no servidor e o item
/// continua em "Precisam de atenção".
class CardBillsDownloader {
  CardBillsDownloader(this._db, this._source, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final PorquinhoDatabase _db;
  final CardBillsRemoteSource _source;
  final DateTime Function() _clock;

  Future<bool> _hasPending(String ownerId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM sync_outbox WHERE owner_id = ? '
          'AND entity_type IN (?, ?) '
          "AND state IN ('pending', 'sending', 'failed')",
          variables: [
            Variable.withString(ownerId),
            Variable.withString(CardBillsEntity.cadastros),
            Variable.withString(CardBillsEntity.invoice),
          ],
        )
        .getSingle();
    return row.read<int>('n') > 0;
  }

  /// Substitui os dados locais da ferramenta pelos do servidor. Devolve
  /// `false` se esperou por envios pendentes. Falha de rede: lança
  /// `SyncTransientError` sem mexer em nada.
  Future<bool> replaceAll(String ownerId) async {
    if (await _hasPending(ownerId)) return false;
    final remote = <String, List<Map<String, dynamic>>>{};
    for (final table in CardBillTables.ordered) {
      remote[table] = await _source.fetchAll(table);
    }
    final now = _clock().toUtc().toIso8601String();
    return _db.transaction(() async {
      if (await _hasPending(ownerId)) return false;
      for (final table in CardBillTables.ordered.reversed) {
        await _db.customStatement('DELETE FROM $table WHERE owner_id = ?', [
          ownerId,
        ]);
      }
      for (final table in CardBillTables.ordered) {
        final columns = CardBillTables.columns[table]!;
        final names = ['owner_id', 'created_at', 'updated_at', ...columns];
        for (final row in remote[table]!) {
          await _db.customStatement(
            'INSERT INTO $table (${names.join(', ')}) '
            'VALUES (${List.filled(names.length, '?').join(', ')})',
            [
              ownerId,
              row['created_at']?.toString() ?? now,
              row['updated_at']?.toString() ?? now,
              for (final c in columns) toSqlValue(c, row[c]),
            ],
          );
        }
      }
      return true;
    });
  }
}
