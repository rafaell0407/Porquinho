import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'session_controller.dart';

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

/// Sai da conta. Antes tenta enviar o que está pendente; se algo não subir,
/// avisa o que será perdido e só sai se o usuário confirmar.
Future<void> signOutWithPendingCheck(
  BuildContext context,
  WidgetRef ref,
) async {
  final session = ref.read(sessionControllerProvider);
  final result = await session.signOut();
  if (result is! LogoutBlockedByPending || !context.mounted) return;
  final leave = await _confirm(
    context,
    title: 'Lançamentos não sincronizados',
    message:
        'Você tem ${result.pendingCount} operação(ões) que ainda não foram '
        'enviadas. Se sair agora, elas serão apagadas deste aparelho e não '
        'poderão ser recuperadas. Para não perder, conecte-se à internet e '
        'tente de novo.',
    action: 'Sair mesmo assim',
  );
  if (leave) await session.signOut(discardPending: true);
}

/// "Esqueci o PIN": o PIN não pode ser recuperado, então o caminho é sair da
/// conta (apagando os dados locais) e entrar de novo.
Future<void> forgotPin(BuildContext context, WidgetRef ref) async {
  final proceed = await _confirm(
    context,
    title: 'Esqueci o PIN',
    message:
        'Para redefinir o PIN você precisa sair da conta e entrar de novo. Os '
        'dados deste aparelho serão apagados; o que já foi sincronizado volta '
        'depois do login.',
    action: 'Sair da conta',
  );
  if (proceed && context.mounted) await signOutWithPendingCheck(context, ref);
}
