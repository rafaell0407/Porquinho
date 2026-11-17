import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Símbolo do Norte (como na referência): arco largo de bússola, aberto
/// embaixo, com a seta vazada apontando para o norte. Desenhado em vetor, na
/// cor de destaque do tema. [size] é a largura; a altura é 70% dela.
class NorteMark extends StatelessWidget {
  const NorteMark({super.key, this.size = 72});

  final double size;

  static const aspect = 0.70;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size, size * aspect),
        painter: _NorteMarkPainter(color),
      ),
    );
  }
}

class _NorteMarkPainter extends CustomPainter {
  _NorteMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset p(double x, double y) => Offset(x * s, y * s);

    // Arco: de ~22° abaixo da horizontal à esquerda até o mesmo ponto à
    // direita, passando pelo topo.
    final ring = Rect.fromCircle(center: p(0.5, 0.485), radius: s * 0.435);
    const start = (180 - 22) * math.pi / 180;
    const sweep = 224 * math.pi / 180;
    final stroke = s * 0.042;
    canvas.drawArc(
      ring,
      start,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
    );
    canvas.drawArc(
      ring,
      start,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // Seta vazada: contorno externo com entalhe e furo interno.
    final arrow = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(p(0.5, 0.214).dx, p(0.5, 0.214).dy)
      ..lineTo(p(0.702, 0.662).dx, p(0.702, 0.662).dy)
      ..lineTo(p(0.5, 0.513).dx, p(0.5, 0.513).dy)
      ..lineTo(p(0.292, 0.662).dx, p(0.292, 0.662).dy)
      ..close()
      ..moveTo(p(0.5, 0.318).dx, p(0.5, 0.318).dy)
      ..lineTo(p(0.596, 0.545).dx, p(0.596, 0.545).dy)
      ..lineTo(p(0.5, 0.468).dx, p(0.5, 0.468).dy)
      ..lineTo(p(0.43, 0.533).dx, p(0.43, 0.533).dy)
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_NorteMarkPainter old) => old.color != color;
}
