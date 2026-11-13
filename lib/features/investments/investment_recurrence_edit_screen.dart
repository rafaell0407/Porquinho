import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../../core/domain/money.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../entries/entry_providers.dart';
import '../periods/period_providers.dart';
import 'investment_models.dart';
import 'investment_providers.dart';

/// Edita "a recorrência" de investimento: o que muda vale só para as próximas
/// ocorrências; as já criadas não são alteradas (D7, D8). Valor sempre fixo.
class InvestmentRecurrenceEditScreen extends ConsumerStatefulWidget {
  const InvestmentRecurrenceEditScreen({required this.template, super.key});

  final InvestmentTemplate template;

  @override
  ConsumerState<InvestmentRecurrenceEditScreen> createState() =>
      _InvestmentRecurrenceEditScreenState();
}

class _InvestmentRecurrenceEditScreenState
    extends ConsumerState<InvestmentRecurrenceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _day;
  late final RecurrenceFrequency _frequency;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _amount = TextEditingController(
      text: formatBrl(t.defaultAmount).replaceFirst('R\$ ', ''),
    );
    _day = TextEditingController(
      text: '${t.monthlyReferenceDay ?? t.startsOn.day}',
    );
    // Só "Todo mês" (13/11/2026): salvar um modelo antigo "por período"
    // o converte para mensal.
    _frequency = RecurrenceFrequency.monthly;
  }

  @override
  void dispose() {
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
      final service = await ref.read(
        investmentRecurrenceServiceProvider.future,
      );
      await service.edit(
        widget.template,
        InvestmentTemplateEdit(
          frequency: _frequency,
          monthlyReferenceDay: _frequency == RecurrenceFrequency.monthly
              ? int.tryParse(_day.text.trim())
              : null,
          defaultAmount: parseBrlToCentavos(_amount.text),
        ),
        today: ref.read(userClockProvider).today(),
      );
      ref.invalidate(investmentTemplatesProvider);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Editar recorrência de investimento')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'As mudanças valem só para as próximas ocorrências. As já '
              'criadas continuam como estão; para mudar o valor de um mês, '
              'edite só aquela ocorrência.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
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
            TextFormField(
              key: const Key('campo-valor'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor investido',
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

/// Confirma e interrompe a recorrência: não cria novas ocorrências; as já
/// geradas ficam como estão.
Future<void> confirmStopInvestmentRecurrence(
  BuildContext context,
  WidgetRef ref,
  InvestmentTemplate template,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Parar de repetir?'),
      content: const Text(
        'Nenhum investimento novo será criado. Os que já existem continuam '
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
    final service = await ref.read(investmentRecurrenceServiceProvider.future);
    await service.stop(template);
    ref.invalidate(investmentTemplatesProvider);
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}
