import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/theme/app_theme.dart';
import 'package:cowsmart/features/cow/presentation/screens/group_qr_screen.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/breed.dart';
import 'package:cowsmart/features/farm/domain/farm.dart';
import 'package:cowsmart/features/farm/domain/zone.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';

void main() {
  testWidgets('Test GroupQrScreen full workflow with AppTheme and cows', (WidgetTester tester) async {
    final mockCow1 = Cow(
      id: 'C029',
      farmId: 'F003',
      zoneId: 'Z005',
      name: 'ขุนศึก',
      tagNumber: 'A06',
      birthDate: DateTime(2022, 1, 1),
      gender: 'M',
      type: CowType.fattening,
      breed: 'B011',
      status: CowStatus.normal,
      latestWeight: 500,
      purchasePrice: 50000,
    );

    final mockCow2 = Cow(
      id: 'C030',
      farmId: 'F003',
      zoneId: 'Z005',
      name: 'มะลิ',
      tagNumber: 'B02',
      birthDate: DateTime(2021, 5, 10),
      gender: 'F',
      type: CowType.breederFemale,
      breed: 'B012',
      status: CowStatus.normal,
      latestWeight: 420,
      purchasePrice: 45000,
    );

    final mockFarm = Farm(
      id: 'F003',
      ownerEmail: 'test@example.com',
      name: 'ฟาร์มทดสอบ',
      address: 'กรุงเทพ',
    );

    final mockZone = Zone(
      id: 'Z005',
      farmId: 'F003',
      name: 'โซน A',
      cowCount: 2,
    );

    final mockBreed = Breed(
      id: 'B011',
      name: 'บราห์มัน',
    );

    final container = ProviderContainer(
      overrides: [
        farmProvider.overrideWith(() => _MockFarmNotifier(mockFarm)),
        zoneProvider.overrideWith(() => _MockZoneNotifier([mockZone])),
        breedProvider.overrideWith(() => _MockBreedNotifier([mockBreed])),
        cowProvider.overrideWith(() => _MockCowNotifier([mockCow1, mockCow2])),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GroupQrScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('สร้าง QR Code กลุ่ม'), findsOneWidget);

    // Verify Cow List items
    expect(find.text('ขุนศึก'), findsOneWidget);
    expect(find.text('มะลิ'), findsOneWidget);
    expect(find.text('พบวัวทั้งหมด 2 ตัว'), findsOneWidget);

    // Tap "เลือกทั้งหมด"
    await tester.tap(find.text('เลือกทั้งหมด'));
    await tester.pumpAndSettle();

    // Verify selection count updated
    expect(find.text('เลือกแล้ว 2 ตัว'), findsWidgets);
    expect(find.text('พิมพ์ QR (2)'), findsOneWidget);

    // Tap single cow to uncheck
    await tester.tap(find.text('ขุนศึก'));
    await tester.pumpAndSettle();

    expect(find.text('เลือกแล้ว 1 ตัว'), findsWidgets);
    expect(find.text('พิมพ์ QR (1)'), findsOneWidget);
  });
}

class _MockFarmNotifier extends FarmNotifier {
  final Farm? mockFarm;
  _MockFarmNotifier(this.mockFarm);

  @override
  FarmState build() {
    return FarmState(currentFarm: mockFarm, farms: mockFarm != null ? [mockFarm!] : []);
  }

  @override
  Future<void> fetchFarms() async {}
}

class _MockZoneNotifier extends ZoneNotifier {
  final List<Zone> initialZones;
  _MockZoneNotifier(this.initialZones);

  @override
  ZoneState build() {
    return ZoneState(zones: initialZones, isLoaded: true);
  }

  @override
  Future<void> fetchZones(String farmId) async {}
}

class _MockBreedNotifier extends BreedNotifier {
  final List<Breed> initialBreeds;
  _MockBreedNotifier(this.initialBreeds);

  @override
  List<Breed> build() {
    return initialBreeds;
  }

  @override
  Future<void> fetchBreeds() async {}
}

class _MockCowNotifier extends CowNotifier {
  final List<Cow> initialCows;
  _MockCowNotifier(this.initialCows);

  @override
  CowState build() {
    return CowState(allCows: initialCows, isLoaded: true);
  }

  @override
  Future<void> fetchCows(String farmId) async {}
}
