import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cowsmart/core/widgets/pdf_export_sheet.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/breed.dart';
import 'package:cowsmart/features/farm/domain/farm.dart';
import 'package:cowsmart/features/farm/services/farm_pdf_export_service.dart';

class GroupQrPdfExportService {
  /// Generates printable PDF catalog containing QR codes for selected cows
  static Future<void> exportGroupQrPdf({
    required Farm farm,
    required List<Cow> cows,
    required List<Breed> breeds,
    BuildContext? context,
  }) async {
    final pdfBytes = await generateGroupQrPdf(
      farm: farm,
      cows: cows,
      breeds: breeds,
    );

    final fileName = 'QR_วัวกลุ่ม_${farm.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    // 1. Direct file save & auto-open on Desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        String targetPath = '';
        if (Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null && userProfile.isNotEmpty) {
            final dlDir = Directory('$userProfile\\Downloads');
            if (dlDir.existsSync()) {
              targetPath = '${dlDir.path}\\$fileName';
            }
          }
        }

        if (targetPath.isEmpty) {
          try {
            final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
            targetPath = '${dir.path}/$fileName';
          } catch (_) {
            targetPath = fileName;
          }
        }

        final file = File(targetPath);
        await file.writeAsBytes(pdfBytes);

        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', file.path]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [file.path]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [file.path]);
        }
      } catch (e) {
        debugPrint('Auto open PDF file on desktop error: $e');
      }
    }

    // 2. Mobile-friendly export sheet (Share / Save / Print)
    if (context != null && context.mounted) {
      await PdfExportSheet.show(
        context: context,
        pdfBytes: pdfBytes,
        fileName: fileName,
        title: 'ป้าย QR Code ประจำตัววัว (PDF)',
      );
      return;
    }

    // 3. Safe Printing preview / print sheet fallback
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
      );
    } catch (e) {
      debugPrint('Printing.layoutPdf fallback: $e');
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(pdfBytes);
        } catch (_) {}
      }
    }
  }

  /// Generates raw PDF Bytes with 2-column or 3-column badge cards
  static Future<Uint8List> generateGroupQrPdf({
    required Farm farm,
    required List<Cow> cows,
    required List<Breed> breeds,
  }) async {
    final doc = pw.Document();

    pw.Font thaiFont;
    pw.Font thaiFontBold;
    try {
      final regData = await rootBundle.load('assets/fonts/Prompt-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Prompt-Bold.ttf');
      thaiFont = ThaiPromptTtfFont(regData);
      thaiFontBold = ThaiPromptTtfFont(boldData);
    } catch (_) {
      try {
        final reg = await PdfGoogleFonts.promptRegular();
        final bold = await PdfGoogleFonts.promptBold();
        thaiFont = reg is pw.TtfFont ? ThaiPromptTtfFont(reg.data) : reg;
        thaiFontBold = bold is pw.TtfFont ? ThaiPromptTtfFont(bold.data) : bold;
      } catch (_) {
        thaiFont = await PdfGoogleFonts.sarabunRegular();
        thaiFontBold = await PdfGoogleFonts.sarabunBold();
      }
    }

    final theme = pw.ThemeData.withFont(
      base: thaiFont,
      bold: thaiFontBold,
      italic: thaiFont,
      boldItalic: thaiFontBold,
    );

    final primaryColor = PdfColor.fromHex('#334A2E');
    final darkGreen = PdfColor.fromHex('#1E331B');
    final lightGreenBg = PdfColor.fromHex('#F4F7F3');
    final borderColor = PdfColor.fromHex('#D4E0D1');

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          theme: theme,
        ),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      FarmPdfExportService.shapeThai('ป้าย QR Code ประจำตัววัว (COWSMART)'),
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      FarmPdfExportService.shapeThai('ฟาร์ม: ${farm.name} • จำนวนที่พิมพ์: ${cows.length} ตัว'),
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  FarmPdfExportService.shapeThai('พิมพ์เมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} น.'),
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              FarmPdfExportService.shapeThai('หน้า ${context.pageNumber} / ${context.pagesCount}'),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          );
        },
        build: (pw.Context context) {
          // Render a 2-column grid of QR Badges suited for cutting/laminating
          return [
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cows.map((cow) {
                final breedObj = breeds.firstWhere(
                  (b) => b.id == cow.breed,
                  orElse: () => Breed(id: '', name: cow.breed),
                );
                final breedName = breedObj.name.isNotEmpty ? breedObj.name : '-';
                final qrUrl = 'https://cowsmart.app/cow/${cow.id}';

                return pw.Container(
                  width: 265,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: lightGreenBg,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: borderColor, width: 1.2),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // QR Code container
                      pw.Container(
                        width: 90,
                        height: 90,
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: borderColor, width: 0.8),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(
                            errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
                          ),
                          data: qrUrl,
                          width: 82,
                          height: 82,
                          color: primaryColor,
                          textStyle: pw.TextStyle(font: thaiFont),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      // Cow details on the right
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: primaryColor,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Text(
                                FarmPdfExportService.shapeThai(cow.tagNumber.isNotEmpty ? cow.tagNumber : 'ไม่มีเบอร์'),
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              FarmPdfExportService.shapeThai(cow.name.isNotEmpty ? cow.name : 'ไม่ระบุชื่อ'),
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: darkGreen,
                              ),
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              FarmPdfExportService.shapeThai('สายพันธุ์: $breedName'),
                              style: const pw.TextStyle(
                                fontSize: 9.5,
                                color: PdfColors.grey800,
                              ),
                              maxLines: 1,
                            ),
                            pw.Text(
                              FarmPdfExportService.shapeThai('เพศ: ${cow.gender == 'M' ? 'ผู้' : 'เมีย'} • ประเภท: ${cow.displayTypeName}'),
                              style: const pw.TextStyle(
                                fontSize: 9.5,
                                color: PdfColors.grey700,
                              ),
                              maxLines: 1,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              FarmPdfExportService.shapeThai('สแกนดูประวัติผ่านแอป'),
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }
}
