import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'sync_scheduler_provider.dart';
import 'sync_providers.dart';
import 'sync_status.dart';

/// Faixa discreta no topo do app: aparece só quando há algo a dizer (sem
/// conexão, sincronizando ou itens que precisam de decisão).
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final messages = <Widget>[];

    if (status.phase == SyncPhase.offline) {
      messages.add(
        _Strip(
          color: theme.colorScheme.secondaryContainer,
          textColor: theme.colorScheme.onSecondaryContainer,
          icon: Icons.cloud_off,
          text: kIsWeb
              ? 'Sem conexão. No navegador não é possível salvar nem '
                    'consultar dados sem internet.'
              : status.pendingCount > 0
              ? 'Sem conexão. ${status.pendingCount} item(ns) salvos neste '
                    'aparelho serão enviados quando a conexão voltar.'
              : 'Sem conexão. Seus dados continuam salvos neste aparelho.',
        ),
      );
    }
    if (status.attentionCount > 0) {
      messages.add(
        InkWell(
          key: const Key('faixa-atencao'),
          onTap: () => context.push('/atencao'),
          child: _Strip(
            color: theme.colorScheme.errorContainer,
            textColor: theme.colorScheme.onErrorContainer,
            icon: Icons.error_outline,
            text:
                '${status.attentionCount} item(ns) precisam da sua atenção. '
                'Toque para resolver.',
          ),
        ),
      );
    }
    if (status.phase == SyncPhase.syncing && messages.isEmpty) {
      messages.add(const LinearProgressIndicator(minHeight: 2));
    }
    if (messages.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      bottom: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: messages),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.text,
  });

  final Color color;
  final Color textColor;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: textColor, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Texto do estado para a linha "Sincronizar agora" em Mais.
String syncStatusLabel(SyncStatus status) {
  switch (status.phase) {
    case SyncPhase.idle:
      return 'Aguardando a primeira sincronização.';
    case SyncPhase.syncing:
      return 'Sincronizando…';
    case SyncPhase.offline:
      return 'Sem conexão. Tentaremos de novo automaticamente.';
    case SyncPhase.synced:
      final at = status.lastSyncAt;
      if (at == null) return 'Sincronizado.';
      final hh = at.hour.toString().padLeft(2, '0');
      final mm = at.minute.toString().padLeft(2, '0');
      return 'Sincronizado às $hh:$mm.';
  }
}

/// Botão "Sincronizar agora".
class SyncNowTile extends ConsumerWidget {
  const SyncNowTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final busy = status.phase == SyncPhase.syncing;
    return ListTile(
      leading: const Icon(Icons.sync),
      title: const Text('Sincronizar agora'),
      subtitle: Text(syncStatusLabel(status)),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      enabled: !busy,
      onTap: () => ref.read(syncSchedulerProvider).tick(),
    );
  }
}
