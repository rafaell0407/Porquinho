import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'auth_models.dart';
import 'auth_repository.dart';

/// [AuthRepository] sobre o Supabase Auth. Nenhuma senha é persistida pelo app.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._client, {
    this.redirectTo,
    this.googleTimeout = const Duration(minutes: 5),
  });

  final GoTrueClient _client;

  /// Endereço de retorno do login por navegador e dos e-mails de confirmação
  /// e recuperação (deep link no celular, URL do app na Web).
  final String? redirectTo;
  final Duration googleTimeout;

  AuthUser? _map(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email ?? '');

  @override
  Future<AuthUser?> restoreSession() async => _map(_client.currentUser);

  @override
  Stream<AuthUser?> get userChanges =>
      _client.onAuthStateChange.map((s) => _map(s.session?.user));

  @override
  Stream<void> get passwordRecovery => _client.onAuthStateChange
      .where((s) => s.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<AuthUser> signInWithEmail(String email, String password) =>
      _guard(() async {
        final res = await _client.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        final user = _map(res.user);
        if (user == null) throw const AuthFailure(AuthFailureCode.unknown);
        return user;
      });

  @override
  Future<AuthUser?> signUpWithEmail(String email, String password) =>
      _guard(() async {
        final res = await _client.signUp(
          email: email.trim(),
          password: password,
          emailRedirectTo: redirectTo,
        );
        // Sem sessão = aguardando confirmação de e-mail.
        return res.session == null ? null : _map(res.user);
      });

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _client.resetPasswordForEmail(email.trim(), redirectTo: redirectTo),
  );

  @override
  Future<void> updatePassword(String newPassword) => _guard(() async {
    await _client.updateUser(UserAttributes(password: newPassword));
  });

  @override
  Future<AuthUser> signInWithGoogle() => _guard(() async {
    final signedIn = _client.onAuthStateChange
        .map((s) => s.session?.user)
        .firstWhere((u) => u != null);
    final launched = await _client.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
    if (!launched) throw const AuthFailure(AuthFailureCode.cancelled);
    try {
      final user = await signedIn.timeout(googleTimeout);
      return _map(user)!;
    } on TimeoutException {
      throw const AuthFailure(AuthFailureCode.cancelled);
    }
  });

  @override
  Future<void> signOut() async {
    try {
      await _guard(() => _client.signOut());
    } on AuthFailure catch (e) {
      // Sem internet a sessão local já foi removida antes da chamada ao
      // servidor; o token remoto expira sozinho. Não bloquear o logout.
      if (e.code != AuthFailureCode.network) rethrow;
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw const AuthFailure(AuthFailureCode.network);
    } on AuthException catch (e) {
      throw AuthFailure(_codeFor(e));
    }
  }

  AuthFailureCode _codeFor(AuthException e) => switch (e.code) {
    'invalid_credentials' => AuthFailureCode.invalidCredentials,
    'email_not_confirmed' => AuthFailureCode.emailNotConfirmed,
    'user_already_exists' ||
    'email_exists' => AuthFailureCode.emailAlreadyRegistered,
    'weak_password' => AuthFailureCode.weakPassword,
    _ =>
      e is AuthWeakPasswordException
          ? AuthFailureCode.weakPassword
          : AuthFailureCode.unknown,
  };
}
