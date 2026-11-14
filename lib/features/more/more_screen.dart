import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/norte_theme.dart';
import '../auth/delete_account_flow.dart';
import '../auth/logout_flow.dart';
import '../sync/sync_indicator.dart';
import '../sync/sync_providers.dart';

/// Aba "Mais": atalhos para categorias, período, tema, recorrências,
/// exportação, segurança, exclusão de conta e saída. Relatórios ficam na aba
/// Ferramentas.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NorteColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!kIsWeb) const SyncNowTile(),
          const _AttentionTile(),
          _MoreTile(
            icon: Icons.category_outlined,
            title: 'Categorias',
            onTap: () => context.push('/categorias'),
          ),
          _MoreTile(
            tileKey: const Key('mais-periodo'),
            icon: Icons.date_range_outlined,
            title: 'Período',
            onTap: () => context.push('/periodo'),
          ),
          _MoreTile(
            tileKey: const Key('mais-configuracao-inicial'),
            icon: Icons.checklist_outlined,
            title: 'Configuração inicial',
            onTap: () => context.push('/configuracao-inicial'),
          ),
          _MoreTile(
            tileKey: const Key('mais-tema'),
            icon: Icons.brightness_6_outlined,
            title: 'Tema',
            onTap: () => context.push('/tema'),
          ),
          _MoreTile(
            tileKey: const Key('mais-recorrencias'),
            icon: Icons.repeat,
            title: 'Recorrências',
            onTap: () => context.push('/recorrencias'),
          ),
          _MoreTile(
            tileKey: const Key('mais-exportar'),
            icon: Icons.download_outlined,
            title: 'Exportar dados (CSV)',
            onTap: () => context.push('/exportar'),
          ),
          if (!kIsWeb)
            _MoreTile(
              icon: Icons.lock_outline,
              title: 'Segurança',
              onTap: () => context.push('/seguranca'),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(),
          ),
          _MoreTile(
            tileKey: const Key('mais-excluir-conta'),
            icon: Icons.delete_forever_outlined,
            iconColor: colors.expense,
            title: 'Excluir conta',
            onTap: () => deleteAccountFlow(context, ref),
          ),
          _MoreTile(
            icon: Icons.logout,
            title: 'Sair',
            onTap: () => signOutWithPendingCheck(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Item do menu: ícone em círculo suave, título e seta.
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.tileKey,
    this.iconColor,
  });

  final Key? tileKey;
  final IconData icon;
  final Color? iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: tileKey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: iconColor ?? scheme.onSurface,
        child: Icon(icon, size: 22),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

/// Atalho para os itens que precisam de decisão, com a contagem atual.
class _AttentionTile extends ConsumerWidget {
  const _AttentionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(syncStatusProvider).attentionCount;
    final colors = NorteColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: count > 0 ? colors.pending : colors.income,
        child: Icon(
          count > 0 ? Icons.error_outline : Icons.check_circle_outline,
          size: 22,
        ),
      ),
      title: Text(
        'Itens que precisam de atenção',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(count > 0 ? '$count item(ns)' : 'Nada pendente'),
      onTap: () => context.push('/atencao'),
    );
  }
}
