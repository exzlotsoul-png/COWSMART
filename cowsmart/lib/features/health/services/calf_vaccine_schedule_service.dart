import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';

class CalfVaccineScheduleItem {
  final String vaccineId;
  final String vaccineName;
  final String doseLabel;
  final String recommendedAgeLabel;
  final int daysAfterBirth;
  DateTime scheduledDate;
  final String targetGender; // 'all' or 'female'
  bool isSelected;

  CalfVaccineScheduleItem({
    required this.vaccineId,
    required this.vaccineName,
    required this.doseLabel,
    required this.recommendedAgeLabel,
    required this.daysAfterBirth,
    required this.scheduledDate,
    required this.targetGender,
    this.isSelected = true,
  });

  /// Description text used when saving the appointment
  String get appointmentDescription =>
      'ฉีดวัคซีน: $vaccineName - $doseLabel';

  CalfVaccineScheduleItem copyWith({
    String? vaccineId,
    String? vaccineName,
    String? doseLabel,
    String? recommendedAgeLabel,
    int? daysAfterBirth,
    DateTime? scheduledDate,
    String? targetGender,
    bool? isSelected,
  }) {
    return CalfVaccineScheduleItem(
      vaccineId: vaccineId ?? this.vaccineId,
      vaccineName: vaccineName ?? this.vaccineName,
      doseLabel: doseLabel ?? this.doseLabel,
      recommendedAgeLabel: recommendedAgeLabel ?? this.recommendedAgeLabel,
      daysAfterBirth: daysAfterBirth ?? this.daysAfterBirth,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      targetGender: targetGender ?? this.targetGender,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class CalfVaccineScheduleService {
  /// ตรวจสอบว่านัดหมายนี้เคยถูกตั้งไว้แล้วหรือยัง
  static bool isAlreadyScheduled(
    CalfVaccineScheduleItem item,
    List<dynamic> existingAppointments,
  ) {
    return existingAppointments.any((appt) {
      final desc = (appt is Map ? appt['description'] : appt.description)?.toString() ?? '';
      // Check exact match with standard description
      if (desc == item.appointmentDescription) return true;
      // Or check if description contains both vaccine name and dose label
      final containsVaccine = desc.contains(item.vaccineName) ||
          (item.vaccineId == 'VAC001' && desc.contains('ปากและเท้าเปื่อย')) ||
          (item.vaccineId == 'VAC002' && desc.contains('แบล็คเลก')) ||
          (item.vaccineId == 'VAC003' && desc.contains('บรูเซลโลซิส')) ||
          (item.vaccineId == 'VAC004' && desc.contains('เฮโมรายิก') || desc.contains('คอบวม'));

      final isBoosterItem = item.doseLabel.contains('กระตุ้น') || item.doseLabel.contains('Booster');
      final descIsBooster = desc.contains('กระตุ้น') || desc.contains('Booster');

      if (containsVaccine) {
        if (isBoosterItem == descIsBooster) {
          return true;
        }
      }
      return false;
    });
  }

  /// กรองเฉพาะรายการที่ยังไม่ได้ถูกนัดหมาย
  static List<CalfVaccineScheduleItem> filterRemainingSchedule({
    required List<CalfVaccineScheduleItem> allItems,
    required List<dynamic> existingAppointments,
  }) {
    return allItems.where((item) {
      return !isAlreadyScheduled(item, existingAppointments);
    }).toList();
  }
  /// คำนวณตารางวัคซีนมาตรฐานตามเกณฑ์กรมปศุสัตว์สำหรับลูกวัว
  static List<CalfVaccineScheduleItem> generateSchedule({
    required DateTime birthDate,
    required String gender, // 'male' / 'female' / 'ผู้' / 'เมีย'
  }) {
    final cleanBirth = DateTime(birthDate.year, birthDate.month, birthDate.day, 9, 0);
    final isFemale = gender.toLowerCase() == 'female' ||
        gender.toLowerCase() == 'f' ||
        gender == 'เมีย' ||
        gender.contains('เมีย');

    final List<CalfVaccineScheduleItem> allItems = [
      // 1. Blackleg dose 1 (2 months / 60 days)
      CalfVaccineScheduleItem(
        vaccineId: 'VAC002',
        vaccineName: 'วัคซีนแบล็คเลก (Blackleg)',
        doseLabel: 'เข็มที่ 1 (ป้องกันโรคไข้ขาบวม)',
        recommendedAgeLabel: 'อายุ 2 เดือน (60 วัน)',
        daysAfterBirth: 60,
        scheduledDate: cleanBirth.add(const Duration(days: 60)),
        targetGender: 'all',
        isSelected: true,
      ),

      // 2. Brucellosis (3 months / 90 days) - เฉพาะเพศเมียเท่านั้น
      CalfVaccineScheduleItem(
        vaccineId: 'VAC003',
        vaccineName: 'วัคซีนบรูเซลโลซิส (Brucellosis)',
        doseLabel: 'เข็มเดียวตลอดชีวิต (ป้องกันโรคแท้งติดต่อ)',
        recommendedAgeLabel: 'อายุ 3-4 เดือน (90 วัน)',
        daysAfterBirth: 90,
        scheduledDate: cleanBirth.add(const Duration(days: 90)),
        targetGender: 'female',
        isSelected: isFemale,
      ),

      // 3. FMD dose 1 (4 months / 120 days)
      CalfVaccineScheduleItem(
        vaccineId: 'VAC001',
        vaccineName: 'วัคซีนปากและเท้าเปื่อย (FMD)',
        doseLabel: 'เข็มที่ 1 (ป้องกันโรคปากและเท้าเปื่อย)',
        recommendedAgeLabel: 'อายุ 4 เดือน (120 วัน)',
        daysAfterBirth: 120,
        scheduledDate: cleanBirth.add(const Duration(days: 120)),
        targetGender: 'all',
        isSelected: true,
      ),

      // 4. Haemorrhagic Septicaemia (4 months / 120 days)
      CalfVaccineScheduleItem(
        vaccineId: 'VAC004',
        vaccineName: 'วัคซีนเฮโมรายิกเซปทิซีเมีย (คอบวม)',
        doseLabel: 'เข็มที่ 1 (ป้องกันโรคคอบวม)',
        recommendedAgeLabel: 'อายุ 4 เดือน (120 วัน)',
        daysAfterBirth: 120,
        scheduledDate: cleanBirth.add(const Duration(days: 120)),
        targetGender: 'all',
        isSelected: true,
      ),

      // 5. FMD Booster (5 months / 150 days)
      CalfVaccineScheduleItem(
        vaccineId: 'VAC001',
        vaccineName: 'วัคซีนปากและเท้าเปื่อย (FMD)',
        doseLabel: 'เข็มกระตุ้น (Booster)',
        recommendedAgeLabel: 'อายุ 5 เดือน (150 วัน)',
        daysAfterBirth: 150,
        scheduledDate: cleanBirth.add(const Duration(days: 150)),
        targetGender: 'all',
        isSelected: true,
      ),

      // 6. Blackleg Booster (6 months / 180 days)
      CalfVaccineScheduleItem(
        vaccineId: 'VAC002',
        vaccineName: 'วัคซีนแบล็คเลก (Blackleg)',
        doseLabel: 'เข็มกระตุ้น (Booster)',
        recommendedAgeLabel: 'อายุ 6 เดือน (180 วัน)',
        daysAfterBirth: 180,
        scheduledDate: cleanBirth.add(const Duration(days: 180)),
        targetGender: 'all',
        isSelected: true,
      ),
    ];

    // กรองออกหากรายการนั้นกำหนดเฉพาะเพศเมียแต่ลูกวัวเป็นเพศผู้
    return allItems.where((item) {
      if (item.targetGender == 'female' && !isFemale) {
        return false;
      }
      return true;
    }).toList();
  }

  /// บันทึกรายการนัดหมายที่เลือกเข้าสู่ระบบ API
  static Future<int> saveAppointments({
    required ApiClient api,
    required String cowId,
    required List<CalfVaccineScheduleItem> items,
    required String reminderSetting,
  }) async {
    int savedCount = 0;
    final selectedItems = items.where((i) => i.isSelected).toList();

    for (final item in selectedItems) {
      try {
        final fullDescription = 'ฉีดวัคซีน: ${item.vaccineName} - ${item.doseLabel}';
        await api.post('/health_appointments', data: {
          'cow_id': cowId,
          'appoint_datetime': item.scheduledDate.toIso8601String(),
          'description': fullDescription,
          'reminder_setting': reminderSetting,
          'status': 0,
        });
        savedCount++;
      } catch (e) {
        debugPrint('[CalfVaccineScheduleService] บันทึกนัดหมาย ${item.vaccineName} ไม่สำเร็จ: $e');
      }
    }

    return savedCount;
  }
}
