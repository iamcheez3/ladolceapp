import 'package:flutter/material.dart';

/// Brand colors shared with [PinScreen].
const Color kCoffeeBrandNavy = Color(0xFF001460);
const Color kCoffeeBrown = Color(0xFF6B4F3A);
const Color kCoffeeGold = Color(0xFFC6A15B);

/// Decorative pattern + faint bear watermark used on PIN and loading screens.
class CoffeeLuxuryPatternPainter extends CustomPainter {
  final Color smokeColor;
  final Color medallionColor;
  final Color coffeeColor;

  CoffeeLuxuryPatternPainter({
    required this.smokeColor,
    required this.medallionColor,
    required this.coffeeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final medallionPaint = Paint()
      ..color = medallionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final coffeeDotPaint = Paint()
      ..color = coffeeColor
      ..style = PaintingStyle.fill;

    const spacing = 170.0;
    for (double y = -50; y < size.height + spacing; y += spacing) {
      for (double x = -50; x < size.width + spacing; x += spacing) {
        final center = Offset(x, y);
        canvas.drawCircle(center, 28, medallionPaint);
        canvas.drawCircle(center, 12, medallionPaint);
        canvas.drawCircle(center.translate(30, 0), 3.2, coffeeDotPaint);
        canvas.drawCircle(center.translate(-30, 0), 3.2, coffeeDotPaint);
        canvas.drawCircle(center.translate(0, 30), 3.2, coffeeDotPaint);
        canvas.drawCircle(center.translate(0, -30), 3.2, coffeeDotPaint);
      }
    }

    final smokePaint = Paint()
      ..color = smokeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    final waveCount = (size.height / 120).ceil() + 1;
    for (int i = 0; i < waveCount; i++) {
      final baseY = 80.0 + (i * 120.0);
      final path = Path()
        ..moveTo(-20, baseY)
        ..cubicTo(
          size.width * 0.18,
          baseY - 24,
          size.width * 0.32,
          baseY + 24,
          size.width * 0.5,
          baseY,
        )
        ..cubicTo(
          size.width * 0.68,
          baseY - 24,
          size.width * 0.82,
          baseY + 24,
          size.width + 20,
          baseY - 4,
        );
      canvas.drawPath(path, smokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CoffeeLuxuryPatternPainter oldDelegate) => false;
}

/// Same background layer stack as [PinScreen]: pattern + full-screen soft logo.
class PinStyleBackground extends StatelessWidget {
  final Widget child;
  final double watermarkLogoWidth;

  const PinStyleBackground({
    super.key,
    required this.child,
    this.watermarkLogoWidth = 380,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: CoffeeLuxuryPatternPainter(
              smokeColor: Colors.white.withValues(alpha: 0.06),
              medallionColor: kCoffeeGold.withValues(alpha: 0.09),
              coffeeColor: kCoffeeBrown.withValues(alpha: 0.09),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.07,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    kCoffeeGold,
                    BlendMode.modulate,
                  ),
                  child: Image.asset(
                    'assets/images/ladolce_bear_logo.png',
                    width: MediaQuery.of(context).size.width * 0.8,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
