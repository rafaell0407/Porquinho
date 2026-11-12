import 'dart:async';

import '../auth/auth_models.dart';
import '../auth/session_controller.dart';

/// Dispara a sincronização ao entrar na conta, a cada [interval] (ou a cada
/// [offlineInterval] enquanto [isOffline] for verdadeiro, para refletir logo a
/// volta da rede) e quando o app volta ao primeiro plano ([onResume]). Só roda
/// com sessão ativa e nunca em paralelo consigo mesma.
class SyncScheduler {
  SyncScheduler(
    this._session,
    this._sync, {
    this.interval = const Duration(minutes: 1),
    this.offlineInterval = const Duration(seconds: 15),
    this.isOffline,
  });

  final SessionController _session;
  final Future<void> Function(String ownerId) _sync;
  final Duration interval;
  final Duration offlineInterval;
  final bool Function()? isOffline;

  StreamSubscription<SessionState>? _subscription;
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;

  void start() {
    _subscription = _session.states.listen((_) => _restart());
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (_session.state is! SessionSignedIn) return;
    unawaited(tick());
  }

  /// Arma o próximo disparo conforme a última situação conhecida.
  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || _session.state is! SessionSignedIn) return;
    final offline = isOffline?.call() ?? false;
    _timer = Timer(offline ? offlineInterval : interval, tick);
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
      _schedule();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _subscription?.cancel();
  }
}
