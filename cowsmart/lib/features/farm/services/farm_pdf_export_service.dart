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
import 'package:cowsmart/features/farm/domain/farm.dart';
import 'package:cowsmart/features/farm/domain/zone.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/breed.dart';
import 'package:cowsmart/features/market/providers/market_price_provider.dart';

const String cowSmartLogoSvg = '''
<svg width="512" height="512" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="512" height="512" rx="115" fill="#2E7D32"/>
  <path d="M 140 180 C 110 130 160 100 190 140 C 170 150 150 165 140 180 Z" fill="#FFFFFF"/>
  <path d="M 372 180 C 402 130 352 100 322 140 C 342 150 362 165 372 180 Z" fill="#FFFFFF"/>
  <path d="M 150 205 C 90 205 90 250 155 240 Z" fill="#FFFFFF"/>
  <path d="M 362 205 C 422 205 422 250 357 240 Z" fill="#FFFFFF"/>
  <path d="M 170 170 L 342 170 C 360 210 360 270 330 320 L 182 320 C 152 270 152 210 170 170 Z" fill="#FFFFFF"/>
  <rect x="180" y="290" width="152" height="110" rx="45" fill="#F1F8E9"/>
  <circle cx="215" cy="345" r="14" fill="#2E7D32"/>
  <circle cx="297" cy="345" r="14" fill="#2E7D32"/>
  <ellipse cx="215" cy="225" rx="14" ry="18" fill="#FFFFFF"/>
  <ellipse cx="297" cy="225" rx="14" ry="18" fill="#FFFFFF"/>
</svg>
''';

/// Custom TtfFont wrapper that dynamically binds standard Thai PUA Unicode codes
/// (U+F700..U+F71A) to Prompt's small/narrow glyph indices at runtime.
class ThaiPromptTtfFont extends pw.TtfFont {
  ThaiPromptTtfFont(super.data, {super.protect});

  static const Map<int, int> _promptPuaMap = {
    0xF70A: 721, // uni0E48.small (Mai Ek level 2)
    0xF70B: 723, // uni0E49.small (Mai Tho level 2)
    0xF70C: 726, // uni0E4A.small (Mai Tri level 2)
    0xF70D: 729, // uni0E4B.small (Mai Chattawa level 2)
    0xF70E: 731, // uni0E4C.small (Thanthakhat level 2)
    0xF705: 755, // uni0E48.narrow (Mai Ek shifted left)
    0xF706: 724, // uni0E49.narrow (Mai Tho shifted left)
    0xF707: 727, // uni0E4A.narrow (Mai Tri shifted left)
    0xF708: 756, // uni0E4B.narrow (Mai Chattawa shifted left)
    0xF709: 732, // uni0E4C.narrow (Thanthakhat shifted left)
    0xF710: 719, // uni0E31.narrow (Mai Han-Akat shifted left)
    0xF701: 737, // uni0E34.narrow (Sara I shifted left)
    0xF702: 739, // uni0E35.narrow (Sara Ii shifted left)
    0xF703: 741, // uni0E36.narrow (Sara Ue shifted left)
    0xF704: 743, // uni0E37.narrow (Sara Uee shifted left)
    0xF700: 734, // uni0E47.narrow (Mai Tai Khu shifted left)
    0xF718: 752, // uni0E38.small (Sara U below descender)
    0xF719: 754, // uni0E39.small (Sara Uu below descender)
    0xF71A: 750, // uni0E3A.small (Phinthu below descender)
    0xF70F: 757, // uni0E4D.narrow (Nikhahit shifted left)
  };

  @override
  PdfFont buildFont(PdfDocument pdfDocument) {
    final pdfFont = super.buildFont(pdfDocument);
    if (pdfFont is PdfTtfFont) {
      for (final entry in _promptPuaMap.entries) {
        pdfFont.font.charToGlyphIndexMap[entry.key] = entry.value;
      }
    }
    return pdfFont;
  }
}

