import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cowsmart/features/farm/domain/farm.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/breed.dart';
import 'package:cowsmart/features/farm/domain/zone.dart';
import 'package:cowsmart/features/market/providers/market_price_provider.dart';
import 'package:cowsmart/features/farm/services/farm_pdf_export_service.dart';
import 'package:cowsmart/features/cow/services/group_qr_pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate and rasterize farm overview PDF', () async {
    final farm = Farm(
      id: 'farm-1',
      ownerEmail: 'user@example.com',
      name: 'ฟาร์มวัวตัวอย่าง โคสมาร์ท',
      address: 'ขอนแก่น',
    );

    final breeds = [
      Breed(id: 'b1', name: 'บราห์มันเบอร์แดง'),
      Breed(id: 'b2', name: 'ชาโรเลส์'),
      Breed(id: 'b3', name: 'แองกัส'),
      Breed(id: 'b4', name: 'วัวพื้นเมืองไทย'),
      Breed(id: 'b5', name: 'ตาก'),
    ];

    final zones = [
      Zone(id: 'z1', name: 'โซนพ่อพันธุ์', farmId: 'farm-1'),
      Zone(id: 'z2', name: 'โซนแม่พันธุ์', farmId: 'farm-1'),
      Zone(id: 'z3', name: 'โซนวัวขุน', farmId: 'farm-1'),
      Zone(id: 'z4', name: 'โซนพยาบาล', farmId: 'farm-1'),
      Zone(id: 'z5', name: 'โซนลูกวัว', farmId: 'farm-1'),
    ];

    final cows = <Cow>[
      Cow(
        id: '1',
        farmId: 'farm-1',
        zoneId: 'z1',
        tagNumber: 'A08',
        name: 'บราโว่',
        birthDate: DateTime(2022, 1, 1),
        breed: 'b1',
        gender: 'M',
        type: CowType.breederMale,
        latestWeight: 614.50,
        purchasePrice: 40000.00,
        status: CowStatus.normal,
      ),
      Cow(
        id: '2',
        farmId: 'farm-1',
        zoneId: 'z2',
        tagNumber: 'B01',
        name: 'สร้อยทอง',
        birthDate: DateTime(2021, 5, 10),
        breed: 'b1',
        gender: 'F',
        type: CowType.breederFemale,
        latestWeight: 490.25,
        purchasePrice: 35000.00,
        status: CowStatus.pregnant,
      ),
      Cow(
        id: '3',
        farmId: 'farm-1',
        zoneId: 'z3',
        tagNumber: 'A01',
        name: 'พลายแก้ว',
        birthDate: DateTime(2023, 2, 15),
        breed: 'b3',
        gender: 'M',
        type: CowType.fattening,
        latestWeight: 400.00,
        purchasePrice: 50000.00,
        status: CowStatus.normal,
      ),
      Cow(
        id: '4',
        farmId: 'farm-1',
        zoneId: 'z3',
        tagNumber: 'A02',
        name: 'ยอดขุนพล',
        birthDate: DateTime(2023, 3, 20),
        breed: 'b2',
        gender: 'M',
        type: CowType.fattening,
        latestWeight: 430.75,
        purchasePrice: 30000.00,
        status: CowStatus.normal,
      ),
      Cow(
        id: '5',
        farmId: 'farm-1',
        zoneId: 'z2',
        tagNumber: 'B03',
        name: 'แสงบุญ',
        birthDate: DateTime(2022, 8, 12),
        breed: 'b2',
        gender: 'F',
        type: CowType.breederFemale,
        latestWeight: 430.00,
        purchasePrice: 30000.00,
        status: CowStatus.sick,
      ),
    ];

    final marketState = MarketPriceState();

    final pdfBytes = await FarmPdfExportService.generateFarmOverviewPdf(
      farm: farm,
      cows: cows,
      breeds: breeds,
      zones: zones,
      marketState: marketState,
      totalIncome: 125000.50,
      totalExpense: 45000.00,
      netBalance: 80000.50,
      issuedBy: 'สมชาย ใจดี',
    );

    expect(pdfBytes.isNotEmpty, true);

    // Save PDF to file for verification
    final outFile = File('test_output.pdf');
    await outFile.writeAsBytes(pdfBytes);
    print('PDF saved to ${outFile.path}, bytes: ${pdfBytes.length}');
  });

  test('generate group QR PDF without font errors', () async {
    final farm = Farm(
      id: 'farm-1',
      ownerEmail: 'user@example.com',
      name: 'ฟาร์มยินดี',
      address: 'ขอนแก่น',
    );

    final breeds = [
      Breed(id: 'b1', name: 'บราห์มันเบอร์แดง'),
      Breed(id: 'b2', name: 'ชาโรเลส์'),
      Breed(id: 'b3', name: 'แองกัส'),
    ];

    final cows = <Cow>[
      Cow(
        id: '1',
        farmId: 'farm-1',
        zoneId: 'z1',
        tagNumber: 'A08',
        name: 'บราโว่',
        birthDate: DateTime(2022, 1, 1),
        breed: 'b1',
        gender: 'M',
        type: CowType.breederMale,
        latestWeight: 614.50,
        purchasePrice: 40000,
        status: CowStatus.normal,
      ),
      Cow(
        id: '2',
        farmId: 'farm-1',
        zoneId: 'z2',
        tagNumber: 'B01',
        name: 'สร้อยทอง',
        birthDate: DateTime(2021, 5, 10),
        breed: 'b1',
        gender: 'F',
        type: CowType.breederFemale,
        latestWeight: 490.25,
        purchasePrice: 35000,
        status: CowStatus.pregnant,
      ),
      Cow(
        id: '3',
        farmId: 'farm-1',
        zoneId: 'z3',
        tagNumber: 'A01',
        name: 'พลายแก้ว',
        birthDate: DateTime(2023, 2, 15),
        breed: 'b3',
        gender: 'M',
        type: CowType.fattening,
        latestWeight: 400.00,
        purchasePrice: 50000,
        status: CowStatus.normal,
      ),
      Cow(
        id: '4',
        farmId: 'farm-1',
        zoneId: 'z3',
        tagNumber: 'A02',
        name: 'ยอดขุนพล',
        birthDate: DateTime(2023, 3, 20),
        breed: 'b2',
        gender: 'M',
        type: CowType.fattening,
        latestWeight: 430.75,
        purchasePrice: 30000,
        status: CowStatus.normal,
      ),
    ];

    final qrPdfBytes = await GroupQrPdfExportService.generateGroupQrPdf(
      farm: farm,
      cows: cows,
      breeds: breeds,
    );

    expect(qrPdfBytes.isNotEmpty, true);
    final qrOutFile = File('test_group_qr.pdf');
    await qrOutFile.writeAsBytes(qrPdfBytes);
    print('Group QR PDF saved to ${qrOutFile.path}, bytes: ${qrPdfBytes.length}');
  });
}
