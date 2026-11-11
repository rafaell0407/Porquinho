import '../../core/local_database/local_database_manager.dart';
import 'drift_pending_sync_counter.dart';

/// Resultado de vincular o banco local a uma conta.
sealed class LocalBindResult {
  const LocalBindResult();
}

class LocalBound extends LocalBindResult {
  const LocalBound();
}

/// O aparelho guarda operações não sincronizadas de outra conta.
class LocalBlockedByPending extends LocalBindResult {
  const LocalBlockedByPending(this.pendingCount);

  final int pendingCount;
}

/// Garante que o banco local nunca é compartilhado entre contas.
abstract interface class LocalOwnerBinder {
  Future<LocalBindResult> bind(String ownerId);
}

/// Regras (decisão D2, 10/11/2026):
/// - mesma conta de antes (ou aparelho sem dono): segue com os dados;
/// - outra conta sem pendências da anterior: apaga os dados locais e vincula;
/// - outra conta com pendências da anterior: bloqueia, sem apagar nada.
///
/// Sessão expirada não passa por aqui: só uma nova entrada vincula.
class ManagedLocalOwnerBinder implements LocalOwnerBinder {
  ManagedLocalOwnerBinder(this._manager);

  final LocalDatabaseManager _manager;
  Future<void> _queue = Future.value();

  @override
  Future<LocalBindResult> bind(String ownerId) {
    final result = _queue.then((_) => _bind(ownerId));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<LocalBindResult> _bind(String ownerId) async {
    final previous = await _manager.boundOwner();
    if (previous != null && previous != ownerId) {
      final pending = await DriftPendingSyncCounter(
        await _manager.open(),
      ).countPending(previous);
      if (pending > 0) return LocalBlockedByPending(pending);
      await _manager.closeAndWipe();
    }
    if (previous != ownerId) await _manager.bindOwner(ownerId);
    return const LocalBound();
  }
}
