import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/norte_theme.dart';
import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import '../application/card_bills_providers.dart';
import '../application/card_bills_service.dart';
import '../domain/card_bill_models.dart';
import '../domain/card_calendar.dart';
import '../domain/cards_and_invoices.dart';
import '../domain/invoice_board.dart';
import '../domain/purchases.dart' show validateItemAmount;
import '../widgets/card_bills_widgets.dart';
import '../widgets/money_dialog.dart';
import 'pay_sheet.dart';
import 'purchase_form_screen.dart';
import 'subscription_form.dart';

/// Detalhe da fatura (spec §5, §8, §11): itens, valor informado
/// (preencher/editar/apagar), datas (corrigir), pagar e desfazer. Paga:
/// congelada, com previsto × pago, origem e os itens copiados como texto.
class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(cardBillsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Fatura')),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não foi possível carregar: $e')),
        data: (s) {
          final view = s.board.invoice(invoiceId);
          if (view == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Esta fatura não aparece mais (sem itens e fora da atual '
                  'e da seguinte).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _InvoiceBody(view: view, snapshot: s);
        },
      ),
    );
  }
}

/// Situação da fatura em palavras ("vence em 17/12", "venceu em 17/11"…).
String invoiceStatusText(InvoiceView v) {
  if (v.isPaid) return 'paga em ${v.payment!.paidOn.toBr()}';
  if (v.isOverdue) return 'venceu em ${ddMm(v.dueOn)}';
  if (v.isClosed) return 'fechada · vence em ${ddMm(v.dueOn)}';
  return v.isCurrent
      ? 'atual · vence em ${ddMm(v.dueOn)}'
      : 'vence em ${ddMm(v.dueOn)}';
}

class _InvoiceBody extends ConsumerWidget {
  const _InvoiceBody({required this.view, required this.snapshot});

