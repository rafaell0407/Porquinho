import 'package:flutter/material.dart';

/// Painel de acesso do login: fundo do tema, cantos superiores arredondados e
/// contorno superior em verde discreto, mais forte no centro.
class LoginPanel extends StatelessWidget {
  const LoginPanel({
    super.key,
    required this.child,
    required this.minHeight,
    this.bottomInset = 0,
  });

  static const radius = 32.0;

  final Widget child;
  final double minHeight;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      foregroundPainter: _TopOutlinePainter(scheme.primary),
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(radius),
          ),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, 6 + bottomInset),
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: child,
        ),
      ),
    );
  }
}

class _TopOutlinePainter extends CustomPainter {
  _TopOutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const r = LoginPanel.radius;
    final w = size.width;
    final path = Path()
      ..moveTo(0, r + 24)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, r + 24);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.05),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0.05),
        ],
        stops: const [0, 0.3, 0.7, 1],
      ).createShader(Rect.fromLTWH(0, 0, w, r + 24));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TopOutlinePainter old) => old.color != color;
}
