import 'auth_models.dart';

/// Contrato de autenticação (RF001–RF002). A implementação com Supabase Auth
/// fica atrás desta interface; as senhas nunca são persistidas pelo app.
///
/// Os métodos lançam [AuthFailure] em caso de erro.
abstract interface class AuthRepository {
  /// Sessão restaurada do armazenamento seguro, se houver.
  Future<AuthUser?> restoreSession();

  /// Emite a cada login, logout ou perda de sessão (token inválido/revogado).
  Stream<AuthUser?> get userChanges;

  /// Emite quando o usuário abre o link de recuperação de senha.
  Stream<void> get passwordRecovery;

  Future<AuthUser> signInWithEmail(String email, String password);

  /// Cria a conta. Devolve `null` enquanto o e-mail não for confirmado.
  Future<AuthUser?> signUpWithEmail(String email, String password);

  Future<void> sendPasswordReset(String email);

  /// Define nova senha para quem abriu o link de recuperação (sessão de
  /// recuperação ativa).
  Future<void> updatePassword(String newPassword);

  Future<AuthUser> signInWithGoogle();

  /// Encerra a sessão remota e local. Não limpa dados financeiros locais.
  Future<void> signOut();
}
