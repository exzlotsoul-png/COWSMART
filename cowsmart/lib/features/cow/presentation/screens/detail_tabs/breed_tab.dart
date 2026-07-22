import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/cow.dart';
import '../../../domain/breeding_record.dart';
import '../../../providers/cow_detail_provider.dart';
import '../../../providers/cow_provider.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

// Provider to get male cows (bulls) for breeding
final bullsProvider = Provider<List<Cow>>((ref) {
  final cowState = ref.watch(cowProvider);
  return cowState.allCows.where((c) => c.gender == 'M' && c.type == CowType.breederMale).toList();
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
    final matches = allCows.where((c) => c.id == id || c.tagNumber == id || c.name == id).toList();
    if (matches.isNotEmpty) {
      final cow = matches.first;
      if (cow.name.isNotEmpty && cow.tagNumber.isNotEmpty && cow.name != cow.tagNumber) {
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
      } else if (current.pregnancyResult == null || current.pregnancyResult == 'รอตรวจ') {
        canRecordPregnancyCheck = true;
      } else if (current.pregnancyResult == 'ตั้งท้อง') {
        canRecordCalving = true;
      }
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
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
              title: const Text('บันทึกเป็นสัด', style: TextStyle(fontWeight: FontWeight.bold)),
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
                child: const Icon(Icons.pets_outlined, color: AppColors.primary),
              ),
              title: const Text('บันทึกผสมพันธุ์', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medical_services_outlined, color: Colors.orange),
              ),
              title: const Text('บันทึกตรวจท้อง / แท้ง', style: TextStyle(fontWeight: FontWeight.bold)),
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
                child: const Icon(Icons.child_care_outlined, color: Colors.teal),
              ),
              title: const Text('บันทึกการคลอด', style: TextStyle(fontWeight: FontWeight.bold)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.pink.withValues(alpha: 0.05),
                leading: const Icon(Icons.calendar_today, color: Colors.pink),
                title: const Text('วันที่และเวลาที่เป็นสัด', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy HH:mm น.').format(heatDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: ctx,
                    initialDate: heatDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(heatDate),
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
                        id: existingRecord?.id ?? 'BR${DateTime.now().millisecondsSinceEpoch % 1000000}',
                        damId: widget.cow.id,
                        heatDate: heatDate,
                        calvingDate: existingRecord?.calvingDate,
                        calvingResult: existingRecord?.calvingResult,
                        calfId: existingRecord?.calfId,
                      );
                      ref
                          .read(cowDetailProvider.notifier)
                          .addBreedingRecord(record);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่มีรายการเป็นสัดที่รอผสม กรุณาบันทึกเป็นสัดก่อน'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      pendingHeats.sort((a, b) => b.heatDate!.compareTo(a.heatDate!));
      activeHeat = pendingHeats.first;
    }

    if (bulls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีพ่อพันธุ์ในระบบ กรุณาเพิ่มวัวผู้ก่อน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (activeHeat == null) return;
    final heatRecord = activeHeat;

    Cow? selectedBull;
    if (heatRecord.sireId != null && bulls.any((b) => b.id == heatRecord.sireId)) {
      selectedBull = bulls.firstWhere((b) => b.id == heatRecord.sireId);
    }
    DateTime matingDate = heatRecord.matingDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.pets, color: AppColors.primary, size: 22),
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
                    border: Border.all(color: Colors.pink.withValues(alpha: 0.2)),
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
                              style: TextStyle(fontSize: 13, color: Colors.pink, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'วันที่ ${DateFormat('dd/MM/yyyy HH:mm น.').format(heatRecord.heatDate!)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                  style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
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
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBull = v),
                ),
                const SizedBox(height: 16),

                // Mating Date Picker
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: AppColors.primary.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                  title: const Text('วันที่และเวลาที่ผสม', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy HH:mm น.').format(matingDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: ctx,
                      initialDate: matingDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(matingDate),
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
                              calfId: null,
                            );
                            ref
                                .read(cowDetailProvider.notifier)
                                .addBreedingRecord(record);
                            Navigator.pop(ctx);
                          },
                    child: const Text('บันทึก', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
          .where((r) => r.matingDate != null && (r.pregnancyResult == null || r.pregnancyResult == 'รอตรวจ'))
          .toList();

      if (pendingMatings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่มีรายการที่รอตรวจท้อง'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Fix the active mating record automatically
      pendingMatings.sort((a, b) => b.matingDate!.compareTo(a.matingDate!));
      activeMating = pendingMatings.first;
    }

    // Look up sire cow details
    final sireCow = allCows.firstWhere(
      (c) => c.id == activeMating.sireId,
      orElse: () => Cow(
        id: activeMating.sireId ?? '-',
        farmId: '',
        zoneId: '',
        name: activeMating.sireId ?? '-',
        tagNumber: '',
        birthDate: DateTime.now(),
        gender: 'M',
        type: CowType.breederMale,
        breed: '',
        status: CowStatus.normal,
        latestWeight: 0,
        purchasePrice: 0,
      ),
    );

    String? result = activeMating.pregnancyResult == 'แท้ง' ? 'แท้งลูก' : activeMating.pregnancyResult;
    DateTime? expectedCalving = activeMating.expectedCalving;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.medical_services_outlined, color: Colors.orange, size: 22),
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
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pets, color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'ผสมกับ: ${_formatCowDisplayById(activeMating.sireId, allCows)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'วันที่ผสม: ${DateFormat('dd/MM/yyyy').format(activeMating.matingDate!)} (${DateTime.now().difference(activeMating.matingDate!).inDays} วันที่แล้ว)',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: result,
                  style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'ผลตรวจ / สถานะ *',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.fact_check_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ตั้งท้อง', child: Text('ตั้งท้อง (ผ่านการตรวจ)', style: TextStyle(fontSize: 16))),
                    DropdownMenuItem(value: 'ไม่ตั้งท้อง', child: Text('ไม่ตั้งท้อง (ผสมไม่ติด)', style: TextStyle(fontSize: 16))),
                    DropdownMenuItem(value: 'แท้งลูก', child: Text('แท้งลูก (แท้งระหว่างตั้งท้อง)', style: TextStyle(color: Colors.red, fontSize: 16))),
                  ],
                  onChanged: (v) {
                    setDialogState(() => result = v);
                    if (v == 'ตั้งท้อง' && activeMating.matingDate != null) {
                      expectedCalving = activeMating.matingDate!.add(const Duration(days: 283));
                    } else {
                      expectedCalving = null;
                    }
                  },
                ),
                if (result == 'ตั้งท้อง') ...[
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.purple.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: const Icon(Icons.calendar_today, color: Colors.purple),
                    title: const Text('กำหนดคลอดโดยประมาณ', style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      expectedCalving != null
                          ? DateFormat('dd/MM/yyyy').format(expectedCalving!)
                          : 'เลือกวันที่',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 16),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: expectedCalving ?? DateTime.now().add(const Duration(days: 283)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => expectedCalving = picked);
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
                              pregnancyResult: result == 'แท้งลูก' ? 'แท้ง' : result,
                              expectedCalving: expectedCalving,
                              calvingDate: null,
                              calvingResult: null,
                              calfId: null,
                            );
                            ref
                                .read(cowDetailProvider.notifier)
                                .addBreedingRecord(record);
                            Navigator.pop(ctx);
                          },
                    child: const Text('บันทึก', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
  void _showCalvingDialog({BreedingRecord? existingRecord}) {
    final records = ref.read(cowDetailProvider).breedingRecords;

    BreedingRecord activePregnancy;
    if (existingRecord != null) {
      activePregnancy = existingRecord;
    } else {
      final pregnantRecords = records
          .where((r) => r.pregnancyResult == 'ตั้งท้อง' && r.calvingDate == null)
          .toList();

      if (pregnantRecords.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่มีรายการที่รอคลอด'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Fix the active pregnancy record automatically
      pregnantRecords.sort((a, b) => (b.expectedCalving ?? DateTime(1900)).compareTo(a.expectedCalving ?? DateTime(1900)));
      activePregnancy = pregnantRecords.first;
    }

    DateTime calvingDate = activePregnancy.calvingDate ?? DateTime.now();
    String? calvingResult = activePregnancy.calvingResult;

    final resultOptions = [
      'คลอดปกติ (ลูกแข็งแรง)',
      'คลอดยาก (ต้องช่วยคลอด)',
      'ลูกตายหลังคลอด (Stillborn)',
      'แฝด (คลอดปกติ)',
      'แฝด (คลอดยาก)',
      'พิการ/ไม่สมบูรณ์',
      'อื่นๆ',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pregnant_woman, color: Colors.purple, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'รายการตั้งท้องปัจจุบัน',
                              style: TextStyle(fontSize: 13, color: Colors.purple, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activePregnancy.expectedCalving != null
                                  ? 'กำหนดคลอด: ${DateFormat('dd/MM/yyyy').format(activePregnancy.expectedCalving!)}'
                                  : 'ผสมวันที่: ${DateFormat('dd/MM/yyyy').format(activePregnancy.matingDate!)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: Colors.teal.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: const Icon(Icons.calendar_today, color: Colors.teal),
                  title: const Text('วันที่และเวลาที่คลอด', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy HH:mm น.').format(calvingDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: ctx,
                      initialDate: calvingDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(calvingDate),
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

                DropdownButtonFormField<String>(
                  initialValue: calvingResult,
                  style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'ผลการคลอด *',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  items: resultOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 16))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => calvingResult = v),
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
                    onPressed: calvingResult == null
                        ? null
                        : () {
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
                              calvingResult: calvingResult,
                              calfId: null,
                            );
                            ref
                                .read(cowDetailProvider.notifier)
                                .addBreedingRecord(record);
                            
                            final result = calvingResult;
                            Navigator.pop(ctx);

                            if (result != null && (result.contains('ปกติ') || result.contains('แฝด') || result.contains('ช่วยคลอด'))) {
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (mounted) {
                                  _showAddCalfPrompt(record);
                                }
                              });
                            }
                          },
                    child: const Text('บันทึก', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCalfPrompt(BreedingRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.child_care, color: Colors.teal),
            SizedBox(width: 8),
            Text('ลงทะเบียนลูกวัวแรกเกิด'),
          ],
        ),
        content: const Text(
          'บันทึกการคลอดสำเร็จเรียบร้อยแล้ว!\nคุณต้องการย้ายไปหน้าลงทะเบียนเพิ่มข้อมูลลูกวัวตัวใหม่ในระบบทันทีเลยหรือไม่?',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('ไว้ทีหลัง'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(
                      '/add_cow',
                      extra: {
                        'mother_id': widget.cow.id,
                        'father_id': record.sireId,
                        'breed_id': widget.cow.breed,
                        'birth_date': record.calvingDate ?? DateTime.now(),
                        'type': CowType.calf,
                        'breeding_record_id': record.id,
                      },
                    ).then((_) {
                      ref.read(cowDetailProvider.notifier).fetchAllData(widget.cow.id);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('ลงทะเบียนลูกวัว'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(cowDetailProvider);
    final records = detailState.breedingRecords;

    ref.listen<CowDetailState>(cowDetailProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกสำเร็จ!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(cowDetailProvider.notifier).clearFlags();
      } else if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(cowDetailProvider.notifier).clearFlags();
      }
    });

    if (detailState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isMale = widget.cow.gender == 'M';

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            if (!isMale) ...[
              _buildCurrentBreedingCards(context, records),
              const SizedBox(height: 20),
            ],

            // Separate records into ongoing vs completed
            Builder(
              builder: (context) {
                final ongoingRecords = records.where((r) => r.calvingDate == null && r.pregnancyResult != 'ไม่ตั้งท้อง' && r.pregnancyResult != 'แท้ง' && r.pregnancyResult != 'แท้งลูก').toList();
                final completedRecords = records.where((r) => r.calvingDate != null || r.pregnancyResult == 'ไม่ตั้งท้อง' || r.pregnancyResult == 'แท้ง' || r.pregnancyResult == 'แท้งลูก').toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Ongoing
                    Row(
                      children: [
                        const Icon(Icons.sync, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'รอบการผสมที่กำลังดำเนินการ',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'ไม่มีรอบการผสมที่กำลังดำเนินการอยู่',
                          style: TextStyle(color: AppColors.textHint, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...ongoingRecords.map((r) => _buildBreedingCard(r)),

                    const SizedBox(height: 16),

                    // Section 2: Completed History
                    Row(
                      children: [
                        const Icon(Icons.history, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isMale ? 'ประวัติการทำหน้าที่พ่อพันธุ์ที่เสร็จสิ้น' : 'ประวัติการผสมพันธุ์ที่เสร็จสิ้นแล้ว',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${completedRecords.length} รายการ',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'ยังไม่มีประวัติการผสมพันธุ์ที่เสร็จสิ้น',
                          style: TextStyle(color: AppColors.textHint, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...completedRecords.map((r) => _buildBreedingCard(r)),
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
              onPressed: _showMenu,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  // Build Primary Card (Bred Partner Info) & Secondary Card (Current Stage Progress Tracker)
  Widget _buildCurrentBreedingCards(
    BuildContext context,
    List<BreedingRecord> records,
  ) {
    final allCows = ref.watch(cowProvider).allCows;

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
          color: Colors.teal.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.teal, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'พร้อมผสมพันธุ์',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ไม่มีรายการเป็นสัดหรือผสมพันธุ์ค้างอยู่',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
    } else if (current.pregnancyResult == null || current.pregnancyResult == 'รอตรวจ') {
      stageTitle = 'รอตรวจท้อง';
      final days = DateTime.now().difference(current.matingDate!).inDays;
      stageSubtitle = 'ผสมแล้ว $days วัน ${days >= 60 ? "(ตรวจท้องได้แล้ว)" : "(รอครบ 60 วัน)"}';
      stageColor = Colors.orange;
      currentStep = 2;
    } else if (current.pregnancyResult == 'ตั้งท้อง') {
      stageTitle = 'ตั้งท้อง (รอคลอด)';
      if (current.expectedCalving != null) {
        final daysLeft = current.expectedCalving!.difference(DateTime.now()).inDays;
        stageSubtitle = daysLeft > 0 ? 'คลอดประมาณอีก $daysLeft วัน' : 'ครบกำหนดคลอดแล้ว';
      }
      stageColor = Colors.purple;
      currentStep = 3;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stageColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: stageColor.withValues(alpha: 0.06),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.timeline, color: stageColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stageTitle,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: stageColor),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ขั้นตอน $currentStep / 3',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: stageColor),
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
                  Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    stageSubtitle,
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
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
                const Text(
                  'พ่อพันธุ์คู่ผสม',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
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
                          border: Border.all(color: Colors.indigo.withValues(alpha: 0.25), width: 2),
                        ),
                        child: ClipOval(
                          child: sireCow.imageUrl != null && sireCow.imageUrl!.isNotEmpty
                              ? Image.network(
                                  sireCow.imageUrl!.startsWith('http')
                                      ? sireCow.imageUrl!.replaceAll('http://127.0.0.1:8000/storage/', 'http://127.0.0.1:8000/api/storage/')
                                      : 'http://127.0.0.1:8000/api/storage/' + sireCow.imageUrl!.replaceAll(RegExp(r'^/?storage/'), ''),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.pets, color: Colors.indigo, size: 28),
                                )
                              : const Icon(Icons.pets, color: Colors.indigo, size: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sireCow.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            const SizedBox(height: 2),
                            if (sireCow.tagNumber.isNotEmpty)
                              Text(
                                'แท็ก/NFC: ${sireCow.tagNumber}',
                                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      if (current.matingDate != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'วันที่ผสม',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy').format(current.matingDate!),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                          ],
                        ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'ยังไม่ได้บันทึกพ่อพันธุ์ (เป็นสัดเมื่อ: ${DateFormat('dd/MM/yyyy').format(current.heatDate!)})',
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
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
        content: const Text('คุณต้องการลบข้อมูลประวัติการผสมพันธุ์นี้ใช่หรือไม่? การดำเนินการนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              ref.read(cowDetailProvider.notifier).deleteBreedingRecord(record.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  Widget _buildBreedingCard(BreedingRecord record) {
    final allCows = ref.watch(cowProvider).allCows;
    final isMale = widget.cow.gender == 'M';

    if (isMale) {
      final stageColor = record.pregnancyResult == 'ตั้งท้อง'
          ? Colors.teal
          : record.pregnancyResult == 'ไม่ตั้งท้อง'
          ? Colors.red
          : Colors.orange;

      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: stageColor.withValues(alpha: 0.2)),
        ),
        color: stageColor.withValues(alpha: 0.04),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: stageColor.withValues(alpha: 0.12),
            child: Icon(Icons.female, color: stageColor),
          ),
          title: Text(
            'ผสมกับแม่พันธุ์: ${_formatCowDisplayById(record.damId, allCows)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (record.matingDate != null)
                Text(
                  'วันที่ผสม: ${DateFormat('dd/MM/yyyy HH:mm น.').format(record.matingDate!)}',
                  style: const TextStyle(fontSize: 14),
                ),
              Text(
                'ผลตรวจท้อง: ${record.pregnancyResult ?? "รอตรวจ"}',
                style: TextStyle(color: stageColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (record.calvingDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'คลอดจริง: ${DateFormat('dd/MM/yyyy HH:mm น.').format(record.calvingDate!)}',
                  style: TextStyle(
                    color: !['แท้ง', 'ลูกตาย'].contains(record.calvingResult)
                        ? Colors.teal
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'ผลการคลอด: ${record.calvingResult}',
                  style: TextStyle(
                    color: !['แท้ง', 'ลูกตาย'].contains(record.calvingResult)
                        ? Colors.teal
                        : Colors.red,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final stage = record.calvingResult != null
        ? 'คลอดแล้ว (${record.calvingResult})'
        : record.pregnancyResult != null
        ? 'ตรวจท้อง: ${record.pregnancyResult}'
        : record.matingDate != null
        ? 'รอตรวจท้อง'
        : record.heatDate != null
        ? 'รอผสม'
        : 'ไม่ระบุ';

    final stageColor = (record.calvingResult != null || record.pregnancyResult == 'ตั้งท้อง')
        ? Colors.teal
        : record.pregnancyResult == 'ไม่ตั้งท้อง' || record.pregnancyResult == 'แท้ง'
        ? Colors.red
        : record.matingDate != null
        ? Colors.orange
        : Colors.pink;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: stageColor.withValues(alpha: 0.2)),
      ),
      color: stageColor.withValues(alpha: 0.04),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: stageColor.withValues(alpha: 0.12),
          child: Icon(Icons.pets, color: stageColor),
        ),
        title: Text(
          stage,
          style: TextStyle(fontWeight: FontWeight.bold, color: stageColor, fontSize: 16),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
          onSelected: (val) {
            if (val == 'edit') {
              if (record.calvingDate != null) {
                _showCalvingDialog(existingRecord: record);
              } else if (record.pregnancyResult != null && record.pregnancyResult != 'รอตรวจ') {
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
                  Icon(Icons.edit, color: AppColors.primary, size: 20),
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
                  Text('ลบประวัติ', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.heatDate != null)
              Text(
                'เป็นสัด: ${DateFormat('dd/MM/yyyy HH:mm น.').format(record.heatDate!)}',
                style: const TextStyle(fontSize: 14),
              ),
            if (record.matingDate != null)
              Text(
                'ผสม: ${DateFormat('dd/MM/yyyy HH:mm น.').format(record.matingDate!)} (พ่อพันธุ์: ${_formatCowDisplayById(record.sireId, allCows)})',
                style: const TextStyle(fontSize: 14),
              ),
            if (record.expectedCalving != null)
              Text(
                'คลอดประมาณ: ${DateFormat('dd/MM/yyyy').format(record.expectedCalving!)}',
                style: const TextStyle(fontSize: 14),
              ),
            if (record.calvingDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'คลอดจริง: ${DateFormat('dd/MM/yyyy HH:mm น.').format(record.calvingDate!)}',
                style: TextStyle(
                  color: !['แท้ง', 'ลูกตาย'].contains(record.calvingResult)
                      ? Colors.teal
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'ผล: ${record.calvingResult}',
                style: TextStyle(
                  color: !['แท้ง', 'ลูกตาย'].contains(record.calvingResult)
                      ? Colors.teal
                      : Colors.red,
                  fontSize: 14,
                ),
              ),
              if ((record.calfId == null || record.calfId!.isEmpty) && (record.calvingResult != null && (record.calvingResult!.contains('ปกติ') || record.calvingResult!.contains('แฝด') || record.calvingResult!.contains('ช่วยคลอด')))) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push(
                        '/add_cow',
                        extra: {
                          'mother_id': widget.cow.id,
                          'father_id': record.sireId,
                          'breed_id': widget.cow.breed,
                          'birth_date': record.calvingDate,
                          'type': CowType.calf,
                          'breeding_record_id': record.id,
                        },
                      ).then((_) {
                        ref.read(cowDetailProvider.notifier).fetchAllData(widget.cow.id);
                      });
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('ลงทะเบียนลูกวัว', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ] else if (record.calfId != null && record.calfId!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 15, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text(
                        'ลงทะเบียนลูกวัวแล้ว (${_formatCowDisplayById(record.calfId, allCows)})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
