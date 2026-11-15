import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tabela mês a mês com cabeçalho fixo e rolagem vertical própria. Em tela
/// estreita, rola também na horizontal (só dentro da tabela).
class EvolutionTable extends StatelessWidget {
  const EvolutionTable({
    required this.headers,
    required this.rowCount,
    required this.cells,
    this.highlightRow,
    super.key,
  });

  /// O primeiro é a coluna "Mês" (mais estreita).
  final List<String> headers;
  final int rowCount;

  /// Textos da linha [index], na ordem de [headers].
  final List<String> Function(int index) cells;

  /// Linha destacada (ex.: mês em que o dinheiro acabou).
  final int? highlightRow;

  static const double _rowHeight = 44;
  static const double _monthWidth = 56;
  static const double _minValueWidth = 116;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cellStyle = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: scheme.onSurface,
    );
    final headStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );
    final height = math.min(420.0, _rowHeight * (rowCount + 1) + 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth =
            _monthWidth + _minValueWidth * (headers.length - 1).toDouble();
        final width = math.max(constraints.maxWidth, minWidth);

        Widget row(List<String> texts, TextStyle? style) => Row(
          children: [
            SizedBox(
              width: _monthWidth,
              child: Text(texts[0], style: style, textAlign: TextAlign.center),
            ),
            for (final t in texts.skip(1))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    t,
                    style: style,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            const SizedBox(width: 8),
          ],
        );

        final table = SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              Container(
                height: _rowHeight,
                color: scheme.surfaceContainerHighest,
                child: row(headers, headStyle),
              ),
              Expanded(
                child: Scrollbar(
                  child: ListView.builder(
                    key: const Key('simulacao-tabela-lista'),
                    primary: false,
                    itemExtent: _rowHeight,
                    itemCount: rowCount,
                    itemBuilder: (context, i) => Container(
                      key: Key('simulacao-tabela-linha-$i'),
                      decoration: BoxDecoration(
                        color: i == highlightRow
                            ? scheme.primaryContainer
                            : null,
                        border: Border(
                          bottom: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: row(cells(i), cellStyle),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: width > constraints.maxWidth
                ? SingleChildScrollView(
                    key: const Key('simulacao-tabela-horizontal'),
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    child: table,
                  )
                : table,
          ),
        );
      },
    );
  }
}
