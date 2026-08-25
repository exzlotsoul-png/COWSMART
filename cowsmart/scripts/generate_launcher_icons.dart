import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  const sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in sizes.entries) {
    final folder = entry.key;
    final size = entry.value;
    final image = img.Image(width: size, height: size, numChannels: 4);

    final greenTop = img.ColorRgba8(0x2E, 0x7D, 0x32, 0xFF);
    final greenBottom = img.ColorRgba8(0x1B, 0x5E, 0x20, 0xFF);
    final white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 0xFF);
    final snoutColor = img.ColorRgba8(0xF1, 0xF8, 0xE9, 0xFF);
    final nostrilColor = img.ColorRgba8(0x2E, 0x7D, 0x32, 0xFF);

    final radius = (size * 0.22).round();

    // Draw rounded background gradient
    for (int y = 0; y < size; y++) {
      final t = y / size;
      final r = ((1 - t) * 0x2E + t * 0x1B).round();
      final g = ((1 - t) * 0x7D + t * 0x5E).round();
      final b = ((1 - t) * 0x32 + t * 0x20).round();
      final c = img.ColorRgba8(r, g, b, 0xFF);

      for (int x = 0; x < size; x++) {
        // Check corner rounded radius
        bool inside = true;
        if (x < radius && y < radius) {
          final dx = radius - x;
          final dy = radius - y;
          if (dx * dx + dy * dy > radius * radius) inside = false;
        } else if (x >= size - radius && y < radius) {
          final dx = x - (size - radius - 1);
          final dy = radius - y;
          if (dx * dx + dy * dy > radius * radius) inside = false;
        } else if (x < radius && y >= size - radius) {
          final dx = radius - x;
          final dy = y - (size - radius - 1);
          if (dx * dx + dy * dy > radius * radius) inside = false;
        } else if (x >= size - radius && y >= size - radius) {
          final dx = x - (size - radius - 1);
          final dy = y - (size - radius - 1);
          if (dx * dx + dy * dy > radius * radius) inside = false;
        }

        if (inside) {
          image.setPixel(x, y, c);
        } else {
          image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        }
      }
    }

    // Draw Cow Face details scaled
    final s = size / 512.0;

    // Head Base
    img.fillRect(
      image,
      x1: (170 * s).round(),
      y1: (170 * s).round(),
      x2: (342 * s).round(),
      y2: (320 * s).round(),
      color: white,
    );

    // Left & Right Horns (filled circles/ovals)
    img.fillCircle(image, x: (160 * s).round(), y: (140 * s).round(), radius: (35 * s).round(), color: white);
    img.fillCircle(image, x: (352 * s).round(), y: (140 * s).round(), radius: (35 * s).round(), color: white);

    // Ears
    img.fillCircle(image, x: (130 * s).round(), y: (220 * s).round(), radius: (28 * s).round(), color: white);
    img.fillCircle(image, x: (382 * s).round(), y: (220 * s).round(), radius: (28 * s).round(), color: white);

    // Muzzle / Snout
    final snoutX1 = (180 * s).round();
    final snoutY1 = (280 * s).round();
    final snoutX2 = (332 * s).round();
    final snoutY2 = (380 * s).round();
    final snoutR = ((snoutY2 - snoutY1) * 0.45).round();

    for (int y = snoutY1; y <= snoutY2; y++) {
      for (int x = snoutX1; x <= snoutX2; x++) {
        image.setPixel(x, y, snoutColor);
      }
    }

    // Nostrils
    final nostrilRadius = max(1, (12 * s).round());
    img.fillCircle(image, x: (215 * s).round(), y: (330 * s).round(), radius: nostrilRadius, color: nostrilColor);
    img.fillCircle(image, x: (297 * s).round(), y: (330 * s).round(), radius: nostrilRadius, color: nostrilColor);

    // Eyes
    final eyeRadiusX = max(1, (12 * s).round());
    img.fillCircle(image, x: (215 * s).round(), y: (220 * s).round(), radius: eyeRadiusX, color: white);
    img.fillCircle(image, x: (297 * s).round(), y: (220 * s).round(), radius: eyeRadiusX, color: white);

    final pngBytes = img.encodePng(image);
    final targetPath = 'android/app/src/main/res/$folder/ic_launcher.png';
    File(targetPath).writeAsBytesSync(pngBytes);
    print('Generated: $targetPath ($size x $size)');
  }
}
