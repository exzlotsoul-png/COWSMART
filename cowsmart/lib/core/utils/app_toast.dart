import 'package:flutter/material.dart';

class AppFeedback {
  /// Shows a success notification banner (green tint, check icon, smooth floating banner)
  static void showSuccess(
    BuildContext context,
    String message, {
    String title = 'บันทึกสำเร็จ',
  }) {
    _showSnackBar(
      context,
      message: message,
      title: title,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF2E7D32),
      textColor: Colors.white,
    );
  }

  /// Shows an error / validation failure notification banner (red tint, error icon)
  static void showError(
    BuildContext context,
    String message, {
    String title = 'ข้อผิดพลาด',
  }) {
    _showSnackBar(
      context,
      message: message,
      title: title,
      icon: Icons.error_rounded,
      backgroundColor: const Color(0xFFC62828),
      textColor: Colors.white,
    );
  }

  /// Shows a warning notification banner (amber/orange tint, warning icon)
  static void showWarning(
    BuildContext context,
    String message, {
    String title = 'แจ้งเตือน',
  }) {
    _showSnackBar(
      context,
      message: message,
      title: title,
      icon: Icons.warning_amber_rounded,
      backgroundColor: const Color(0xFFE65100),
      textColor: Colors.white,
    );
  }

  /// Shows an info notification banner (blue tint, info icon)
  static void showInfo(
    BuildContext context,
    String message, {
    String title = 'แจ้งเพื่อทราบ',
  }) {
    _showSnackBar(
      context,
      message: message,
      title: title,
      icon: Icons.info_rounded,
      backgroundColor: const Color(0xFF0277BD),
      textColor: Colors.white,
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required String title,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
