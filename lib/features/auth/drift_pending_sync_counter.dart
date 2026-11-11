import 'package:drift/drift.dart';

import '../../core/local_database/app_database.dart';
import '../../core/local_database/local_database_manager.dart';
import 'session_controller.dart';

/// Considera pendente toda linha de `sync_outbox` do usuário (operação aplicada
/// é removida; `arquitetura.md` §16.1.1) e todo conflito não resolvido.
class DriftPendingSyncCounter implements PendingSyncCounter {
  DriftPendingSyncCounter(this._db);

  final PorquinhoDatabase _db;

  @override
  Future<int> countPending(String ownerId) async {
    final row = await _db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM sync_outbox WHERE owner_id = ?1) '
          "+ (SELECT COUNT(*) FROM sync_conflicts WHERE owner_id = ?1 "
          "AND state <> 'resolved') AS total",
          variables: [Variable.withString(ownerId)],
        )
        .getSingle();
    return row.read<int>('total');
  }
}

/// Abre o banco local (se preciso) e conta as pendências do usuário.
class ManagedPendingSyncCounter implements PendingSyncCounter {
  ManagedPendingSyncCounter(this._manager);

  final LocalDatabaseManager _manager;

  @override
  Future<int> countPending(String ownerId) async =>
      DriftPendingSyncCounter(await _manager.open()).countPending(ownerId);
}
