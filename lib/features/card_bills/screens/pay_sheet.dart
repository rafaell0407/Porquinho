import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import '../application/card_bills_providers.dart';
import '../data/card_bills_repository.dart';
import '../domain/card_bill_models.dart';
import '../domain/invoice_board.dart';
import '../domain/reserve.dart';
import '../widgets/card_bills_widgets.dart';

/// "Pagar fatura" (spec §8): valor pago (preenchido com o valor da fatura,
/// editável, R$ 0,00 = sem valor a pagar), data e origem. Avisos ao vivo.
Future<bool> showPaySheet(BuildContext context, InvoiceView view) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PaySheet(view: view),
    ) ??
    false;

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.view});

  final InvoiceView view;

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  late final _amount = TextEditingController(
    text: moneyInput(widget.view.value),
  );
  PaymentSource _source = PaymentSource.reserve;
  CalendarDate? _date;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _confirm(CalendarDate date) async {
    final paid = parseMoney(_amount.text);
    final error = validatePaidAmount(paid);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _busy = true);
    final controller = ref.read(cardBillsControllerProvider.notifier);
    String? result;
    try {
      result = await controller.run(
        (s) => s.pay(widget.view, paid!, _source, date),
      );
    } on DuplicatePaymentException catch (e) {
      if (!mounted) return;
      result = await _duplicate(e.remote, paid!, date);
      if (result == 'kept') {
        if (mounted) Navigator.pop(context, false);
        return;
      }
    }
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  /// Web: a fatura já foi paga em outro aparelho; o usuário escolhe.
  Future<String?> _duplicate(
    InvoiceRecord remote,
    BigInt paid,
    CalendarDate date,
  ) async {
    final p = remote.payment!;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fatura já paga em outro aparelho'),
        content: Text(
          'Já existe um pagamento de ${formatBrl(p.paidAmount)} em '
          '${p.paidOn.toBr()}. Qual manter? A reserva é descontada uma vez só.',
        ),
        actions: [
          TextButton(
            key: const Key('cb-duplicado-manter-outro'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Manter o já registrado'),
          ),
          FilledButton(
            key: const Key('cb-duplicado-manter-este'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Manter este'),
          ),
        ],
      ),
    );
    if (replace != true) {
      await ref.read(cardBillsControllerProvider.notifier).reload();
      return 'kept';
    }
    return ref
        .read(cardBillsControllerProvider.notifier)
        .run((s) => s.replacePayment(widget.view, remote, paid, _source, date));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(cardBillsControllerProvider).value;
    if (snapshot == null) return const SizedBox.shrink();
    final date = _date ?? snapshot.today;
    final reserve = snapshot.board.reserve;
    final paid = parseMoney(_amount.text);
    PaymentPlan? plan;
    if (validatePaidAmount(paid) == null) {
      plan = planPayment(
        expectedAmount: widget.view.value,
        paidAmount: paid!,
        source: _source,
        events: snapshot.data.reserveEvents,
      );
    }
    final theme = Theme.of(context);
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
            Text('Pagar fatura', style: theme.textTheme.titleLarge),
            Text(
              '${widget.view.cardName} · vence em ${widget.view.dueOn.toBr()} '
              '· previsto ${formatBrl(widget.view.value)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            MoneyField(
              key: const Key('cb-pagar-valor'),
              controller: _amount,
              label: 'Valor pago',
              errorText: _error,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (paid == BigInt.zero)
              const CbNotice(
                'R\$ 0,00: sem valor a pagar; a fatura sai da lista.',
              ),
            ListTile(
              key: const Key('cb-pagar-data'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Data do pagamento'),
              subtitle: Text(date.toBr()),
              onTap: () async {
                final picked = await pickDate(context, initial: date);
                if (picked != null) setState(() => _date = picked);
              },
            ),
            Text('Origem', style: theme.textTheme.titleSmall),
            RadioGroup<PaymentSource>(
              groupValue: _source,
              onChanged: (v) => setState(() => _source = v ?? _source),
              child: Column(
                children: [
                  RadioListTile<PaymentSource>(
                    key: const Key('cb-pagar-origem-reserva'),
                    contentPadding: EdgeInsets.zero,
                    value: PaymentSource.reserve,
                    title: const Text('Dinheiro reservado'),
                    subtitle: Text('${formatBrl(reserve)} na reserva'),
                  ),
                  const RadioListTile<PaymentSource>(
                    key: Key('cb-pagar-origem-outras'),
                    contentPadding: EdgeInsets.zero,
                    value: PaymentSource.other,
                    title: Text('Outras fontes'),
                    subtitle: Text('A reserva não muda'),
                  ),
                ],
              ),
            ),
            if (plan != null)
              for (final w in plan.warnings)
                CbNotice(w, icon: Icons.warning_amber_outlined),
            if (plan != null && plan.reserveUsed > BigInt.zero)
              CbNotice('Sairão ${formatBrl(plan.reserveUsed)} da reserva.'),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('cb-pagar-confirmar'),
              onPressed: _busy ? null : () => _confirm(date),
              child: const Text('Confirmar pagamento'),
            ),
          ],
        ),
      ),
    );
  }
}
