import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/cow.dart';
import '../../../domain/breeding_record.dart';
import '../../../providers/cow_detail_provider.dart';
import '../../../providers/cow_provider.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/features/calendar/providers/appointment_type_provider.dart';
import 'package:go_router/go_router.dart';

// Provider to get male cows (bulls) for breeding
final bullsProvider = Provider<List<Cow>>((ref) {
  final cowState = ref.watch(cowProvider);
  return cowState.allCows
      .where((c) => c.gender == 'M' && c.type == CowType.breederMale)
      .toList();
});

class BreedTab extends ConsumerStatefulWidget {
  final Cow cow;
  const BreedTab({super.key, required this.cow});

  @override
  ConsumerState<BreedTab> createState() => _BreedTabState();
}

class _BreedTabState extends ConsumerState<BreedTab> {
  String _formatCowDisplayById(String? id, List<Cow> allCows) {
    if (id == null || id.isEmpty || id == '-') return '-';
    final ids = id
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (ids.length > 1) {
      return ids
          .map((singleId) {
            final matches = allCows
                .where(
                  (c) =>
                      c.id == singleId ||
                      c.tagNumber == singleId ||
                      c.name == singleId,
                )
                .toList();
            if (matches.isNotEmpty) {
              final cow = matches.first;
              if (cow.name.isNotEmpty &&
                  cow.tagNumber.isNotEmpty &&
                  cow.name != cow.tagNumber) {
                return '${cow.name} (${cow.tagNumber})';
              } else if (cow.name.isNotEmpty) {
                return cow.name;
              } else if (cow.tagNumber.isNotEmpty) {
                return cow.tagNumber;
              }
            }
            return singleId;
          })
          .join(', ');
    }

    final matches = allCows
        .where((c) => c.id == id || c.tagNumber == id || c.name == id)
        .toList();
    if (matches.isNotEmpty) {
      final cow = matches.first;
      if (cow.name.isNotEmpty &&
          cow.tagNumber.isNotEmpty &&
          cow.name != cow.tagNumber) {
        return '${cow.name} (${cow.tagNumber})';
      } else if (cow.name.isNotEmpty) {
        return cow.name;
      } else if (cow.tagNumber.isNotEmpty) {
        return cow.tagNumber;
      }
    }
    return id;
  }