  final InvoiceView view;
  final CardBillsSnapshot snapshot;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(CardBillsService) action,
  ) async {
    final result = await ref
        .read(cardBillsControllerProvider.notifier)
        .run(action);
    if (result != null && context.mounted) showMessage(context, result);
  }

  Future<void> _informed(BuildContext context, WidgetRef ref) async {
    final result = await showMoneyDialog(
      context,
      title: 'Valor da fatura',
      message:
          'O valor informado substitui a soma dos itens (nunca soma os dois).',
      label: 'Valor informado',
      fieldKey: 'cb-informado-valor',
      saveKey: 'cb-informado-salvar',
      initial: view.informedAmount,
      validate: validateInformedAmount,
    );
    final amount = result?.amount;
    if (amount == null || !context.mounted) return;
    await _run(context, ref, (s) => s.setInformedAmount(view, amount));
  }

  Future<void> _dates(BuildContext context, WidgetRef ref) async {
    final card = snapshot.data.card(view.cardId);
    if (card == null) return;
    final calendar = CardCalendar(card, snapshot.data.invoices);
    var closing = view.closingOn;
    var due = view.dueOn;
    final result = await showDialog<(CalendarDate, CalendarDate)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final error = calendar.validateCorrection(view.month, closing, due);
          return AlertDialog(
            title: const Text('Corrigir datas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Use quando o banco mudar a data desta fatura (fim de '
                  'semana ou feriado). Compras já cadastradas não mudam de '
                  'fatura.',
                ),
                ListTile(
                  key: const Key('cb-datas-fechamento'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fechamento'),
                  subtitle: Text(closing.toBr()),
                  onTap: () async {
                    final p = await pickDate(context, initial: closing);
                    if (p != null) setLocal(() => closing = p);
                  },
                ),
                ListTile(
                  key: const Key('cb-datas-vencimento'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vencimento'),
                  subtitle: Text(due.toBr()),
                  onTap: () async {
                    final p = await pickDate(context, initial: due);
                    if (p != null) setLocal(() => due = p);
                  },
                ),
                if (error != null)
                  Text(
                    error,
                    key: const Key('cb-datas-erro'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('cb-datas-salvar'),
                onPressed: error != null
                    ? null
                    : () => Navigator.pop(context, (closing, due)),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !context.mounted) return;
    await _run(context, ref, (s) => s.correctDates(view, result.$1, result.$2));
  }

  Future<void> _charge(
    BuildContext context,
    WidgetRef ref,
    SubscriptionCharge charge,
  ) async {
    final result = await showMoneyDialog(
      context,
      title: charge.description,
      message: 'Muda só a cobrança desta fatura.',
      label: 'Valor nesta fatura',
      fieldKey: 'cb-cobranca-valor',
      saveKey: 'cb-cobranca-salvar',
      initial: charge.amount,
      validate: validateItemAmount,
      secondary: ('cb-cobranca-remover', 'Remover desta fatura'),
    );
    if (result == null || !context.mounted) return;
    final amount = result.amount;
    if (result.secondary) {
      await _run(context, ref, (s) => s.removeCharge(charge));
    } else if (amount != null) {
      await _run(context, ref, (s) => s.editCharge(charge, amount));
    }
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final p = view.payment!;
    final ok = await confirmDialog(
      context,
      title: 'Desfazer o pagamento?',
      message: p.reserveUsed > BigInt.zero
          ? 'A fatura volta a pendente e ${formatBrl(p.reserveUsed)} voltam '
                'para a reserva (só o que saiu dela).'
          : 'A fatura volta a pendente. A reserva não muda (o pagamento veio '
                'de outras fontes).',
      action: 'Desfazer pagamento',
    );
    if (!ok || !context.mounted) return;
    await _run(context, ref, (s) => s.undoPayment(view));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = NorteColors.of(context);
    final p = view.payment;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(view.cardName, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        invoiceStatusText(view),
                        key: const Key('cb-fatura-situacao'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: view.isOverdue
                              ? colors.expense
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: view.isOverdue ? FontWeight.w700 : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        formatBrl(view.value),
                        key: const Key('cb-fatura-valor'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fecha em ${view.closingOn.toBr()} · vence em '
                        '${view.dueOn.toBr()}'
                        '${view.datesManual ? ' (corrigidas)' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (p != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'previsto ${formatBrl(p.expectedAmount)} · pago '
                          '${formatBrl(p.paidAmount)}',
                          key: const Key('cb-fatura-previsto-pago'),
                        ),
                        Text(
                          p.reserveUsed > BigInt.zero
                              ? 'Da reserva: ${formatBrl(p.reserveUsed)}'
                                    '${p.paidAmount > p.reserveUsed ? ' · de outras fontes: ${formatBrl(p.paidAmount - p.reserveUsed)}' : ''}'
                              : 'De outras fontes',
                        ),
                      ],
                      if (p == null && view.informedAmount != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          view.informedBelowItems
                              ? '${formatBrl(view.informedAmount!)} informados'
                              : '${formatBrl(view.informedAmount!)} informados, '
                                    'dos quais ${formatBrl(view.itemsTotal)} em '
                                    'parcelas e despesas recorrentes e '
                                    '${formatBrl(view.otherSpending)} em outros '
                                    'gastos',
                          key: const Key('cb-fatura-detalhe-informado'),
                        ),
                      ],
                      if (p == null && view.informedBelowItems)
                        CbNotice(
                          'O valor informado é menor que a soma dos itens '
                          '(${formatBrl(view.itemsTotal)}). Vale o valor '
                          'informado.',
                          icon: Icons.warning_amber_outlined,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (p == null)
                CbSection(
                  title: 'Valor e datas',
                  children: [
                    CbValueRow(
                      view.informedAmount == null
                          ? 'Informar o valor da fatura'
                          : 'Valor informado',
                      view.informedAmount == null
                          ? ''
                          : formatBrl(view.informedAmount!),
                      key: const Key('cb-fatura-informar'),
                      subtitle: view.informedAmount == null
                          ? 'Opcional: substitui a soma dos itens'
                          : null,
                      onTap: () => _informed(context, ref),
                    ),
                    if (view.informedAmount != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('cb-fatura-apagar-informado'),
                          onPressed: () => _run(
                            context,
                            ref,
                            (s) => s.setInformedAmount(view, null),
                          ),
                          child: const Text('Apagar o valor informado'),
                        ),
                      ),
                    CbValueRow(
                      'Corrigir datas',
                      '',
                      key: const Key('cb-fatura-corrigir-datas'),
                      subtitle: 'Fechamento e vencimento desta fatura',
                      onTap: () => _dates(context, ref),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              CbSection(
                title: p == null ? 'Compras parceladas' : 'Itens no pagamento',
                trailing: view.items.isEmpty
                    ? null
                    : Text(
                        view.items.length == 1
                            ? '1 lançamento'
                            : '${view.items.length} lançamentos',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                children: [
                  if (view.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Nenhum item nesta fatura.'),
                    ),
                  CbCollapsibleList<InvoiceItem>(
                    items: view.items,
                    rowBuilder: (item) => CbValueRow(
                      item.description,
                      formatBrl(item.amount),
                      key: Key('cb-item-${item.id}'),
                      subtitle: p != null
                          ? null
                          : item.kind == InvoiceItemKind.charge
                          ? 'Despesa recorrente${item.manuallyEdited ? ' · ajustada' : ''}'
                          : '${item.isSinglePurchase ? 'Compra' : 'Parcela'}'
                                '${item.manuallyEdited ? ' · ajustada' : ''}',
                      onTap: p != null
                          ? null
                          : () => _openItem(context, ref, item),
                    ),
                  ),
                  if (view.items.isNotEmpty)
                    CbValueRow(
                      'Soma dos itens',
                      formatBrl(view.itemsTotal),
                      bold: true,
                    ),
                  if (p == null) ...[
                    CbValueRow(
                      'Adicionar compra',
                      '',
                      key: const Key('cb-fatura-add-compra'),
                      subtitle: 'Compra à vista ou parcelada nesta fatura',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PurchaseFormScreen(
                            initialCardId: view.cardId,
                            initialFirstMonth: view.month,
                          ),
                        ),
                      ),
                    ),
                    CbValueRow(
                      'Adicionar despesa recorrente',
                      '',
                      key: const Key('cb-fatura-add-assinatura'),
                      subtitle: 'Cobrança mensal recorrente',
                      onTap: () => showSubscriptionForm(
                        context,
                        initialCardId: view.cardId,
                        initialStart: view.month,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (p == null)
                FilledButton.icon(
                  key: const Key('cb-fatura-pagar'),
                  onPressed: () => showPaySheet(context, view),
                  icon: const Icon(Icons.check),
                  label: const Text('Pagar fatura'),
                )
              else
                OutlinedButton.icon(
                  key: const Key('cb-fatura-desfazer'),
                  onPressed: () => _undo(context, ref),
                  icon: const Icon(Icons.undo),
                  label: const Text('Desfazer pagamento'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openItem(BuildContext context, WidgetRef ref, InvoiceItem item) {
    if (item.kind == InvoiceItemKind.charge) {
      final charge = snapshot.data.charges
          .where((c) => c.id == item.id)
          .firstOrNull;
      if (charge != null) _charge(context, ref, charge);
      return;
    }
    final purchase = snapshot.data.purchase(item.sourceId);
    if (purchase == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PurchaseFormScreen(existing: purchase),
      ),
    );
  }
}
