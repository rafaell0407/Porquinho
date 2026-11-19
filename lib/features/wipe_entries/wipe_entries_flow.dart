import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_access.dart';
import '../auth/auth_providers.dart';
import '../entries/entry_providers.dart';
import '../recurrence/recurrence_providers.dart';
import '../sync/sync_models.dart';
import '../sync/sync_providers.dart';
import 'wipe_entries_gateway.dart';
import 'wipe_entries_runner.dart';

/// Palavra que o usuário digita na segunda confirmação.
const wipeEntriesWord = 'APAGAR';

/// Tamanho de cada parte no servidor. Sobrescrito nos testes.
final wipeEntriesLimitProvider = Provider<int>((ref) => 200);

/// Fluxo "Apagar todos os lançamentos" (RF031, RN056): exige conexão, fila
/// vazia e nenhum conflito aberto; mostra o resumo (1ª confirmação) e pede a
/// palavra APAGAR (2ª). Apaga como o "Apagar" de sempre (RN029) e desativa as
/// recorrências. Não pode ser desfeito.
Future<void> wipeEntriesFlow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final local = ref.read(dataAccessModeProvider) == DataAccessMode.local;

  if (!await ref.read(connectivityProbeProvider).isOnline()) {
    if (!context.mounted) return;
    await _inform(
      context,
      title: 'Sem conexão',
      message:
          'Para apagar todos os lançamentos é preciso estar conectado à '
          'internet. Conecte-se e tente de novo. Nada foi apagado.',
    );
    return;
  }

  if (local) {
    if (!context.mounted) return;
    final pending = await _withProgress(
      context,
      'Enviando o que falta…',
      () => ref.read(sessionControllerProvider).pendingBeforeAccountDeletion(),
    );
    if (!context.mounted || pending == null) return;
    if (pending > 0) {
      await _inform(
        context,
        title: 'Ainda há dados não enviados',
        message:
            'Você tem $pending operação(ões) ou conflito(s) que ainda não '
            'foram resolvidos. Aguarde o envio, resolva os itens que precisam '
            'de atenção e tente de novo. Nada foi apagado.',
      );
      return;
    }
  }

  if (!context.mounted) return;
  final gateway = ref.read(wipeEntriesGatewayProvider);
  WipePreview? loaded;
  try {
    loaded = await _withProgress(context, 'Conferindo…', gateway.preview);
  } on Object {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível conferir os lançamentos. Verifique a conexão e '
          'tente de novo. Nada foi apagado.',
        ),
      ),
    );
    return;
  }
  if (!context.mounted || loaded == null) return;
  final preview = loaded;

  if (preview.openConflicts > 0) {
    await _showConflicts(context, preview.openConflicts);
    return;
  }
  if (preview.isEmpty) {
    await _inform(
      context,
      title: 'Nada para apagar',
      message: 'Você não tem receitas, despesas nem investimentos lançados.',
    );
    return;
  }

  final first = await showDialog<_SummaryChoice>(
    context: context,
    builder: (_) => _SummaryDialog(preview: preview, web: !local),
  );
  if (!context.mounted) return;
  if (first == _SummaryChoice.export) {
    unawaited(context.push('/exportar'));
    return;
  }
  if (first != _SummaryChoice.proceed) return;

  final second =
      await showDialog<bool>(
        context: context,
        builder: (_) => const _TypeToConfirmDialog(),
      ) ??
      false;
  if (!second || !context.mounted) return;

  final runner = WipeEntriesRunner(
    gateway,
    limit: ref.read(wipeEntriesLimitProvider),
  );
  final progress = ValueNotifier<int>(0);
  WipeOutcome? outcome;
  Object? failure;
  try {
    outcome = await _withProgress(
      context,
      'Apagando…',
      () => runner.run(
        operationId: newUuid(),
        asOf: preview.asOf,
        onProgress: (done) => progress.value = done,
      ),
      progress: progress,
      total: preview.entries,
    );
  } on Object catch (e) {
    failure = e;
  }

  // Mesmo numa falha no meio, parte pode ter sido apagada: atualiza tudo.
  if (local) {
    try {
      await ref
          .read(syncStatusProvider.notifier)
          .run(ref.read(ownerIdProvider));
    } on Object {
      // A próxima sincronização traz o que faltar.
    }
  }
  refreshFinanceData(ref);
  ref.invalidate(recurringTemplatesProvider);
  progress.dispose();

  if (failure != null || outcome == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível concluir. Parte dos lançamentos pode já ter sido '
          'apagada. Verifique a conexão e tente de novo para terminar.',
        ),
      ),
    );
    return;
  }
  switch (outcome) {
    case WipeBlocked(:final openConflicts):
      if (context.mounted) await _showConflicts(context, openConflicts);
    case final WipeDone done:
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            done.entries == 0
                ? 'Recorrências desativadas.'
                : '${_plural(done.entries, 'lançamento apagado', 'lançamentos apagados')}.',
          ),
        ),
      );
  }
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

