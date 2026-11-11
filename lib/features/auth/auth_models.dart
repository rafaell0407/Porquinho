/// Usuário autenticado. O [id] é o `auth.users.id` do backend e vira `owner_id`
/// de todos os registros locais e remotos.
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;
}

enum AuthFailureCode {
  invalidCredentials,
  emailNotConfirmed,
  emailAlreadyRegistered,
  weakPassword,
  network,
  cancelled,
  unknown,
}

/// Erro de autenticação sem detalhes técnicos nem dados sensíveis.
class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  @override
  String toString() => 'AuthFailure(${code.name})';
}

/// Estado da sessão observado pela interface e pelo roteamento.
sealed class SessionState {
  const SessionState();
}

/// Ainda não se sabe se há sessão (abertura do app).
class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.blockedPendingCount = 0});

  /// Maior que zero quando a entrada foi recusada porque este aparelho ainda
  /// guarda operações não sincronizadas de outra conta (decisão D2,
  /// 10/11/2026).
  final int blockedPendingCount;
}

class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.user);

  final AuthUser user;
}

/// O usuário abriu o link de recuperação de senha: há sessão, mas o app deve
/// pedir a nova senha antes de seguir.
class SessionPasswordRecovery extends SessionState {
  const SessionPasswordRecovery(this.user);

  final AuthUser user;
}