class FarmPdfExportService {
  /// Generates and opens Print / Save dialog for Farm Overview PDF Report
  static Future<void> exportFarmOverviewReport({
    required Farm farm,
    required List<Cow> cows,
    required List<Breed> breeds,
    required List<Zone> zones,
    required MarketPriceState marketState,
    double totalIncome = 0.0,
    double totalExpense = 0.0,
    double netBalance = 0.0,
    String? issuedBy,
    BuildContext? context,
  }) async {
    final pdfBytes = await generateFarmOverviewPdf(
      farm: farm,
      cows: cows,
      breeds: breeds,
      zones: zones,
      marketState: marketState,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netBalance: netBalance,
      issuedBy: issuedBy,
    );

    final fileName =
        'รายงานสรุปภาพรวมฟาร์ม_${farm.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    // 1. Direct file save & auto-open for Desktop (Windows / macOS / Linux)
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
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
            final dir =
                await getDownloadsDirectory() ??
                await getApplicationDocumentsDirectory();
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

    // 2. Mobile-friendly export sheet (Share / Save to device / Print)
    if (context != null && context.mounted) {
      await PdfExportSheet.show(
        context: context,
        pdfBytes: pdfBytes,
        fileName: fileName,
        title: 'รายงานสรุปภาพรวมฟาร์ม (PDF)',
      );
      return;
    }

    // 3. Safe Printing preview with graceful fallback when no context
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

  /// Generates raw PDF Bytes
  static Future<Uint8List> generateFarmOverviewPdf({
    required Farm farm,
    required List<Cow> cows,
    required List<Breed> breeds,
    required List<Zone> zones,
    required MarketPriceState marketState,
    double totalIncome = 0.0,
    double totalExpense = 0.0,
    double netBalance = 0.0,
    String? issuedBy,
  }) async {
    final doc = pw.Document();

    // Load Thai Font (Prompt from assets if available, fallback to Google Fonts)
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
    );

    // Styling Palette
    final primaryColor = PdfColor.fromHex('#334A2E');
    final secondaryColor = PdfColor.fromHex('#4B6344');
    final headerBgColor = PdfColor.fromHex('#EAF2EA');
    final cardBgColor = PdfColor.fromHex('#F8FAF7');
    final borderColor = PdfColor.fromHex('#D8E2D6');
    final textDarkColor = PdfColor.fromHex('#1B2618');
    final textMutedColor = PdfColor.fromHex('#5E6E5A');
    final greenColor = PdfColor.fromHex('#1E7E34');
    final redColor = PdfColor.fromHex('#BD2130');

    // Thai Date Formatter
    final now = DateTime.now();
    final thaiYear = now.year + 543;
    final formattedDate =
        '${now.day} ${_getThaiMonth(now.month)} $thaiYear  ${DateFormat('HH:mm').format(now)} น.';

    // Calculate Herd Stats
    final totalCows = cows.length;
    final totalZones = zones.length;
    double totalHerdAssetValue = 0.0;

    // Helper map for breeds
    final Map<String, String> breedNameMap = {};
    for (final b in breeds) {
      breedNameMap[b.id] = b.name;
    }

    // Helper map for zones
    final Map<String, String> zoneNameMap = {};
    for (final z in zones) {
      zoneNameMap[z.id] = z.name;
    }

    // Breed Distribution Calculation
    final Map<String, int> breedCountMap = {};
    final Map<String, double> breedValueMap = {};

    // Status Distribution
    int normalCount = 0;
    int sickCount = 0;
    int pregnantCount = 0;
    int otherStatusCount = 0;

    // Zone Distribution
    final Map<String, int> zoneCountMap = {};

    for (final cow in cows) {
      final bName = breedNameMap[cow.breed] ?? cow.breed;
      final zName = zoneNameMap[cow.zoneId] ?? cow.zoneId;

      final estVal = marketState.calculateEstimatedValue(
        breedName: bName,
        weight: cow.latestWeight,
      );
      totalHerdAssetValue += estVal;

      breedCountMap[bName] = (breedCountMap[bName] ?? 0) + 1;
      breedValueMap[bName] = (breedValueMap[bName] ?? 0.0) + estVal;

      zoneCountMap[zName] = (zoneCountMap[zName] ?? 0) + 1;

      // Status check
      if (cow.status == CowStatus.sick || cow.status == CowStatus.injured) {
        sickCount++;
      } else if (cow.status == CowStatus.pregnant ||
          cow.status == CowStatus.estrous) {
        pregnantCount++;
      } else if (cow.status == CowStatus.normal) {
        normalCount++;
      } else {
        otherStatusCount++;
      }
    }

    final numberFormat = NumberFormat('#,##0');

    // Page 1: Overview, Summary Cards, Breed Breakdown & Health/Zone Breakdown
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.all(32),
        ),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 44,
                            height: 44,
                            child: pw.SvgImage(svg: cowSmartLogoSvg),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: pw.BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Text(
                                      'COWSMART',
                                      style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Text(
                                    shapeThai('รายงานสรุปภาพรวมฟาร์ม'),
                                    style: pw.TextStyle(
                                      fontSize: 17,
                                      fontWeight: pw.FontWeight.bold,
                                      color: textDarkColor,
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                shapeThai('ฟาร์ม: ${farm.name}'),
                                style: pw.TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        shapeThai('วันที่พิมพ์: $formattedDate'),
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          color: textMutedColor,
                        ),
                      ),
                      if (issuedBy != null && issuedBy.isNotEmpty)
                        pw.Text(
                          shapeThai('ผู้จัดทำ: $issuedBy'),
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            color: textMutedColor,
                          ),
                        ),
                      pw.Text(
                        shapeThai(
                          'หน้า ${context.pageNumber} จาก ${context.pagesCount}',
                        ),
                        style: pw.TextStyle(fontSize: 9, color: textMutedColor),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: primaryColor, thickness: 1.5),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: borderColor, thickness: 0.8),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 14,
                        height: 14,
                        child: pw.SvgImage(svg: cowSmartLogoSvg),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Text(
                        shapeThai('COWSMART — ระบบบริหารจัดการฟาร์มโคอัจฉริยะ'),
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          color: textMutedColor,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    shapeThai('เอกสารสรุปภาพรวมฟาร์มอย่างเป็นทางการ'),
                    style: pw.TextStyle(fontSize: 8.5, color: textMutedColor),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // ── Section 1: Executive Summary Cards ──
            pw.Text(
              shapeThai('1. สรุปภาพรวมทรัพยากรและสินทรัพย์ฟาร์ม'),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSummaryCard(
                    title: 'จำนวนวัวทั้งหมด',
                    value: '${numberFormat.format(totalCows)} ตัว',
                    subValue: 'จำแนกใน $totalZones โซน/คอก',
                    bgColor: cardBgColor,
                    borderColor: borderColor,
                    textColor: primaryColor,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryCard(
                    title: 'มูลค่าประเมินฝูงวัวรวม',
                    value: _formatPrice(totalHerdAssetValue),
                    subValue: 'อิงราคาตลาดกลาง DLD/สศก.',
                    bgColor: cardBgColor,
                    borderColor: borderColor,
                    textColor: greenColor,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryCard(
                    title: 'ผลกำไรสุทธิฟาร์ม',
                    value: _formatPrice(netBalance),
                    subValue:
                        'รายรับ ${_formatPrice(totalIncome)} | รายจ่าย ${_formatPrice(totalExpense)}',
                    bgColor: cardBgColor,
                    borderColor: borderColor,
                    textColor: netBalance >= 0 ? greenColor : redColor,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // ── Section 2: Breed & Zone Breakdowns ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Breed Distribution Table
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        shapeThai('2. สัดส่วนและมูลค่าแยกตามสายพันธุ์'),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Table(
                        border: pw.TableBorder.all(
                          color: borderColor,
                          width: 0.6,
                        ),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1.4),
                          1: pw.FixedColumnWidth(48),
                          2: pw.FixedColumnWidth(48),
                          3: pw.FixedColumnWidth(76),
                        },
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: headerBgColor),
                            children: [
                              _tableHeaderCell('สายพันธุ์', font: thaiFontBold),
                              _tableHeaderCell(
                                'จำนวน (ตัว)',
                                font: thaiFontBold,
                                align: pw.TextAlign.center,
                              ),
                              _tableHeaderCell(
                                'สัดส่วน (%)',
                                font: thaiFontBold,
                                align: pw.TextAlign.center,
                              ),
                              _tableHeaderCell(
                                'มูลค่าประเมิน (บาท)',
                                font: thaiFontBold,
                                align: pw.TextAlign.right,
                              ),
                            ],
                          ),
                          ...breedCountMap.entries.map((e) {
                            final pct = totalCows > 0
                                ? (e.value / totalCows * 100).toStringAsFixed(1)
                                : '0';
                            final val = breedValueMap[e.key] ?? 0.0;
                            return pw.TableRow(
                              children: [
                                _tableBodyCell(e.key, font: thaiFont),
                                _tableBodyCell(
                                  numberFormat.format(e.value),
                                  font: thaiFont,
                                  align: pw.TextAlign.center,
                                ),
                                _tableBodyCell(
                                  '$pct%',
                                  font: thaiFont,
                                  align: pw.TextAlign.center,
                                ),
                                _tableBodyCell(
                                  _formatPrice(val),
                                  font: thaiFont,
                                  align: pw.TextAlign.right,
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 14),

                // Right: Status & Zone Breakdown
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        shapeThai('3. สถานะสุขภาพและการกระจายในฟาร์ม'),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Table(
                        border: pw.TableBorder.all(
                          color: borderColor,
                          width: 0.6,
                        ),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1.5),
                          1: pw.FixedColumnWidth(44),
                          2: pw.FixedColumnWidth(44),
                        },
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: headerBgColor),
                            children: [
                              _tableHeaderCell(
                                'หมวดหมู่ / สถานะ',
                                font: thaiFontBold,
                              ),
                              _tableHeaderCell(
                                'จำนวน (ตัว)',
                                font: thaiFontBold,
                                align: pw.TextAlign.center,
                              ),
                              _tableHeaderCell(
                                'สัดส่วน',
                                font: thaiFontBold,
                                align: pw.TextAlign.right,
                              ),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _tableBodyCell(
                                'สุขภาพปกติ (Normal)',
                                font: thaiFont,
                              ),
                              _tableBodyCell(
                                '$normalCount',
                                font: thaiFont,
                                align: pw.TextAlign.center,
                              ),
                              _tableBodyCell(
                                totalCows > 0
                                    ? '${(normalCount / totalCows * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                font: thaiFont,
                                align: pw.TextAlign.right,
                              ),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _tableBodyCell(
                                'ป่วย / บาดเจ็บ (Sick/Injured)',
                                font: thaiFont,
                              ),
                              _tableBodyCell(
                                '$sickCount',
                                font: thaiFont,
                                align: pw.TextAlign.center,
                              ),
                              _tableBodyCell(
                                totalCows > 0
                                    ? '${(sickCount / totalCows * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                font: thaiFont,
                                align: pw.TextAlign.right,
                              ),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _tableBodyCell(
                                'ตั้งท้อง / เป็นสัด (Pregnant)',
                                font: thaiFont,
                              ),
                              _tableBodyCell(
                                '$pregnantCount',
                                font: thaiFont,
                                align: pw.TextAlign.center,
                              ),
                              _tableBodyCell(
                                totalCows > 0
                                    ? '${(pregnantCount / totalCows * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                font: thaiFont,
                                align: pw.TextAlign.right,
                              ),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _tableBodyCell(
                                'สถานะอื่นๆ / พักฟื้น (Other)',
                                font: thaiFont,
                              ),
                              _tableBodyCell(
                                '$otherStatusCount',
                                font: thaiFont,
                                align: pw.TextAlign.center,
                              ),
                              _tableBodyCell(
                                totalCows > 0
                                    ? '${(otherStatusCount / totalCows * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                font: thaiFont,
                                align: pw.TextAlign.right,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── Section 3: Detailed Cattle Roster Table ──
            pw.Text(
              shapeThai('4. รายชื่อวัวและมูลค่าประเมินในฟาร์ม'),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),

            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.6),
              columnWidths: const {
                0: pw.FixedColumnWidth(18), // #
                1: pw.FixedColumnWidth(52), // เบอร์หู (Tag)
                2: pw.FixedColumnWidth(55), // ชื่อวัว
                3: pw.FixedColumnWidth(48), // ประเภทวัว (NEW)
                4: pw.FlexColumnWidth(1.2), // สายพันธุ์
                5: pw.FixedColumnWidth(24), // เพศ
                6: pw.FixedColumnWidth(52), // น้ำหนัก (กก.)
                7: pw.FlexColumnWidth(1.1), // โซน/คอก
                8: pw.FixedColumnWidth(44), // สถานะ
                9: pw.FixedColumnWidth(74), // ราคาประเมิน (บาท)
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerBgColor),
                  children: [
                    _tableHeaderCell(
                      '#',
                      font: thaiFontBold,
                      align: pw.TextAlign.center,
                    ),
                    _tableHeaderCell('เบอร์หู (Tag)', font: thaiFontBold),
                    _tableHeaderCell('ชื่อวัว', font: thaiFontBold),
                    _tableHeaderCell('ประเภทวัว', font: thaiFontBold),
                    _tableHeaderCell('สายพันธุ์', font: thaiFontBold),
                    _tableHeaderCell(
                      'เพศ',
                      font: thaiFontBold,
                      align: pw.TextAlign.center,
                    ),
                    _tableHeaderCell(
                      'น้ำหนัก (กก.)',
                      font: thaiFontBold,
                      align: pw.TextAlign.right,
                    ),
                    _tableHeaderCell('โซน/คอก', font: thaiFontBold),
                    _tableHeaderCell(
                      'สถานะ',
                      font: thaiFontBold,
                      align: pw.TextAlign.center,
                    ),
                    _tableHeaderCell(
                      'ราคาประเมิน (บาท)',
                      font: thaiFontBold,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                ...List.generate(cows.length, (idx) {
                  final cow = cows[idx];
                  final bName = breedNameMap[cow.breed] ?? cow.breed;
                  final zName = zoneNameMap[cow.zoneId] ?? cow.zoneId;
                  final estVal = marketState.calculateEstimatedValue(
                    breedName: bName,
                    weight: cow.latestWeight,
                  );
                  final isEven = idx % 2 == 0;
                  final isMale =
                      cow.gender.toUpperCase() == 'M' ||
                      cow.gender.toLowerCase() == 'male';

                  return pw.TableRow(
                    decoration: isEven
                        ? null
                        : pw.BoxDecoration(color: PdfColor.fromHex('#FBFDFB')),
                    children: [
                      _tableBodyCell(
                        '${idx + 1}',
                        font: thaiFont,
                        align: pw.TextAlign.center,
                      ),
                      _tableBodyCell(
                        cow.tagNumber.isNotEmpty ? cow.tagNumber : cow.id,
                        font: thaiFontBold,
                        isBold: true,
                      ),
                      _tableBodyCell(cow.name, font: thaiFont),
                      _tableBodyCell(cow.displayTypeName, font: thaiFont),
                      _tableBodyCell(bName, font: thaiFont),
                      _tableBodyCell(
                        isMale ? 'ผู้' : 'เมีย',
                        font: thaiFont,
                        align: pw.TextAlign.center,
                      ),
                      _tableBodyCell(
                        _formatWeight(cow.latestWeight),
                        font: thaiFont,
                        align: pw.TextAlign.right,
                      ),
                      _tableBodyCell(zName, font: thaiFont),
                      _tableBodyCell(
                        cow.status.label,
                        font: thaiFont,
                        align: pw.TextAlign.center,
                      ),
                      _tableBodyCell(
                        estVal > 0 ? _formatPrice(estVal) : '-',
                        font: thaiFontBold,
                        align: pw.TextAlign.right,
                        isBold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),

            // Summary Bottom Note
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: cardBgColor,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      shapeThai(
                        '* มูลค่าประเมินคำนวณจากน้ำหนักตัวคูณราคาตลาดกลาง ณ วันที่ออกรายงาน (กรมปศุสัตว์ / สศก.)',
                      ),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: textMutedColor,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text(
                    shapeThai(
                      'รวมมูลค่าวัวทั้งฟาร์ม: ${_formatPrice(totalHerdAssetValue)}',
                    ),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  // ────────────────────────────────────────────────────────
  //  UI Building Helpers
  // ────────────────────────────────────────────────────────
  static String _formatWeight(double weight) {
    if (weight <= 0) return '-';
    return NumberFormat('#,##0.0').format(weight);
  }

  static String _formatPrice(double price) {
    if (price == 0) return '0 บาท';
    return '${NumberFormat('#,##0').format(price)} บาท';
  }

  /// Shapes Thai Unicode text to use Thai PUA glyphs (level-2 elevated tone marks and narrow ascender-shifted glyphs)
  static String shapeThai(String text) {
    if (text.isEmpty) return text;

    const upperVowels = {
      0x0E31,
      0x0E34,
      0x0E35,
      0x0E36,
      0x0E37,
      0x0E47,
      0x0E4D,
    };
    const toneMarks = {0x0E48, 0x0E49, 0x0E4A, 0x0E4B, 0x0E4C};
    const ascenderConsonants = {
      0x0E1B,
      0x0E1C,
      0x0E1D,
      0x0E1F,
      0x0E2C,
    }; // ป ผ ฝ ฟ ฬ
    const descenderConsonants = {0x0E0E, 0x0E0F}; // ฎ ฏ
    const lowerVowels = {0x0E38, 0x0E39, 0x0E3A}; // ุ ู ฺ

    // Tone mark -> small (level 2, above upper vowel e.g. ตั้ง, ซื้อ, อื่น, ทั้ง)
    const toneToSmall = {
      0x0E48: 0xF70A, // Mai Ek small
      0x0E49: 0xF70B, // Mai Tho small
      0x0E4A: 0xF70C, // Mai Tri small
      0x0E4B: 0xF70D, // Mai Chattawa small
      0x0E4C: 0xF70E, // Thanthakhat small
    };

    // Tone mark -> narrow (shifted left, after ascender consonant e.g. ป่วย, ผู้)
    const toneToNarrow = {
      0x0E48: 0xF705, // Mai Ek narrow
      0x0E49: 0xF706, // Mai Tho narrow
      0x0E4A: 0xF707, // Mai Tri narrow
      0x0E4B: 0xF708, // Mai Chattawa narrow
      0x0E4C: 0xF709, // Thanthakhat narrow
    };

    // Upper vowel -> narrow (shifted left, after ascender consonant e.g. ปี่, ฝึ)
    const vowelToNarrow = {
      0x0E47: 0xF700, // Mai Tai Khu narrow
      0x0E34: 0xF701, // Sara I narrow
      0x0E35: 0xF702, // Sara Ii narrow
      0x0E36: 0xF703, // Sara Ue narrow
      0x0E37: 0xF704, // Sara Uee narrow
      0x0E4D: 0xF70F, // Nikhahit narrow
      0x0E31: 0xF710, // Mai Han-Akat narrow
    };

    // Lower vowel -> small (shifted down, below descender consonant)
    const lowerToSmall = {
      0x0E38: 0xF718, // Sara U small
      0x0E39: 0xF719, // Sara Uu small
      0x0E3A: 0xF71A, // Phinthu small
    };

    final runes = text.runes.toList();
    final result = <int>[];

    for (int i = 0; i < runes.length; i++) {
      final c = runes[i];

      // 1. Tone mark following upper vowel (Consonant + Upper Vowel + Tone Mark)
      if (toneMarks.contains(c) &&
          i > 0 &&
          upperVowels.contains(runes[i - 1])) {
        result.add(toneToSmall[c] ?? c);
        continue;
      }

      // 2. Tone mark directly on ascender consonant (e.g. ป่วย, ผู้)
      if (toneMarks.contains(c) &&
          i > 0 &&
          ascenderConsonants.contains(runes[i - 1])) {
        result.add(toneToNarrow[c] ?? c);
        continue;
      }

      // 3. Upper vowel on ascender consonant (e.g. ปิ, ปั)
      if (upperVowels.contains(c) &&
          i > 0 &&
          ascenderConsonants.contains(runes[i - 1])) {
        result.add(vowelToNarrow[c] ?? c);
        continue;
      }

      // 4. Lower vowel below descender consonant (e.g. ฎุ, ฏู)
      if (lowerVowels.contains(c) &&
          i > 0 &&
          descenderConsonants.contains(runes[i - 1])) {
        result.add(lowerToSmall[c] ?? c);
        continue;
      }

      result.add(c);
    }

    return String.fromCharCodes(result);
  }

  static pw.Widget _buildThaiText(
    String text, {
    required pw.Font font,
    double fontSize = 8,
    PdfColor? color,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
    int? maxLines,
  }) {
    return pw.Text(
      shapeThai(text),
      style: pw.TextStyle(
        font: font,
        fontSize: fontSize,
        color: color ?? PdfColor.fromHex('#1E2A1B'),
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      textAlign: align,
      maxLines: maxLines,
    );
  }

  static pw.Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subValue,
    required PdfColor bgColor,
    required PdfColor borderColor,
    required PdfColor textColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            shapeThai(title),
            style: pw.TextStyle(
              fontSize: 9.5,
              color: PdfColor.fromHex('#6A7B66'),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            shapeThai(value),
            style: pw.TextStyle(
              fontSize: 13.5,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            shapeThai(subValue),
            style: pw.TextStyle(
              fontSize: 7.5,
              color: PdfColor.fromHex('#8A9986'),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderCell(
    String text, {
    required pw.Font font,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 3.5),
      child: _buildThaiText(
        text,
        font: font,
        fontSize: 7.5,
        isBold: true,
        align: align,
        color: PdfColor.fromHex('#263821'),
      ),
    );
  }

  static pw.Widget _tableBodyCell(
    String text, {
    required pw.Font font,
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 3.5),
      child: _buildThaiText(
        text,
        font: font,
        fontSize: 7,
        isBold: isBold,
        align: align,
        color: color ?? PdfColor.fromHex('#1E2A1B'),
      ),
    );
  }

  static String _getThaiMonth(int month) {
    const months = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    if (month >= 1 && month <= 12) return months[month];
    return '';
  }
}
