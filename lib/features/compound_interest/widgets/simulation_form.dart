import 'package:flutter/material.dart';

import '../domain/simulation_math.dart';

/// Largura a partir da qual os campos ficam em duas colunas.
const double twoColumnBreakpoint = 560;

/// Seção da calculadora: cartão do tema com título.
class SimulationSection extends StatelessWidget {
  const SimulationSection({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: text.titleLarge)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Dois itens lado a lado em tela larga; um abaixo do outro no celular.
class ResponsivePair extends StatelessWidget {
  const ResponsivePair({required this.first, required this.second, super.key});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= twoColumnBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 14), second],
        );
      },
    );
  }
}

/// Campo de dinheiro no padrão brasileiro ("8.000,00").
class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    this.error,
    this.helper,
    this.onSubmitted,
    super.key,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? error;
  final String? helper;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'R\$ ',
        hintText: '0,00',
        helperText: helper,
        errorText: error,
        errorMaxLines: 2,
      ),
    );
  }
}

/// Campo numérico com seletor ao lado (taxa + periodicidade, período +
/// unidade).
class _NumberWithSelector<T> extends StatelessWidget {
  const _NumberWithSelector({
    required this.fieldKey,
    required this.selectorKey,
    required this.controller,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.suffix,
    this.hint,
    this.error,
    super.key,
  });

  final Key fieldKey;
  final Key selectorKey;
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? hint;
  final String? error;
  final T value;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: label,
              suffixText: suffix,
              hintText: hint,
              errorText: error,
              errorMaxLines: 3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 118,
          child: DropdownButtonFormField<T>(
            key: selectorKey,
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.fromLTRB(14, 16, 8, 16),
            ),
            items: [
              for (final o in options)
                DropdownMenuItem(value: o, child: Text(optionLabel(o))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

class RateField extends StatelessWidget {
  const RateField({
    required this.controller,
    required this.period,
    required this.onPeriodChanged,
    this.keyPrefix = 'juros',
    this.error,
    super.key,
  });

  final TextEditingController controller;
  final RatePeriod period;
  final ValueChanged<RatePeriod> onPeriodChanged;
  final String keyPrefix;
  final String? error;

  @override
  Widget build(BuildContext context) => _NumberWithSelector<RatePeriod>(
    // A chave muda com o valor para o seletor refletir "Limpar".
    key: ValueKey('$keyPrefix-taxa-${period.name}'),
    fieldKey: Key('$keyPrefix-campo-taxa'),
    selectorKey: Key('$keyPrefix-taxa-periodo'),
    controller: controller,
    label: 'Taxa de juros',
    suffix: '%',
    hint: '0,00',
    error: error,
    value: period,
    options: RatePeriod.values,
    optionLabel: (p) => p.label,
    onChanged: onPeriodChanged,
  );
}

class TermField extends StatelessWidget {
  const TermField({
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
    this.keyPrefix = 'juros',
    this.error,
    super.key,
  });

  final TextEditingController controller;
  final TermUnit unit;
  final ValueChanged<TermUnit> onUnitChanged;
  final String keyPrefix;
  final String? error;

  @override
  Widget build(BuildContext context) => _NumberWithSelector<TermUnit>(
    key: ValueKey('$keyPrefix-periodo-${unit.name}'),
    fieldKey: Key('$keyPrefix-campo-periodo'),
    selectorKey: Key('$keyPrefix-periodo-unidade'),
    controller: controller,
    label: 'Período',
    error: error,
    value: unit,
    options: TermUnit.values,
    optionLabel: (u) => u.label,
    onChanged: onUnitChanged,
  );
}

/// Mensagem de erro do cálculo (ex.: resultado acima do limite).
class SimulationErrorBanner extends StatelessWidget {
  const SimulationErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('simulacao-erro'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa informativa neutra (ex.: "o dinheiro acaba no mês 7").
class SimulationNotice extends StatelessWidget {
  const SimulationNotice({
    required this.icon,
    required this.message,
    this.color,
    this.background,
    super.key,
  });

  final IconData icon;
  final String message;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botões do formulário: Calcular (principal) e ações secundárias.
class SimulationActions extends StatelessWidget {
  const SimulationActions({
    required this.onCalculate,
    required this.secondary,
    super.key,
  });

  final VoidCallback onCalculate;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    final calculate = FilledButton(
      key: const Key('simulacao-calcular'),
      onPressed: onCalculate,
      child: const Text('Calcular'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= twoColumnBreakpoint) {
          return Row(
            children: [
              SizedBox(width: 180, child: calculate),
              const Spacer(),
              ...secondary,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            calculate,
            const SizedBox(height: 6),
            Wrap(alignment: WrapAlignment.spaceBetween, children: secondary),
          ],
        );
      },
    );
  }
}
