import 'package:flutter/material.dart';

import 'card_bills_widgets.dart';

/// Resposta do [showMoneyDialog].
class MoneyDialogResult {
  const MoneyDialogResult({
    this.amount,
    this.option = 0,
    this.secondary = false,
  });

  final BigInt? amount;

  /// Opção escolhida entre as `options` (0 se não houver).
  final int option;

  /// `true` = tocou na ação secundária (ex.: "Remover desta fatura").
  final bool secondary;
}

/// Diálogo com um campo de valor. O próprio diálogo cuida do campo, para o
/// texto não ser descartado enquanto a animação de saída ainda roda.
Future<MoneyDialogResult?> showMoneyDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String fieldKey,
  required String saveKey,
  String? message,
  BigInt? initial,
  String? Function(BigInt? amount)? validate,
  List<(String, String)> options = const [],
  (String, String)? secondary,
}) => showDialog<MoneyDialogResult>(
  context: context,
  builder: (_) => _MoneyDialog(
    title: title,
    label: label,
    fieldKey: fieldKey,
    saveKey: saveKey,
    message: message,
    initial: initial,
    validate: validate,
    options: options,
    secondary: secondary,
  ),
);

class _MoneyDialog extends StatefulWidget {
  const _MoneyDialog({
    required this.title,
    required this.label,
    required this.fieldKey,
    required this.saveKey,
    required this.options,
    this.message,
    this.initial,
    this.validate,
    this.secondary,
  });

  final String title;
  final String label;
  final String fieldKey;
  final String saveKey;
  final String? message;
  final BigInt? initial;
  final String? Function(BigInt? amount)? validate;

  /// (chave, rótulo) de cada opção.
  final List<(String, String)> options;

  /// (chave, rótulo) da ação secundária; sem ela, aparece "Cancelar".
  final (String, String)? secondary;

  @override
  State<_MoneyDialog> createState() => _MoneyDialogState();
}

class _MoneyDialogState extends State<_MoneyDialog> {
  late final _controller = TextEditingController(
    text: widget.initial == null ? '' : moneyInput(widget.initial!),
  );
  int _option = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final amount = parseMoney(text);
    final error = text.isEmpty
        ? null
        : (moneyError(text) ?? widget.validate?.call(amount));
    final secondary = widget.secondary;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!),
              const SizedBox(height: 12),
            ],
            MoneyField(
              key: Key(widget.fieldKey),
              controller: _controller,
              label: widget.label,
              errorText: error,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            if (widget.options.isNotEmpty)
              RadioGroup<int>(
                groupValue: _option,
                onChanged: (v) => setState(() => _option = v ?? 0),
                child: Column(
                  children: [
                    for (final (i, option) in widget.options.indexed)
                      RadioListTile<int>(
                        key: Key(option.$1),
                        contentPadding: EdgeInsets.zero,
                        value: i,
                        title: Text(option.$2),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (secondary != null)
          TextButton(
            key: Key(secondary.$1),
            onPressed: () => Navigator.pop(
              context,
              const MoneyDialogResult(secondary: true),
            ),
            child: Text(secondary.$2),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        FilledButton(
          key: Key(widget.saveKey),
          onPressed: amount == null || error != null
              ? null
              : () => Navigator.pop(
                  context,
                  MoneyDialogResult(amount: amount, option: _option),
                ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
