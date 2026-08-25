import 'package:flutter/material.dart';

class CowSmartLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showShadow;

  const CowSmartLogo({
    super.key,
    this.size = 80,
    this.borderRadius = 18,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.25),
                  blurRadius: size * 0.15,
                  offset: Offset(0, size * 0.06),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          size: Size(size, size),
          painter: _CowSmartLogoPainter(),
        ),
      ),
    );
  }
}

class _CowSmartLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 512.0;

    // 1. Background Gradient
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      ).createShader(bgRect);

    canvas.drawRect(bgRect, bgPaint);

    canvas.save();
    canvas.scale(scale, scale);

    final whitePaint = Paint()..color = Colors.white;

    // 2. Left Horn
    final leftHorn = Path()
      ..moveTo(140, 180)
      ..cubicTo(110, 130, 160, 100, 190, 140)
      ..cubicTo(170, 150, 150, 165, 140, 180)
      ..close();
    canvas.drawPath(leftHorn, whitePaint);

    // 3. Right Horn
    final rightHorn = Path()
      ..moveTo(372, 180)
      ..cubicTo(402, 130, 352, 100, 322, 140)
      ..cubicTo(342, 150, 362, 165, 372, 180)
      ..close();
    canvas.drawPath(rightHorn, whitePaint);

    // 4. Left Ear
    final leftEar = Path()
      ..moveTo(150, 205)
      ..cubicTo(90, 205, 90, 250, 155, 240)
      ..close();
    canvas.drawPath(leftEar, whitePaint);

    // 5. Right Ear
    final rightEar = Path()
      ..moveTo(362, 205)
      ..cubicTo(422, 205, 422, 250, 357, 240)
      ..close();
    canvas.drawPath(rightEar, whitePaint);

    // 6. Head Base
    final headBase = Path()
      ..moveTo(170, 170)
      ..lineTo(342, 170)
      ..cubicTo(360, 210, 360, 270, 330, 320)
      ..lineTo(182, 320)
      ..cubicTo(152, 270, 152, 210, 170, 170)
      ..close();
    canvas.drawPath(headBase, whitePaint);

    // 7. Muzzle / Snout
    final snoutRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(180, 290, 152, 110),
      const Radius.circular(45),
    );
    final snoutPaint = Paint()..color = const Color(0xFFF1F8E9);
    canvas.drawRRect(snoutRRect, snoutPaint);

    // 8. Nostrils
    final nostrilPaint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawCircle(const Offset(215, 345), 14, nostrilPaint);
    canvas.drawCircle(const Offset(297, 345), 14, nostrilPaint);

    // 9. Eyes
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(215, 225), width: 28, height: 36),
      whitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(297, 225), width: 28, height: 36),
      whitePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
