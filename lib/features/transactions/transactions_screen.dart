import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/calendar_date.dart';
import '../../core/domain/money.dart';
import '../categories/category_providers.dart';
import '../entries/entry_form_screen.dart';
import '../entries/entry_models.dart';
import '../entries/entry_providers.dart';
import '../investments/investment_models.dart';
import '../investments/investment_providers.dart';
import '../investments/investment_recurrence_edit_screen.dart';
import '../periods/period_navigation.dart';
import '../periods/period_providers.dart';
import '../recurrence/recurrence_edit_screen.dart';
import '../recurrence/recurrence_providers.dart';
import '../recurrence/recurrences_screen.dart';

/// Filtro por tipo (decisão D12; categoria e status ficam para a Fase 7).
enum EntryFilter {
  all('Todos'),
  income('Receitas'),
  expense('Despesas'),
  investment('Investimentos');

  const EntryFilter(this.label);
  final String label;
}

enum _NewItem { income, expense, investment }

class EntryFilterNotifier extends Notifier<EntryFilter> {
  @override
  EntryFilter build() => EntryFilter.all;

  void set(EntryFilter filter) => state = filter;
}

final entryFilterProvider = NotifierProvider<EntryFilterNotifier, EntryFilter>(
  EntryFilterNotifier.new,
);

/// Aba Lançamentos: receitas e despesas avulsas do período escolhido.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(selectedPeriodProvider);
    final filter = ref.watch(entryFilterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('novo-lancamento'),
        onPressed: () => _chooseKind(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: Column(
        children: [
          const PeriodNavigator(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final f in EntryFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('filtro-${f.name}'),
                      label: Text(f.label),
                      selected: filter == f,
                      onSelected: (_) =>
                          ref.read(entryFilterProvider.notifier).set(f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: view.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                child: Text('Não foi possível carregar os lançamentos.'),
              ),
              data: (v) {
                if (v == null) {
                  return const Center(child: Text('Nenhum período ainda.'));
                }
                if (!v.exists) return MissingPeriodCard(view: v);
                return _EntryList(filter: filter);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseKind(BuildContext context, WidgetRef ref) async {
    final kind = await showModalBottomSheet<_NewItem>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('nova-receita'),
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Nova receita'),
              onTap: () => Navigator.pop(sheet, _NewItem.income),
            ),
            ListTile(
              key: const Key('nova-despesa'),
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Nova despesa'),
              onTap: () => Navigator.pop(sheet, _NewItem.expense),
            ),
            ListTile(
              key: const Key('novo-investimento'),
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Novo investimento'),
              onTap: () => Navigator.pop(sheet, _NewItem.investment),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !context.mounted) return;
    if (kind == _NewItem.investment) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const EntryFormScreen.investment()),
      );
      return;
    }
    await _openForm(
      context,
      ref,
      kind == _NewItem.income ? EntryKind.income : EntryKind.expense,
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    EntryKind kind,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntryFormScreen(kind: kind)),
    );
  }
}

/// Linha da lista mista: lançamento (receita/despesa) ou investimento.
class _Row {
  const _Row.entry(EntryRecord this.entry) : investment = null;
  const _Row.investment(InvestmentRecord this.investment) : entry = null;

  final EntryRecord? entry;
  final InvestmentRecord? investment;

  CalendarDate get date => entry?.date ?? investment!.date;
}

class _EntryList extends ConsumerWidget {
  const _EntryList({required this.filter});

