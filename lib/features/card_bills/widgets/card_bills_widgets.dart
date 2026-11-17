import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/money.dart';

/// Peças visuais da Gestão de Faturas (visual do Norte: cartões, Menta,
/// claro e escuro pelo tema central; nenhuma cor própria).

String ddMm(CalendarDate d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Valor digitado ("1.234,56") em centavos, ou `null` se inválido/vazio.
BigInt? parseMoney(String text) {
  try {
    return parseBrlToCentavos(text);
  } on MoneyFormatException {
    return null;
  }
}

/// Mensagem de erro do valor digitado, ou `null`.
String? moneyError(String text) {
  try {
    parseBrlToCentavos(text);
    return null;
  } on MoneyFormatException catch (e) {
    return e.message;
  }
}

/// Centavos no formato do campo ("1.234,56").
String moneyInput(BigInt cents) => formatBrl(cents).replaceFirst('R\$ ', '');

class CbSection extends StatelessWidget {
  const CbSection({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.controller,
    required this.label,
    this.errorText,
    this.onChanged,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(
      labelText: label,
      prefixText: 'R\$ ',
      errorText: errorText,
    ),
    onChanged: onChanged,
  );
}

class DayField extends StatelessWidget {
  const DayField({
    required this.controller,
    required this.label,
    this.errorText,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(2),
    ],
    decoration: InputDecoration(
      labelText: label,
      helperText: 'De 1 a 31',
      errorText: errorText,
    ),
  );
}

/// Aviso em destaque (não é erro).
class CbNotice extends StatelessWidget {
  const CbNotice(this.text, {this.icon = Icons.info_outline, super.key});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String cancel = 'Voltar',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          key: const Key('cb-confirmar-nao'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancel),
        ),
        FilledButton(
          key: const Key('cb-confirmar-sim'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<CalendarDate?> pickDate(
  BuildContext context, {
  required CalendarDate initial,
  CalendarDate? last,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(2000),
    lastDate: last == null
        ? DateTime(2100)
        : DateTime(last.year, last.month, last.day),
  );
  if (picked == null) return null;
  return CalendarDate(picked.year, picked.month, picked.day);
}

/// Linha "rótulo …… valor".
class CbValueRow extends StatelessWidget {
  const CbValueRow(
    this.label,
    this.value, {
    this.subtitle,
    this.onTap,
    this.bold = false,
    super.key,
  });

  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyLarge;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: style),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(value, style: style),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lista de itens: mostra os primeiros [_visibleCount]; o restante fica num
/// cartão "Mais N itens" que expande ("Ver todos os itens").
class CbCollapsibleList<T> extends StatefulWidget {
  const CbCollapsibleList({
    required this.items,
    required this.rowBuilder,
    this.hint = 'Visualize os demais lançamentos desta fatura',
    this.moreKey = const Key('cb-fatura-itens-mais'),
    super.key,
  });

  final List<T> items;
  final Widget Function(T) rowBuilder;
  final String hint;
  final Key moreKey;

  @override
  State<CbCollapsibleList<T>> createState() => _CbCollapsibleListState<T>();
}

class _CbCollapsibleListState<T> extends State<CbCollapsibleList<T>> {
  static const _visibleCount = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final hidden = items.length > _visibleCount
        ? items.length - _visibleCount
        : 0;
    final shown = _expanded || hidden == 0
        ? items
        : items.sublist(0, _visibleCount);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in shown) widget.rowBuilder(item),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: widget.moreKey,
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _expanded
                                  ? 'Mostrar menos'
                                  : (hidden == 1
                                        ? 'Mais 1 item'
                                        : 'Mais $hidden itens'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                      if (!_expanded) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.hint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'Ver todos os itens',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
