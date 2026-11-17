import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../application/card_bills_providers.dart';
import '../domain/card_bill_models.dart';
import '../domain/card_calendar.dart';
import '../domain/cards_and_invoices.dart';
import '../widgets/card_bills_widgets.dart';

/// Cadastro e edição do cartão (spec §4): nome, dia de fechamento e de
/// vencimento. Na edição, "Apagar cartão" com aviso do valor que deixa de
/// contar.
Future<void> showCardForm(BuildContext context, {CreditCard? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CardForm(existing: existing),
    );

class _CardForm extends ConsumerStatefulWidget {
  const _CardForm({this.existing});

  final CreditCard? existing;

  @override
  ConsumerState<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends ConsumerState<_CardForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _closing = TextEditingController(
    text: widget.existing?.closingDay.toString() ?? '',
  );
  late final _due = TextEditingController(
    text: widget.existing?.dueDay.toString() ?? '',
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _closing.dispose();
    _due.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final closing = int.tryParse(_closing.text);
    final due = int.tryParse(_due.text);
    final error = validateCard(_name.text, closing, due);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _busy = true);
    final controller = ref.read(cardBillsControllerProvider.notifier);
    final existing = widget.existing;
    final result = await controller.run(
      (s) => existing == null
          ? s.createCard(_name.text, closing!, due!)
          : s.editCard(existing, _name.text, closing!, due!),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final card = widget.existing!;
    final snapshot = ref.read(cardBillsControllerProvider).value;
    final value = snapshot == null
        ? BigInt.zero
        : cardCommitment(card.id, snapshot.board);
    final ok = await confirmDialog(
      context,
      title: 'Apagar o cartão ${card.name}?',
      message:
          'Compras, despesas recorrentes e faturas pendentes deste cartão serão '
          'apagadas e ${formatBrl(value)} deixarão de contar no comprometido. '
          'Faturas já pagas continuam no histórico.',
      action: 'Apagar cartão',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final result = await ref
        .read(cardBillsControllerProvider.notifier)
        .run((s) => s.deleteCard(card));
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }
    Navigator.pop(context);
  }

  String? get _preview {
    final closing = int.tryParse(_closing.text);
    final due = int.tryParse(_due.text);
    if (validateCardDays(closing, due) != null) return null;
    final card = CreditCard(
      id: '',
      name: '',
      closingDay: closing!,
      dueDay: due!,
    );
    final today = ref.read(cardBillsServiceProvider).value?.today;
    if (today == null) return null;
    final calendar = CardCalendar(card, const []);
    final month = calendar.currentMonth(today);
    return 'Fatura atual: fecha em ${calendar.closingOf(month).toBr()} e '
        'vence em ${calendar.dueOf(month).toBr()}.';
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Editar cartão' : 'Novo cartão',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('cb-cartao-nome'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome do cartão'),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DayField(
                    key: const Key('cb-cartao-fechamento'),
                    controller: _closing,
                    label: 'Fecha dia',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DayField(
                    key: const Key('cb-cartao-vencimento'),
                    controller: _due,
                    label: 'Vence dia',
                  ),
                ),
              ],
            ),
            ListenableBuilder(
              listenable: Listenable.merge([_closing, _due]),
              builder: (_, _) {
                final text = _preview;
                return text == null ? const SizedBox.shrink() : CbNotice(text);
              },
            ),
            if (editing)
              const CbNotice(
                'Mudar os dias só altera as faturas que ainda não fecharam; '
                'compras já cadastradas não mudam de fatura.',
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('cb-cartao-erro'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('cb-cartao-salvar'),
              onPressed: _busy ? null : _save,
              child: Text(editing ? 'Salvar' : 'Cadastrar cartão'),
            ),
            if (editing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('cb-cartao-apagar'),
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Apagar cartão'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