  final EntryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(periodEntriesProvider);
    final investments = ref.watch(periodInvestmentsProvider);
    final cats = ref.watch(categoryDataProvider).value;
    if (entries.hasError || investments.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível carregar os lançamentos.'),
            TextButton(
              key: const Key('tentar-de-novo'),
              onPressed: () => refreshFinanceData(ref),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    if (!entries.hasValue || !investments.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = <_Row>[
      for (final e in entries.requireValue)
        if (filter == EntryFilter.all ||
            (filter == EntryFilter.income && e.kind == EntryKind.income) ||
            (filter == EntryFilter.expense && e.kind == EntryKind.expense))
          _Row.entry(e),
      if (filter == EntryFilter.all || filter == EntryFilter.investment)
        for (final i in investments.requireValue) _Row.investment(i),
    ]..sort((a, b) => b.date.compareTo(a.date));
    if (rows.isEmpty) {
      return Center(
        child: Text(
          filter == EntryFilter.investment
              ? 'Nenhum investimento neste período.'
              : 'Nenhum lançamento neste período.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => refreshFinanceData(ref),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final row = rows[i];
          if (row.investment != null) {
            return _InvestmentTile(investment: row.investment!);
          }
          final e = row.entry!;
          final category = cats?.categories
              .where((c) => c.id == e.categoryId)
              .firstOrNull;
          return _EntryTile(entry: e, categoryName: category?.name);
        },
      ),
    );
  }
}

/// Investimento na lista: só valor e data, sem status de pagamento (D2).
class _InvestmentTile extends ConsumerWidget {
  const _InvestmentTile({required this.investment});

  final InvestmentRecord investment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strike = investment.cancelled
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    return ListTile(
      key: Key('investimento-${investment.id}'),
      leading: Icon(
        Icons.savings_outlined,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      title: Text('Investimento', style: strike),
      subtitle: Text(
        [
          investment.date.toBr(),
          if (investment.cancelled) 'Cancelado',
          if (investment.isRecurring) 'Recorrente',
        ].join(' · '),
      ),
      trailing: Text(
        '- ${formatBrl(investment.amount)}',
        style: (strike ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => _showActions(context, ref),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!investment.cancelled) ...[
              ListTile(
                key: const Key('acao-editar'),
                leading: const Icon(Icons.edit_outlined),
                title: Text(
                  investment.isRecurring ? 'Editar só esta' : 'Editar',
                ),
                onTap: () async {
                  Navigator.pop(sheet);
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => EntryFormScreen.investment(
                        existingInvestment: investment,
                      ),
                    ),
                  );
                },
              ),
              if (investment.isRecurring) ...[
                ListTile(
                  key: const Key('acao-editar-recorrencia'),
                  leading: const Icon(Icons.repeat),
                  title: const Text('Editar a recorrência'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _withTemplate(
                      context,
                      ref,
                      (t) => Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              InvestmentRecurrenceEditScreen(template: t),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  key: const Key('acao-parar-recorrencia'),
                  leading: const Icon(Icons.stop_circle_outlined),
                  title: const Text('Parar de repetir'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _withTemplate(
                      context,
                      ref,
                      (t) => confirmStopInvestmentRecurrence(context, ref, t),
                    );
                  },
                ),
              ],
              ListTile(
                key: const Key('acao-cancelar'),
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancelar investimento'),
                onTap: () {
                  Navigator.pop(sheet);
                  _cancel(context, ref);
                },
              ),
            ] else
              const ListTile(
                title: Text('Investimento cancelado'),
                subtitle: Text(
                  'Fica no histórico e não entra no dinheiro livre.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _withTemplate(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(InvestmentTemplate template) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = await ref.read(investmentRecurrenceServiceProvider.future);
    final template = await service.template(investment.templateId!);
    if (template == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Recorrência não encontrada.')),
      );
      return;
    }
    if (context.mounted) await action(template);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar este investimento?'),
        content: const Text(
          'O valor volta para o dinheiro livre do período em que foi investido e o '
          'registro continua no histórico como cancelado. Não é possível '
          'desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const Key('confirmar-cancelar'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar investimento'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final blocked = await ref.read(writeGateProvider).blockedReason();
      if (blocked != null) {
        messenger.showSnackBar(SnackBar(content: Text(blocked)));
        return;
      }
      final service = await ref.read(investmentServiceProvider.future);
      await service.cancel(investment);
      refreshFinanceData(ref);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

String entryStatusLabel(EntryRecord e) {
  if (e.isCancelled) return 'Cancelado';
  if (e.kind == EntryKind.income) {
    return e.status == 'pending' ? 'A receber' : 'Recebida';
  }
  return e.isPaid ? 'Paga' : 'Pendente';
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, this.categoryName});

  final EntryRecord entry;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final income = entry.kind == EntryKind.income;
    final theme = Theme.of(context);
    final title = entry.description?.isNotEmpty == true
        ? entry.description!
        : (categoryName ?? entry.kind.label);
    final amount = entry.amount == null
        ? 'Sem valor'
        : formatBrl(entry.amount!);
    final strike = entry.isCancelled
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    return ListTile(
      key: Key('lancamento-${entry.id}'),
      leading: Icon(
        income ? Icons.arrow_downward : Icons.arrow_upward,
        color: income ? Colors.green : theme.colorScheme.error,
      ),
      title: Text(title, style: strike),
      subtitle: Text(
        [
          entry.date.toBr(),
          ?categoryName,
          entryStatusLabel(entry),
          if (entry.isRecurring) 'Recorrente',
          if (entry.dueOn != null && entry.isPendingExpense)
            'vence ${entry.dueOn!.toBr()}',
        ].join(' · '),
      ),
      trailing: Text(
        income ? '+ $amount' : '- $amount',
        style: (strike ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => _showActions(context, ref),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!entry.isCancelled) ...[
              if (entry.isPendingIncome)
                ListTile(
                  key: const Key('acao-receber'),
                  leading: const Icon(Icons.download_done_outlined),
                  title: const Text('Confirmar recebimento'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _receive(context, ref);
                  },
                ),
              if (entry.isRecurring && entry.amount == null)
                ListTile(
                  key: const Key('acao-informar-valor'),
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Informar valor'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _informAmount(context, ref);
                  },
                ),
              ListTile(
                key: const Key('acao-editar'),
                leading: const Icon(Icons.edit_outlined),
                title: Text(entry.isRecurring ? 'Editar só esta' : 'Editar'),
                onTap: () async {
                  Navigator.pop(sheet);
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          EntryFormScreen(kind: entry.kind, existing: entry),
                    ),
                  );
                },
              ),
              if (entry.kind == EntryKind.expense && entry.amount != null)
                ListTile(
                  key: const Key('acao-pagar'),
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(
                    entry.isPaid
                        ? 'Corrigir data do pagamento'
                        : 'Marcar como paga',
                  ),
                  onTap: () {
                    Navigator.pop(sheet);
                    _pay(context, ref);
                  },
                ),
              if (entry.isRecurring) ...[
                ListTile(
                  key: const Key('acao-editar-recorrencia'),
                  leading: const Icon(Icons.repeat),
                  title: const Text('Editar a recorrência'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _withTemplate(
                      context,
                      ref,
                      (t) => Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => RecurrenceEditScreen(template: t),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  key: const Key('acao-parar-recorrencia'),
                  leading: const Icon(Icons.stop_circle_outlined),
                  title: const Text('Parar de repetir'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _withTemplate(
                      context,
                      ref,
                      (t) => confirmStopRecurrence(context, ref, t),
                    );
                  },
                ),
              ],
              ListTile(
                key: const Key('acao-cancelar'),
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancelar lançamento'),
                onTap: () {
                  Navigator.pop(sheet);
                  _cancel(context, ref);
                },
              ),
            ] else
              const ListTile(
                title: Text('Lançamento cancelado'),
                subtitle: Text(
                  'Fica no histórico e não entra no dinheiro livre.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(dynamic service) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final blocked = await ref.read(writeGateProvider).blockedReason();
      if (blocked != null) {
        messenger.showSnackBar(SnackBar(content: Text(blocked)));
        return;
      }
      final service = await ref.read(entryServiceProvider.future);
      await action(service);
      refreshFinanceData(ref);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final today = ref.read(userClockProvider).today();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Data do pagamento',
      initialDate: DateTime(today.year, today.month, today.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !context.mounted) return;
    final date = CalendarDate(picked.year, picked.month, picked.day);
    await _run(context, ref, (s) => s.pay(entry, date));
  }

  Future<void> _withTemplate(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(dynamic template) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = await ref.read(recurrenceRepositoryProvider.future);
    final template = await repo.template(entry.kind, entry.templateId!);
    if (template == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Recorrência não encontrada.')),
      );
      return;
    }
    if (context.mounted) await action(template);
  }

  /// Pede só o valor (recorrência de valor variável): a ocorrência passa a
  /// contar na sobra (despesa) ou fica pronta para ser confirmada (receita).
  Future<void> _informAmount(BuildContext context, WidgetRef ref) async {
    final value = await _askAmount(context, 'Valor desta ocorrência');
    if (value == null || !context.mounted) return;
    await _run(
      context,
      ref,
      (s) => s.update(
        entry,
        EntryDraft(
          kind: entry.kind,
          amount: value,
          date: entry.date,
          description: entry.description,
          categoryId: entry.categoryId,
          subcategoryId: entry.subcategoryId,
          dueOn: entry.dueOn,
        ),
      ),
    );
  }

  Future<BigInt?> _askAmount(
    BuildContext context,
    String title, {
    BigInt? initial,
  }) => showDialog<BigInt>(
    context: context,
    builder: (context) => _AmountDialog(title: title, initial: initial),
  );

  /// Confirma o recebimento: data (padrão hoje) e valor (RN011–RN012).
  Future<void> _receive(BuildContext context, WidgetRef ref) async {
    final today = ref.read(userClockProvider).today();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Data do recebimento',
      initialDate: DateTime(today.year, today.month, today.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !context.mounted) return;
    final date = CalendarDate(picked.year, picked.month, picked.day);
    BigInt? amount = entry.amount;
    if (amount == null || !context.mounted) {
      amount = await _askAmount(context, 'Valor recebido');
      if (amount == null || !context.mounted) return;
    }
    final value = amount;
    await _run(context, ref, (s) => s.receive(entry, date, amount: value));
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar este lançamento?'),
        content: const Text(
          'Ele deixa de entrar no dinheiro livre, mas continua no histórico como '
          'cancelado. Não é possível desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const Key('confirmar-cancelar'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar lançamento'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, ref, (s) => s.cancel(entry));
    }
  }
}

/// Pergunta um valor em reais; guarda o próprio controlador de texto.
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.title, this.initial});

  final String title;
  final BigInt? initial;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null
        ? ''
        : formatBrl(widget.initial!).replaceFirst('R\$ ', ''),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('campo-valor-ocorrencia'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          prefixText: 'R\$ ',
          hintText: '0,00',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        FilledButton(
          key: const Key('confirmar-valor'),
          onPressed: () {
            try {
              Navigator.pop(context, parseBrlToCentavos(_controller.text));
            } on MoneyFormatException catch (e) {
              setState(() => _error = e.message);
            }
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
