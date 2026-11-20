import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/card_bills_providers.dart';
import '../domain/reserve_calculator.dart';

/// Calculadora do "Dinheiro reservado" (spec §9): o visor começa com o valor
/// atual; a conta fica visível com o resumo "Atual → Novo" e Confirmar.
/// Nenhum lançamento é criado; o app grava só a diferença como ajuste.
Future<void> showReserveCalculator(BuildContext context, BigInt current) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CalculatorSheet(current: current),
    );

class _CalculatorSheet extends ConsumerStatefulWidget {
  const _CalculatorSheet({required this.current});

  final BigInt current;

  @override
  ConsumerState<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends ConsumerState<_CalculatorSheet> {
  late ReserveCalculator _calc = ReserveCalculator.start(widget.current);
  bool _busy = false;
  String? _saveError;

  void _press(ReserveCalculator Function(ReserveCalculator) f) => setState(() {
    _calc = f(_calc);
    _saveError = null;
  });

  /// Valor que seria gravado agora (resultado ou conta em andamento).
  (BigInt?, String?) get _value {
    if (_calc.error != null) return (null, _calc.error);
    final r = _calc.result;
    if (r != null) return (r, null);
    try {
      return (_calc.evaluate(), null);
    } on CalculatorError catch (e) {
      return (null, _calc.isEmpty ? null : e.message);
    }
  }

  Future<void> _confirm(BigInt value) async {
    setState(() => _busy = true);
    final result = await ref
        .read(cardBillsControllerProvider.notifier)
        .run((s) => s.setReserve(value));
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _saveError = result;
      });
      return;
    }
    Navigator.pop(context);
  }

  Widget _key(String label, VoidCallback onTap, {bool accent = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: 52,
        child: accent
            ? FilledButton.tonal(
                key: Key('cb-calc-$label'),
                onPressed: onTap,
                child: Text(label, style: const TextStyle(fontSize: 20)),
              )
            : OutlinedButton(
                key: Key('cb-calc-$label'),
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                ),
                child: Text(label, style: const TextStyle(fontSize: 20)),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (value, error) = _value;
    Widget digit(int d) => _key('$d', () => _press((c) => c.digit(d)));
    Widget op(CalcOp o) =>
        _key(o.symbol, () => _press((c) => c.operation(o)), accent: true);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Dinheiro reservado', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _calc.display.isEmpty ? '0' : _calc.display,
                  key: const Key('cb-calc-visor'),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error ??
                    (value == null
                        ? ' '
                        : calculatorSummary(widget.current, value)),
                key: const Key('cb-calc-resumo'),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: error == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Table(
                children: [
                  TableRow(
                    children: [
                      _key('C', () => _press((c) => c.clear())),
                      _key('⌫', () => _press((c) => c.backspace())),
                      op(CalcOp.divide),
                      op(CalcOp.multiply),
                    ],
                  ),
                  TableRow(
                    children: [
                      digit(7),
                      digit(8),
                      digit(9),
                      op(CalcOp.subtract),
                    ],
                  ),
                  TableRow(
                    children: [digit(4), digit(5), digit(6), op(CalcOp.add)],
                  ),
                  TableRow(
                    children: [
                      digit(1),
                      digit(2),
                      digit(3),
                      _key('=', () => _press((c) => c.equals()), accent: true),
                    ],
                  ),
                  TableRow(
                    children: [
                      const SizedBox.shrink(),
                      digit(0),
                      _key(',', () => _press((c) => c.comma())),
                      const SizedBox.shrink(),
                    ],
                  ),
                ],
              ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _saveError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('cb-calc-confirmar'),
                onPressed: _busy || value == null
                    ? null
                    : () => _confirm(value),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
