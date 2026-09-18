import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/widgets/cowsmart_logo.dart';

/// Reusable Cow Icon widget that renders the app's signature cow logo
/// as a vector icon supporting dynamic sizing and theming/colors.
class CowIcon extends StatelessWidget {
  final double? size;
  final Color? color;
  final bool fullLogo;
  final bool isOutlined;

  const CowIcon({
    super.key,
    this.size,
    this.color,
    this.fullLogo = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveSize = size ?? iconTheme.size ?? 24.0;
    final effectiveColor = color ?? iconTheme.color ?? AppColors.primary;

    if (fullLogo) {
      return CowSmartLogo(
        size: effectiveSize,
        borderRadius: effectiveSize * 0.22,
        showShadow: false,
      );
    }

    return SizedBox(
      width: effectiveSize,
      height: effectiveSize,
      child: CustomPaint(
        size: Size(effectiveSize, effectiveSize),
        painter: _CowHeadIconPainter(
          color: effectiveColor,
          isOutlined: isOutlined,
        ),
      ),
    );
  }
}

class _CowHeadIconPainter extends CustomPainter {
  final Color color;
  final bool isOutlined;

  _CowHeadIconPainter({required this.color, this.isOutlined = false});

  @override
  void paint(Canvas canvas, Size size) {
    final double iconSize = min(size.width, size.height);
    final double scale = iconSize / 440.0;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, scale);
    canvas.translate(-256.0, -250.0);

    const layerRect = Rect.fromLTWH(0, 0, 512, 512);
    canvas.saveLayer(layerRect, Paint());

    final paint = Paint()
      ..color = color
      ..style = isOutlined ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = isOutlined ? 28.0 : 0.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final leftHorn = Path()
      ..moveTo(140, 180)
      ..cubicTo(110, 130, 160, 100, 190, 140)
      ..cubicTo(170, 150, 150, 165, 140, 180)
      ..close();

    final rightHorn = Path()
      ..moveTo(372, 180)
      ..cubicTo(402, 130, 352, 100, 322, 140)
      ..cubicTo(342, 150, 362, 165, 372, 180)
      ..close();

    final leftEar = Path()
      ..moveTo(150, 205)
      ..cubicTo(90, 205, 90, 250, 155, 240)
      ..close();

    final rightEar = Path()
      ..moveTo(362, 205)
      ..cubicTo(422, 205, 422, 250, 357, 240)
      ..close();

    final headBase = Path()
      ..moveTo(170, 170)
      ..lineTo(342, 170)
      ..cubicTo(360, 210, 360, 270, 330, 320)
      ..lineTo(182, 320)
      ..cubicTo(152, 270, 152, 210, 170, 170)
      ..close();

    final snoutRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(180, 285, 152, 115),
      const Radius.circular(45),
    );

    if (isOutlined) {
      Path full = Path.combine(PathOperation.union, leftHorn, rightHorn);
      full = Path.combine(PathOperation.union, full, leftEar);
      full = Path.combine(PathOperation.union, full, rightEar);
      full = Path.combine(PathOperation.union, full, headBase);
      full = Path.combine(PathOperation.union, full, Path()..addRRect(snoutRRect));
      
      canvas.drawPath(full, paint);
      
      final sepPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..strokeCap = StrokeCap.round;
      
      canvas.drawPath(Path()..moveTo(180, 290)..quadraticBezierTo(256, 275, 332, 290), sepPaint);

      final eyePaint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(215, 225), 15, eyePaint);
      canvas.drawCircle(const Offset(297, 225), 15, eyePaint);

      canvas.drawCircle(const Offset(215, 345), 12, eyePaint);
      canvas.drawCircle(const Offset(297, 345), 12, eyePaint);
    } else {
      canvas.drawPath(leftHorn, paint);
      canvas.drawPath(rightHorn, paint);
      canvas.drawPath(leftEar, paint);
      canvas.drawPath(rightEar, paint);
      canvas.drawPath(headBase, paint);
      canvas.drawRRect(snoutRRect, paint);

      final clearFill = Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.fill;

      final cutStroke = Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;

      canvas.drawRRect(snoutRRect, cutStroke);

      canvas.drawOval(
        Rect.fromCenter(center: const Offset(215, 225), width: 22, height: 30),
        clearFill,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(297, 225), width: 22, height: 30),
        clearFill,
      );

      canvas.drawCircle(const Offset(215, 345), 13, clearFill);
      canvas.drawCircle(const Offset(297, 345), 13, clearFill);
    }

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CowHeadIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