  void _showMenu() {
    final records = ref.read(cowDetailProvider).breedingRecords;

    // Find active breeding cycle (heat date exists, not calved, not marked 'ไม่ตั้งท้อง' or 'แท้ง')
    final activeRecords = records
        .where(
          (r) =>
              r.heatDate != null &&
              r.calvingDate == null &&
              r.pregnancyResult != 'ไม่ตั้งท้อง' &&
              r.pregnancyResult != 'แท้ง' &&
              r.pregnancyResult != 'แท้งลูก',
        )
        .toList();

    bool canRecordHeat = activeRecords.isEmpty;
    bool canRecordMating = false;
    bool canRecordPregnancyCheck = false;
    bool canRecordCalving = false;

    if (activeRecords.isNotEmpty) {
      activeRecords.sort((a, b) => b.heatDate!.compareTo(a.heatDate!));
      final current = activeRecords.first;
      if (current.matingDate == null) {
        canRecordMating = true;
      } else if (current.pregnancyResult == null ||
          current.pregnancyResult == 'รอตรวจ') {
        canRecordPregnancyCheck = true;
      } else if (current.pregnancyResult == 'ตั้งท้อง') {
        canRecordCalving = true;
      }
    }

    final calvedRecords = records.where((r) => r.calvingDate != null).toList();
    int daysPassed = 999;
    if (calvedRecords.isNotEmpty) {
      calvedRecords.sort((a, b) => b.calvingDate!.compareTo(a.calvingDate!));
      daysPassed = DateTime.now()
          .difference(calvedRecords.first.calvingDate!)
          .inDays;
    }

    final isRecovering =
        (daysPassed < 45) || (widget.cow.status == CowStatus.recovering);
    if (isRecovering) {
      canRecordHeat = false;
      canRecordMating = false;
      canRecordPregnancyCheck = false;
      canRecordCalving = false;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.isDark(ctx)
                    ? AppColors.darkBorder
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isRecovering)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.isDark(ctx)
                      ? AppColors.darkSurface
                      : const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.isDark(ctx)
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
                        : const Color(0xFF2563EB).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.hotel_rounded,
                          color: AppColors.isDark(ctx)
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'แม่วัวกำลังพักฟื้นหลังคลอด (เหลือพักอีก ${(45 - daysPassed).clamp(0, 45)} วัน) ไม่อนุญาตให้บันทึกการผสมพันธุ์',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.isDark(ctx)
                                  ? AppColors.text(ctx)
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          ref
                              .read(cowProvider.notifier)
                              .updateCowStatus(widget.cow.id, CowStatus.normal);
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'พร้อมผสมพันธุ์',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite_outline, color: Colors.pink),
              ),
              title: const Text(
                'บันทึกเป็นสัด',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('บันทึกวันที่วัวเป็นสัด'),
              enabled: canRecordHeat,
              onTap: () {
                Navigator.pop(ctx);
                _showHeatDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const CowIcon(color: AppColors.primary, size: 24),
              ),
              title: const Text(
                'บันทึกผสมพันธุ์',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('เลือกพ่อพันธุ์และบันทึกการผสม'),
              enabled: canRecordMating,
              onTap: () {
                Navigator.pop(ctx);
                _showMatingDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Colors.purple,
                ),
              ),
              title: const Text(
                'บันทึกตรวจท้อง / แท้ง',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('บันทึกผลการตรวจท้อง หรือรายงานการแท้งลูก'),
              enabled: canRecordPregnancyCheck,
              onTap: () {
                Navigator.pop(ctx);
                _showPregnancyCheckDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.child_care_outlined,
                  color: Colors.teal,
                ),
              ),
              title: const Text(
                'บันทึกการคลอด',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('บันทึกผลการคลอดและลูกวัว'),
              enabled: canRecordCalving,
              onTap: () {
                Navigator.pop(ctx);
                _showCalvingDialog();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Step 1: Record Heat
  void _showHeatDialog({BreedingRecord? existingRecord}) {
    DateTime heatDate = existingRecord?.heatDate ?? DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.favorite, color: Colors.pink, size: 22),
              SizedBox(width: 8),
              Text('บันทึกเป็นสัด'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: Colors.pink.withValues(alpha: 0.05),
                leading: const Icon(Icons.calendar_today, color: Colors.pink),
                title: const Text(
                  'วันที่และเวลาที่เป็นสัด',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  AppDateUtils.formatThaiDate(heatDate, includeTime: true),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: ctx,
                    initialDate: heatDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    helpText: 'เลือกวันที่',
                    cancelText: 'ยกเลิก',
                    confirmText: 'ตกลง',
                  );
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(heatDate),
                      helpText: 'ระบุเวลา',
                      cancelText: 'ยกเลิก',
                      confirmText: 'ตกลง',
                      hourLabelText: 'ชั่วโมง',
                      minuteLabelText: 'นาที',
                    );
                    if (pickedTime != null) {
                      setDialogState(() {
                        heatDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final record = BreedingRecord(
                        id:
                            existingRecord?.id ??
                            'BR${DateTime.now().millisecondsSinceEpoch % 1000000}',
                        damId: widget.cow.id,
                        heatDate: heatDate,
                        calvingDate: existingRecord?.calvingDate,
                        calvingResult: existingRecord?.calvingResult,
                        calfId: existingRecord?.calfId,
                      );
                      ref
                          .read(cowDetailProvider.notifier)
                          .addBreedingRecord(record);
                      ref
                          .read(cowProvider.notifier)
                          .updateCowStatus(widget.cow.id, CowStatus.estrous);
                      Navigator.pop(ctx);
                    },
                    child: const Text('บันทึก'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Step 2: Record Mating (Allows creating or editing sireId and mating details)
  void _showMatingDialog({BreedingRecord? existingRecord}) {
    final records = ref.read(cowDetailProvider).breedingRecords;
    final bulls = ref.read(bullsProvider);

    BreedingRecord? activeHeat;
    if (existingRecord != null) {
      activeHeat = existingRecord;
    } else {
      final pendingHeats = records
          .where((r) => r.heatDate != null && r.matingDate == null)
          .toList();

      if (pendingHeats.isEmpty) {
        AppFeedback.showWarning(context, 'ไม่มีรายการเป็นสัดที่รอผสม กรุณาบันทึกเป็นสัดก่อน');
        return;
      }

      pendingHeats.sort((a, b) => b.heatDate!.compareTo(a.heatDate!));
      activeHeat = pendingHeats.first;
    }

    if (bulls.isEmpty) {
      AppFeedback.showWarning(context, 'ไม่มีพ่อพันธุ์ในระบบ กรุณาเพิ่มวัวผู้ก่อน');
      return;
    }

    final heatRecord = activeHeat;

    Cow? selectedBull;
    if (heatRecord.sireId != null &&
        bulls.any((b) => b.id == heatRecord.sireId)) {
      selectedBull = bulls.firstWhere((b) => b.id == heatRecord.sireId);
    }
    DateTime matingDate = heatRecord.matingDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              CowIcon(color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text('บันทึกผสมพันธุ์'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner for fixed active heat record
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.pink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.pink.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.pink, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'รายการเป็นสัดรอบปัจจุบัน',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.pink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'วันที่ ${DateFormat('dd/MM/yyyy HH:mm น.').format(heatRecord.heatDate!)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Select Bull Dropdown
                DropdownButtonFormField<Cow>(
                  initialValue: selectedBull,
                  style: TextStyle(fontSize: 16, color: AppColors.text(ctx)),
                  decoration: const InputDecoration(
                    labelText: 'เลือกพ่อพันธุ์ *',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.male, color: Colors.blue),
                  ),
                  items: bulls
                      .map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text(
                            '${b.name} (${b.tagNumber.isNotEmpty ? b.tagNumber : b.id})',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.text(ctx),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBull = v),
                ),
                const SizedBox(height: 16),

                // Mating Date Picker
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor:
                      (AppColors.isDark(ctx)
                              ? AppColors.primaryLight
                              : AppColors.primary)
                          .withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.calendar_today,
                    color: AppColors.isDark(ctx)
                        ? AppColors.primaryLight
                        : AppColors.primary,
                  ),
                  title: Text(
                    'วันที่และเวลาที่ผสม',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.subText(ctx),
                    ),
                  ),
                  subtitle: Text(
                    AppDateUtils.formatThaiDate(matingDate, includeTime: true),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.text(ctx),
                    ),
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: ctx,
                      initialDate: matingDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      helpText: 'เลือกวันที่',
                      cancelText: 'ยกเลิก',
                      confirmText: 'ตกลง',
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(matingDate),
                        helpText: 'ระบุเวลา',
                        cancelText: 'ยกเลิก',
                        confirmText: 'ตกลง',
                        hourLabelText: 'ชั่วโมง',
                        minuteLabelText: 'นาที',
                      );
                      if (pickedTime != null) {
                        setDialogState(() {
                          matingDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ยกเลิก', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.isDark(ctx)
                          ? AppColors.primaryLight
                          : AppColors.primary,
                      foregroundColor: AppColors.isDark(ctx)
                          ? AppColors.darkBackground
                          : Colors.white,
                    ),
                    onPressed: selectedBull == null
                        ? null
                        : () {
                            final record = BreedingRecord(
                              id: heatRecord.id,
                              damId: widget.cow.id,
                              sireId: selectedBull!.id,
                              heatDate: heatRecord.heatDate,
                              matingDate: matingDate,
                              calvingDate: null,
                              calvingResult: null,
                              calfId: heatRecord.calfId,
                            );
                            ref
                                .read(cowDetailProvider.notifier)
                                .addBreedingRecord(record);
                            Navigator.pop(ctx);
                          },
                    child: const Text(
                      'บันทึก',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Pregnancy Check & Miscarriage (Fixed active mating record - no dropdown required)
  void _showPregnancyCheckDialog({BreedingRecord? existingRecord}) {
    final records = ref.read(cowDetailProvider).breedingRecords;
    final allCows = ref.read(cowProvider).allCows;

    BreedingRecord activeMating;
    if (existingRecord != null) {
      activeMating = existingRecord;
    } else {
      final pendingMatings = records
          .where(
            (r) =>
                r.matingDate != null &&
                (r.pregnancyResult == null || r.pregnancyResult == 'รอตรวจ'),
          )
          .toList();

      if (pendingMatings.isEmpty) {
        AppFeedback.showWarning(context, 'ไม่มีรายการที่รอตรวจท้อง');
        return;
      }

      // Fix the active mating record automatically
      pendingMatings.sort((a, b) => b.matingDate!.compareTo(a.matingDate!));
      activeMating = pendingMatings.first;
    }

    String? result = activeMating.pregnancyResult == 'แท้ง'
        ? 'แท้งลูก'
        : activeMating.pregnancyResult;
    DateTime? expectedCalving = activeMating.expectedCalving;
    String selectedCalvingReminder =
        activeMating.reminderSetting ?? 'ก่อน 7 วัน';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.medical_services_outlined,
                color: Colors.purple,
                size: 22,
              ),
              SizedBox(width: 8),
              Text('บันทึกตรวจท้อง / แท้ง'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner for fixed active mating record
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CowIcon(color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'ผสมกับ: ${_formatCowDisplayById(activeMating.sireId, allCows)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'วันที่ผสม: ${AppDateUtils.formatThaiDate(activeMating.matingDate!)} (${DateTime.now().difference(activeMating.matingDate!).inDays} วันที่แล้ว)',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.text(ctx),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: result,
                  style: TextStyle(fontSize: 16, color: AppColors.text(ctx)),
                  decoration: const InputDecoration(
                    labelText: 'ผลตรวจ / สถานะ *',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.fact_check_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'ตั้งท้อง',
                      child: Text(
                        'ตั้งท้อง (ผ่านการตรวจ)',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.text(ctx),
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'ไม่ตั้งท้อง',
                      child: Text(
                        'ไม่ตั้งท้อง (ผสมไม่ติด)',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.text(ctx),
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'แท้งลูก',
                      child: Text(
                        'แท้งลูก (แท้งระหว่างตั้งท้อง)',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setDialogState(() => result = v);
                    if (v == 'ตั้งท้อง' && activeMating.matingDate != null) {
                      expectedCalving = activeMating.matingDate!.add(
                        const Duration(days: 283),
                      );
                    } else {
                      expectedCalving = null;
                    }
                  },
                ),
                if (result == 'ตั้งท้อง') ...[
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor:
                        (AppColors.isDark(ctx)
                                ? const Color(0xFFC084FC)
                                : Colors.purple)
                            .withValues(alpha: 0.08),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Icon(
                      Icons.calendar_today,
                      color: AppColors.isDark(ctx)
                          ? const Color(0xFFC084FC)
                          : Colors.purple,
                    ),
                    title: Text(
                      'กำหนดคลอดโดยประมาณ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.subText(ctx),
                      ),
                    ),
                    subtitle: Text(
                      expectedCalving != null
                          ? AppDateUtils.formatThaiDate(expectedCalving!)
                          : 'เลือกวันที่',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.isDark(ctx)
                            ? const Color(0xFFC084FC)
                            : Colors.purple,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            expectedCalving ??
                            DateTime.now().add(const Duration(days: 283)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        helpText: 'เลือกวันที่กำหนดคลอด',
                        cancelText: 'ยกเลิก',
                        confirmText: 'ตกลง',
                      );
                      if (picked != null) {
                        setDialogState(() => expectedCalving = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCalvingReminder,
                    style: TextStyle(fontSize: 15, color: AppColors.text(ctx)),
                    decoration: const InputDecoration(
                      labelText: 'แจ้งเตือนล่วงหน้า (กำหนดคลอด)',
                      labelStyle: TextStyle(fontSize: 15),
                      prefixIcon: Icon(Icons.notifications_active_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'ก่อน 1 วัน',
                        child: Text(
                          'ก่อน 1 วัน',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text(ctx),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ก่อน 3 วัน',
                        child: Text(
                          'ก่อน 3 วัน',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text(ctx),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ก่อน 7 วัน',
                        child: Text(
                          'ก่อน 7 วัน (แนะนำ)',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text(ctx),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ก่อน 14 วัน',
                        child: Text(
                          'ก่อน 14 วัน',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text(ctx),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ก่อน 30 วัน',
                        child: Text(
                          'ก่อน 30 วัน',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text(ctx),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ไม่แจ้งเตือน',
                        child: Text(
                          'ไม่แจ้งเตือน',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text(ctx),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedCalvingReminder = v);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ยกเลิก', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.isDark(ctx)
                          ? AppColors.primaryLight
                          : AppColors.primary,
                      foregroundColor: AppColors.isDark(ctx)
                          ? AppColors.darkBackground
                          : Colors.white,
                    ),
                    onPressed: result == null
                        ? null
                        : () {
                            final record = BreedingRecord(
                              id: activeMating.id,
                              damId: widget.cow.id,
                              sireId: activeMating.sireId,
                              heatDate: activeMating.heatDate,
                              matingDate: activeMating.matingDate,
                              checkDate: DateTime.now(),
                              pregnancyResult: result == 'แท้งลูก'
                                  ? 'แท้ง'
                                  : result,
                              expectedCalving: expectedCalving,
                              calvingDate: null,
                              calvingResult: null,
                              calfId: activeMating.calfId,
                              reminderSetting: selectedCalvingReminder,
                            );
                            ref
                                .read(cowDetailProvider.notifier)
                                .addBreedingRecord(record);
                            if (result == 'ตั้งท้อง') {
                              ref
                                  .read(cowProvider.notifier)
                                  .updateCowStatus(
                                    widget.cow.id,
                                    CowStatus.pregnant,
                                  );
                            } else if (result == 'ไม่ท้อง' ||
                                result == 'แท้ง' ||
                                result == 'แท้งลูก') {
                              ref
                                  .read(cowProvider.notifier)
                                  .updateCowStatus(
                                    widget.cow.id,
                                    CowStatus.normal,
                                  );
                            }
                            Navigator.pop(ctx);
                          },
                    child: const Text(
                      'บันทึก',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Step 4: Record Calving (Fixed active pregnancy record - no dropdown required, expanded results)
  Future<void> _showCalvingDialog({BreedingRecord? existingRecord}) async {
    final records = ref.read(cowDetailProvider).breedingRecords;

    BreedingRecord activePregnancy;
    if (existingRecord != null) {
      activePregnancy = existingRecord;
    } else {
      final pregnantRecords = records
          .where(
            (r) => r.pregnancyResult == 'ตั้งท้อง' && r.calvingDate == null,
          )
          .toList();

      if (pregnantRecords.isEmpty) {
        AppFeedback.showWarning(context, 'ไม่มีรายการที่รอคลอด');
        return;
      }

      // Fix the active pregnancy record automatically
      pregnantRecords.sort(
        (a, b) => (b.expectedCalving ?? DateTime(1900)).compareTo(
          a.expectedCalving ?? DateTime(1900),
        ),
      );
      activePregnancy = pregnantRecords.first;
    }

    DateTime calvingDate = activePregnancy.calvingDate ?? DateTime.now();
    String? rawResult = activePregnancy.calvingResult;
    String? calvingResult = rawResult;
    int twinCount = 2;

    if (rawResult != null &&
        rawResult.contains('แฝด') &&
        rawResult.contains('ตัว')) {
      final match = RegExp(r'-\s*(\d+)\s*ตัว').firstMatch(rawResult);
      if (match != null) {
        twinCount = int.tryParse(match.group(1)!) ?? 2;
        calvingResult = rawResult.replaceAll(match.group(0)!, '').trim();
      }
    }

    // Logic to lock the dropdown if >= 2 calves are registered
    final int registeredCount = (activePregnancy.calfId != null && activePregnancy.calfId!.isNotEmpty)
        ? activePregnancy.calfId!.split(',').where((s) => s.trim().isNotEmpty).length
        : 0;
    final bool isResultLocked = registeredCount >= 2;


    final resultOptions = [
      'คลอดปกติ (ลูกแข็งแรง)',
      'คลอดยาก (ต้องช่วยคลอด)',
      'ลูกตายหลังคลอด (Stillborn)',
      'แฝด (คลอดปกติ)',
      'แฝด (คลอดยาก)',
      'พิการ/ไม่สมบูรณ์',
      'อื่นๆ',
    ];

    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.child_care_outlined, color: Colors.teal, size: 22),
              SizedBox(width: 8),
              Text('บันทึกการคลอด'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner for fixed active pregnancy
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pregnant_woman,
                        color: Colors.purple,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'รายการตั้งท้องปัจจุบัน',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activePregnancy.expectedCalving != null
                                  ? 'กำหนดคลอด: ${AppDateUtils.formatThaiDate(activePregnancy.expectedCalving!)}'
                                  : 'ผสมวันที่: ${AppDateUtils.formatThaiDate(activePregnancy.matingDate!)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Colors.teal.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  leading: const Icon(Icons.calendar_today, color: Colors.teal),
                  title: const Text(
                    'วันที่และเวลาที่คลอด',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    AppDateUtils.formatThaiDate(calvingDate, includeTime: true),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: ctx,
                      initialDate: calvingDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      helpText: 'เลือกวันที่',
                      cancelText: 'ยกเลิก',
                      confirmText: 'ตกลง',
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(calvingDate),
                        helpText: 'ระบุเวลา',
                        cancelText: 'ยกเลิก',
                        confirmText: 'ตกลง',
                        hourLabelText: 'ชั่วโมง',
                        minuteLabelText: 'นาที',
                      );
                      if (pickedTime != null) {
                        setDialogState(() {
                          calvingDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),

                if (isResultLocked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ไม่สามารถแก้ไขผลการคลอดได้ เนื่องจากมีการลงทะเบียนลูกวัวไปแล้ว $registeredCount ตัว (แก้ไขได้เฉพาะวันที่)',
                            style: const TextStyle(color: Colors.orange, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                DropdownButtonFormField<String>(
                  initialValue: calvingResult,
                  style: TextStyle(fontSize: 16, color: AppColors.text(ctx)),
                  decoration: const InputDecoration(
                    labelText: 'ผลการคลอด *',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  items: resultOptions
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            r,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.text(ctx),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isResultLocked ? null : (v) => setDialogState(() => calvingResult = v),
                ),

                if (calvingResult != null &&
                    calvingResult!.contains('แฝด')) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people_alt_outlined,
                          color: Colors.teal,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'จำนวนลูกวัวที่เกิด (ลูกแฝด)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text(ctx),
                                ),
                              ),
                              Text(
                                'ระบุจำนวนลูกวัวเพื่อลงทะเบียน',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.subText(ctx),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBg(ctx),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.teal.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove,
                                  size: 18,
                                  color: Colors.teal,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: (isResultLocked || twinCount <= 2)
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          twinCount--;
                                        });
                                      },
                              ),
                              Text(
                                '$twinCount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text(ctx),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: Colors.teal,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: (isResultLocked || twinCount >= 6)
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          twinCount++;
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ยกเลิก', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.isDark(ctx)
                          ? AppColors.primaryLight
                          : AppColors.primary,
                      foregroundColor: AppColors.isDark(ctx)
                          ? AppColors.darkBackground
                          : Colors.white,
                    ),
                    onPressed: calvingResult == null
                        ? null
                        : () {
                            final isTwin = calvingResult!.contains('แฝด');
                            final finalCalfCount = isTwin ? twinCount : 1;

                            String finalResultStr = calvingResult!;
                            if (isTwin && finalCalfCount > 1) {
                              finalResultStr =
                                  '$calvingResult - $finalCalfCount ตัว';
                            }

                            final record = BreedingRecord(
                              id: activePregnancy.id,
                              damId: activePregnancy.damId,
                              sireId: activePregnancy.sireId,
                              heatDate: activePregnancy.heatDate,
                              matingDate: activePregnancy.matingDate,
                              checkDate: activePregnancy.checkDate,
                              pregnancyResult: activePregnancy.pregnancyResult,
                              expectedCalving: activePregnancy.expectedCalving,
                              calvingDate: calvingDate,
                              calvingResult: finalResultStr,
                              calfId: activePregnancy.calfId,
                            );
                            Navigator.pop(ctx, {
                              'record': record,
                              'finalCalfCount': finalCalfCount,
                              'result': finalResultStr,
                            });
                          },
                    child: const Text(
                      'บันทึก',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (dialogResult != null && mounted) {
      final record = dialogResult['record'] as BreedingRecord;
      final finalCalfCount = dialogResult['finalCalfCount'] as int;
      final result = dialogResult['result'] as String?;

      ref.read(cowDetailProvider.notifier).addBreedingRecord(record);
      ref
          .read(cowProvider.notifier)
          .updateCowStatus(widget.cow.id, CowStatus.recovering);

      if (result != null &&
          (result.contains('ปกติ') ||
              result.contains('แฝด') ||
              result.contains('ช่วยคลอด'))) {
        _showAddCalfPrompt(record, totalCalves: finalCalfCount);
      }
    }
  }

  void _showAddCalfPrompt(
    BreedingRecord record, {
    int totalCalves = 1,
    int initialRegisteredCount = 0,
  }) {
    // Count strictly from record.calfId — do NOT use date-based matching
    // to avoid leaking calf counts from deleted breeding records.
    final int actualCount = (record.calfId != null && record.calfId!.isNotEmpty)
        ? record.calfId!.split(',').where((s) => s.trim().isNotEmpty).length
        : initialRegisteredCount;
    final Set<int> registeredCalves = {};
    for (int i = 0; i < actualCount; i++) {
      registeredCalves.add(i + 1);
    }

    // Mutable calfId that tracks the latest registered IDs inside the modal.
    // Updated after each successful registration so subsequent calves correctly
    // append to the running comma-separated list instead of using the stale
    // record.calfId that was captured when the modal first opened.
    String currentCalfId = record.calfId ?? '';
    
    int? _loadingCalfIndex;

    showModalBottomSheet(

      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = AppColors.isDark(ctx);
          final tealColor = isDark ? const Color(0xFF2DD4BF) : Colors.teal;

          return Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg(ctx),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.of(bCtx).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      totalCalves > 1 ? Icons.people_alt : Icons.child_care,
                      color: tealColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        totalCalves > 1
                            ? 'ลงทะเบียนลูกวัวแรกเกิด (แฝด $totalCalves ตัว)'
                            : 'ลงทะเบียนลูกวัวแรกเกิด',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(ctx),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.subText(ctx)),
                      onPressed: () => Navigator.pop(bCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  totalCalves > 1
                      ? 'บันทึกการคลอดลูกแฝด ($totalCalves ตัว) เรียบร้อยแล้ว!\nกรุณากดปุ่มลงทะเบียนข้อมูลลูกวัวทีละตัวได้ทันที:'
                      : 'บันทึกการคลอดสำเร็จเรียบร้อยแล้ว!\nคุณต้องการย้ายไปหน้าลงทะเบียนเพิ่มข้อมูลลูกวัวตัวใหม่ในระบบทันทีเลยหรือไม่?',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.subText(ctx),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (totalCalves > 1) ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(bCtx).size.height * 0.45,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: totalCalves,
                      itemBuilder: (ctx, index) {
                        final calfNum = index + 1;
                        final isRegistered = registeredCalves.contains(calfNum);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isRegistered
                                ? (isDark
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : Colors.green.withValues(alpha: 0.05))
                                : (isDark
                                      ? tealColor.withValues(alpha: 0.1)
                                      : Colors.teal.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isRegistered
                                  ? Colors.green.withValues(
                                      alpha: isDark ? 0.4 : 0.3,
                                    )
                                  : tealColor.withValues(
                                      alpha: isDark ? 0.35 : 0.2,
                                    ),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isRegistered
                                    ? Colors.green.withValues(
                                        alpha: isDark ? 0.25 : 0.15,
                                      )
                                    : tealColor.withValues(
                                        alpha: isDark ? 0.25 : 0.15,
                                      ),
                                child: Text(
                                  '$calfNum',
                                  style: TextStyle(
                                    color: isRegistered
                                        ? (isDark
                                              ? const Color(0xFF4ADE80)
                                              : Colors.green)
                                        : tealColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ลูกวัวตัวที่ $calfNum (แฝด)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.text(ctx),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'แม่: ${widget.cow.name} • คลอด: ${AppDateUtils.formatThaiDate(record.calvingDate ?? DateTime.now())}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.subText(ctx),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: (isRegistered || _loadingCalfIndex != null)
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          _loadingCalfIndex = calfNum;
                                        });

                                        try {
                                          final result = await context.push<bool>(
                                            '/add_cow',
                                            extra: {
                                              'mother_id': widget.cow.id,
                                              'father_id': record.sireId,
                                              'breed_id': widget.cow.breed,
                                              'birth_date':
                                                  record.calvingDate ??
                                                  DateTime.now(),
                                              'type': CowType.calf,
                                              'breeding_record_id': record.id,
                                              'existing_calf_id': currentCalfId,
                                            },
                                          );
                                          if (result == true && mounted) {
                                            await ref
                                                .read(cowDetailProvider.notifier)
                                                .fetchAllData(widget.cow.id);
                                            if (widget.cow.farmId.isNotEmpty) {
                                              ref
                                                  .read(cowProvider.notifier)
                                                  .fetchCows(widget.cow.farmId);
                                            }
                                            
                                            final updatedRecord = ref
                                                .read(cowDetailProvider)
                                                .breedingRecords
                                                .where((r) => r.id == record.id)
                                                .firstOrNull;
                                            
                                            if (mounted) {
                                              setModalState(() {
                                                registeredCalves.add(calfNum);
                                                if (updatedRecord?.calfId != null &&
                                                    updatedRecord!.calfId!.isNotEmpty) {
                                                  currentCalfId = updatedRecord.calfId!;
                                                }
                                              });
                                            }
                                          }
                                        } finally {
                                          if (mounted) {
                                            setModalState(() {
                                              _loadingCalfIndex = null;
                                            });
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tealColor,
                                  disabledBackgroundColor: isDark
                                      ? const Color(0xFF166534)
                                      : Colors.green.shade400,
                                  disabledForegroundColor: Colors.white,
                                  foregroundColor: isDark
                                      ? AppColors.darkBackground
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  minimumSize: const Size(0, 36),
                                ),
                                icon: isRegistered
                                    ? const Icon(Icons.check_circle, size: 16)
                                    : _loadingCalfIndex == calfNum
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.add, size: 16),
                                label: Text(
                                  isRegistered 
                                      ? 'ลงทะเบียนแล้ว' 
                                      : (_loadingCalfIndex == calfNum ? 'กำลังโหลด...' : 'ลงทะเบียน'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(bCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        registeredCalves.length == totalCalves
                            ? 'เสร็จสิ้น'
                            : 'เสร็จสิ้น / ไว้ลงทะเบียนภายหลัง',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(ctx),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(bCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'ไว้ทีหลัง',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.text(ctx),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(bCtx);
                            final result = await context.push<bool>(
                              '/add_cow',
                              extra: {
                                'mother_id': widget.cow.id,
                                'father_id': record.sireId,
                                'breed_id': widget.cow.breed,
                                'birth_date':
                                    record.calvingDate ?? DateTime.now(),
                                'type': CowType.calf,
                                'breeding_record_id': record.id,
                                'existing_calf_id': record.calfId ?? '',
                              },
                            );
                            if (result == true && mounted) {
                              ref
                                  .read(cowDetailProvider.notifier)
                                  .fetchAllData(widget.cow.id);
                              if (widget.cow.farmId.isNotEmpty) {
                                ref
                                    .read(cowProvider.notifier)
                                    .fetchCows(widget.cow.farmId);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tealColor,
                            foregroundColor: isDark
                                ? AppColors.darkBackground
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ลงทะเบียนลูกวัว',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(cowDetailProvider);
    final records = detailState.breedingRecords;

    ref.listen<CowDetailState>(cowDetailProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess == false) {
        ref.read(cowDetailProvider.notifier).clearFlags();
      } else if (next.error != null && prev?.error != next.error) {
        AppFeedback.showError(context, next.error!);
        ref.read(cowDetailProvider.notifier).clearFlags();
      }
    });

    if (detailState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final cows = ref.watch(cowProvider).allCows;
    final currentCow = cows.firstWhere(
      (c) => c.id == widget.cow.id,
      orElse: () => widget.cow,
    );

    final isMale = currentCow.gender == 'M';

    final calvedRecords = records.where((r) => r.calvingDate != null).toList();
    BreedingRecord? latestCalvingRecord;
    int daysPassed = 999;
    if (calvedRecords.isNotEmpty) {
      calvedRecords.sort((a, b) => b.calvingDate!.compareTo(a.calvingDate!));
      latestCalvingRecord = calvedRecords.first;
      daysPassed = DateTime.now()
          .difference(latestCalvingRecord.calvingDate!)
          .inDays;
    }

    final isRecovering =
        (latestCalvingRecord != null && daysPassed < 45) &&
        (currentCow.status == CowStatus.recovering);

    if (currentCow.status == CowStatus.recovering) {
      if (latestCalvingRecord == null || daysPassed >= 45) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(cowProvider.notifier)
              .updateCowStatus(currentCow.id, CowStatus.normal);
        });
      }
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            if (!isMale) ...[
              if (isRecovering)
                _buildRecoveryCard(
                  daysPassed,
                  45,
                  latestCalvingRecord.calvingDate!,
                )
              else
                _buildCurrentBreedingCards(context, records),
              const SizedBox(height: 20),
            ],

            // Separate records into ongoing vs completed
            Builder(
              builder: (context) {
                final ongoingRecords = records
                    .where(
                      (r) =>
                          r.calvingDate == null &&
                          r.pregnancyResult != 'ไม่ตั้งท้อง' &&
                          r.pregnancyResult != 'แท้ง' &&
                          r.pregnancyResult != 'แท้งลูก',
                    )
                    .toList();
                final completedRecords = records
                    .where(
                      (r) =>
                          r.calvingDate != null ||
                          r.pregnancyResult == 'ไม่ตั้งท้อง' ||
                          r.pregnancyResult == 'แท้ง' ||
                          r.pregnancyResult == 'แท้งลูก',
                    )
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Ongoing
                    Row(
                      children: [
                        const Icon(
                          Icons.sync,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'รอบการผสมที่กำลังดำเนินการ',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${ongoingRecords.length} รายการ',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (ongoingRecords.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.surfAlt(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.brd(context)),
                        ),
                        child: Text(
                          'ไม่มีรอบการผสมที่กำลังดำเนินการอยู่',
                          style: TextStyle(
                            color: AppColors.hint(context),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...ongoingRecords.map((r) => _buildBreedingCard(r)),

                    const SizedBox(height: 16),

                    // Section 2: Completed History
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: AppColors.subText(context),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isMale
                                ? 'ประวัติการทำหน้าที่พ่อพันธุ์ที่เสร็จสิ้น'
                                : 'ประวัติการผสมพันธุ์ที่เสร็จสิ้นแล้ว',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () {
                            context.push(
                              '/cow_history_list',
                              extra: {
                                'cow': widget.cow,
                                'initialTab': 'breeding',
                              },
                            );
                          },
                          icon: Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: AppColors.isDark(context)
                                ? AppColors.primaryLight
                                : AppColors.primary,
                          ),
                          label: Text(
                            'ดูทั้งหมด (${completedRecords.length})',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.isDark(context)
                                  ? AppColors.primaryLight
                                  : AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (completedRecords.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfAlt(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.brd(context)),
                        ),
                        child: Text(
                          'ยังไม่มีประวัติการผสมพันธุ์ที่เสร็จสิ้น',
                          style: TextStyle(
                            color: AppColors.hint(context),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...completedRecords
                          .take(5)
                          .map((r) => _buildBreedingCard(r)),
                    if (completedRecords.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.push(
                              '/cow_history_list',
                              extra: {
                                'cow': widget.cow,
                                'initialTab': 'breeding',
                              },
                            );
                          },
                          icon: const Icon(Icons.history, size: 18),
                          label: Text(
                            'ดูประวัติการผสมพันธุ์ทั้งหมด (${completedRecords.length} รายการ)',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        if (!isMale)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'breed_tab_fab',
              onPressed: _showMenu,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildRecoveryCard(
    int daysPassed,
    int totalDays,
    DateTime calvingDate,
  ) {
    final remainingDays = (totalDays - daysPassed).clamp(0, totalDays);
    final progress = (daysPassed / totalDays).clamp(0.0, 1.0);
    final isDark = AppColors.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
              : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF2563EB).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                      : const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.hotel_rounded,
                  color: isDark
                      ? const Color(0xFF60A5FA)
                      : const Color(0xFF1D4ED8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'อยู่ในช่วงพักฟื้นหลังคลอด',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF1E3A8A),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: isDark
                      ? Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        )
                      : null,
                ),
                child: Text(
                  'เหลือพักอีก $remainingDays วัน',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF1D4ED8),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'แม่วัวคลอดเมื่อวันที่ ${AppDateUtils.formatThaiDate(calvingDate)} (พักฟื้นมาแล้ว $daysPassed วัน จาก $totalDays วัน)',
            style: TextStyle(
              color: isDark ? AppColors.text(context) : const Color(0xFF1E40AF),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceAlt
                  : const Color(0xFFDBEAFE),
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: isDark
                    ? const Color(0xFF60A5FA)
                    : const Color(0xFF1D4ED8),
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'งดบันทึกการผสมพันธุ์ชั่วคราวเพื่อรอให้มดลูกแม่วัวเข้าอู่สมบูรณ์',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.subText(context)
                        : const Color(0xFF1E40AF),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(cowProvider.notifier)
                    .updateCowStatus(widget.cow.id, CowStatus.normal);
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text(
                'สิ้นสุดการพักฟื้น (พร้อมผสมพันธุ์)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build Primary Card (Bred Partner Info) & Secondary Card (Current Stage Progress Tracker)
  Widget _buildCurrentBreedingCards(
    BuildContext context,
    List<BreedingRecord> records,
  ) {
    final allCows = ref.watch(cowProvider).allCows;
    final isDark = AppColors.isDark(context);
    final tealColor = isDark ? const Color(0xFF2DD4BF) : Colors.teal;

    // Filter active cycle
    final activeRecords = records
        .where(
          (r) =>
              r.heatDate != null &&
              r.calvingDate == null &&
              r.pregnancyResult != 'ไม่ตั้งท้อง' &&
              r.pregnancyResult != 'แท้ง' &&
              r.pregnancyResult != 'แท้งลูก',
        )
        .toList();

    if (activeRecords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurface
              : Colors.teal.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tealColor.withValues(alpha: isDark ? 0.35 : 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tealColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: tealColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'พร้อมผสมพันธุ์',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: tealColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ไม่มีรายการเป็นสัดหรือผสมพันธุ์ค้างอยู่',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.subText(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    activeRecords.sort((a, b) => b.heatDate!.compareTo(a.heatDate!));
    final current = activeRecords.first;

    // Sire Cow lookup
    Cow? sireCow;
    if (current.sireId != null) {
      sireCow = allCows.firstWhere(
        (c) => c.id == current.sireId,
        orElse: () => Cow(
          id: current.sireId!,
          farmId: '',
          zoneId: '',
          name: current.sireId!,
          tagNumber: '',
          birthDate: DateTime.now(),
          gender: 'M',
          type: CowType.calf,
          breed: '',
          status: CowStatus.normal,
          latestWeight: 0,
          purchasePrice: 0,
        ),
      );
    }

    // Determine current stage & step index (1: เป็นสัด, 2: รอตรวจท้อง, 3: ตั้งท้อง)
    String stageTitle = 'เป็นสัด';
    String stageSubtitle = '';
    Color stageColor = Colors.pink;
    int currentStep = 1;

    if (current.matingDate == null) {
      stageTitle = 'เป็นสัด (รอผสมพันธุ์)';
      final days = DateTime.now().difference(current.heatDate!).inDays;
      stageSubtitle = days == 0 ? 'เป็นสัดวันนี้' : '$days วันที่แล้ว';
      stageColor = Colors.pink;
      currentStep = 1;
    } else if (current.pregnancyResult == null ||
        current.pregnancyResult == 'รอตรวจ') {
      stageTitle = 'รอตรวจท้อง';
      final days = DateTime.now().difference(current.matingDate!).inDays;
      stageSubtitle =
          'ผสมแล้ว $days วัน ${days >= 60 ? "(ตรวจท้องได้แล้ว)" : "(รอครบ 60 วัน)"}';
      stageColor = Colors.orange;
      currentStep = 2;
    } else if (current.pregnancyResult == 'ตั้งท้อง') {
      stageTitle = 'ตั้งท้อง (รอคลอด)';
      if (current.expectedCalving != null) {
        final daysLeft = current.expectedCalving!
            .difference(DateTime.now())
            .inDays;
        stageSubtitle = daysLeft > 0
            ? 'คลอดประมาณอีก $daysLeft วัน'
            : 'ครบกำหนดคลอดแล้ว';
      }
      stageColor = Colors.purple;
      currentStep = 3;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stageColor.withValues(
            alpha: AppColors.isDark(context) ? 0.35 : 0.25,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: stageColor.withValues(
              alpha: AppColors.isDark(context) ? 0.12 : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stage Header Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: stageColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.timeline, color: stageColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stageTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: stageColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ขั้นตอน $currentStep / 3',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: stageColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stage Subtitle
          if (stageSubtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.subText(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    stageSubtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.subText(context),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 24, indent: 16, endIndent: 16),

          // Sire Info Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'พ่อพันธุ์คู่ผสม',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subText(context),
                  ),
                ),
                const SizedBox(height: 10),
                if (sireCow != null) ...[
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.indigo.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.indigo.withValues(alpha: 0.25),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child:
                              sireCow.imageUrl != null &&
                                  sireCow.imageUrl!.isNotEmpty
                              ? Image.network(
                                  sireCow.imageUrl!.startsWith('http')
                                      ? sireCow.imageUrl!.replaceAll(
                                          'http://127.0.0.1:8000/storage/',
                                          'http://127.0.0.1:8000/api/storage/',
                                        )
                                      : 'http://127.0.0.1:8000/api/storage/' +
                                            sireCow.imageUrl!.replaceAll(
                                              RegExp(r'^/?storage/'),
                                              '',
                                            ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const CowIcon(
                                    color: Colors.indigo,
                                    size: 28,
                                  ),
                                )
                              : const CowIcon(color: Colors.indigo, size: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sireCow.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: AppColors.text(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (sireCow.tagNumber.isNotEmpty)
                              Text(
                                'แท็ก/NFC: ${sireCow.tagNumber}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.subText(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (current.matingDate != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'วันที่ผสม',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.subText(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              AppDateUtils.formatThaiDate(current.matingDate!),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text(context),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'ยังไม่ได้บันทึกพ่อพันธุ์ (เป็นสัดเมื่อ: ${AppDateUtils.formatThaiDate(current.heatDate!)})',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.text(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BreedingRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text(
          'คุณต้องการลบข้อมูลประวัติการผสมพันธุ์นี้ใช่หรือไม่? การดำเนินการนี้ไม่สามารถย้อนกลับได้',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    ref
                        .read(cowDetailProvider.notifier)
                        .deleteBreedingRecord(record.id);
                    Navigator.pop(ctx);
                  },
                  child: const Text('ลบ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreedingCard(BreedingRecord record) {
    final allCows = ref.watch(cowProvider).allCows;
    final isMale = widget.cow.gender == 'M';
    final isDark = AppColors.isDark(context);

    if (isMale) {
      final stageColor = record.pregnancyResult == 'ตั้งท้อง'
          ? (isDark ? const Color(0xFFC084FC) : Colors.purple)
          : record.pregnancyResult == 'ไม่ตั้งท้อง'
          ? Colors.red
          : Colors.orange;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: stageColor.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.favorite_rounded, size: 18, color: stageColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ผสมกับแม่พันธุ์: ${_formatCowDisplayById(record.damId, allCows)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.text(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.pregnancyResult ?? 'รอตรวจท้อง',
                    style: TextStyle(
                      color: stageColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (record.matingDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 16,
                      color: AppColors.subText(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'วันที่ผสม: ${AppDateUtils.formatThaiDate(record.matingDate!, includeTime: true)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (record.calvingDate != null) ...[
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.child_care_rounded,
                    size: 17,
                    color: isDark ? const Color(0xFF2DD4BF) : Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'คลอดจริง: ${AppDateUtils.formatThaiDate(record.calvingDate!, includeTime: true)} (${record.calvingResult ?? "-"})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF2DD4BF) : Colors.teal,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    final stageColor = record.calvingResult != null
        ? (isDark ? const Color(0xFF2DD4BF) : Colors.teal)
        : record.pregnancyResult == 'ตั้งท้อง'
        ? (isDark ? const Color(0xFFC084FC) : Colors.purple)
        : record.pregnancyResult == 'ไม่ตั้งท้อง' ||
              record.pregnancyResult == 'แท้ง'
        ? Colors.red
        : record.matingDate != null
        ? Colors.orange
        : Colors.pink;

    final badgeText = record.calvingResult != null
        ? 'คลอดแล้ว'
        : record.pregnancyResult != null
        ? record.pregnancyResult!
        : record.matingDate != null
        ? 'รอตรวจท้อง'
        : record.heatDate != null
        ? 'รอผสม'
        : 'ไม่ระบุ';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stageColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded, size: 18, color: stageColor),
                  const SizedBox(width: 8),
                  Text(
                    record.heatDate != null
                        ? 'เป็นสัด: ${AppDateUtils.formatThaiDate(record.heatDate!)}'
                        : (record.matingDate != null
                              ? 'วันที่ผสม: ${AppDateUtils.formatThaiDate(record.matingDate!)}'
                              : 'บันทึกผสมพันธุ์'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.text(context),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: stageColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppColors.subText(context),
                    ),
                    onSelected: (val) {
                      if (val == 'edit') {
                        if (record.calvingDate != null) {
                          _showCalvingDialog(existingRecord: record);
                        } else if (record.pregnancyResult != null &&
                            record.pregnancyResult != 'รอตรวจ') {
                          _showPregnancyCheckDialog(existingRecord: record);
                        } else if (record.matingDate != null) {
                          _showMatingDialog(existingRecord: record);
                        } else if (record.heatDate != null) {
                          _showHeatDialog(existingRecord: record);
                        } else {
                          _showMatingDialog(existingRecord: record);
                        }
                      } else if (val == 'delete') {
                        _confirmDelete(record);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text('แก้ไข/อัปเดตสถานะ'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ลบประวัติ',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (record.matingDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 16,
                    color: AppColors.subText(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'วันที่ผสม: ${AppDateUtils.formatThaiDate(record.matingDate!, includeTime: true)}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (record.sireId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  CowIcon(size: 16, color: AppColors.subText(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'พ่อพันธุ์: ${_formatCowDisplayById(record.sireId, allCows)}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (record.expectedCalving != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_calendar_outlined,
                    size: 16,
                    color: AppColors.subText(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'คาดว่าจะคลอด: ${AppDateUtils.formatThaiDate(record.expectedCalving!)}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (record.calvingDate != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.child_care_rounded,
                    size: 17,
                    color: isDark ? const Color(0xFF2DD4BF) : Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'คลอดจริง: ${AppDateUtils.formatThaiDate(record.calvingDate!, includeTime: true)} (${record.calvingResult ?? "-"})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF2DD4BF) : Colors.teal,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Builder(
            builder: (ctx) {
              int totalCalves = 1;
              bool canRegister = false;

              if (record.calvingResult != null) {
                final res = record.calvingResult!;
                canRegister =
                    res.contains('ปกติ') ||
                    res.contains('แฝด') ||
                    res.contains('ช่วยคลอด');
                if (res.contains('แฝด')) {
                  final match = RegExp(r'-\s*(\d+)\s*ตัว').firstMatch(res);
                  totalCalves = match != null
                      ? (int.tryParse(match.group(1)!) ?? 2)
                      : 2;
                }
              }

              if (!canRegister) return const SizedBox.shrink();

              // Count strictly from record.calfId per-card.
              // Removed date-based matching to prevent deleted records from
              // carrying over registered calf counts to new records.
              final int registeredCalves =
                  (record.calfId != null && record.calfId!.isNotEmpty)
                  ? record.calfId!
                        .split(',')
                        .where((s) => s.trim().isNotEmpty)
                        .length
                  : 0;

              final bool isComplete = registeredCalves >= totalCalves;
              final tealColor = isDark ? const Color(0xFF2DD4BF) : Colors.teal;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isComplete) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddCalfPrompt(
                          record,
                          totalCalves: totalCalves,
                          initialRegisteredCount: registeredCalves,
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: Text(
                          'ลงทะเบียนลูกวัว${totalCalves > 1 ? 'เพิ่ม ($registeredCalves/$totalCalves)' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tealColor,
                          side: BorderSide(color: tealColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (registeredCalves > 0 ||
                      (record.calfId != null && record.calfId!.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tealColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: tealColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 15,
                            color: tealColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isComplete && totalCalves == 1
                                  ? 'ลงทะเบียนลูกวัวแล้ว (${_formatCowDisplayById(record.calfId, allCows)})'
                                  : isComplete
                                  ? 'ลงทะเบียนลูกวัวแล้วครบ $totalCalves ตัว'
                                  : 'ลงทะเบียนแล้ว $registeredCalves ตัว',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: tealColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
