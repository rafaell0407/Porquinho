import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/calendar_date.dart';
import '../../core/domain/money.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../categories/category_appearance.dart';
import '../categories/category_editor.dart';
import '../categories/category_models.dart';
import '../categories/category_picker.dart';
import '../categories/category_providers.dart';
import '../categories/category_service.dart';
import '../investments/investment_models.dart';
import '../investments/investment_providers.dart';
import '../periods/period_providers.dart';
import 'entry_models.dart';
import 'entry_providers.dart';
import 'entry_service.dart';

/// Cadastro e edição de receita ou despesa avulsa.
///
/// A data é do usuário (padrão: hoje) e pode ser passada ou futura (RN004,
/// RN008); ela define o período. Se o período não existir, o usuário confirma
/// a criação antes de salvar (RN002).
///
/// No modo investimento (D10) é o mesmo formulário da despesa, só com os campos
/// que se aplicam: valor e data (D2).
class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({required this.kind, this.existing, super.key})
    : existingInvestment = null,
      isInvestment = false;

  const EntryFormScreen.investment({this.existingInvestment, super.key})
    : kind = EntryKind.expense,
      existing = null,
      isInvestment = true;

  final EntryKind kind;
  final EntryRecord? existing;
  final bool isInvestment;
  final InvestmentRecord? existingInvestment;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late CalendarDate _date;
  CalendarDate? _dueOn;
  bool _alreadyPaid = false;
  bool _repeat = false;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  bool _variable = false;
  bool _alreadyReceived = false;
  late CalendarDate _paidOn;
  String? _categoryId;
  String? _subcategoryId;
  bool _saving = false;
  String? _error;

  /// Tipo mostrado no seletor; só muda em lançamento novo (o tipo de um
  /// lançamento existente não troca).
  late _FormType _type;

  EntryKind get _kind => _isIncome ? EntryKind.income : EntryKind.expense;
  bool get _isIncome => _type == _FormType.income;
  bool get _isInvestment => _type == _FormType.investment;
  bool get _editing =>
      widget.existing != null || widget.existingInvestment != null;

  /// Ocorrência de recorrência que está sendo editada (só esta, D8).
  bool get _occurrence => widget.existing?.isRecurring ?? false;

  /// Receita recorrente ainda não recebida: não tem data de recebimento.
  bool get _pendingIncome => widget.existing?.isPendingIncome ?? false;

  /// "Repetir" só em lançamento novo ou avulso (D8).
  bool get _canRepeat =>
      !_occurrence && !(widget.existingInvestment?.isRecurring ?? false);

  /// O valor pode ficar em branco: recorrência de valor variável (a
  /// ocorrência recebe o valor depois) ou ocorrência já existente.
  bool get _amountOptional => (_repeat && _variable) || _occurrence;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final inv = widget.existingInvestment;
    final today = ref.read(userClockProvider).today();
    _type = widget.isInvestment
        ? _FormType.investment
        : widget.kind == EntryKind.income
        ? _FormType.income
        : _FormType.expense;
    final amount = e?.amount ?? inv?.amount;
    _amount = TextEditingController(
      text: amount == null ? '' : formatBrl(amount).replaceFirst('R\$ ', ''),
    );
    _description = TextEditingController(text: e?.description ?? '');
    _date = e?.date ?? inv?.date ?? today;
    _dueOn = e?.dueOn;
    _paidOn = today;
    _categoryId = e?.categoryId;
    _subcategoryId = e?.subcategoryId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Abre o seletor de categoria; "Nova categoria" leva ao editor e a criada
  /// já fica selecionada. Cancelar ou falhar mantém a escolha anterior.
  Future<void> _chooseCategory(CategoryData? data) async {
    if (data == null) return;
    final pick = await showCategoryPicker(
      context,
      data: data,
      kind: CategoryKind.fromDb(_kind.categoryKind),
      selectedCategoryId: _categoryId,
      selectedSubcategoryId: _subcategoryId,
    );
    if (!mounted) return;
    switch (pick) {
      case PickedNone():
        setState(() {
          _categoryId = null;
          _subcategoryId = null;
        });
      case PickedCategory(:final categoryId, :final subcategoryId):
        setState(() {
          _categoryId = categoryId;
          _subcategoryId = subcategoryId;
        });
      case PickedCreate():
        await _createCategory();
      case null:
        break;
    }
  }

  Future<void> _createCategory() async {
    final messenger = ScaffoldMessenger.of(context);
    final draft = await showCategoryEditor(
      context,
      title: _isIncome
          ? 'Nova categoria de receita'
          : 'Nova categoria de despesa',
    );
    if (draft == null || !mounted) return;
    try {
      final service = await ref.read(categoryServiceProvider.future);
      final id = await service.createCategory(
        CategoryKind.fromDb(_kind.categoryKind),
        draft.name,
        iconKey: draft.iconKey,
        colorKey: draft.colorKey,
      );
      ref.invalidate(categoryDataProvider);
      if (!mounted) return;
      setState(() {
        _categoryId = id;
        _subcategoryId = null;
      });
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<CalendarDate?> _pick(CalendarDate initial) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    return picked == null
        ? null
        : CalendarDate(picked.year, picked.month, picked.day);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final blocked = await ref.read(writeGateProvider).blockedReason();
    if (blocked != null) {
      setState(() => _error = blocked);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    if (_isInvestment) {
      await _saveInvestment();
      return;
    }
    final draft = EntryDraft(
      kind: _kind,
      amount: _amount.text.trim().isEmpty
          ? null
          : parseBrlToCentavos(_amount.text),
      date: _date,
      description: _description.text,
      categoryId: _categoryId,
      subcategoryId: _subcategoryId,
      dueOn: _isIncome ? null : _dueOn,
    );
    try {
      final service = await ref.read(entryServiceProvider.future);
      await _write(service, draft);
      refreshFinanceData(ref);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _saveInvestment() async {
    try {
      final service = await ref.read(investmentServiceProvider.future);
      final draft = InvestmentDraft(
        amount: parseBrlToCentavos(_amount.text),
        date: _date,
      );
      final repeat = _repeat && _canRepeat ? _frequency : null;
      if (_editing) {
        await service.update(widget.existingInvestment!, draft, repeat: repeat);
      } else {
        await service.create(draft, repeat: repeat);
      }
      refreshFinanceData(ref);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _write(EntryService service, EntryDraft draft) async {
    final repeat = _repeat && _canRepeat
        ? RepeatChoice(frequency: _frequency, variableValue: _variable)
        : null;
    if (_editing) {
      await service.update(widget.existing!, draft, repeat: repeat);
    } else {
      await service.create(
        draft,
        alreadyPaid: !_isIncome && _alreadyPaid,
        paidOn: _paidOn,
        repeat: repeat,
        alreadyReceived: _isIncome && repeat != null && _alreadyReceived,
        receivedOn: _paidOn,
      );
    }
  }

  /// Troca o tipo de um lançamento novo. Campos que não existem no outro tipo
  /// (categoria, vencimento, "já paga/recebi", valor variável) voltam ao
  /// padrão; valor, data e "Repetir" ficam.
  void _selectType(_FormType type) {
    if (type == _type || _editing) return;
    setState(() {
      _type = type;
      _categoryId = null;
      _subcategoryId = null;
      _dueOn = null;
      _alreadyPaid = false;
      _alreadyReceived = false;
      if (type == _FormType.investment) _variable = false;
      _error = null;
    });
  }

  /// "Repetir" (D8): o lançamento vira a primeira ocorrência; as próximas
  /// seguem o dia dele, todo mês (RN038).
  Future<void> _chooseRepeat() async {
    final choice = await showModalBottomSheet<(RecurrenceFrequency?,)>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('repetir-nao'),
              title: const Text('Não se repete'),
              trailing: _repeat ? null : const Icon(Icons.check),
              onTap: () => Navigator.pop(sheet, (null,)),
            ),
            for (final f in RecurrenceFrequency.selectable)
              ListTile(
                key: Key('repetir-${f.dbValue}'),
                title: Text(f.label),
                trailing: _repeat && _frequency == f
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheet, (f,)),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == null) return; // fechou sem escolher: nada muda
    setState(() {
      final frequency = choice.$1;
      _repeat = frequency != null;
      if (frequency != null) _frequency = frequency;
    });
  }

  /// Explicação curta do tipo escolhido, com as regras vigentes (RN).
  List<String> _notes() {
    final lines = <String>[];
    if (_isInvestment) {
      lines.add(
        'Investimento é descontado do dinheiro livre do período da data '
        'informada.',
      );
    } else if (_isIncome) {
      lines.add(
        _repeat
            ? 'Receita recorrente nasce pendente e só entra no dinheiro livre '
                  'quando o recebimento é confirmado.'
            : 'Receita entra no período da data de recebimento.',
      );
    } else {
      lines.add(
        _repeat
            ? 'Despesa recorrente entra no período quando a ocorrência é '
                  'gerada (se o valor muda, depois de informado).'
            : 'Despesa avulsa entra no período assim que é salva.',
      );
    }
    if (_pendingIncome) {
      lines.add(
        'A data de recebimento é informada ao confirmar o recebimento.',
      );
    }
    if (_repeat && _canRepeat) {
      lines.add(
        _date.day > 28
            ? 'Repete todo dia ${_date.day}. Em mês sem esse dia, no último '
                  'dia útil do mês.'
            : 'Repete todo dia ${_date.day}.',
      );
      if (_isInvestment) {
        lines.add(
          'Cada ocorrência nasce com este valor; você pode mudar o valor de um '
          'mês depois.',
        );
      }
    }
    return lines;
  }

  String get _title => _isInvestment
      ? (_editing ? 'Editar investimento' : 'Novo investimento')
      : _editing
      ? (_isIncome ? 'Editar receita' : 'Editar despesa')
      : (_isIncome ? 'Nova receita' : 'Nova despesa');

  String get _saveLabel => _saving
      ? 'Salvando…'
      : _isInvestment
      ? 'Salvar investimento'
      : _isIncome
      ? 'Salvar receita'
      : 'Salvar despesa';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cats = ref.watch(categoryDataProvider).value;
    final chosen = _categoryId == null
        ? null
        : cats?.categories.where((c) => c.id == _categoryId).firstOrNull;
    final chosenSub = _subcategoryId == null
        ? null
        : cats?.subcategories.where((s) => s.id == _subcategoryId).firstOrNull;
    final placeholder = _valueStyle(
      theme,
    ).copyWith(color: scheme.onSurfaceVariant);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _Header(title: _title),
              if (!_editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _TypeSelector(
                    selected: _type,
                    onSelected: _selectType,
                  ),
                ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  children: [
                    TextFormField(
                      key: const Key('campo-valor'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        prefixText: 'R\$ ',
                        prefixStyle: theme.textTheme.displaySmall?.copyWith(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                        ),
                        hintText: '0,00',
                        hintStyle: theme.textTheme.displaySmall?.copyWith(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      validator: (v) {
                        if (_amountOptional && (v ?? '').trim().isEmpty) {
                          return null;
                        }
                        try {
                          parseBrlToCentavos(v ?? '');
                          return null;
                        } on MoneyFormatException catch (e) {
                          return e.message;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Divider(color: scheme.outlineVariant),
                    if (_pendingIncome)
                      _FieldRow(
                        key: const Key('campo-data-prevista'),
                        label: 'Recebimento previsto',
                        value: Text(_date.toBr(), style: _valueStyle(theme)),
                      )
                    else
                      _FieldRow(
                        key: const Key('campo-data'),
                        label: _isInvestment
                            ? 'Data do investimento'
                            : _isIncome
                            ? 'Data do recebimento'
                            : 'Data da despesa',
                        value: Text(_date.toBr(), style: _valueStyle(theme)),
                        showChevron: true,
                        onTap: () async {
                          final picked = await _pick(_date);
                          if (picked != null) setState(() => _date = picked);
                        },
                      ),
                    if (!_isInvestment) ...[
                      _FieldRow(
                        label: 'Descrição',
                        value: TextFormField(
                          key: const Key('campo-descricao'),
                          controller: _description,
                          maxLength: EntryService.maxDescriptionLength,
                          textAlign: TextAlign.end,
                          style: _valueStyle(theme),
                          decoration: InputDecoration(
                            hintText: 'Opcional',
                            hintStyle: placeholder,
                            counterText: '',
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      _FieldRow(
                        key: const Key('campo-categoria'),
                        label: 'Categoria',
                        value: chosen == null
                            ? Text('Escolher', style: placeholder)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CategoryBadge(
                                    iconKey: chosen.iconKey,
                                    colorKey: chosen.colorKey,
                                    size: 28,
                                    filled: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      [
                                        chosen.isActive
                                            ? chosen.name
                                            : '${chosen.name} (desativada)',
                                        ?chosenSub?.name,
                                      ].join(' › '),
                                      style: _valueStyle(theme),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                        showChevron: true,
                        onTap: () => _chooseCategory(cats),
                      ),
                      if (!_isIncome) ...[
                        _FieldRow(
                          key: const Key('campo-vencimento'),
                          label: 'Vencimento',
                          value: _dueOn == null
                              ? Text('Opcional', style: placeholder)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _dueOn!.toBr(),
                                      style: _valueStyle(theme),
                                    ),
                                    IconButton(
                                      tooltip: 'Remover vencimento',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () =>
                                          setState(() => _dueOn = null),
                                    ),
                                  ],
                                ),
                          showChevron: _dueOn == null,
                          onTap: () async {
                            final picked = await _pick(_dueOn ?? _date);
                            if (picked != null) setState(() => _dueOn = picked);
                          },
                        ),
                        if (!_editing)
                          _FieldRow(
                            key: const Key('ja-paga'),
                            label: 'Já está paga',
                            value: Text(
                              _alreadyPaid
                                  ? 'Paga em ${_paidOn.toBr()}'
                                  : 'Nasce como pendente',
                              style: placeholder,
                            ),
                            trailing: Switch(
                              value: _alreadyPaid,
                              onChanged: (v) =>
                                  setState(() => _alreadyPaid = v),
                            ),
                            onTap: () =>
                                setState(() => _alreadyPaid = !_alreadyPaid),
                          ),
                      ],
                    ],
                    if (_canRepeat) ...[
                      _FieldRow(
                        key: const Key('repetir'),
                        label: 'Repetir',
                        value: Text(
                          _repeat ? _frequency.label : 'Não se repete',
                          key: _repeat ? const Key('frequencia') : null,
                          style: _valueStyle(theme),
                        ),
                        showChevron: true,
                        onTap: _chooseRepeat,
                      ),
                      if (_repeat && !_isInvestment)
                        _FieldRow(
                          key: const Key('valor-variavel'),
                          label: 'O valor muda todo mês',
                          value: Text(
                            _variable ? 'Informe o valor depois' : 'Valor fixo',
                            style: placeholder,
                          ),
                          trailing: Switch(
                            value: _variable,
                            onChanged: (v) => setState(() => _variable = v),
                          ),
                          onTap: () => setState(() => _variable = !_variable),
                        ),
                      if (_repeat && _isIncome)
                        _FieldRow(
                          key: const Key('ja-recebi'),
                          label: 'Já recebi',
                          value: Text(
                            _alreadyReceived
                                ? 'Recebida em ${_paidOn.toBr()}'
                                : 'Nasce pendente',
                            style: placeholder,
                          ),
                          trailing: Switch(
                            value: _alreadyReceived,
                            onChanged: (v) =>
                                setState(() => _alreadyReceived = v),
                          ),
                          onTap: () => setState(
                            () => _alreadyReceived = !_alreadyReceived,
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    for (final line in _notes())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          line,
                          key: line == _notes().first
                              ? const Key('texto-explicativo')
                              : null,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          key: const Key('erro-formulario'),
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('salvar-lancamento'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(_saveLabel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _valueStyle(ThemeData theme) => TextStyle(
    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: theme.colorScheme.onSurface,
  );
}

enum _FormType { expense, income, investment }

/// Cabeçalho compacto: título centralizado e botão circular de fechar.
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 72),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 20,
            child: Material(
              color: scheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: IconButton(
                key: const Key('fechar-formulario'),
                tooltip: 'Fechar',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra em pílula com os três tipos de lançamento.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onSelected});

  final _FormType selected;
  final ValueChanged<_FormType> onSelected;

  static const _labels = {
    _FormType.expense: 'Despesa',
    _FormType.income: 'Receita',
    _FormType.investment: 'Investimento',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          for (final type in _FormType.values)
            Expanded(
              child: Semantics(
                selected: type == selected,
                button: true,
                child: GestureDetector(
                  key: Key('tipo-${type.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: type == selected
                          ? scheme.primaryContainer
                          : Colors.transparent,
                      shape: const StadiumBorder(),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _labels[type]!,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: type == selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Linha do formulário: nome à esquerda, valor ou ação à direita, divisor
/// discreto embaixo.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    this.onTap,
    this.showChevron = false,
    this.trailing,
    super.key,
  });

  final String label;
  final Widget value;
  final VoidCallback? onTap;
  final bool showChevron;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: value),
            ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 20, color: scheme.onSurfaceVariant),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
