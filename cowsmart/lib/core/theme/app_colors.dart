import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Earth-tone Green
  static const Color primary = Color(0xFF5D7052); // Sage/olive green
  static const Color primaryLight = Color(0xFF8FA584);
  static const Color primaryDark = Color(0xFF3E4E36);

  // Secondary Colors - Earth-tone Brown
  static const Color secondary = Color(0xFF8B6F4E); // Warm brown
  static const Color secondaryLight = Color(0xFFB89878);
  static const Color secondaryDark = Color(0xFF5D4A35);

  // Accent
  static const Color accent = Color(0xFFC9A86A); // Warm tan/gold

  // Background Colors - Warm cream/beige (Light Mode)
  static const Color background = Color(0xFFF5F1E8); // Cream background
  static const Color surface = Color(0xFFFAF7F0); // Off-white surface
  static const Color surfaceAlt = Color(0xFFFBF9F5); // Light warm off-white fill

  // Dark Mode Palette (Warm Charcoal / Earth-tone Dark)
  static const Color darkBackground = Color(0xFF141712);
  static const Color darkSurface = Color(0xFF1F241C);
  static const Color darkSurfaceAlt = Color(0xFF262D22);
  static const Color darkTextPrimary = Color(0xFFECE6DA);
  static const Color darkTextSecondary = Color(0xFFB8AE9D);
  static const Color darkTextHint = Color(0xFF7A7264);
  static const Color darkBorder = Color(0xFF353E30);
  static const Color darkDivider = Color(0xFF2A3225);

  // Text Colors (Light Mode)
  static const Color textPrimary = Color(0xFF3E3528); // Dark brown
  static const Color textSecondary = Color(0xFF7A6D5C); // Medium brown
  static const Color textHint = Color(0xFFB5A890);

  // Status Colors
  static const Color success = Color(0xFF6B8E5A); // Earth green
  static const Color warning = Color(0xFFD4A04C); // Mustard
  static const Color error = Color(0xFFB85A4A); // Terracotta
  static const Color info = Color(0xFF6B8BA4); // Muted blue

  // Borders & Dividers (Light Mode)
  static const Color divider = Color(0xFFD8CDB8);
  static const Color border = Color(0xFFE5DCC6);

  // ── Context-aware adaptive helpers ──
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? darkSurface : Colors.white;

  static Color surf(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color surfAlt(BuildContext context) =>
      isDark(context) ? darkSurfaceAlt : surfaceAlt;

  static Color text(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color subText(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color hint(BuildContext context) =>
      isDark(context) ? darkTextHint : textHint;

  static Color brd(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color div(BuildContext context) =>
      isDark(context) ? darkDivider : divider;
}
