import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/money.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../categories/category_models.dart';
import '../categories/category_providers.dart';
import '../entries/entry_providers.dart';
import '../periods/period_providers.dart';
import 'recurrence_models.dart';
import 'recurrence_providers.dart';
import 'recurrence_service.dart';

/// Edita "a recorrência": o que muda vale só para as próximas ocorrências; as
/// já criadas não são alteradas (RN038, D2).
class RecurrenceEditScreen extends ConsumerStatefulWidget {
  const RecurrenceEditScreen({required this.template, super.key});

  final RecurringTemplate template;

  @override
  ConsumerState<RecurrenceEditScreen> createState() =>
      _RecurrenceEditScreenState();
}

class _RecurrenceEditScreenState extends ConsumerState<RecurrenceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _day;
  late final RecurrenceFrequency _frequency;
  late bool _variable;
  String? _categoryId;
  String? _subcategoryId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _description = TextEditingController(text: t.description ?? '');
    _amount = TextEditingController(
      text: t.defaultAmount == null
          ? ''
          : formatBrl(t.defaultAmount!).replaceFirst('R\$ ', ''),
    );
    _day = TextEditingController(
      text: '${t.monthlyReferenceDay ?? t.startsOn.day}',
    );
    // Só "Todo mês" (13/11/2026): salvar um modelo antigo "por período"
    // o converte para mensal.
    _frequency = RecurrenceFrequency.monthly;
    _variable = t.variableValue;
    _categoryId = t.categoryId;
    _subcategoryId = t.subcategoryId;
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
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
    try {
      final service = await ref.read(recurrenceServiceProvider.future);
      await service.edit(
        widget.template,
        TemplateEdit(
          description: _description.text,
          frequency: _frequency,
          monthlyReferenceDay: _frequency == RecurrenceFrequency.monthly
              ? int.tryParse(_day.text.trim())
              : null,
          variableValue: _variable,
          defaultAmount: _variable || _amount.text.trim().isEmpty
              ? null
              : parseBrlToCentavos(_amount.text),
          categoryId: _categoryId,
          subcategoryId: _subcategoryId,
        ),
        today: ref.read(userClockProvider).today(),
      );
      ref.invalidate(recurringTemplatesProvider);
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

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final cats = ref.watch(categoryDataProvider).value;
    final categories = cats == null
        ? <CategoryRecord>[]
        : cats.categories
              .where(
                (c) =>
                    c.kind.dbValue == t.kind.categoryKind &&
                    (c.isActive || c.id == t.categoryId),
              )
              .toList();
    final subs = (cats == null || _categoryId == null)
        ? <SubcategoryRecord>[]
        : cats.subcategories
              .where(
                (s) =>
                    s.categoryId == _categoryId &&
                    (s.isActive || s.id == t.subcategoryId),
              )
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar recorrência de ${t.kind.label.toLowerCase()}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'As mudanças valem só para as próximas ocorrências. As já '
              'criadas continuam como estão.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('campo-descricao'),
              controller: _description,
              maxLength: RecurrenceService.maxDescriptionLength,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
            ),
            TextFormField(
              key: const Key('campo-dia'),
              controller: _day,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Dia do mês (1 a 31)',
                helperText:
                    'Dia que não existe no mês (29 a 31): último dia útil '
                    'até o fim do mês.',
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return (n == null || n < 1 || n > 31)
                    ? 'Informe um dia entre 1 e 31.'
                    : null;
              },
            ),
            SwitchListTile(
              key: const Key('valor-variavel'),
              contentPadding: EdgeInsets.zero,
              title: const Text('O valor muda todo mês'),
              value: _variable,
              onChanged: (v) => setState(() => _variable = v),
            ),
            if (!_variable)
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
              key: const Key('salvar-recorrencia'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando…' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
