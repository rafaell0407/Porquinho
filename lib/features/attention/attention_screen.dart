import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/money.dart';
import '../auth/auth_providers.dart';
import '../sync/sync_models.dart';
import '../sync/sync_providers.dart';
import 'attention_models.dart';
import 'attention_providers.dart';
import 'attention_repository.dart';

/// Mais > Itens que precisam de atenção: conflitos (manter a versão do
/// aparelho, a do servidor ou editar) e alterações recusadas (descartar só
/// por decisão do usuário). Funciona no celular e na Web.
class AttentionScreen extends ConsumerWidget {
  const AttentionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(attentionItemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Precisam de atenção')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar.'),
              TextButton(
                onPressed: () => ref.invalidate(attentionItemsProvider),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Nada precisa da sua atenção.'))
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [for (final item in list) _ItemCard(item: item)],
              ),
      ),
    );
  }
}

class _ItemCard extends ConsumerStatefulWidget {
  const _ItemCard({required this.item});

  final AttentionItem item;

  @override
  ConsumerState<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<_ItemCard> {
  bool _busy = false;

  AttentionItem get item => widget.item;

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _run(Future<void> Function(AttentionRepository r) action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final repo = await ref.read(attentionRepositoryProvider.future);
      await action(repo);
      ref.invalidate(attentionItemsProvider);
      // Atualiza o aviso no topo (contagens e conexão).
      unawaited(
        ref.read(syncStatusProvider.notifier).run(ref.read(ownerIdProvider)),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is SyncRejectedError || e is SyncTransientError
                ? e.toString()
                : 'Não foi possível concluir: $e',
          ),
        ),
      );
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _keepRemote() async {
    final ok = await _confirm(
      'Manter a versão do servidor?',
      'A sua alteração será substituída. As duas versões ficam registradas '
          'no histórico.',
      'Manter a do servidor',
    );
    if (ok) {
      await _run((r) => r.resolve(item, ConflictResolution.keepRemote));
    }
  }

  Future<void> _keepLocal() =>
      _run((r) => r.resolve(item, ConflictResolution.keepLocal));

  Future<void> _edit() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditDialog(item: item),
    );
    if (result != null) {
      await _run(
        (r) => r.resolve(item, ConflictResolution.edit, editedRequest: result),
      );
    }
  }

  Future<void> _discard() async {
    final ok = await _confirm(
      'Descartar esta alteração?',
      'Ela não será enviada e o item voltará a ser como está no servidor.',
      'Descartar',
    );
    if (ok) await _run((r) => r.discard(item));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConflict = item.kind == AttentionKind.conflict;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConflict
                  ? '${item.title}: alterada em dois lugares'
                  : '${item.title}: alteração recusada',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Sua alteração: ${item.mineSummary}'),
            if (isConflict) Text('No servidor: ${item.serverSummary}'),
            if (!isConflict && item.reason != null)
              Text('Motivo: ${item.reason}'),
            const SizedBox(height: 12),
            if (_busy)
              const LinearProgressIndicator()
            else if (isConflict)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (item.canKeepLocal)
                    FilledButton(
                      key: Key('manter-meu-${item.id}'),
                      onPressed: _keepLocal,
                      child: const Text('Manter a minha'),
                    ),
                  OutlinedButton(
                    key: Key('manter-servidor-${item.id}'),
                    onPressed: _keepRemote,
                    child: const Text('Manter a do servidor'),
                  ),
                  if (item.canEdit)
                    OutlinedButton(
                      key: Key('editar-${item.id}'),
                      onPressed: _edit,
                      child: const Text('Editar'),
                    ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    key: Key('tentar-${item.id}'),
                    onPressed: () => _run((r) => r.retry(item)),
                    child: const Text('Tentar de novo'),
                  ),
                  TextButton(
                    key: Key('descartar-${item.id}'),
                    onPressed: _discard,
                    child: const Text('Descartar'),
                  ),
                ],
              ),
            if (isConflict && !item.canKeepLocal)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Este tipo de conflito só pode ser resolvido mantendo a '
                  'versão do servidor.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Edição da versão consolidada: nome (categorias) ou descrição e valor
/// (lançamentos). O valor segue a mesma validação de qualquer lançamento.
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.item});

  final AttentionItem item;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.item.request;
    final payload = Map<String, dynamic>.from((r['payload'] as Map?) ?? {});
    _name = TextEditingController(text: '${r['name'] ?? ''}');
    _description = TextEditingController(
      text: '${payload['description'] ?? ''}',
    );
    final cents = payload['amount_centavos'];
    _amount = TextEditingController(
      text: cents == null
          ? ''
          : formatBrl(BigInt.parse(cents.toString())).replaceFirst('R\$ ', ''),
    );
  }

  void _save() {
    final item = widget.item;
    if (item.isEntry) {
      BigInt? amount;
      if (_amount.text.trim().isNotEmpty) {
        try {
          amount = parseBrlToCentavos(_amount.text);
        } on MoneyFormatException catch (e) {
          setState(() => _error = e.message);
          return;
        }
      }
      Navigator.pop(
        context,
        buildEditedRequest(
          item,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          amountCentavos: amount,
        ),
      );
    } else {
      if (_name.text.trim().isEmpty) {
        setState(() => _error = 'Informe um nome.');
        return;
      }
      Navigator.pop(context, buildEditedRequest(item, name: _name.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar a versão final'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.item.isEntry) ...[
            TextField(
              key: const Key('editar-valor'),
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Valor (R\$)',
                errorText: _error,
              ),
            ),
            TextField(
              key: const Key('editar-descricao'),
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
          ] else
            TextField(
              key: const Key('editar-nome'),
              controller: _name,
              decoration: InputDecoration(labelText: 'Nome', errorText: _error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}
