import 'package:flutter_test/flutter_test.dart';
import 'package:cowsmart/features/health/services/calf_vaccine_schedule_service.dart';

void main() {
  test('CalfVaccineScheduleService generateSchedule defaults isSelected to false', () {
    final schedule = CalfVaccineScheduleService.generateSchedule(
      birthDate: DateTime.now().subtract(const Duration(days: 30)),
      gender: 'female',
    );

    expect(schedule.isNotEmpty, true);
    // All items should have isSelected == false initially
    for (final item in schedule) {
      expect(item.isSelected, false, reason: '${item.vaccineName} should not be selected by default');
    }
  });

  test('CalfVaccineScheduleService male calf excludes brucellosis and defaults to false', () {
    final schedule = CalfVaccineScheduleService.generateSchedule(
      birthDate: DateTime.now().subtract(const Duration(days: 30)),
      gender: 'male',
    );

    expect(schedule.isNotEmpty, true);
    expect(schedule.any((i) => i.vaccineId == 'VAC003'), false);
    for (final item in schedule) {
      expect(item.isSelected, false);
    }
  });
}
