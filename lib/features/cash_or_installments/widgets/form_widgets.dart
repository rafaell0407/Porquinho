import 'package:flutter/material.dart';

import '../../../app/theme/norte_theme.dart';
import '../cash_or_installments_texts.dart';

/// Peças do formulário da Calculadora à vista ou parcelado (módulo próprio,
/// sem depender de outras ferramentas).

/// Cartão de seção com título em caixa alta ("A COMPRA").
class AvpSection extends StatelessWidget {
  const AvpSection({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Seletor de duas (ou mais) opções em pílula.
class AvpChoice<T> extends StatelessWidget {
  const AvpChoice({
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
    required this.keyPrefix,
    super.key,
  });

  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      segments: [
        for (final o in options)
          ButtonSegment<T>(
            value: o,
            label: Text(
              label(o),
              key: Key('$keyPrefix-${(o as Enum).name}'),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Campo numérico (dinheiro, percentual ou inteiro).
class AvpField extends StatelessWidget {
  const AvpField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    this.prefix,
    this.suffix,
    this.hint,
    this.error,
    this.decimal = true,
    this.onChanged,
    super.key,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? prefix;
  final String? suffix;
  final String? hint;
  final String? error;
  final bool decimal;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    textInputAction: TextInputAction.next,
    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    decoration: InputDecoration(
      labelText: label,
      prefixText: prefix,
      suffixText: suffix,
      hintText: hint,
      errorText: error,
      errorMaxLines: 3,
    ),
  );
}

/// Dois campos lado a lado (um embaixo do outro se a tela for estreita).
class AvpPair extends StatelessWidget {
  const AvpPair({required this.first, required this.second, super.key});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth >= 300
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          ),
  );
}

/// Caixa informativa (valor calculado, vencimentos).
class AvpInfoBox extends StatelessWidget {
  const AvpInfoBox({required this.child, this.highlight = false, super.key});

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: highlight ? scheme.onPrimaryContainer : scheme.onSurface,
        ),
        child: child,
      ),
    );
  }
}

/// Texto auxiliar discreto.
class AvpHint extends StatelessWidget {
  const AvpHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    );
  }
}

/// Opção de fatura (cartão selecionável com rádio).
class AvpBillOption extends StatelessWidget {
  const AvpBillOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (subtitle != null) TextSpan(text: ' — $subtitle'),
                        ],
                      ),
                      style: TextStyle(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faixa permanente de atenção (spec §9.1): não fecha; "Ler mais" abre o
/// texto completo.
class AvpWarningBanner extends StatelessWidget {
  const AvpWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = NorteColors.of(context);
    final theme = Theme.of(context);
    final text = theme.colorScheme.onSurface;
    return Container(
      key: const Key('avp-faixa-aviso'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: colors.pendingBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              color: colors.pending,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CashOrInstallmentsTexts.alertTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CashOrInstallmentsTexts.alertBody,
                  style: theme.textTheme.bodySmall?.copyWith(color: text),
                ),
                TextButton(
                  key: const Key('avp-ler-mais'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 40),
                    foregroundColor: colors.pending,
                  ),
                  onPressed: () => showReadMoreSheet(context),
                  child: const Text('Ler mais'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto completo dos avisos (spec §9.2).
Future<void> showReadMoreSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final body = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
        ),
        child: SingleChildScrollView(
          key: const Key('avp-ler-mais-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                CashOrInstallmentsTexts.alertTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final t in CashOrInstallmentsTexts.readMore)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: body),
                      Expanded(child: Text(t, style: body)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(sheet).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
