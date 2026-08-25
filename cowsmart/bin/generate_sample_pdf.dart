import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

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

void main() async {
  print('Generating PDF with Logo...');
  final doc = pw.Document();

  // Palette
  final primaryColor = PdfColor.fromHex('#334A2E');
  final secondaryColor = PdfColor.fromHex('#4B6344');
  final headerBgColor = PdfColor.fromHex('#EAF2EA');
  final cardBgColor = PdfColor.fromHex('#F8FAF7');
  final borderColor = PdfColor.fromHex('#D8E2D6');
  final textDarkColor = PdfColor.fromHex('#1B2618');
  final textMutedColor = PdfColor.fromHex('#5E6E5A');
  final greenColor = PdfColor.fromHex('#1E7E34');

  final now = DateTime.now();
  final thaiYear = now.year + 543;
  final formattedDate = '${now.day} สิงหาคม $thaiYear  ${DateFormat('HH:mm').format(now)} น.';

  doc.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
      ),
      header: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
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
                          'ฟาร์ม: ฟาร์มยินดี (รหัส: F003)',
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
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'วันที่พิมพ์: $formattedDate',
                      style: pw.TextStyle(fontSize: 9.5, color: textMutedColor),
                    ),
                    pw.Text(
                      'ผู้จัดทำ: ธนภัทร เตียนต๊ะนันท์',
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
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    color: cardBgColor,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: borderColor, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('จำนวนวัวทั้งหมด', style: pw.TextStyle(fontSize: 9.5, color: textMutedColor, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('13 ตัว', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('จำแนกใน 5 โซน/คอก', style: pw.TextStyle(fontSize: 7.5, color: textMutedColor)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    color: cardBgColor,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: borderColor, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('มูลค่าประเมินฝูงวัวรวม', style: pw.TextStyle(fontSize: 9.5, color: textMutedColor, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('฿295,213', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: greenColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('อิงราคาตลาดกลาง DLD/สศก.', style: pw.TextStyle(fontSize: 7.5, color: textMutedColor)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    color: cardBgColor,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: borderColor, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ผลกำไรสุทธิฟาร์ม', style: pw.TextStyle(fontSize: 9.5, color: textMutedColor, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('฿64,002', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: greenColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('รายรับ ฿65,002 | รายจ่าย ฿1,000', style: pw.TextStyle(fontSize: 7.5, color: textMutedColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),

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
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('สายพันธุ์', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('จำนวน (ตัว)', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('สัดส่วน (%)', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('มูลค่าประเมิน (฿)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('บราห์มัน (Brahman)', style: const pw.TextStyle(fontSize: 8.5))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('6', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('46.2%', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('฿142,500', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
              ]),
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('ชาร์โรเลส์ (Charolais)', style: const pw.TextStyle(fontSize: 8.5))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('4', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('30.8%', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('฿98,400', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
              ]),
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('พื้นเมืองไทย (Thai Native)', style: const pw.TextStyle(fontSize: 8.5))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('3', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('23.0%', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('฿54,313', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
              ]),
            ],
          ),
          pw.SizedBox(height: 18),

          pw.Text(
            '3. บัญชีรายชื่อและมูลค่าประเมินวัวในฟาร์ม (Cattle Inventory Roster)',
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
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('#', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('เบอร์หู (Tag)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('ชื่อวัว', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('สายพันธุ์', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('เพศ', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('น้ำหนัก (กก.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('โซน', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('สถานะ', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('ราคาประเมิน (฿)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...[
                ['1', 'YD-010', 'ขุนศึก', 'บราห์มัน', 'ผู้', '512', 'โซนแปลงหญ้า 1', 'ปกติ', '฿35,681'],
                ['2', 'YD-011', 'สายฟ้า', 'บราห์มัน', 'ผู้', '480', 'โซนคอกขุน A', 'ปกติ', '฿33,451'],
                ['3', 'YD-006', 'แสงบุญ', 'ชาร์โรเลส์', 'เมีย', '430', 'โซนแม่พันธุ์ 1', 'ตั้งท้อง', '฿31,428'],
                ['4', 'YD-001', 'นำโชค', 'บราห์มัน', 'ผู้', '410', 'โซนคอกขุน A', 'ปกติ', '฿28,573'],
                ['5', 'YD-002', 'มั่งมี', 'พื้นเมืองไทย', 'เมีย', '320', 'โซนแม่พันธุ์ 2', 'ปกติ', '฿19,369'],
                ['6', 'YD-003', 'ร่ำรวย', 'พื้นเมืองไทย', 'เมีย', '290', 'โซนแม่พันธุ์ 2', 'ปกติ', '฿17,553'],
                ['7', 'YD-004', 'เงินล้าน', 'ชาร์โรเลส์', 'ผู้', '540', 'โซนคอกพ่อพันธุ์', 'ปกติ', '฿39,468'],
              ].map((row) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[0], textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[1], style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[2], style: const pw.TextStyle(fontSize: 8.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[3], style: const pw.TextStyle(fontSize: 8.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[4], textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[5], textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[6], style: const pw.TextStyle(fontSize: 8.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[7], textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[8], textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 14),

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
                  style: pw.TextStyle(fontSize: 8.5, color: textMutedColor),
                ),
                pw.Text(
                  'รวมมูลค่าวัวทั้งฟาร์ม: ฿295,213.00',
                  style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
          ),
        ];
      },
    ),
  );

  final bytes = await doc.save();
  final outputFile = File('d:\\GIT end project\\COWSMART\\รายงานสรุปภาพรวมฟาร์มยินดี_COWSMART.pdf');
  await outputFile.writeAsBytes(bytes);
  print('Saved PDF with Logo to: ${outputFile.path}');

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null) {
    final dlFile = File('$userProfile\\Downloads\\รายงานสรุปภาพรวมฟาร์มยินดี_COWSMART.pdf');
    await dlFile.writeAsBytes(bytes);
    print('Saved PDF with Logo to Downloads: ${dlFile.path}');
  }
}
