import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/norte_theme.dart';
import '../../core/data_access.dart';
import '../../core/domain/calendar_date.dart';
import '../../core/domain/money.dart';
import '../categories/category_appearance.dart';
import '../categories/category_models.dart';
import '../categories/category_providers.dart';
import '../entries/entry_form_screen.dart';
import '../entries/entry_models.dart';
import '../entries/entry_providers.dart';
import '../investments/investment_models.dart';
import '../investments/investment_providers.dart';
import '../investments/investment_recurrence_edit_screen.dart';
import '../dashboard/dashboard_screen.dart' show PeriodHeader;
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

class EntrySearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String text) => state = text;
}

final entrySearchProvider = NotifierProvider<EntrySearchNotifier, String>(
  EntrySearchNotifier.new,
);

/// Aba Lançamentos: receitas e despesas avulsas do período escolhido.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(selectedPeriodProvider);
    final filter = ref.watch(entryFilterProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (view.value != null)
              PeriodHeader(
                view: view.value!,
                newButtonKey: const Key('novo-lancamento'),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'Lançamentos',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                key: const Key('busca-lancamentos'),
                onChanged: (t) => ref.read(entrySearchProvider.notifier).set(t),
                decoration: InputDecoration(
                  hintText: 'Buscar',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  for (final f in EntryFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('filtro-${f.name}'),
                        label: Text(f.label),
                        showCheckmark: false,
                        selected: filter == f,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: filter == f
                              ? Theme.of(context).colorScheme.surface
                              : Theme.of(context).colorScheme.onSurface,
                        ),
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
                  return _EntryList(filter: filter);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Escolhe o tipo (receita, despesa, investimento) e abre o formulário.
/// Também usado pelo botão "+" da Dashboard.
Future<void> showNewEntryChooser(BuildContext context, WidgetRef ref) async {
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
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => EntryFormScreen(
        kind: kind == _NewItem.income ? EntryKind.income : EntryKind.expense,
      ),
    ),
  );
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
    final query = ref.watch(entrySearchProvider).trim().toLowerCase();
    bool matches(String? text) =>
        query.isEmpty || (text ?? '').toLowerCase().contains(query);
    final rows = <_Row>[
      for (final e in entries.requireValue)
        if (!e.isCancelled &&
            (filter == EntryFilter.all ||
                (filter == EntryFilter.income && e.kind == EntryKind.income) ||
                (filter == EntryFilter.expense &&
                    e.kind == EntryKind.expense)) &&
            (matches(e.description) ||
                matches(
                  cats?.categories
                      .where((c) => c.id == e.categoryId)
                      .firstOrNull
                      ?.name,
                )))
          _Row.entry(e),
      if (filter == EntryFilter.all || filter == EntryFilter.investment)
        for (final i in investments.requireValue)
          if (!i.cancelled && matches('investimento')) _Row.investment(i),
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
    // Cabeçalho por dia ("Hoje", "Ontem", "5 de nov") antes de cada grupo.
    final today = ref.watch(userClockProvider).today();
    final items = <Object>[];
    CalendarDate? lastDay;
    for (final row in rows) {
      if (lastDay == null || row.date.toBr() != lastDay.toBr()) {
        items.add(_dayLabel(row.date, today));
        lastDay = row.date;
      }
      items.add(row);
    }
    return RefreshIndicator(
      onRefresh: () async => refreshFinanceData(ref),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          if (item is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                item,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            );
          }
          final row = item as _Row;
          if (row.investment != null) {
            return _InvestmentTile(investment: row.investment!);
          }
          final e = row.entry!;
          final category = cats?.categories
              .where((c) => c.id == e.categoryId)
              .firstOrNull;
          final subcategory = e.subcategoryId == null
              ? null
              : cats?.subcategories
                    .where((s) => s.id == e.subcategoryId)
                    .firstOrNull;
          return _EntryTile(
            entry: e,
            category: category,
            subcategory: subcategory,
          );
        },
      ),
    );
  }
}

const _monthAbbr = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String _dayLabel(CalendarDate date, CalendarDate today) {
  if (date.toBr() == today.toBr()) return 'Hoje';
  if (date.toBr() == today.addDays(-1).toBr()) return 'Ontem';
  final label = '${date.day} de ${_monthAbbr[date.month - 1]}';
  return date.year == today.year ? label : '$label de ${date.year}';
}

