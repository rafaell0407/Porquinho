import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import '../application/card_bills_providers.dart';
import '../application/card_bills_service.dart';
import '../domain/card_bill_models.dart';
import '../domain/card_calendar.dart';
import '../domain/purchases.dart';
import '../domain/year_month.dart';
import '../widgets/card_bills_widgets.dart';
import '../widgets/money_dialog.dart';

/// Nova compra parcelada ou edição (spec §6): descrição, cartão, data (sem
/// data futura), valor total ou da parcela, 1–24 parcelas e a fatura da 1ª
/// parcela (automática, com troca para a anterior ou a seguinte).
class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({
    this.existing,
    this.initialCardId,
    this.initialFirstMonth,
    super.key,
  });

  final Purchase? existing;
  final String? initialCardId;

  /// Fatura da 1ª parcela já escolhida (ex.: ao adicionar pela fatura).
  final YearMonth? initialFirstMonth;

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<PurchaseFormScreen> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _count = TextEditingController(text: '1');
  String? _cardId;
  late CalendarDate _date;
  AmountMode _mode = AmountMode.total;
  YearMonth? _firstMonth;
  Map<String, String> _errors = const {};
  bool _busy = false;
  bool _initialized = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _count.dispose();
    super.dispose();
  }

  void _init(CardBillsSnapshot s) {
    if (_initialized) return;
    _initialized = true;
    final p = widget.existing;
    _date = s.today;
    if (p == null) {
      _firstMonth = widget.initialFirstMonth;
      _cardId =
          widget.initialCardId ??
          (s.data.cards.length == 1 ? s.data.cards.single.id : null);
      return;
    }
    final installments = s.data.installmentsOf(p.id);
    _description.text = p.description;
    _cardId = p.cardId;
    _date = p.purchasedOn;
    _mode = p.amountMode;
    _count.text = '${p.installmentCount}';
    final total = installments.fold(BigInt.zero, (a, i) => a + i.amount);
    _amount.text = moneyInput(
      _mode == AmountMode.total || installments.isEmpty
          ? total
          : installments.last.amount,
    );
    if (installments.isNotEmpty) {
      _firstMonth = installments.first.month.add(1 - installments.first.number);
    }
  }

  PurchaseDraft _draft() => PurchaseDraft(
    cardId: _cardId,
    description: _description.text,
    purchasedOn: _date,
    installmentCount: int.tryParse(_count.text),
    amountMode: _mode,
    amount: parseMoney(_amount.text),
    firstMonth: _firstMonth,
  );

  /// Cálculo ao vivo (sem gravar). `null` enquanto o formulário não fecha.
  (PurchasePlan?, String?) _preview(CardBillsSnapshot s) {
    final draft = _draft();
    if (validatePurchaseDraft(draft, s.data, s.today).isNotEmpty) {
      return (null, null);
    }
    try {
      final existing = widget.existing;
      return (
        existing == null
            ? planNewPurchase(
                id: 'preview',
                draft: draft,
                data: s.data,
                today: s.today,
              )
            : planPurchaseEdit(
                existing: existing,
                draft: draft,
                data: s.data,
                today: s.today,
              ),
        null,
      );
    } on ArgumentError catch (e) {
      return (null, '${e.message}');
    }
  }

  Future<void> _save(CardBillsSnapshot s) async {
    final draft = _draft();
    final errors = validatePurchaseDraft(draft, s.data, s.today);
    if (_amount.text.trim().isNotEmpty && moneyError(_amount.text) != null) {
      errors['amount'] = moneyError(_amount.text)!;
    }
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    final (plan, error) = _preview(s);
    if (error != null) {
      setState(() => _errors = {'general': error});
      return;
    }
    if (plan != null && plan.warnings.any((w) => w.contains('à mão'))) {
      final ok = await confirmDialog(
        context,
        title: 'Refazer os ajustes?',
        message: 'Os ajustes feitos à mão nas parcelas serão refeitos.',
        action: 'Salvar mesmo assim',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    PurchasePlan? saved;
    final result = await ref
        .read(cardBillsControllerProvider.notifier)
        .run(
          (service) async => saved = await service.savePurchase(
            draft,
            existing: widget.existing,
          ),
        );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _errors = {'general': result};
      });
      return;
    }
    final notes = saved?.warnings.where((w) => !w.contains('à mão')).toList();
    if (widget.existing == null) {
      // Nova compra: permanece na tela, com o formulário limpo (cartão e data
      // mantidos) para adicionar a próxima.
      setState(() {
        _busy = false;
        _errors = const {};
        _description.clear();
        _amount.clear();
        _count.text = '1';
        _mode = AmountMode.total;
        _firstMonth = widget.initialFirstMonth;
      });
      showMessage(context, ['Compra adicionada.', ...?notes].join(' '));
      return;
    }
    if (notes != null && notes.isNotEmpty) {
      showMessage(context, notes.join(' '));
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final p = widget.existing!;
    final ok = await confirmDialog(
      context,
      title: 'Apagar a compra?',
      message:
          '"${p.description}" e as parcelas pendentes serão apagadas. As '
          'parcelas de faturas já pagas ficam só como texto no histórico.',
      action: 'Apagar compra',
    );
    if (!ok || !mounted) return;
    final result = await ref
        .read(cardBillsControllerProvider.notifier)
        .run((s) => s.deletePurchase(p));
    if (!mounted) return;
    if (result != null) {
      showMessage(context, result);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(cardBillsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nova compra' : 'Editar compra'),
        actions: [
          if (widget.existing != null)
            IconButton(
              key: const Key('cb-compra-apagar'),
              tooltip: 'Apagar compra',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não foi possível carregar: $e')),
        data: (s) {
          _init(s);
          return _form(s);
        },
      ),
    );
  }

  Widget _form(CardBillsSnapshot s) {
    final (plan, planError) = _preview(s);
    final card = _cardId == null ? null : s.data.card(_cardId!);
    final calendar = card == null ? null : CardCalendar(card, s.data.invoices);
    // Fatura da parcela 1 (base da troca para a anterior ou a seguinte).
    final firstInstallment = plan?.installments.first;
    final firstMonth = firstInstallment?.month.add(1 - firstInstallment.number);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CbSection(
                title: 'A compra',
                children: [
                  TextField(
                    key: const Key('cb-compra-descricao'),
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Descrição',
                      errorText: _errors['description'],
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: const Key('cb-compra-cartao'),
                    initialValue: _cardId,
                    decoration: InputDecoration(
                      labelText: 'Cartão',
                      errorText: _errors['card'],
                    ),
                    items: [
                      for (final c in s.data.cards)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() {
                      _cardId = v;
                      _firstMonth = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    key: const Key('cb-compra-data'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Data da compra'),
                    subtitle: Text(
                      _errors['date'] ?? _date.toBr(),
                      style: _errors['date'] == null
                          ? null
                          : TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                    ),
                    onTap: () async {
                      final picked = await pickDate(
                        context,
                        initial: _date,
                        last: s.today,
                      );
                      if (picked != null) {
                        setState(() {
                          _date = picked;
                          _firstMonth = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CbSection(
                title: 'Valor e parcelas',
                children: [
                  SegmentedButton<AmountMode>(
                    key: const Key('cb-compra-modo'),
                    segments: const [
                      ButtonSegment(
                        value: AmountMode.total,
                        label: Text('Valor total'),
                      ),
                      ButtonSegment(
                        value: AmountMode.installment,
                        label: Text('Valor da parcela'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (v) => setState(() => _mode = v.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: MoneyField(
                          key: const Key('cb-compra-valor'),
                          controller: _amount,
                          label: _mode == AmountMode.total
                              ? 'Valor total'
                              : 'Valor da parcela',
                          errorText: _errors['amount'],
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: const Key('cb-compra-parcelas'),
                          controller: _count,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Parcelas',
                            helperText: '1 = à vista',
                            errorText: _errors['count'],
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (plan != null && calendar != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          key: const Key('cb-compra-fatura-anterior'),
                          tooltip: 'Fatura anterior',
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () =>
                              setState(() => _firstMonth = firstMonth!.add(-1)),
                        ),
                        Expanded(
                          child: Text(
                            '1ª parcela na fatura que vence em '
                            '${calendar.dueOf(plan.installments.first.month).toBr()}',
                            key: const Key('cb-compra-primeira-fatura'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          key: const Key('cb-compra-fatura-seguinte'),
                          tooltip: 'Fatura seguinte',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () =>
                              setState(() => _firstMonth = firstMonth!.add(1)),
                        ),
                      ],
                    ),
                    _summary(plan),
                    for (final w in plan.warnings) CbNotice(w),
                  ],
                  if (planError != null) CbNotice(planError),
                  if (_errors['general'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errors['general']!,
                        key: const Key('cb-compra-erro'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 12),
                _installmentsSection(s),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('cb-compra-salvar'),
                onPressed: _busy ? null : () => _save(s),
                child: Text(
                  widget.existing == null ? 'Salvar compra' : 'Salvar',
                ),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('cb-compra-apagar-botao'),
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Apagar compra'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(PurchasePlan plan) {
    final total = plan.installments.fold(BigInt.zero, (a, i) => a + i.amount);
    final n = plan.installments.length;
    final first = plan.installments.first.amount;
    final other = n > 1 ? plan.installments.last.amount : first;
    final text = n == 1
        ? 'À vista no cartão: ${formatBrl(total)}'
        : first == other
        ? '$n × ${formatBrl(other)} = ${formatBrl(total)}'
        : '1ª de ${formatBrl(first)} + ${n - 1} × ${formatBrl(other)} = '
              '${formatBrl(total)}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        key: const Key('cb-compra-resumo'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _installmentsSection(CardBillsSnapshot s) {
    final p = widget.existing!;
    final installments = s.data.installmentsOf(p.id);
    return CbSection(
      title: 'Parcelas',
      children: [
        for (final i in installments)
          _installmentTile(s, p, i, installments.length),
      ],
    );
  }

  Widget _installmentTile(
    CardBillsSnapshot s,
    Purchase p,
    Installment i,
    int count,
  ) {
    final card = s.data.card(i.cardId);
    final due = card == null
        ? null
        : CardCalendar(card, s.data.invoices).dueOf(i.month);
    final settled = isSettled(i, s.data);
    final status = i.paidOutside
        ? 'considerada paga'
        : settled
        ? 'paga'
        : i.manuallyEdited
        ? 'ajustada à mão'
        : null;
    return CbValueRow(
      '${i.number}/$count${due == null ? '' : ' · vence ${due.toBr()}'}',
      formatBrl(i.amount),
      subtitle: status,
      key: Key('cb-parcela-${i.number}'),
      onTap: settled ? null : () => _editInstallment(i),
    );
  }

  Future<void> _editInstallment(Installment i) async {
    final result = await showMoneyDialog(
      context,
      title: 'Parcela ${i.number}',
      label: 'Valor da parcela',
      fieldKey: 'cb-parcela-valor',
      saveKey: 'cb-parcela-salvar',
      initial: i.amount,
      validate: validateItemAmount,
      options: const [
        ('cb-parcela-so-esta', 'Só esta parcela'),
        ('cb-parcela-e-proximas', 'Esta e as próximas'),
      ],
    );
    final amount = result?.amount;
    if (amount == null || !mounted) return;
    final message = await ref
        .read(cardBillsControllerProvider.notifier)
        .run(
          (s) =>
              s.editInstallment(i, amount, andFollowing: result!.option == 1),
        );
    if (message != null && mounted) showMessage(context, message);
  }
}
