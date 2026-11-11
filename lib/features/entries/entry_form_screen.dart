import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/calendar_date.dart';
import '../../core/domain/money.dart';
import '../categories/category_models.dart';
import '../categories/category_providers.dart';
import '../periods/period_providers.dart';
import 'entry_models.dart';
import 'entry_providers.dart';
import 'entry_service.dart';

/// Cadastro e edição de receita ou despesa avulsa.
///
/// A data é do usuário (padrão: hoje) e pode ser passada ou futura (RN004,
/// RN008); ela define o período. Se o período não existir, o usuário confirma
/// a criação antes de salvar (RN002).
class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({required this.kind, this.existing, super.key});

  final EntryKind kind;
  final EntryRecord? existing;

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
  late CalendarDate _paidOn;
  String? _categoryId;
  String? _subcategoryId;
  bool _saving = false;
  String? _error;

  bool get _isIncome => widget.kind == EntryKind.income;
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final today = ref.read(userClockProvider).today();
    _amount = TextEditingController(
      text: e?.amount == null
          ? ''
          : formatBrl(e!.amount!).replaceFirst('R\$ ', ''),
    );
    _description = TextEditingController(text: e?.description ?? '');
    _date = e?.date ?? today;
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
    final draft = EntryDraft(
      kind: widget.kind,
      amount: parseBrlToCentavos(_amount.text),
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

  Future<void> _write(EntryService service, EntryDraft draft) async {
    Future<void> attempt() async {
      if (_editing) {
        await service.update(widget.existing!, draft);
      } else {
        await service.create(
          draft,
          alreadyPaid: !_isIncome && _alreadyPaid,
          paidOn: _paidOn,
        );
      }
    }

    try {
      await attempt();
    } on PeriodMissingException catch (missing) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
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
      if (ok != true) {
        throw const ChangeRejectedException('Nada foi salvo.');
      }
      await service.createMissingPeriods(missing.date);
      await attempt();
    }
  }

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
    final title = _editing
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
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
                hintText: '0,00',
              ),
              validator: (v) {
                try {
                  parseBrlToCentavos(v ?? '');
                  return null;
                } on MoneyFormatException catch (e) {
                  return e.message;
                }
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('campo-data'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                _isIncome ? 'Data do recebimento' : 'Data da despesa',
              ),
              subtitle: Text(_date.toBr()),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await _pick(_date);
                if (picked != null) setState(() => _date = picked);
              },
            ),
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
                    child: Text(c.isActive ? c.name : '${c.name} (desativada)'),
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
                    DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
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
              child: Text(_saving ? 'Salvando…' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
