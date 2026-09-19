import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/app_toast.dart';

class PdfExportSheet extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;
  final String title;

  const PdfExportSheet({
    super.key,
    required this.pdfBytes,
    required this.fileName,
    this.title = 'ส่งออกเอกสาร PDF',
  });

  static Future<void> show({
    required BuildContext context,
    required Uint8List pdfBytes,
    required String fileName,
    String title = 'ส่งออกเอกสาร PDF',
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PdfExportSheet(
        pdfBytes: pdfBytes,
        fileName: fileName,
        title: title,
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    Navigator.pop(context);
    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการแชร์ไฟล์: $e');
      }
    }
  }

  Future<void> _saveToDevice(BuildContext context) async {
    Navigator.pop(context);
    try {
      String savedPath = '';
      if (!kIsWeb && Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final dlDir = Directory('$userProfile\\Downloads');
          if (dlDir.existsSync()) {
            savedPath = '${dlDir.path}\\$fileName';
          }
        }
      }

      if (savedPath.isEmpty) {
        try {
          final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
          savedPath = '${dir.path}/$fileName';
        } catch (_) {
          final dir = await getApplicationDocumentsDirectory();
          savedPath = '${dir.path}/$fileName';
        }
      }

      final file = File(savedPath);
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        AppFeedback.showSuccess(context, 'บันทึกไฟล์เรียบร้อยแล้ว: $fileName');
      }

      // If mobile, also trigger system share so the user can easily save to Files or other locations
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, 'บันทึกไฟล์ไม่สำเร็จ: $e');
      }
    }
  }

  Future<void> _printPdf(BuildContext context) async {
    Navigator.pop(context);
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: fileName,
      );
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการเปิดตัวอย่างพิมพ์: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.cardBg(context);
    final textColor = AppColors.text(context);
    final subtextColor = AppColors.subText(context);
    final brdColor = AppColors.brd(context);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.prompt(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileName,
                      style: GoogleFonts.prompt(
                        color: subtextColor,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: brdColor.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 14),

          // Option 1: Share PDF (Line, Gmail, Drive, etc.)
          _buildOptionCard(
            context,
            icon: Icons.share_rounded,
            iconColor: const Color(0xFF0288D1),
            iconBgColor: const Color(0xFFE1F5FE),
            title: 'แชร์ไฟล์ PDF',
            subtitle: 'ส่งต่อผ่าน LINE, อีเมล, Google Drive, AirDrop ฯลฯ',
            badge: 'สะดวก',
            onTap: () => _sharePdf(context),
          ),
          const SizedBox(height: 10),

          // Option 2: Save to Device
          _buildOptionCard(
            context,
            icon: Icons.download_rounded,
            iconColor: const Color(0xFFE65100),
            iconBgColor: const Color(0xFFFFF3E0),
            title: 'บันทึกไฟล์ลงเครื่อง',
            subtitle: 'บันทึกเก็บไว้ในโทรศัพท์ / โฟลเดอร์ Downloads',
            onTap: () => _saveToDevice(context),
          ),
          const SizedBox(height: 10),

          // Option 3: Print & Preview
          _buildOptionCard(
            context,
            icon: Icons.print_rounded,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primary.withValues(alpha: 0.12),
            title: 'ดูตัวอย่าง / พิมพ์เอกสาร',
            subtitle: 'เปิดหน้าต่างตัวอย่างและสั่งพิมพ์ไปยังเครื่องพิมพ์',
            onTap: () => _printPdf(context),
          ),
          const SizedBox(height: 16),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: brdColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'ยกเลิก',
                style: GoogleFonts.prompt(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    final brdColor = AppColors.brd(context);
    final textColor = AppColors.text(context);
    final subtextColor = AppColors.subText(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: brdColor.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.prompt(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.prompt(
                              color: const Color(0xFF2E7D32),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.prompt(
                      color: subtextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: subtextColor.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
