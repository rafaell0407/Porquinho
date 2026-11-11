import 'dart:async';

import 'auth_models.dart';
import 'auth_repository.dart';

/// Conta operações locais ainda não confirmadas pelo servidor.
abstract interface class PendingSyncCounter {
  Future<int> countPending(String ownerId);
}

/// Resultado de um pedido de logout.
sealed class LogoutResult {
  const LogoutResult();
}

class LogoutDone extends LogoutResult {
  const LogoutDone();
}

/// Logout recusado: há operações locais não sincronizadas
/// (`arquitetura.md` §16.1/§17.5; decisão de 10/11/2026, opção 1).
class LogoutBlockedByPending extends LogoutResult {
  const LogoutBlockedByPending(this.pendingCount);

  final int pendingCount;
}

/// Mantém o [SessionState] e aplica a política de logout.
class SessionController {
  SessionController(
    this._auth,
    this._pending, {
    Future<void> Function(String ownerId)? onSignedOut,
    Future<void> Function(String ownerId)? flushPending,
  }) : _onSignedOut = onSignedOut,
       _flushPending = flushPending;

  final AuthRepository _auth;
  final PendingSyncCounter _pending;
  final Future<void> Function(String ownerId)? _onSignedOut;

  /// Tenta enviar a fila antes de recusar o logout. Falhas são ignoradas: o
  /// que não subir continua contando como pendência.
  final Future<void> Function(String ownerId)? _flushPending;

  final _controller = StreamController<SessionState>.broadcast();
  SessionState _state = const SessionUnknown();
  bool _recoveryPending = false;
  StreamSubscription<AuthUser?>? _subscription;
  StreamSubscription<void>? _recoverySubscription;

  SessionState get state => _state;
  Stream<SessionState> get states => _controller.stream;

  /// Restaura a sessão e passa a acompanhar mudanças. Chamar uma vez.
  Future<void> start() async {
    _subscription = _auth.userChanges.listen(_setUser);
    _recoverySubscription = _auth.passwordRecovery.listen((_) {
      final current = _state;
      if (current is SessionSignedIn) {
        _emit(SessionPasswordRecovery(current.user));
      } else {
        _recoveryPending = true;
      }
    });
    _setUser(await _auth.restoreSession());
  }

  Future<void> signInWithEmail(String email, String password) async =>
      _setUser(await _auth.signInWithEmail(email, password));

  Future<void> signInWithGoogle() async =>
      _setUser(await _auth.signInWithGoogle());

  /// Tenta sincronizar e verifica pendências antes de qualquer alteração. Se
  /// ainda houver, nada é encerrado nem apagado e o usuário deve ser avisado.
  ///
  /// Com [discardPending] (escolha explícita do usuário, após o aviso) sai
  /// mesmo assim: as operações não sincronizadas são apagadas com os dados
  /// locais e não podem ser recuperadas.
  Future<LogoutResult> signOut({bool discardPending = false}) async {
    final current = _state;
    final user = switch (current) {
      SessionSignedIn(:final user) => user,
      SessionPasswordRecovery(:final user) => user,
      _ => null,
    };
    if (user == null) return const LogoutDone();
    if (!discardPending) {
      try {
        await _flushPending?.call(user.id);
      } on Object {
        // Segue para a contagem: o que não subiu continua pendente.
      }
      final count = await _pending.countPending(user.id);
      if (count > 0) return LogoutBlockedByPending(count);
    }
    await _auth.signOut();
    await _onSignedOut?.call(user.id);
    _setUser(null);
    return const LogoutDone();
  }

  /// Define a nova senha durante a recuperação e segue para a área logada.
  Future<void> completePasswordRecovery(String newPassword) async {
    final current = _state;
    if (current is! SessionPasswordRecovery) return;
    await _auth.updatePassword(newPassword);
    _emit(SessionSignedIn(current.user));
  }

  /// Segue sem trocar a senha (a sessão de recuperação continua válida).
  void skipPasswordRecovery() {
    final current = _state;
    if (current is SessionPasswordRecovery) {
      _emit(SessionSignedIn(current.user));
    }
  }

  void _setUser(AuthUser? user) {
    if (user == null) {
      _recoveryPending = false;
      _emit(const SessionSignedOut());
    } else if (_state is SessionPasswordRecovery) {
      // Mantém a recuperação em andamento (eventos de usuário repetidos).
    } else if (_recoveryPending) {
      _recoveryPending = false;
      _emit(SessionPasswordRecovery(user));
    } else {
      _emit(SessionSignedIn(user));
    }
  }

  void _emit(SessionState state) {
    _state = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _recoverySubscription?.cancel();
    await _controller.close();
  }
}
