import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';
import '../../../shared/main_shell.dart' show NorteNavBar;
import '../../periods/period_providers.dart' show userClockProvider;
import '../../tools/registry/tool_registry.dart' show cashOrInstallmentsTool;
import '../../tools/widgets/tool_explanation.dart' show showToolInfoSheet;
import '../../transactions/transactions_screen.dart' show showNewEntryChooser;
import '../application/cash_or_installments_providers.dart';
import '../cash_or_installments_texts.dart';
import '../data/reference_rates.dart';
import '../domain/cash_or_installments_engine.dart';
import '../domain/purchase_input.dart';
import '../widgets/form_widgets.dart';
import '../widgets/result_widgets.dart';

/// Ferramentas → Calculadora à vista ou parcelado (rota
/// `/a-vista-ou-parcelado`; spec `docs/ferramentas/a_vista_ou_parcelado.md`).
/// Só simula: não grava a simulação e não cria lançamentos.
class CashOrInstallmentsScreen extends ConsumerStatefulWidget {
  const CashOrInstallmentsScreen({super.key});

  static const route = '/a-vista-ou-parcelado';

  @override
  ConsumerState<CashOrInstallmentsScreen> createState() =>
      _CashOrInstallmentsScreenState();
}

/// "13,65" (para o campo da taxa).
String _rateFieldText(int e2) =>
    '${e2 ~/ 100},${(e2 % 100).toString().padLeft(2, '0')}';

