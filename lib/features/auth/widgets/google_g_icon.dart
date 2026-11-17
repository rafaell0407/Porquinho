import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "G" do Google nas quatro cores oficiais, desenhado em vetor (sem pacote
/// de SVG nem imagem).
class GoogleGIcon extends StatelessWidget {
  const GoogleGIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _GPainter()),
  );
}

class _GPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final radius = (s - stroke) / 2;
    final c = Offset(s / 2, s / 2);
    final rect = Rect.fromCircle(center: c, radius: radius);
    Paint p(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double rad(double deg) => deg * math.pi / 180;

    // Ângulos no sentido horário a partir do leste (y para baixo).
    canvas.drawArc(rect, rad(-142), rad(97), false, p(_red));
    canvas.drawArc(rect, rad(160), rad(58), false, p(_yellow));
    canvas.drawArc(rect, rad(42), rad(120), false, p(_green));
    canvas.drawArc(rect, rad(-2), rad(46), false, p(_blue));
    // Barra horizontal do G.
    canvas.drawRect(
      Rect.fromLTRB(
        s * 0.5,
        c.dy - stroke / 2,
        c.dx + radius + stroke / 2,
        c.dy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GPainter old) => false;
}
