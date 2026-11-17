import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../application/card_bills_providers.dart';
import '../domain/card_bill_models.dart';
import '../domain/card_calendar.dart';
import '../domain/subscriptions.dart';
import '../domain/year_month.dart';
import '../widgets/card_bills_widgets.dart';

/// Assinatura (spec §7): descrição, cartão, valor mensal e a fatura da
/// primeira cobrança (padrão: a atual). Cancelar vale a partir da fatura
/// seguinte, perguntando pela cobrança da fatura atual.
Future<void> showSubscriptionForm(
  BuildContext context, {
  Subscription? existing,
  String? initialCardId,
  YearMonth? initialStart,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _SubscriptionForm(
    existing: existing,
    initialCardId: initialCardId,
    initialStart: initialStart,
  ),
);

class _SubscriptionForm extends ConsumerStatefulWidget {
  const _SubscriptionForm({
    this.existing,
    this.initialCardId,
    this.initialStart,
  });

  final Subscription? existing;
  final String? initialCardId;
  final YearMonth? initialStart;

  @override
  ConsumerState<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends ConsumerState<_SubscriptionForm> {
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : moneyInput(widget.existing!.monthlyAmount),
  );
  String? _cardId;
  YearMonth? _start;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cardId = widget.existing?.cardId ?? widget.initialCardId;
    if (widget.existing == null) _start = widget.initialStart;
    final cards = ref.read(cardBillsControllerProvider).value?.data.cards;
    if (_cardId == null && cards != null && cards.length == 1) {
      _cardId = cards.single.id;
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final snapshot = ref.read(cardBillsControllerProvider).value;
    if (snapshot == null) return;
    final amount = parseMoney(_amount.text);
    final error = validateSubscription(
      description: _description.text,
      cardId: _cardId,
      monthlyAmount: amount,
      data: snapshot.data,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final existing = widget.existing;
    final start =
        _start ??
        startMonthOptions(_cardId!, snapshot.data, snapshot.today).first;
    setState(() => _busy = true);
    final result = await ref
        .read(cardBillsControllerProvider.notifier)
        .run(
          (s) => existing == null
              ? s.createSubscription(
                  description: _description.text,
                  cardId: _cardId!,
                  monthlyAmount: amount!,
                  startMonthKey: start.toKey(),
                )
              : s.editSubscription(
                  existing,
                  description: _description.text,
                  cardId: _cardId!,
                  monthlyAmount: amount!,
                ),
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

  Future<void> _cancel() async {
    final sub = widget.existing!;
    final snapshot = ref.read(cardBillsControllerProvider).value;
    if (snapshot == null) return;
    final charge = currentCharge(sub, snapshot.data, snapshot.today);
    bool? removeCurrent;
    if (charge == null) {
      final ok = await confirmDialog(
        context,
        title: 'Cancelar a despesa recorrente?',
        message: 'Ela deixa de gerar cobranças a partir da próxima fatura.',
        action: 'Cancelar despesa recorrente',
      );
      if (!ok) return;
      removeCurrent = false;
    } else {
      removeCurrent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancelar a despesa recorrente?'),
          content: Text(
            'O cancelamento vale a partir da próxima fatura. Remover também a '
            'cobrança de ${formatBrl(charge.amount)} da fatura atual?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar'),
            ),
            TextButton(
              key: const Key('cb-assinatura-manter-cobranca'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Manter a cobrança'),
            ),
            FilledButton(
              key: const Key('cb-assinatura-remover-cobranca'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover também'),
            ),
          ],
        ),
      );
      if (removeCurrent == null) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final result = await ref
        .read(cardBillsControllerProvider.notifier)
        .run(
          (s) => s.cancelSubscription(sub, removeCurrentCharge: removeCurrent!),
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

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(cardBillsControllerProvider).value;
    final editing = widget.existing != null;
    final cards = snapshot?.data.cards ?? const <CreditCard>[];
    final card = _cardId == null ? null : snapshot?.data.card(_cardId!);
    final options = card == null || snapshot == null
        ? const <YearMonth>[]
        : startMonthOptions(card.id, snapshot.data, snapshot.today);
    final calendar = card == null || snapshot == null
        ? null
        : CardCalendar(card, snapshot.data.invoices);
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
              editing ? 'Editar despesa recorrente' : 'Nova Despesa Recorrente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('cb-assinatura-descricao'),
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: const Key('cb-assinatura-cartao'),
              initialValue: _cardId,
              decoration: const InputDecoration(labelText: 'Cartão'),
              items: [
                for (final c in cards)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() {
                _cardId = v;
                _start = null;
              }),
            ),
            const SizedBox(height: 12),
            MoneyField(
              key: const Key('cb-assinatura-valor'),
              controller: _amount,
              label: 'Valor mensal',
            ),
            if (!editing && options.isNotEmpty && calendar != null) ...[
              const SizedBox(height: 12),
              // Recriado ao trocar de cartão: o campo guarda o valor antigo e
              // o mês escolhido pode não existir nas opções do novo cartão.
              KeyedSubtree(
                key: ValueKey('cb-assinatura-inicio-${card!.id}'),
                child: DropdownButtonFormField<YearMonth>(
                  isExpanded: true,
                  key: const Key('cb-assinatura-inicio'),
                  initialValue: options.contains(_start)
                      ? _start
                      : options.first,
                  decoration: const InputDecoration(
                    labelText: 'Primeira cobrança',
                  ),
                  items: [
                    for (final (i, m) in options.indexed)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          'Fatura que vence em ${calendar.dueOf(m).toBr()}'
                          '${i == 0 ? ' (atual)' : ''}',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _start = v),
                ),
              ),
            ],
            if (editing)
              const CbNotice(
                'Preço novo vale para a fatura atual (se ainda não foi paga) '
                'e as próximas; faturas fechadas mantêm o valor antigo.',
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('cb-assinatura-erro'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('cb-assinatura-salvar'),
              onPressed: _busy ? null : _save,
              child: const Text('Salvar'),
            ),
            if (editing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('cb-assinatura-cancelar'),
                onPressed: _busy ? null : _cancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar despesa recorrente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
