import 'dart:async';

import '../auth/auth_models.dart';
import '../auth/session_controller.dart';

/// Dispara a sincronização ao entrar na conta, a cada [interval] e quando o
/// app volta ao primeiro plano ([onResume]). Só roda com sessão ativa e nunca
/// em paralelo consigo mesma.
class SyncScheduler {
  SyncScheduler(
    this._session,
    this._sync, {
    this.interval = const Duration(minutes: 1),
  });

  final SessionController _session;
  final Future<void> Function(String ownerId) _sync;
  final Duration interval;

  StreamSubscription<SessionState>? _subscription;
  Timer? _timer;
  bool _running = false;

  void start() {
    _subscription = _session.states.listen((_) => _restart());
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (_session.state is! SessionSignedIn) return;
    _timer = Timer.periodic(interval, (_) => tick());
    unawaited(tick());
  }

  void onResume() => unawaited(tick());

  /// Uma rodada de envio. Falhas ficam registradas na própria fila.
  Future<void> tick() async {
    final state = _session.state;
    if (state is! SessionSignedIn || _running) return;
    _running = true;
    try {
      await _sync(state.user.id);
    } on Object {
      // O próximo disparo tenta de novo.
    } finally {
      _running = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _subscription?.cancel();
  }
}
