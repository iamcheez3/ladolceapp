import 'package:flutter/material.dart';

class LuxuryPatternBackground extends StatelessWidget {
  final Color backgroundColor;
  final Color patternColor;
  final Widget child;

  const LuxuryPatternBackground({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFFF6F7FB),
    this.patternColor = const Color(0xFF0D1565),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: backgroundColor),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _LuxuryPatternPainter(patternColor),
          ),
        ),
        child,
      ],
    );
  }
}

class _LuxuryPatternPainter extends CustomPainter {
  final Color color;
  const _LuxuryPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final fill = Paint()
      ..color = color.withOpacity(0.025)
      ..style = PaintingStyle.fill;

    final stepX = size.width / 3.2;
    final stepY = size.height / 4.2;

    for (double y = -stepY; y < size.height + stepY; y += stepY) {
      for (double x = -stepX; x < size.width + stepX; x += stepX) {
        final center = Offset(x + stepX / 2, y + stepY / 2);
        final r = (stepX < stepY ? stepX : stepY) * 0.26;

        canvas.drawCircle(center, r * 1.25, fill);
        canvas.drawCircle(center, r * 1.25, stroke);

        _petal(canvas, center.translate(0, -r * 0.9), r * 0.55, stroke);
        _petal(canvas, center.translate(r * 0.9, 0), r * 0.55, stroke);
        _petal(canvas, center.translate(0, r * 0.9), r * 0.55, stroke);
        _petal(canvas, center.translate(-r * 0.9, 0), r * 0.55, stroke);
      }
    }
  }

  void _petal(Canvas canvas, Offset c, double r, Paint paint) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