class _CashOrInstallmentsScreenState
    extends ConsumerState<CashOrInstallmentsScreen> {
  final _cashValue = TextEditingController();
  final _price = TextEditingController();
  final _discount = TextEditingController();
  final _total = TextEditingController();
  final _installment = TextEditingController();
  final _count = TextEditingController();
  final _dueDay = TextEditingController();
  final _percent = TextEditingController(text: '100');
  final _rate = TextEditingController();
  final _resultKey = GlobalKey();

  CashPriceMode _cashMode = CashPriceMode.value;
  InstallmentMode _installmentMode = InstallmentMode.total;
  FirstBill _bill = FirstBill.next;
  InvestmentProduct _product = InvestmentProduct.cdb;
  bool _totalTouched = false;
  bool _editingRate = false;
  Map<PurchaseField, String> _errors = const {};

  /// Data da taxa do Banco Central usada no último cálculo (`null` =
  /// digitada).
  CalendarDate? _resultRateDate;

  List<TextEditingController> get _controllers => [
    _cashValue,
    _price,
    _discount,
    _total,
    _installment,
    _count,
    _dueDay,
    _percent,
    _rate,
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  RateIndex get _rateIndex =>
      _product == InvestmentProduct.cdb ? RateIndex.cdi : RateIndex.selic;

  T? _try<T>(T Function() f) {
    try {
      return f();
    } on PurchaseInputException {
      return null;
    }
  }

  int? get _countValue => _try(
    () => parsePurchaseInt(
      _count.text,
      min: 1,
      max: PurchaseLimits.maxInstallments,
    ),
  );

  int? get _dueDayValue =>
      _try(() => parsePurchaseInt(_dueDay.text, min: 1, max: 31));

  void _refresh() => setState(() {});

  void _onPriceChanged(String text) {
    if (_cashMode == CashPriceMode.discount && !_totalTouched) {
      _total.text = text;
    }
    _refresh();
  }

  void _calculate(RateLookup? lookup) {
    FocusScope.of(context).unfocus();
    final useFetched = !_editingRate && lookup?.rate != null;
    final rateText = useFetched
        ? _rateFieldText(lookup!.rate!.annualRateE2)
        : _rate.text;
    final today = ref.read(userClockProvider).today();
    final v = validatePurchase(
      PurchaseForm(
        cashMode: _cashMode,
        installmentMode: _installmentMode,
        bill: _bill,
        product: _product,
        cashValue: _cashValue.text,
        price: _price.text,
        discount: _discount.text,
        total: _total.text,
        installmentValue: _installment.text,
        count: _count.text,
        dueDay: _dueDay.text,
        percent: _percent.text,
        rate: rateText,
      ),
      today,
    );
    setState(() {
      _errors = v.errors;
      _resultRateDate = useFetched ? lookup!.rate!.date : null;
    });
    final controller = ref.read(cashOrInstallmentsProvider.notifier);
    if (v.input == null) {
      controller.clear();
      return;
    }
    controller.calculate(v.input!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _clear() {
    FocusScope.of(context).unfocus();
    for (final c in _controllers) {
      c.clear();
    }
    _percent.text = '100';
    setState(() {
      _cashMode = CashPriceMode.value;
      _installmentMode = InstallmentMode.total;
      _bill = FirstBill.next;
      _product = InvestmentProduct.cdb;
      _totalTouched = false;
      _editingRate = false;
      _errors = const {};
    });
    ref.read(cashOrInstallmentsProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(userClockProvider).today();
    // Busca as duas taxas ao abrir (a troca de produto não espera a rede).
    final cdi = ref.watch(referenceRateProvider(RateIndex.cdi));
    final selic = ref.watch(referenceRateProvider(RateIndex.selic));
    final lookup = _rateIndex == RateIndex.cdi ? cdi : selic;
    final result = ref.watch(cashOrInstallmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(CashOrInstallmentsTexts.title),
        actions: [
          IconButton(
            key: const Key('avp-info'),
            tooltip: 'Sobre a calculadora',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showToolInfoSheet(context, cashOrInstallmentsTool),
          ),
        ],
      ),
      bottomNavigationBar: NorteNavBar(
        currentIndex: 1,
        onTab: (i) => context.go(NorteNavBar.tabRoutes[i]),
        onAdd: () => showNewEntryChooser(context, ref),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AvpWarningBanner(),
                const SizedBox(height: 16),
                _purchaseSection(),
                const SizedBox(height: 16),
                _cardSection(today),
                const SizedBox(height: 16),
                _moneySection(lookup, today),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('avp-calcular'),
                  onPressed: () => _calculate(lookup.value),
                  child: const Text('Calcular'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const Key('avp-limpar'),
                  onPressed: _clear,
                  child: const Text('Limpar'),
                ),
                if (result != null) ...[
                  const SizedBox(height: 16),
                  Column(
                    key: _resultKey,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VerdictCard(result: result),
                      const SizedBox(height: 12),
                      AssumptionsBlock(
                        result: result,
                        rateDate: _resultRateDate,
                      ),
                      const SizedBox(height: 12),
                      SideBySideTable(result: result),
                      const SizedBox(height: 12),
                      BalanceChart(result: result),
                      const SizedBox(height: 12),
                      InstallmentsTable(result: result),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _purchaseSection() {
    final price = _try(() => parsePurchaseMoney(_price.text));
    final discount = _discount.text.trim().isEmpty
        ? 0
        : _try(
            () => parsePurchasePercent(
              _discount.text,
              maxE2: PurchaseLimits.maxDiscountE2,
            ),
          );
    final computed = price != null && discount != null
        ? cashPriceFromDiscount(price, discount)
        : null;
    return AvpSection(
      title: 'A compra',
      children: [
        AvpChoice<CashPriceMode>(
          keyPrefix: 'avp-modo-avista',
          value: _cashMode,
          options: CashPriceMode.values,
          label: (m) => switch (m) {
            CashPriceMode.value => 'Valor à vista',
            CashPriceMode.discount => 'Preço + desconto',
          },
          onChanged: (m) => setState(() {
            _cashMode = m;
            _errors = const {};
          }),
        ),
        const SizedBox(height: 14),
        if (_cashMode == CashPriceMode.value)
          AvpField(
            fieldKey: const Key('avp-campo-valor-a-vista'),
            controller: _cashValue,
            label: 'Valor à vista',
            prefix: 'R\$ ',
            hint: '0,00',
            error: _errors[PurchaseField.cashValue],
          )
        else ...[
          AvpPair(
            first: AvpField(
              fieldKey: const Key('avp-campo-preco'),
              controller: _price,
              label: 'Preço original',
              prefix: 'R\$ ',
              hint: '0,00',
              error: _errors[PurchaseField.price],
              onChanged: _onPriceChanged,
            ),
            second: AvpField(
              fieldKey: const Key('avp-campo-desconto'),
              controller: _discount,
              label: 'Desconto',
              suffix: '%',
              hint: '0',
              error: _errors[PurchaseField.discount],
              onChanged: (_) => _refresh(),
            ),
          ),
          if (computed != null && computed > BigInt.zero) ...[
            const SizedBox(height: 12),
            AvpInfoBox(
              key: const Key('avp-valor-calculado'),
              highlight: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Valor à vista: '),
                        TextSpan(
                          text: formatBrl(computed),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Confira o valor informado pela loja.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _cardSection(CalendarDate today) {
    final count = _countValue;
    final dueDay = _dueDayValue;
    String? preview;
    if (count != null) {
      final List<BigInt>? values = _installmentMode == InstallmentMode.total
          ? switch (_try(() => parsePurchaseMoney(_total.text))) {
              final t? when t >= BigInt.from(count) => splitInstallments(
                t,
                count,
              ),
              _ => null,
            }
          : switch (_try(() => parsePurchaseMoney(_installment.text))) {
              final p? => List.filled(count, p),
              _ => null,
            };
      if (values != null) {
        preview = values.first == values.last
            ? '${count}x de ${formatBrl(values.first)}'
            : '1ª de ${formatBrl(values.first)} + ${count - 1}x de '
                  '${formatBrl(values.last)}';
        if (_installmentMode == InstallmentMode.perInstallment) {
          preview +=
              ' · total ${formatBrl(values.fold(BigInt.zero, (a, b) => a + b))}';
        }
      }
    }
    final next = dueDay == null ? null : nextBillDueDate(today, dueDay);
    final following = dueDay == null
        ? null
        : installmentDueDates(today, dueDay, FirstBill.following, 1).first;
    final dates = dueDay != null && count != null
        ? installmentDueDates(today, dueDay, _bill, count)
        : null;

    return AvpSection(
      title: 'No cartão',
      children: [
        AvpChoice<InstallmentMode>(
          keyPrefix: 'avp-modo-parcelas',
          value: _installmentMode,
          options: InstallmentMode.values,
          label: (m) => switch (m) {
            InstallmentMode.total => 'Total parcelado',
            InstallmentMode.perInstallment => 'Valor da parcela',
          },
          onChanged: (m) => setState(() {
            _installmentMode = m;
            _errors = const {};
          }),
        ),
        const SizedBox(height: 14),
        AvpPair(
          first: _installmentMode == InstallmentMode.total
              ? AvpField(
                  fieldKey: const Key('avp-campo-total'),
                  controller: _total,
                  label: 'Total parcelado',
                  prefix: 'R\$ ',
                  hint: '0,00',
                  error: _errors[PurchaseField.total],
                  onChanged: (_) {
                    _totalTouched = true;
                    _refresh();
                  },
                )
              : AvpField(
                  fieldKey: const Key('avp-campo-parcela'),
                  controller: _installment,
                  label: 'Valor da parcela',
                  prefix: 'R\$ ',
                  hint: '0,00',
                  error: _errors[PurchaseField.installmentValue],
                  onChanged: (_) => _refresh(),
                ),
          second: AvpField(
            fieldKey: const Key('avp-campo-parcelas'),
            controller: _count,
            label: 'Parcelas (1 a 24)',
            decimal: false,
            error: _errors[PurchaseField.count],
            onChanged: (_) => _refresh(),
          ),
        ),
        if (preview != null) ...[
          const SizedBox(height: 10),
          Text(
            preview,
            key: const Key('avp-resumo-parcelas'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const Divider(height: 28),
        AvpField(
          fieldKey: const Key('avp-campo-vencimento'),
          controller: _dueDay,
          label: 'Dia de vencimento do cartão',
          hint: '1 a 31',
          decimal: false,
          error: _errors[PurchaseField.dueDay],
          onChanged: (_) => _refresh(),
        ),
        const SizedBox(height: 14),
        Text(
          'Em qual fatura vem a 1ª parcela?',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        AvpBillOption(
          key: const Key('avp-fatura-proxima'),
          title: 'Próxima fatura',
          subtitle: next == null ? null : 'vence em ${next.toBr()}',
          selected: _bill == FirstBill.next,
          onTap: () => setState(() => _bill = FirstBill.next),
        ),
        const SizedBox(height: 8),
        AvpBillOption(
          key: const Key('avp-fatura-seguinte'),
          title: 'Fatura seguinte',
          subtitle: following == null ? null : 'vence em ${following.toBr()}',
          selected: _bill == FirstBill.following,
          onTap: () => setState(() => _bill = FirstBill.following),
        ),
        const SizedBox(height: 8),
        const AvpHint(CashOrInstallmentsTexts.billHint),
        if (dates != null) ...[
          const SizedBox(height: 12),
          AvpInfoBox(
            key: const Key('avp-vencimentos'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dates.length == 1
                        ? 'Vencimento: ${dates.first.toBr()}'
                        : 'Vencimentos: ${dates.first.toBr()} … '
                              '${dates.last.toBr()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  key: const Key('avp-ver-vencimentos'),
                  onPressed: () => _showDueDates(dates),
                  child: const Text('ver todos'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showDueDates(List<CalendarDate> dates) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheet) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.8,
          ),
          child: ListView(
            key: const Key('avp-vencimentos-lista'),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                'Vencimentos das parcelas',
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final (i, d) in dates.indexed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text('${i + 1}ª'),
                  title: Text('${d.toBr()} (${weekdayName(d)})'),
                ),
            ],
          ),
        ),
      );

  Widget _moneySection(AsyncValue<RateLookup> lookup, CalendarDate today) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final index = _rateIndex;
    final data = lookup.value;
    final fetched = data?.rate;
    final showField = _editingRate || (!lookup.isLoading && fetched == null);

    Widget rateRow;
    if (lookup.isLoading && !_editingRate) {
      rateRow = Row(
        key: const Key('avp-taxa-carregando'),
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errors[PurchaseField.rate] == null
                  ? 'Buscando o ${index.label} no Banco Central…'
                  : 'Aguarde a taxa do Banco Central ou toque em Calcular '
                        'de novo.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      );
    } else if (showField) {
      rateRow = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fetched == null) ...[
            Text(
              'Não foi possível buscar o ${index.label} no Banco Central. '
              'Informe a taxa ao ano.',
              key: const Key('avp-taxa-falhou'),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
            const SizedBox(height: 10),
          ],
          AvpField(
            fieldKey: const Key('avp-campo-taxa'),
            controller: _rate,
            label: '${index.label} ao ano',
            suffix: '%',
            hint: '0,00',
            error: _errors[PurchaseField.rate],
          ),
          const SizedBox(height: 6),
          const AvpHint('De 0 a 100% ao ano. Vale só para esta simulação.'),
          if (fetched != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('avp-taxa-usar-bc'),
                onPressed: () => setState(() => _editingRate = false),
                child: const Text('Usar a taxa do Banco Central'),
              ),
            ),
        ],
      );
    } else {
      final stale = data!.isStale(today);
      rateRow = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index.label} ${formatPercentE2(fetched!.annualRateE2)} '
                      'ao ano',
                      key: const Key('avp-taxa-valor'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Taxa de ${fetched.date.toBr()} · Banco Central',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                key: const Key('avp-taxa-editar'),
                onPressed: () => setState(() {
                  _editingRate = true;
                  _rate.text = _rateFieldText(fetched.annualRateE2);
                }),
                child: const Text('Editar'),
              ),
            ],
          ),
          if (data.fetchFailed || stale) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (data.fetchFailed)
                  'Não foi possível atualizar agora; esta é a última taxa '
                      'guardada.',
                if (stale) 'Taxa com mais de 30 dias. Confira ou edite.',
              ].join(' '),
              key: const Key('avp-taxa-aviso'),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      );
    }

    return AvpSection(
      title: 'Onde o dinheiro fica',
      children: [
        AvpChoice<InvestmentProduct>(
          keyPrefix: 'avp-produto',
          value: _product,
          options: InvestmentProduct.values,
          label: (p) => p.label,
          onChanged: (p) => setState(() {
            _product = p;
            _editingRate = false;
            _rate.clear();
            _errors = const {};
          }),
        ),
        const SizedBox(height: 14),
        if (_product == InvestmentProduct.cdb) ...[
          AvpField(
            fieldKey: const Key('avp-campo-cdi'),
            controller: _percent,
            label: '% do CDI',
            suffix: '%',
            error: _errors[PurchaseField.percent],
          ),
          const SizedBox(height: 8),
          const AvpHint(CashOrInstallmentsTexts.cdbRisk),
        ] else
          const AvpHint(CashOrInstallmentsTexts.treasuryNote),
        const Divider(height: 28),
        rateRow,
      ],
    );
  }
}
