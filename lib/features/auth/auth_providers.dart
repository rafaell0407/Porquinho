import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_models.dart';
import 'auth_repository.dart';
import 'session_controller.dart';

/// Sobrescrito em `main.dart` com o adaptador real (e nos testes, com falsos).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('authRepositoryProvider não configurado'),
);

/// Sobrescrito em `main.dart`. O controlador já deve ter executado `start()`.
final sessionControllerProvider = Provider<SessionController>(
  (ref) =>
      throw UnimplementedError('sessionControllerProvider não configurado'),
);

/// Estado da sessão para a interface e para o roteamento.
final sessionStateProvider = StreamProvider<SessionState>((ref) async* {
  final controller = ref.watch(sessionControllerProvider);
  yield controller.state;
  yield* controller.states;
});

/// Texto em português para cada falha de autenticação.
String authFailureMessage(AuthFailureCode code) => switch (code) {
  AuthFailureCode.invalidCredentials => 'E-mail ou senha incorretos.',
  AuthFailureCode.emailNotConfirmed =>
    'Confirme seu e-mail antes de entrar. Verifique sua caixa de entrada.',
  AuthFailureCode.emailAlreadyRegistered =>
    'Este e-mail já está cadastrado. Tente entrar ou recuperar a senha.',
  AuthFailureCode.weakPassword =>
    'Senha fraca. Escolha uma senha mais longa e difícil de adivinhar.',
  AuthFailureCode.network =>
    'Não foi possível conectar. Verifique sua internet e tente de novo.',
  AuthFailureCode.cancelled => 'Login cancelado.',
  AuthFailureCode.unknown => 'Algo deu errado. Tente novamente.',
};

/// `owner_id` do usuário logado; toda gravação local e remota deve usá-lo.
/// Lança [StateError] se não houver sessão.
final ownerIdProvider = Provider<String>((ref) {
  final state = ref.watch(sessionStateProvider).value;
  return switch (state) {
    SessionSignedIn(:final user) => user.id,
    SessionPasswordRecovery(:final user) => user.id,
    _ => throw StateError('Nenhum usuário autenticado.'),
  };
});
