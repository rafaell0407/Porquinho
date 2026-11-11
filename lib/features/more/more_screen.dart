import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/logout_flow.dart';
import '../sync/sync_indicator.dart';
import '../sync/sync_providers.dart';

/// Aba "Mais": Segurança (só no celular) e Sair. Demais itens (categorias,
/// período, relatórios) entram nas fases seguintes.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        children: [
          if (!kIsWeb) const SyncNowTile(),
          const _AttentionTile(),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categorias'),
            onTap: () => context.push('/categorias'),
          ),
          ListTile(
            key: const Key('mais-recorrencias'),
            leading: const Icon(Icons.repeat),
            title: const Text('Recorrências'),
            onTap: () => context.push('/recorrencias'),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Segurança'),
              onTap: () => context.push('/seguranca'),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () => signOutWithPendingCheck(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Atalho para os itens que precisam de decisão, com a contagem atual.
class _AttentionTile extends ConsumerWidget {
  const _AttentionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(syncStatusProvider).attentionCount;
    return ListTile(
      leading: Icon(
        count > 0 ? Icons.error_outline : Icons.check_circle_outline,
        color: count > 0 ? Theme.of(context).colorScheme.error : null,
      ),
      title: const Text('Itens que precisam de atenção'),
      subtitle: Text(count > 0 ? '$count item(ns)' : 'Nada pendente'),
      onTap: () => context.push('/atencao'),
    );
  }
}
