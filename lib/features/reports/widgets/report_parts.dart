import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/norte_theme.dart';
import '../../../core/domain/period_calendar.dart';
import '../models/report_definition.dart';

/// Relatório em desenho: os módulos leem daqui o próprio ID (chaves) e, na
/// prévia vazia do catálogo, o ícone e a descrição.
class ReportScope extends InheritedWidget {
  const ReportScope({
    required this.definition,
    required super.child,
    super.key,
  });

  final ReportDefinition definition;

  static ReportDefinition of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReportScope>()!.definition;

  @override
  bool updateShouldNotify(ReportScope oldWidget) =>
      oldWidget.definition.id != definition.id;
}

/// Participação em pontos-base (1/100 de %) como "12,3%", arredondada na
/// 1ª casa com meio para cima (A10, 21/11/2026: 88,79% → "88,8%").
///
/// [basisPoints] já vem truncado (`CategoryBreakdown.basisPoints`); como o
/// ponto de meio cai sempre num ponto-base inteiro, arredondar a partir dele
/// dá o mesmo resultado que arredondar o valor exato.
String formatPercent(int basisPoints) {
  final tenths = (basisPoints + 5) ~/ 10;
  return '${tenths ~/ 10},${tenths % 10}%';
}

/// "01/11/2026 a 30/11/2026".
String rangeLabel(PeriodRange range) =>
    '${range.start.toBr()} a ${range.end.addDays(-1).toBr()}';

/// Carregando, erro com "Tentar de novo" (só neste relatório) ou os dados.
/// Nos níveis compacto/expandido ocupa pouco espaço; na tela completa centraliza.
class ReportAsync<T> extends StatelessWidget {
  const ReportAsync({
    required this.value,
    required this.level,
    required this.onRetry,
    required this.builder,
    super.key,
  });

  final AsyncValue<T> value;
  final ReportLevel level;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    final full = level == ReportLevel.full;
    Widget center(Widget child) => full
        ? Center(child: child)
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: child),
          );
    return value.when(
      skipLoadingOnReload: true,
      loading: () => center(
        const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      error: (_, _) => center(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível carregar o relatório.'),
            TextButton(
              key: Key('${ReportScope.of(context).id}-tentar-de-novo'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
      data: builder,
    );
  }
}

/// Frase de período vazio (compacto, expandido e tela completa). Na prévia do
/// catálogo vira o ícone e a descrição do relatório.
class ReportEmpty extends StatelessWidget {
  const ReportEmpty(this.text, {required this.level, super.key});

  final String text;
  final ReportLevel level;

  @override
  Widget build(BuildContext context) {
    final definition = ReportScope.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (level == ReportLevel.preview) {
      return Row(
        key: Key('${definition.id}-previa-vazia'),
        children: [
          Icon(definition.icon, size: 32, color: muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              definition.benefit,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: level == ReportLevel.full ? 16 : 4,
      ),
      child: Text(
        text,
        key: Key(
          level == ReportLevel.full
              ? 'relatorio-vazio'
              : '${definition.id}-vazio',
        ),
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      ),
    );
  }
}

/// Barra dividida: cada parte com a largura proporcional ao seu peso (só
/// desenho; os números escritos vêm dos centavos).
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({required this.segments, this.height = 10, super.key});

  /// (peso, cor); pesos não positivos são ignorados.
  final List<(int, Color)> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final s in segments)
        if (s.$1 > 0) s,
    ];
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      // Partes sem filho: a largura e a altura vêm da barra (sem isso, elas
      // ficariam com altura zero).
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: visible.isEmpty
            ? ColoredBox(color: track)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, s) in visible.indexed) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: s.$1,
                      child: ColoredBox(color: s.$2),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Mini-gráfico de barras sem eixos nem números, do mais antigo ao mais
/// recente (destacado). Valores negativos descem da linha de base.
class MiniBars extends StatelessWidget {
  const MiniBars({
    required this.values,
    required this.color,
    this.negativeColor,
    this.height = 40,
    super.key,
  });

  final List<BigInt> values;
  final Color color;
  final Color? negativeColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _MiniBarsPainter(
          values: [for (final v in values) v.toDouble()],
          color: color,
          negativeColor: negativeColor ?? color,
          baseline: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _MiniBarsPainter extends CustomPainter {
  _MiniBarsPainter({
    required this.values,
    required this.color,
    required this.negativeColor,
    required this.baseline,
  });

  final List<double> values;
  final Color color;
  final Color negativeColor;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final top = values.fold<double>(0, (m, v) => v > m ? v : m);
    final bottom = values.fold<double>(0, (m, v) => v < m ? v : m);
    final range = top - bottom;
    final baseY = range == 0 ? size.height : size.height * top / range;
    final slot = size.width / values.length;
    final barWidth = (slot * 0.6).clamp(2.0, 18.0);
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final h = range == 0 ? 0.0 : size.height * v.abs() / range;
      final x = slot * i + (slot - barWidth) / 2;
      final last = i == values.length - 1;
      final base = v < 0 ? negativeColor : color;
      final paint = Paint()..color = last ? base : base.withValues(alpha: 0.45);
      final rect = v < 0
          ? Rect.fromLTWH(x, baseY, barWidth, h)
          : Rect.fromLTWH(x, baseY - h, barWidth, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_MiniBarsPainter old) =>
      old.values != values || old.color != color;
}

/// Linha de legenda: bolinha colorida, rótulo e valor.
class LegendValue extends StatelessWidget {
  const LegendValue({
    required this.color,
    required this.label,
    required this.value,
    this.valueKey,
    super.key,
  });

  final Color color;
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(
            value,
            key: valueKey,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cores de receitas, despesas e investimentos (as mesmas da Home).
(Color, Color, Color) flowColors(BuildContext context) {
  final c = NorteColors.of(context);
  return (c.income, c.expense, c.investment);
}

/// Valor em destaque do compacto/expandido.
class ReportHeadline extends StatelessWidget {
  const ReportHeadline({
    required this.label,
    required this.value,
    this.valueKey,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          key: valueKey,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
