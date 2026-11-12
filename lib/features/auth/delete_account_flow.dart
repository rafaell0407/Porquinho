import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/infra_providers.dart';
import 'auth_providers.dart';

/// Palavra que o usuário digita para confirmar a exclusão (segunda confirmação).
const deleteAccountWord = 'EXCLUIR';

/// Exclusão definitiva no servidor (RPC `delete_my_account`). Sobrescrito nos
/// testes.
final deleteAccountRpcProvider = Provider<Future<void> Function()>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return () async {
    await client.rpc(
      'delete_my_account',
      params: {'p_confirmation': 'DELETE_MY_ACCOUNT'},
    );
  };
});

/// Fluxo "Excluir conta" (Entrega 73, decisão D3): exige fila vazia, duas
/// confirmações e apaga na hora, sem volta.
Future<void> deleteAccountFlow(BuildContext context, WidgetRef ref) async {
  final session = ref.read(sessionControllerProvider);
  final messenger = ScaffoldMessenger.of(context);

  final pending = await session.pendingBeforeAccountDeletion();
  if (!context.mounted) return;
  if (pending > 0) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ainda há dados não enviados'),
        content: Text(
          'Você tem $pending operação(ões) que ainda não foram enviadas ao '
          'servidor. Conecte-se à internet, aguarde o envio e tente excluir a '
          'conta de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    return;
  }

  final first =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Excluir a conta?'),
          content: const Text(
            'Todos os seus lançamentos, categorias, períodos, recorrências e '
            'configurações serão apagados agora, neste aparelho e no servidor. '
            'Esta ação não pode ser desfeita e os dados não poderão ser '
            'recuperados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ) ??
      false;
  if (!first || !context.mounted) return;

  final second =
      await showDialog<bool>(
        context: context,
        builder: (_) => const _TypeToConfirmDialog(),
      ) ??
      false;
  if (!second || !context.mounted) return;

  try {
    await ref.read(deleteAccountRpcProvider)();
  } on PostgrestException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Não foi possível excluir a conta: ${e.message}')),
    );
    return;
  } on Object {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível excluir a conta. Verifique a conexão e tente de '
          'novo. Nada foi apagado.',
        ),
      ),
    );
    return;
  }
  await session.completeAccountDeletion();
}

class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog();

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _controller.text.trim().toUpperCase() == deleteAccountWord;
    return AlertDialog(
      title: const Text('Confirme a exclusão'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Digite $deleteAccountWord para apagar a conta de forma '
            'definitiva.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('excluir-conta-campo'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('excluir-conta-confirmar'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Excluir definitivamente'),
        ),
      ],
    );
  }
}
