import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/norte_theme.dart';
import '../../../core/domain/money.dart';
import '../../../shared/main_shell.dart' show NorteNavBar;
import '../../tools/registry/tool_registry.dart' show cardBillsTool;
import '../../tools/widgets/tool_explanation.dart' show showToolInfoSheet;
import '../../transactions/transactions_screen.dart' show showNewEntryChooser;
import '../application/card_bills_providers.dart';
import '../application/card_bills_service.dart';
import '../card_bills_texts.dart';
import '../domain/card_bill_models.dart';
import '../domain/card_calendar.dart';
import '../domain/invoice_board.dart';
import '../domain/reserve.dart';
import '../domain/subscriptions.dart' show currentInvoiceMonth;
import '../widgets/card_bills_widgets.dart';
import 'card_form.dart';
import 'invoice_detail_screen.dart';
import 'pay_sheet.dart';
import 'purchase_form_screen.dart';
import 'reserve_calculator_sheet.dart';
import 'subscription_form.dart';

/// Ferramentas → Gestão de Faturas de Cartões (rota `/gestao-de-faturas`;
/// spec `docs/ferramentas/gestao_de_faturas.md`). Ferramenta separada: não
/// cria lançamentos nem muda o dinheiro livre.
class CardBillsScreen extends ConsumerWidget {
  const CardBillsScreen({super.key});

  static const route = '/gestao-de-faturas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(cardBillsControllerProvider);
    final hasCards = snapshot.value?.data.cards.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text(CardBillsTexts.title),
        actions: [
          IconButton(
            key: const Key('cb-info'),
            tooltip: 'Sobre a ferramenta',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showToolInfoSheet(context, cardBillsTool),
          ),
          if (snapshot.hasValue)
            IconButton(
              key: const Key('cb-adicionar'),
              tooltip: 'Adicionar',
              icon: const Icon(Icons.add),
              onPressed: () => _showAddMenu(context, hasCards),
            ),
        ],
      ),
      bottomNavigationBar: NorteNavBar(
        currentIndex: 1,
        onTab: (i) => context.go(NorteNavBar.tabRoutes[i]),
        onAdd: () => showNewEntryChooser(context, ref),
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Não foi possível carregar a Gestão de Faturas.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => ref.invalidate(cardBillsControllerProvider),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
        data: (s) => s.data.cards.isEmpty && s.board.paid.isEmpty
            ? const _EmptyState()
            : _Board(snapshot: s),
      ),
    );
  }
}