Future<void> _inform(
  BuildContext context, {
  required String title,
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Entendi'),
      ),
    ],
  ),
);

Future<void> _showConflicts(BuildContext context, int count) async {
  final open =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Há itens que precisam de atenção'),
          content: Text(
            'Existe(m) $count conflito(s) de sincronização em aberto. Resolva '
            'antes de apagar todos os lançamentos. Nada foi apagado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ver itens'),
            ),
          ],
        ),
      ) ??
      false;
  if (open && context.mounted) unawaited(context.push('/atencao'));
}

/// Mostra um aviso de espera (não fecha ao tocar fora) enquanto [work] roda.
/// Devolve `null` se a tela sumiu no meio.
Future<T?> _withProgress<T>(
  BuildContext context,
  String label,
  Future<T> Function() work, {
  ValueNotifier<int>? progress,
  int? total,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('apagar-todos-progresso'),
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: progress == null
                    ? Text(label)
                    : ValueListenableBuilder<int>(
                        valueListenable: progress,
                        builder: (_, done, _) => Text(
                          total == null || total == 0
                              ? label
                              : '$label $done de $total',
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    if (navigator.mounted) navigator.pop();
  }
}

enum _SummaryChoice { proceed, export }

/// 1ª confirmação: o que sai, o que fica e o atalho para exportar antes.
class _SummaryDialog extends StatelessWidget {
  const _SummaryDialog({required this.preview, required this.web});

  final WipePreview preview;
  final bool web;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <String>[
      _plural(preview.income, 'receita', 'receitas'),
      _plural(preview.expense, 'despesa', 'despesas'),
      _plural(preview.investment, 'investimento', 'investimentos'),
      if (preview.templates > 0)
        '${_plural(preview.templates, 'recorrência', 'recorrências')} '
            '(${preview.templates == 1 ? 'será desativada' : 'serão desativadas'})',
    ];
    return AlertDialog(
      key: const Key('apagar-todos-resumo'),
      title: const Text('Apagar todos os lançamentos?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Serão apagados, de todos os períodos:'),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text(
                  '• $line',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'O dinheiro livre de todos os períodos volta a zero. As '
              'recorrências param de gerar lançamentos novos. Esta ação não '
              'pode ser desfeita.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Continuam: categorias, configuração do período, preferências e '
              'a Gestão de Faturas.',
            ),
            const SizedBox(height: 12),
            Text(
              web
                  ? 'Para guardar uma cópia, exporte os dados em CSV antes.'
                  : 'Para guardar uma cópia, exporte os dados em CSV pela '
                        'versão Web antes.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        if (web)
          TextButton(
            key: const Key('apagar-todos-exportar'),
            onPressed: () => Navigator.of(context).pop(_SummaryChoice.export),
            child: const Text('Exportar antes'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('apagar-todos-continuar'),
          onPressed: () => Navigator.of(context).pop(_SummaryChoice.proceed),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

/// 2ª confirmação: só libera depois de digitar APAGAR.
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
    final ok = _controller.text.trim().toUpperCase() == wipeEntriesWord;
    return AlertDialog(
      title: const Text('Confirme para apagar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Digite $wipeEntriesWord para apagar todos os lançamentos.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('apagar-todos-campo'),
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
          key: const Key('apagar-todos-confirmar'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Apagar tudo'),
        ),
      ],
    );
  }
}
