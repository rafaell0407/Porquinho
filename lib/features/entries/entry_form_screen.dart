import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/calendar_date.dart';
import '../../core/domain/money.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../categories/category_models.dart';
import '../categories/category_providers.dart';
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

  bool get _isIncome => widget.kind == EntryKind.income;
  bool get _isInvestment => widget.isInvestment;
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
      kind: widget.kind,
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
      await _confirmingPeriods(
        service.createMissingPeriods,
        () => _editing
            ? service.update(widget.existingInvestment!, draft, repeat: repeat)
            : service.create(draft, repeat: repeat),
      );
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

  /// Tenta gravar; se o período não existe, pergunta antes de criá-lo (RN002).
  Future<void> _confirmingPeriods(
    Future<void> Function(CalendarDate) createPeriods,
    Future<void> Function() attempt,
  ) async {
    try {
      await attempt();
    } on PeriodMissingException catch (missing) {
      if (!mounted) return;
      final ok = await _askCreatePeriods(missing);
      if (ok != true) {
        throw const ChangeRejectedException('Nada foi salvo.');
      }
      await createPeriods(missing.date);
      await attempt();
    }
  }

  Future<bool?> _askCreatePeriods(PeriodMissingException missing) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Período ainda não existe'),
          content: Text(missing.plan.question),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              key: const Key('confirmar-periodos'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Criar e salvar'),
            ),
          ],
        ),
      );

  Future<void> _write(EntryService service, EntryDraft draft) async {
    final repeat = _repeat && _canRepeat
        ? RepeatChoice(frequency: _frequency, variableValue: _variable)
        : null;
    Future<void> attempt() async {
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

    await _confirmingPeriods(service.createMissingPeriods, attempt);
  }

  /// "Repetir" (D8): o lançamento vira a primeira ocorrência; as próximas
  /// seguem o dia dele (todo mês) ou o início de cada período.
  List<Widget> _repeatSection() => [
    SwitchListTile(
      key: const Key('repetir'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Repetir'),
      subtitle: Text(
        _repeat
            ? 'Este ${_isInvestment ? 'investimento' : 'lançamento'} é o '
                  'primeiro; os próximos são criados automaticamente'
            : (_isInvestment ? 'Investimento único' : 'Lançamento único'),
      ),
      value: _repeat,
      onChanged: (v) => setState(() => _repeat = v),
    ),
    if (_repeat) ...[
      SegmentedButton<RecurrenceFrequency>(
        key: const Key('frequencia'),
        segments: [
          for (final f in RecurrenceFrequency.values)
            ButtonSegment(value: f, label: Text(f.label)),
        ],
        selected: {_frequency},
        onSelectionChanged: (s) => setState(() => _frequency = s.first),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          _frequency == RecurrenceFrequency.monthly
              ? 'Repete todo dia ${_date.day} (em mês curto, no último dia).'
              : 'A ocorrência fica no início do período que contém a data '
                    'informada.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      if (_isInvestment)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Cada ocorrência nasce com este valor e entra no dinheiro livre do período '
            'da sua data. Você pode mudar o valor de um mês depois.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        )
      else
        SwitchListTile(
          key: const Key('valor-variavel'),
          contentPadding: EdgeInsets.zero,
          title: const Text('O valor muda todo mês'),
          subtitle: const Text('Informe o valor de cada ocorrência depois'),
          value: _variable,
          onChanged: (v) => setState(() => _variable = v),
        ),
      if (_isIncome)
        SwitchListTile(
          key: const Key('ja-recebi'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Já recebi'),
          subtitle: Text(
            _alreadyReceived
                ? 'Recebida em ${_paidOn.toBr()}'
                : 'Nasce pendente e só entra no dinheiro livre quando confirmada',
          ),
          value: _alreadyReceived,
          onChanged: (v) => setState(() => _alreadyReceived = v),
        ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoryDataProvider).value;
    final categories = cats == null
        ? <CategoryRecord>[]
        : cats.categories
              .where(
                (c) =>
                    c.kind.dbValue == widget.kind.categoryKind &&
                    (c.isActive || c.id == widget.existing?.categoryId),
              )
              .toList();
    final subs = (cats == null || _categoryId == null)
        ? <SubcategoryRecord>[]
        : cats.subcategories
              .where(
                (s) =>
                    s.categoryId == _categoryId &&
                    (s.isActive || s.id == widget.existing?.subcategoryId),
              )
              .toList();
    final title = _isInvestment
        ? (_editing ? 'Editar investimento' : 'Novo investimento')
        : _editing
        ? (_isIncome ? 'Editar receita' : 'Editar despesa')
        : (_isIncome ? 'Nova receita' : 'Nova despesa');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('campo-valor'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _isInvestment ? 'Valor investido' : 'Valor',
                prefixText: 'R\$ ',
                hintText: '0,00',
              ),
              validator: (v) {
                if (_amountOptional && (v ?? '').trim().isEmpty) return null;
                try {
                  parseBrlToCentavos(v ?? '');
                  return null;
                } on MoneyFormatException catch (e) {
                  return e.message;
                }
              },
            ),
            const SizedBox(height: 12),
            if (_pendingIncome)
              ListTile(
                key: const Key('campo-data-prevista'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Recebimento previsto'),
                subtitle: Text(
                  '${_date.toBr()} (a data de recebimento é informada '
                  'ao confirmar)',
                ),
              )
            else
              ListTile(
                key: const Key('campo-data'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _isInvestment
                      ? 'Data do investimento'
                      : _isIncome
                      ? 'Data do recebimento'
                      : 'Data da despesa',
                ),
                subtitle: Text(_date.toBr()),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await _pick(_date);
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            if (!_isInvestment) ...[
              TextFormField(
                key: const Key('campo-descricao'),
                controller: _description,
                maxLength: EntryService.maxDescriptionLength,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
              ),
              DropdownButtonFormField<String?>(
                key: const Key('campo-categoria'),
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem categoria'),
                  ),
                  for (final c in categories)
                    DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(
                        c.isActive ? c.name : '${c.name} (desativada)',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _categoryId = v;
                  _subcategoryId = null;
                }),
              ),
              if (subs.isNotEmpty)
                DropdownButtonFormField<String?>(
                  key: const Key('campo-subcategoria'),
                  initialValue: _subcategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Subcategoria (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Nenhuma'),
                    ),
                    for (final s in subs)
                      DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _subcategoryId = v),
                ),
              if (!_isIncome) ...[
                ListTile(
                  key: const Key('campo-vencimento'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vencimento (opcional)'),
                  subtitle: Text(_dueOn?.toBr() ?? 'Sem vencimento'),
                  trailing: _dueOn == null
                      ? const Icon(Icons.event)
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _dueOn = null),
                        ),
                  onTap: () async {
                    final picked = await _pick(_dueOn ?? _date);
                    if (picked != null) setState(() => _dueOn = picked);
                  },
                ),
                if (!_editing)
                  SwitchListTile(
                    key: const Key('ja-paga'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Já está paga'),
                    subtitle: _alreadyPaid
                        ? Text('Paga em ${_paidOn.toBr()}')
                        : const Text('Nasce como pendente'),
                    value: _alreadyPaid,
                    onChanged: (v) => setState(() => _alreadyPaid = v),
                  ),
              ],
            ],
            if (_canRepeat) ..._repeatSection(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('erro-formulario'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('salvar-lancamento'),
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? 'Salvando…'
                    : (_isInvestment ? 'Salvar investimento' : 'Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