Future<void> _showAddMenu(
  BuildContext context,
  bool hasCards,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: const Key('cb-adicionar-compra'),
          enabled: hasCards,
          leading: const Icon(Icons.shopping_bag_outlined),
          title: const Text('Compra parcelada'),
          subtitle: hasCards ? null : const Text('Cadastre um cartão antes'),
          onTap: () {
            Navigator.pop(sheet);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PurchaseFormScreen(),
              ),
            );
          },
        ),
        ListTile(
          key: const Key('cb-adicionar-assinatura'),
          enabled: hasCards,
          leading: const Icon(Icons.autorenew),
          title: const Text('Despesa recorrente'),
          subtitle: hasCards ? null : const Text('Cadastre um cartão antes'),
          onTap: () {
            Navigator.pop(sheet);
            showSubscriptionForm(context);
          },
        ),
        ListTile(
          key: const Key('cb-adicionar-cartao'),
          leading: const Icon(Icons.credit_card),
          title: const Text('Cartão'),
          onTap: () {
            Navigator.pop(sheet);
            showCardForm(context);
          },
        ),
      ],
    ),
  ),
);

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.credit_card,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                CardBillsTexts.emptyTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(CardBillsTexts.emptyBody, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('cb-primeiro-cartao'),
                onPressed: () => showCardForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar cartão'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board({required this.snapshot});

  final CardBillsSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = snapshot.board;
    final data = snapshot.data;
    return RefreshIndicator(
      onRefresh: () => ref.read(cardBillsControllerProvider.notifier).reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Summary(board: board),
                  const SizedBox(height: 12),
                  _InvoicesSection(board: board),
                  if (board.paid.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _PaidSection(board: board),
                  ],
                  const SizedBox(height: 12),
                  _CardsSection(data: data),
                  if (data.purchases.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _PurchasesSection(data: data),
                  ],
                  if (data.subscriptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SubscriptionsSection(snapshot: snapshot),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.board});

  final CardBillsBoard board;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = NorteColors.of(context);
    final short = board.shortfall > BigInt.zero;
    final last = board.lastAutomaticChange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              short ? 'Faltam' : 'Saldo não comprometido',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              short
                  ? '${formatBrl(board.shortfall)} para cobrir as faturas'
                  : formatBrl(board.uncommitted),
              key: const Key('cb-saldo'),
              style:
                  (short
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.headlineMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: short ? colors.expense : null,
                      ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            CbValueRow(
              'Reservado',
              formatBrl(board.reserve),
              key: const Key('cb-reservado'),
              subtitle: last != null
                  ? describeAutomaticEvent(last)
                  : board.reserve == BigInt.zero
                  ? 'Toque para informar quanto separou'
                  : 'Toque para mudar',
              onTap: () => showReserveCalculator(context, board.reserve),
            ),
            CbValueRow(
              'Comprometido',
              formatBrl(board.committed),
              key: const Key('cb-comprometido'),
              subtitle: 'Faturas a pagar de todos os cartões',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Despesas recorrentes ativas: '
                '${formatBrl(board.activeSubscriptionsMonthly)} por mês',
                key: const Key('cb-assinaturas-ativas'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openInvoice(BuildContext context, InvoiceView v) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceDetailScreen(invoiceId: v.id),
      ),
    );

class _InvoicesSection extends StatefulWidget {
  const _InvoicesSection({required this.board});

  final CardBillsBoard board;

  @override
  State<_InvoicesSection> createState() => _InvoicesSectionState();
}

class _InvoicesSectionState extends State<_InvoicesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = NorteColors.of(context);
    final board = widget.board;
    // Por padrão: por cartão, as duas faturas pendentes de vencimento mais
    // próximo (a que vence primeiro e a seguinte) e as vencidas (nunca
    // escondidas). `pending` já vem ordenada por vencimento.
    final perCard = <String, int>{};
    final visible = _expanded
        ? board.pending
        : board.pending.where((v) {
            final n = perCard[v.cardName] = (perCard[v.cardName] ?? 0) + 1;
            return n <= 2 || v.isOverdue;
          }).toList();
    final hasMore = board.pending.length > visible.length;
    return CbSection(
      title: 'Faturas',
      children: [
        if (board.pending.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nenhuma fatura a pagar.'),
          ),
        for (final v in visible)
          InkWell(
            key: Key('cb-fatura-${v.id}'),
            onTap: () => _openInvoice(context, v),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${v.cardName} · vence ${ddMm(v.dueOn)}',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          v.isOverdue
                              ? 'vencida · venceu em ${ddMm(v.dueOn)}'
                              : v.isClosed
                              ? 'fechada · pendente'
                              : v.isCurrent
                              ? 'atual · pendente'
                              : 'pendente',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: v.isOverdue
                                ? colors.expense
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: v.isOverdue ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatBrl(v.value),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        key: Key('cb-pagar-${v.id}'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => showPaySheet(context, v),
                        child: const Text('Pagar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (hasMore || _expanded)
          Column(
            children: [
              const Divider(height: 16),
              TextButton.icon(
                key: const Key('cb-faturas-expandir'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                iconAlignment: IconAlignment.end,
                label: Text(
                  _expanded ? 'Recolher faturas' : 'Ver todas as faturas',
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _PaidSection extends StatelessWidget {
  const _PaidSection({required this.board});

  final CardBillsBoard board;

  @override
  Widget build(BuildContext context) => Card(
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('cb-pagas'),
        title: Text('Pagas (${board.paid.length})'),
        children: [
          for (final v in board.paid)
            ListTile(
              key: Key('cb-paga-${v.id}'),
              title: Text('${v.cardName} · venceu ${ddMm(v.dueOn)}'),
              subtitle: Text(
                'paga em ${v.payment!.paidOn.toBr()} · previsto '
                '${formatBrl(v.payment!.expectedAmount)} · pago '
                '${formatBrl(v.payment!.paidAmount)}',
              ),
              onTap: () => _openInvoice(context, v),
            ),
        ],
      ),
    ),
  );
}

class _CardsSection extends StatelessWidget {
  const _CardsSection({required this.data});

  final CardBillsData data;

  @override
  Widget build(BuildContext context) => CbSection(
    title: 'Cartões',
    trailing: IconButton(
      key: const Key('cb-novo-cartao'),
      tooltip: 'Novo cartão',
      icon: const Icon(Icons.add),
      onPressed: () => showCardForm(context),
    ),
    children: [
      for (final c in data.cards)
        CbValueRow(
          c.name,
          '',
          key: Key('cb-cartao-${c.id}'),
          subtitle: 'fecha dia ${c.closingDay} · vence dia ${c.dueDay}',
          onTap: () => showCardForm(context, existing: c),
        ),
    ],
  );
}

class _PurchasesSection extends ConsumerWidget {
  const _PurchasesSection({required this.data});

  final CardBillsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CbSection(
    title: 'Compras parceladas',
    children: [
      CbCollapsibleList<Purchase>(
        items: data.purchases,
        hint: 'Visualize as demais compras parceladas',
        moreKey: const Key('cb-compras-mais'),
        rowBuilder: (p) => CbValueRow(
          p.description,
          formatBrl(
            data.installmentsOf(p.id).fold(BigInt.zero, (a, i) => a + i.amount),
          ),
          key: Key('cb-compra-${p.id}'),
          subtitle:
              '${data.card(p.cardId)?.name ?? ''} · ${p.installmentCount}x · '
              '${p.purchasedOn.toBr()}',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PurchaseFormScreen(existing: p),
            ),
          ),
        ),
      ),
    ],
  );
}

class _SubscriptionsSection extends ConsumerWidget {
  const _SubscriptionsSection({required this.snapshot});

  final CardBillsSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = snapshot.data;
    return CbSection(
      title: 'Despesas recorrentes',
      children: [
        CbCollapsibleList<Subscription>(
          items: data.subscriptions,
          hint: 'Visualize as demais despesas recorrentes',
          moreKey: const Key('cb-assinaturas-mais'),
          rowBuilder: (s) => _tile(context, ref, data, s),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    CardBillsData data,
    Subscription s,
  ) {
    final card = data.card(s.cardId);
    String? starts;
    if (card != null) {
      final calendar = CardCalendar(card, data.invoices);
      if (s.startMonth.isAfter(
        currentInvoiceMonth(card, data, snapshot.today),
      )) {
        starts =
            'começa na fatura que vence em '
            '${calendar.dueOf(s.startMonth).toBr()}';
      }
    }
    return CbValueRow(
      s.description,
      '${formatBrl(s.monthlyAmount)}/mês',
      key: Key('cb-assinatura-${s.id}'),
      subtitle: [card?.name ?? '', ?starts].join(' · '),
      onTap: () => showSubscriptionForm(context, existing: s),
    );
  }
}
