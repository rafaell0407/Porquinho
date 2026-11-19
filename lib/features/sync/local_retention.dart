import '../../core/domain/retention.dart';
import '../../core/local_database/app_database.dart';

/// Quantos registros a limpeza apagou no aparelho.
class LocalRetentionResult {
  const LocalRetentionResult({
    this.entries = 0,
    this.auditEvents = 0,
    this.conflicts = 0,
  });

  final int entries;
  final int auditEvents;
  final int conflicts;

  int get total => entries + auditEvents + conflicts;
}

/// Limpeza de retenção no aparelho (D15; RN029 e RN030). É a mesma regra de
/// `purge_expired_records` no servidor:
/// - lançamento avulso cancelado sem alteração há 12 meses, sem pendência na
///   fila e sem conflito aberto (ocorrência de recorrência fica enquanto o
///   modelo existir: é ela que impede o mês de ser gerado de novo);
/// - auditoria e conflitos resolvidos com mais de 12 meses.
///
/// As datas são comparadas com `julianday`, que entende tanto o formato do
/// aparelho (`...Z`) quanto o do servidor (`...+00:00`, microssegundos).
class LocalRetention {
  LocalRetention(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final PorquinhoDatabase _db;
  final DateTime Function() _clock;

  static const _entryTables = [
    ('income_entries', 'income_entry', "status = 'cancelled'"),
    ('expense_entries', 'expense_entry', "status = 'cancelled'"),
    (
      'investment_allocations',
      'investment_allocation',
      'cancelled_at IS NOT NULL',
    ),
  ];

  Future<LocalRetentionResult> purge(String ownerId) async {
    final cutoff = Retention.cutoff(_clock()).toIso8601String();
    return _db.transaction(() async {
      var entries = 0;
      for (final (table, entityType, cancelled) in _entryTables) {
        entries += await _delete(
          'DELETE FROM $table WHERE owner_id = ?1 AND $cancelled '
          'AND recurrence_template_id IS NULL '
          'AND julianday(updated_at) < julianday(?2) '
          'AND NOT EXISTS (SELECT 1 FROM sync_outbox o WHERE o.owner_id = ?1 '
          'AND o.entity_type = ?3 AND o.entity_id = $table.id) '
          'AND NOT EXISTS (SELECT 1 FROM sync_conflicts c '
          "WHERE c.owner_id = ?1 AND c.state = 'open' "
          'AND c.entity_type = ?3 AND c.entity_id = $table.id)',
          [ownerId, cutoff, entityType],
        );
      }
      final audit = await _delete(
        'DELETE FROM audit_events WHERE owner_id = ?1 '
        'AND julianday(occurred_at) < julianday(?2)',
        [ownerId, cutoff],
      );
      final conflicts = await _delete(
        "DELETE FROM sync_conflicts WHERE owner_id = ?1 AND state = 'resolved' "
        'AND julianday(updated_at) < julianday(?2)',
        [ownerId, cutoff],
      );
      return LocalRetentionResult(
        entries: entries,
        auditEvents: audit,
        conflicts: conflicts,
      );
    });
  }

  Future<int> _delete(String sql, List<Object?> args) async {
    final before = await _changes();
    await _db.customStatement(sql, args);
    return await _changes() - before;
  }

  Future<int> _changes() async =>
      (await _db.customSelect('SELECT total_changes() AS n').getSingle())
          .read<int>('n');
}
