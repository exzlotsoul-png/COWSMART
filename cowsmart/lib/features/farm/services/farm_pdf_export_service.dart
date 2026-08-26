import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

    final fileName = 'รายงานสรุป_${farm.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    // 1. Direct file save & auto-open for Desktop (Windows / macOS / Linux) using pure Dart
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

    // 2. Safe Printing preview with graceful fallback
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
      );
    } catch (e) {
      debugPrint('Printing.layoutPdf fallback: $e');
      // If on mobile and Printing failed, try saving to temp/documents
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

    // Load Google Fonts Sarabun for Thai language support
    final thaiFont = await PdfGoogleFonts.sarabunRegular();
    final thaiFontBold = await PdfGoogleFonts.sarabunBold();
    final thaiFontItalic = await PdfGoogleFonts.sarabunItalic();

    final theme = pw.ThemeData.withFont(
      base: thaiFont,
      bold: thaiFontBold,
      italic: thaiFontItalic,
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
    final formattedDate = '${now.day} ${_getThaiMonth(now.month)} $thaiYear  ${DateFormat('HH:mm').format(now)} น.';

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
      } else if (cow.status == CowStatus.pregnant || cow.status == CowStatus.estrous) {
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
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                                    'รายงานสรุปภาพรวมฟาร์ม',
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
                                'ฟาร์ม: ${farm.name} (รหัส: ${farm.id})',
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
                        'วันที่พิมพ์: $formattedDate',
                        style: pw.TextStyle(fontSize: 9.5, color: textMutedColor),
                      ),
                      if (issuedBy != null && issuedBy.isNotEmpty)
                        pw.Text(
                          'ผู้จัดทำ: $issuedBy',
                          style: pw.TextStyle(fontSize: 9.5, color: textMutedColor),
                        ),
                      pw.Text(
                        'หน้า ${context.pageNumber} จาก ${context.pagesCount}',
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
                        'COWSMART — ระบบบริหารจัดการฟาร์มโคอัจฉริยะ',
                        style: pw.TextStyle(fontSize: 8.5, color: textMutedColor),
                      ),
                    ],
                  ),
                  pw.Text(
                    'เอกสารสรุปภาพรวมฟาร์มอย่างเป็นทางการ',
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
              '1. สรุปภาพรวมทรัพยากรและสินทรัพย์ฟาร์ม (Executive Summary)',
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
                    value: '฿${numberFormat.format(totalHerdAssetValue)}',
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
                    value: '฿${numberFormat.format(netBalance)}',
                    subValue: 'รายรับ ฿${numberFormat.format(totalIncome)} | รายจ่าย ฿${numberFormat.format(totalExpense)}',
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
                        '2. สัดส่วนและมูลค่าแยกตามสายพันธุ์ (Breeds)',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Table(
                        border: pw.TableBorder.all(color: borderColor, width: 0.6),
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: headerBgColor),
                            children: [
                              _tableHeaderCell('สายพันธุ์'),
                              _tableHeaderCell('จำนวน (ตัว)', align: pw.TextAlign.center),
                              _tableHeaderCell('สัดส่วน (%)', align: pw.TextAlign.center),
                              _tableHeaderCell('มูลค่าประเมิน (฿)', align: pw.TextAlign.right),
                            ],
                          ),
                          ...breedCountMap.entries.map((e) {
                            final pct = totalCows > 0 ? (e.value / totalCows * 100).toStringAsFixed(1) : '0';
                            final val = breedValueMap[e.key] ?? 0.0;
                            return pw.TableRow(
                              children: [
                                _tableBodyCell(e.key),
                                _tableBodyCell(numberFormat.format(e.value), align: pw.TextAlign.center),
                                _tableBodyCell('$pct%', align: pw.TextAlign.center),
                                _tableBodyCell('฿${numberFormat.format(val)}', align: pw.TextAlign.right),
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
                        '3. สถานะสุขภาพและการกระจายในฟาร์ม',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Table(
                        border: pw.TableBorder.all(color: borderColor, width: 0.6),
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: headerBgColor),
                            children: [
                              _tableHeaderCell('หมวดหมู่ / สถานะ'),
                              _tableHeaderCell('จำนวน (ตัว)', align: pw.TextAlign.center),
                              _tableHeaderCell('สัดส่วน', align: pw.TextAlign.right),
                            ],
                          ),
                          pw.TableRow(children: [
                            _tableBodyCell('สุขภาพปกติ (Normal)'),
                            _tableBodyCell('$normalCount', align: pw.TextAlign.center),
                            _tableBodyCell(totalCows > 0 ? '${(normalCount / totalCows * 100).toStringAsFixed(0)}%' : '0%', align: pw.TextAlign.right),
                          ]),
                          pw.TableRow(children: [
                            _tableBodyCell('ป่วย / บาดเจ็บ (Sick/Injured)'),
                            _tableBodyCell('$sickCount', align: pw.TextAlign.center),
                            _tableBodyCell(totalCows > 0 ? '${(sickCount / totalCows * 100).toStringAsFixed(0)}%' : '0%', align: pw.TextAlign.right),
                          ]),
                          pw.TableRow(children: [
                            _tableBodyCell('ตั้งท้อง / เป็นสัด (Pregnant)'),
                            _tableBodyCell('$pregnantCount', align: pw.TextAlign.center),
                            _tableBodyCell(totalCows > 0 ? '${(pregnantCount / totalCows * 100).toStringAsFixed(0)}%' : '0%', align: pw.TextAlign.right),
                          ]),
                          pw.TableRow(children: [
                            _tableBodyCell('สถานะอื่นๆ / พักฟื้น (Other)'),
                            _tableBodyCell('$otherStatusCount', align: pw.TextAlign.center),
                            _tableBodyCell(totalCows > 0 ? '${(otherStatusCount / totalCows * 100).toStringAsFixed(0)}%' : '0%', align: pw.TextAlign.right),
                          ]),
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
              '4. บัญชีรายชื่อและมูลค่าประเมินวัวในฟาร์ม (Cattle Inventory Roster)',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),

            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.6),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerBgColor),
                  children: [
                    _tableHeaderCell('#', align: pw.TextAlign.center),
                    _tableHeaderCell('เบอร์หู (Tag)'),
                    _tableHeaderCell('ชื่อวัว'),
                    _tableHeaderCell('สายพันธุ์'),
                    _tableHeaderCell('เพศ', align: pw.TextAlign.center),
                    _tableHeaderCell('น้ำหนัก (กก.)', align: pw.TextAlign.right),
                    _tableHeaderCell('โซน/คอก'),
                    _tableHeaderCell('สถานะ', align: pw.TextAlign.center),
                    _tableHeaderCell('ราคาประเมิน (฿)', align: pw.TextAlign.right),
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
                  final isMale = cow.gender.toUpperCase() == 'M' || cow.gender.toLowerCase() == 'male';

                  return pw.TableRow(
                    decoration: isEven ? null : pw.BoxDecoration(color: PdfColor.fromHex('#FBFDFB')),
                    children: [
                      _tableBodyCell('${idx + 1}', align: pw.TextAlign.center),
                      _tableBodyCell(cow.tagNumber.isNotEmpty ? cow.tagNumber : cow.id, isBold: true),
                      _tableBodyCell(cow.name),
                      _tableBodyCell(bName),
                      _tableBodyCell(isMale ? 'ผู้' : 'เมีย', align: pw.TextAlign.center),
                      _tableBodyCell(cow.latestWeight > 0 ? cow.latestWeight.toStringAsFixed(0) : '-', align: pw.TextAlign.right),
                      _tableBodyCell(zName),
                      _tableBodyCell(cow.status.label, align: pw.TextAlign.center),
                      _tableBodyCell(estVal > 0 ? '฿${numberFormat.format(estVal)}' : '-', align: pw.TextAlign.right, isBold: true),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),

            // Summary Bottom Note
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: cardBgColor,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '* มูลค่าประเมินคำนวณจากน้ำหนักตัวคูณราคาตลาดกลาง ณ วันที่ออกรายงาน (กรมปศุสัตว์ / สศก.)',
                    style: pw.TextStyle(fontSize: 8.5, color: textMutedColor, fontStyle: pw.FontStyle.italic),
                  ),
                  pw.Text(
                    'รวมมูลค่าวัวทั้งฟาร์ม: ฿${numberFormat.format(totalHerdAssetValue)}',
                    style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
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
            title,
            style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#6A7B66'), fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subValue,
            style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#8A9986')),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#263821'),
        ),
      ),
    );
  }

  static pw.Widget _tableBodyCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColor.fromHex('#1E2A1B'),
        ),
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
      'ธันวาคม'
    ];
    if (month >= 1 && month <= 12) return months[month];
    return '';
  }
}
