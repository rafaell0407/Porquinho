import 'package:flutter/material.dart';

import '../../../core/domain/money.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Um valor de resultado (o primeiro da lista recebe destaque).
class ResultValue {
  const ResultValue({
    required this.key,
    required this.label,
    required this.cents,
  });

  final Key key;
  final String label;
  final BigInt cents;
}

/// Três cartões de resultado: lado a lado em tela larga; no celular, o
/// destaque ocupa a largura toda e os outros dois dividem a linha de baixo.
class ResultCards extends StatelessWidget {
  const ResultCards({required this.values, super.key})
    : assert(values.length == 3);

  final List<ResultValue> values;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final (i, v) in values.indexed)
        _ResultCard(value: v, highlight: i == 0),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= 600) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
              ],
            ),
          );
        }
        final rest = w >= 300
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[2]),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cards[1], const SizedBox(height: 12), cards[2]],
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [cards[0], const SizedBox(height: 12), rest],
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.value, required this.highlight});

  final ResultValue value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = highlight ? scheme.onPrimary : scheme.onSurface;
    final muted = highlight
        ? scheme.onPrimary.withValues(alpha: 0.8)
        : scheme.onSurfaceVariant;
    final full = formatBrl(value.cents);
    final cut = full.indexOf('R\$ ') + 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: highlight ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Valor sempre embaixo: alinhado entre cartões mesmo se o rótulo
        // quebrar linha.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              key: value.key,
              TextSpan(
                children: [
                  TextSpan(
                    text: full.substring(0, cut),
                    style: TextStyle(
                      fontSize: highlight ? 16 : 13,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  TextSpan(text: full.substring(cut)),
                ],
              ),
              style:
                  (highlight
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontFeatures: _tabular,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