/// Texto do valor em fonte de números alinhados, na cor do significado.
TextStyle _amountStyle(BuildContext context, Color color, {TextStyle? base}) =>
    (base ?? const TextStyle()).copyWith(
      color: color,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Item da lista em duas regiões: esquerda flexível (ícone, título, detalhes,
/// com reticências) e direita com largura natural (valor e badge de status,
/// alinhados à direita). O valor nunca é cortado.
class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.amountStyle,
    required this.onTap,
    super.key,
    this.badge,
    this.badgePending = false,
    this.strike = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String amountText;
  final TextStyle amountStyle;
  final String? badge;
  final bool badgePending;
  final bool strike;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = NorteColors.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: strike ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Região direita: largura natural, até 55% da linha (acima disso o
            // valor reduz só se realmente não couber, nunca é cortado).
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.55,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(amountText, style: amountStyle, maxLines: 1),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgePending
                            ? colors.pendingBackground
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: badgePending
                              ? colors.pending
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
    final colors = NorteColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final strike = investment.cancelled
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    return _TxTile(
      key: Key('investimento-${investment.id}'),
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: colors.investment,
        child: const Icon(Icons.trending_up),
      ),
      title: 'Investimento',
      strike: investment.cancelled,
      subtitle: [
        investment.date.toBr(),
        if (investment.cancelled) 'Cancelado',
        if (investment.isRecurring) 'Recorrente',
      ].join(' · '),
      amountText: '- ${formatBrl(investment.amount)}',
      amountStyle: _amountStyle(
        context,
        investment.cancelled ? scheme.onSurfaceVariant : colors.investment,
        base: strike,
      ),
      onTap: () => _showActions(context, ref),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
          'registro some da lista. Não é possível desfazer.',
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
  const _EntryTile({required this.entry, this.category, this.subcategory});

  final EntryRecord entry;
  final CategoryRecord? category;
  final SubcategoryRecord? subcategory;

  String? get categoryName => category?.name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final income = entry.kind == EntryKind.income;
    final theme = Theme.of(context);
    final colors = NorteColors.of(context);
    final title = entry.description?.isNotEmpty == true
        ? entry.description!
        : (categoryName ?? entry.kind.label);
    final needsAmount = entry.amount == null && !entry.isCancelled;
    final amount = entry.amount == null
        ? (needsAmount ? 'Informar valor' : 'Sem valor')
        : formatBrl(entry.amount!);
    final strike = entry.isCancelled
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    final pending =
        !entry.isCancelled &&
        (income ? entry.status == 'pending' : !entry.isPaid);
    return _TxTile(
      key: Key('lancamento-${entry.id}'),
      leading: category != null
          ? CategoryBadge(
              iconKey: category!.iconKey,
              colorKey: category!.colorKey,
              filled: true,
            )
          : CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: income ? colors.income : colors.expense,
              child: Icon(income ? Icons.south_west : Icons.north_east),
            ),
      title: title,
      strike: entry.isCancelled,
      subtitle: [
        entry.date.toBr(),
        // Categoria já aparece como título quando não há descrição; o
        // detalhe mostra a subcategoria, sem repetir o nome.
        if (entry.description?.isNotEmpty == true) ?categoryName,
        ?subcategory?.name,
        if (entry.isRecurring) 'Recorrente',
        if (entry.dueOn != null && entry.isPendingExpense)
          'vence ${entry.dueOn!.toBr()}',
      ].join(' · '),
      amountText: entry.amount == null
          ? amount
          : (income ? '+ $amount' : '- $amount'),
      amountStyle: _amountStyle(
        context,
        entry.isCancelled
            ? theme.colorScheme.onSurfaceVariant
            : (needsAmount
                  ? theme.colorScheme.onSurfaceVariant
                  : (income ? colors.income : colors.expense)),
        base: strike,
      ),
      badge: entryStatusLabel(entry),
      badgePending: pending,
      onTap: () => _showActions(context, ref),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
          'Ele deixa de entrar no dinheiro livre e some da lista. '
          'Não é possível desfazer.',
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
