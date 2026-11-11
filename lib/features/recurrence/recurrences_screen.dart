import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/money.dart';
import '../categories/category_providers.dart';
import '../categories/category_service.dart';
import '../entries/entry_models.dart';
import '../investments/investment_models.dart';
import '../investments/investment_providers.dart';
import '../investments/investment_recurrence_edit_screen.dart';
import 'recurrence_edit_screen.dart';
import 'recurrence_models.dart';
import 'recurrence_providers.dart';

/// Mais → Recorrências: receitas e despesas que se repetem. Criar uma
/// recorrência é feito no formulário de lançamento ("Repetir").
class RecurrencesScreen extends ConsumerWidget {
  const RecurrencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(recurringTemplatesProvider);
    final investments = ref.watch(investmentTemplatesProvider);
    final cats = ref.watch(categoryDataProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Recorrências')),
      body: templates.hasError || investments.hasError
          ? const Center(child: Text('Não foi possível carregar.'))
          : !templates.hasValue || !investments.hasValue
          ? const Center(child: CircularProgressIndicator())
          : _list(ref, cats, templates.requireValue, investments.requireValue),
    );
  }

  Widget _list(
    WidgetRef ref,
    CategoryData? cats,
    List<RecurringTemplate> list,
    List<InvestmentTemplate> investments,
  ) {
    if (list.isEmpty && investments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Nenhuma recorrência ainda. Ao cadastrar uma receita, despesa ou '
            'investimento, ligue "Repetir" para ela se repetir sozinha.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Ativas primeiro; a ordem entre elas se mantém.
    final tiles = <({bool active, Widget tile})>[
      for (final t in list)
        (
          active: t.isActive,
          tile: _TemplateTile(
            template: t,
            categoryName: cats?.categories
                .where((c) => c.id == t.categoryId)
                .firstOrNull
                ?.name,
          ),
        ),
      for (final t in investments)
        (active: t.isActive, tile: _InvestmentTemplateTile(template: t)),
    ];
    final ordered = [
      ...tiles.where((e) => e.active),
      ...tiles.where((e) => !e.active),
    ];
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recurringTemplatesProvider);
        ref.invalidate(investmentTemplatesProvider);
      },
      child: ListView.separated(
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => ordered[i].tile,
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template, this.categoryName});

  final RecurringTemplate template;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = template;
    final income = t.kind == EntryKind.income;
    final title = t.description?.isNotEmpty == true
        ? t.description!
        : (categoryName ?? t.kind.label);
    final value = t.variableValue
        ? 'valor variável'
        : (t.defaultAmount == null ? '' : formatBrl(t.defaultAmount!));
    return ListTile(
      key: Key('recorrencia-${t.id}'),
      leading: Icon(
        income ? Icons.arrow_downward : Icons.arrow_upward,
        color: income ? Colors.green : Theme.of(context).colorScheme.error,
      ),
      title: Text(
        title,
        style: t.isActive
            ? null
            : const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      subtitle: Text(
        [
          t.kind.label,
          t.scheduleLabel,
          ?(value.isEmpty ? null : value),
          if (!t.isActive) 'Interrompida',
        ].join(' · '),
      ),
      onTap: t.isActive ? () => _actions(context, ref) : null,
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('acao-editar-recorrencia'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar a recorrência'),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => RecurrenceEditScreen(template: template),
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
                confirmStopRecurrence(context, ref, template);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirma e interrompe a recorrência: não cria novas ocorrências; as já
/// geradas ficam como estão (D7).
Future<void> confirmStopRecurrence(
  BuildContext context,
  WidgetRef ref,
  RecurringTemplate template,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Parar de repetir?'),
      content: const Text(
        'Nenhuma ocorrência nova será criada. As que já existem continuam '
        'como estão. Não é possível retomar esta recorrência.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          key: const Key('confirmar-parar'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Parar de repetir'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final blocked = await ref.read(writeGateProvider).blockedReason();
    if (blocked != null) {
      messenger.showSnackBar(SnackBar(content: Text(blocked)));
      return;
    }
    final service = await ref.read(recurrenceServiceProvider.future);
    await service.stop(template);
    ref.invalidate(recurringTemplatesProvider);
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Investimento recorrente na lista: valor fixo, sem categoria, pagamento nem
/// vencimento (D8, D9).
class _InvestmentTemplateTile extends ConsumerWidget {
  const _InvestmentTemplateTile({required this.template});

  final InvestmentTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = template;
    return ListTile(
      key: Key('recorrencia-${t.id}'),
      leading: Icon(
        Icons.savings_outlined,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      title: Text(
        'Investimento',
        style: t.isActive
            ? null
            : const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      subtitle: Text(
        [
          'Investimento',
          t.scheduleLabel,
          formatBrl(t.defaultAmount),
          if (!t.isActive) 'Interrompida',
        ].join(' · '),
      ),
      onTap: t.isActive ? () => _actions(context, ref) : null,
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('acao-editar-recorrencia'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar a recorrência'),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        InvestmentRecurrenceEditScreen(template: template),
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
                confirmStopInvestmentRecurrence(context, ref, template);
              },
            ),
          ],
        ),
      ),
    );
  }
}
