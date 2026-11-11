import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/calendar_date.dart';
import '../../core/domain/money.dart';
import '../categories/category_providers.dart';
import '../entries/entry_form_screen.dart';
import '../entries/entry_models.dart';
import '../entries/entry_providers.dart';
import '../periods/period_navigation.dart';
import '../periods/period_providers.dart';

/// Filtro por tipo (decisão D12; categoria e status ficam para a Fase 7).
enum EntryFilter {
  all('Todos'),
  income('Receitas'),
  expense('Despesas');

  const EntryFilter(this.label);
  final String label;
}

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
    final kind = await showModalBottomSheet<EntryKind>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('nova-receita'),
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Nova receita'),
              onTap: () => Navigator.pop(sheet, EntryKind.income),
            ),
            ListTile(
              key: const Key('nova-despesa'),
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Nova despesa'),
              onTap: () => Navigator.pop(sheet, EntryKind.expense),
            ),
          ],
        ),
      ),
    );
    if (kind != null && context.mounted) await _openForm(context, ref, kind);
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

class _EntryList extends ConsumerWidget {
  const _EntryList({required this.filter});

  final EntryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(periodEntriesProvider);
    final cats = ref.watch(categoryDataProvider).value;
    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
        child: Text('Não foi possível carregar os lançamentos.'),
      ),
      data: (all) {
        final list = all
            .where(
              (e) =>
                  filter == EntryFilter.all ||
                  (filter == EntryFilter.income &&
                      e.kind == EntryKind.income) ||
                  (filter == EntryFilter.expense &&
                      e.kind == EntryKind.expense),
            )
            .toList();
        if (list.isEmpty) {
          return const Center(child: Text('Nenhum lançamento neste período.'));
        }
        return RefreshIndicator(
          onRefresh: () async => refreshFinanceData(ref),
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i];
              final category = cats?.categories
                  .where((c) => c.id == e.categoryId)
                  .firstOrNull;
              return _EntryTile(entry: e, categoryName: category?.name);
            },
          ),
        );
      },
    );
  }
}

String entryStatusLabel(EntryRecord e) {
  if (e.isCancelled) return 'Cancelado';
  if (e.kind == EntryKind.income) return 'Recebida';
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
              ListTile(
                key: const Key('acao-editar'),
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar'),
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
                subtitle: Text('Fica no histórico e não entra na sobra.'),
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

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar este lançamento?'),
        content: const Text(
          'Ele deixa de entrar na sobra, mas continua no histórico como '
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
