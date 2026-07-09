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
  void _showMenu() {
    final records = ref.read(cowDetailProvider).breedingRecords;
    
    // Find active breeding cycle
    final activeRecords = records
        .where(
          (r) =>
              r.heatDate != null &&
              r.calvingDate == null &&
              r.pregnancyResult != 'ไม่ตั้งท้อง',
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.pink),
              title: const Text('บันทึกเป็นสัด'),
              subtitle: const Text('บันทึกวันที่วัวเป็นสัด'),
              enabled: canRecordHeat,
              onTap: () {
                Navigator.pop(ctx);
                _showHeatDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.pets, color: AppColors.primary),
              title: const Text('บันทึกผสมพันธุ์'),
              subtitle: const Text('เลือกพ่อพันธุ์และบันทึกการผสม'),
              enabled: canRecordMating,
              onTap: () {
                Navigator.pop(ctx);
                _showMatingDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_services, color: Colors.orange),
              title: const Text('บันทึกตรวจท้อง'),
              subtitle: const Text('บันทึกผลการตรวจท้อง'),
              enabled: canRecordPregnancyCheck,
              onTap: () {
                Navigator.pop(ctx);
                _showPregnancyCheckDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.child_care, color: Colors.teal),
              title: const Text('บันทึกการคลอด'),
              subtitle: const Text('บันทึกผลการคลอดและลูกวัว'),
              enabled: canRecordCalving,
              onTap: () {
                Navigator.pop(ctx);
                _showCalvingDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Record Heat
  void _showHeatDialog() {
    DateTime heatDate = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('บันทึกเป็นสัด'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('วันที่และเวลาที่เป็นสัด'),
                subtitle: Text(DateFormat('dd/MM/yyyy HH:mm น.').format(heatDate)),
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
                        id: 'BR${DateTime.now().millisecondsSinceEpoch % 1000000}',
                        damId: widget.cow.id,
                        heatDate: heatDate,
                        calvingDate: null,
                        calvingResult: null,
                        calfId: null,
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

  // Step 2: Record Mating with sire dropdown
  void _showMatingDialog() {
    final records = ref.read(cowDetailProvider).breedingRecords;
    final bulls = ref.read(bullsProvider);

    // Filter records that have heatDate but no matingDate yet
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

    if (bulls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีพ่อพันธุ์ในระบบ กรุณาเพิ่มวัวผู้ก่อน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    BreedingRecord? selectedHeat;
    Cow? selectedBull;
    DateTime matingDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('บันทึกผสมพันธุ์'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Select Heat Record
                DropdownButtonFormField<BreedingRecord>(
                  initialValue: selectedHeat,
                  decoration: const InputDecoration(
                    labelText: 'เลือกรายการเป็นสัด',
                    prefixIcon: Icon(Icons.favorite, color: Colors.pink),
                  ),
                  items: pendingHeats
                      .map(
                        (h) => DropdownMenuItem(
                          value: h,
                          child: Text(
                            'เป็นสัด ${DateFormat('dd/MM/yyyy').format(h.heatDate!)} (ID: ${h.id})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedHeat = v),
                ),
                const SizedBox(height: 16),
                // Select Bull
                DropdownButtonFormField<Cow>(
                  initialValue: selectedBull,
                  decoration: const InputDecoration(
                    labelText: 'เลือกพ่อพันธุ์',
                    prefixIcon: Icon(Icons.male, color: Colors.blue),
                  ),
                  items: bulls
                      .map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text('${b.name} (${b.id}) - ${b.breed}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBull = v),
                ),
                const SizedBox(height: 16),
                 // Mating Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('วันที่และเวลาที่ผสม'),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm น.').format(matingDate)),
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
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedHeat == null || selectedBull == null
                        ? null
                        : () {
                            final record = BreedingRecord(
                              id: selectedHeat!.id,
                              damId: widget.cow.id,
                              sireId: selectedBull!.id,
                              heatDate: selectedHeat!.heatDate,
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

  // Step 4: Record Calving (update breeding record)
  void _showCalvingDialog() {
    final records = ref.read(cowDetailProvider).breedingRecords;

    // Filter records that are pregnant and not yet calved
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

    BreedingRecord? selectedPregnancy;
    DateTime calvingDate = DateTime.now();
    String? calvingResult;

    final resultOptions = ['คลอดปกติ', 'คลอดยาก', 'แท้ง', 'ลูกตาย', 'แฝด'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('บันทึกการคลอด'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<BreedingRecord>(
                  initialValue: selectedPregnancy,
                  decoration: const InputDecoration(
                    labelText: 'เลือกรายการตั้งท้อง',
                    prefixIcon: Icon(
                      Icons.pregnant_woman,
                      color: Colors.purple,
                    ),
                  ),
                  items: pregnantRecords
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            'ผสม ${DateFormat('dd/MM/yyyy').format(p.matingDate!)} - คลอดประมาณ ${DateFormat('dd/MM/yyyy').format(p.expectedCalving!)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedPregnancy = v),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('วันที่และเวลาที่คลอด'),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm น.').format(calvingDate)),
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
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: calvingResult,
                  decoration: const InputDecoration(
                    labelText: 'ผลการคลอด',
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                  items: resultOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
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
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        selectedPregnancy == null || calvingResult == null
                        ? null
                        : () {
                            // Update existing breeding record with calving info
                            final record = BreedingRecord(
                              id: selectedPregnancy!.id,
                              damId: selectedPregnancy!.damId,
                              sireId: selectedPregnancy!.sireId,
                              heatDate: selectedPregnancy!.heatDate,
                              matingDate: selectedPregnancy!.matingDate,
                              checkDate: selectedPregnancy!.checkDate,
                              pregnancyResult:
                                  selectedPregnancy!.pregnancyResult,
                              expectedCalving:
                                  selectedPregnancy!.expectedCalving,
                              calvingDate: calvingDate,
                              calvingResult: calvingResult,
                              calfId: null,
                            );
                            ref
                                .read(cowDetailProvider.notifier)
                                .addBreedingRecord(record);
                            
                            final result = calvingResult;
                            Navigator.pop(ctx);

                            if (result == 'คลอดปกติ' || result == 'แฝด') {
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (mounted) {
                                  _showAddCalfPrompt(record);
                                }
                              });
                            }
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

  void _showAddCalfPrompt(BreedingRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                      },
                    );
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

  // Step 3: Pregnancy Check
  void _showPregnancyCheckDialog() {
    final records = ref.read(cowDetailProvider).breedingRecords;
    final pendingMatings = records
        .where((r) => r.matingDate != null && r.pregnancyResult == null)
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

    BreedingRecord? selectedMating;
    String? result;
    DateTime? expectedCalving;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('บันทึกตรวจท้อง'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<BreedingRecord>(
                  initialValue: selectedMating,
                  decoration: const InputDecoration(
                    labelText: 'เลือกรายการผสม',
                    prefixIcon: Icon(Icons.pets),
                  ),
                  items: pendingMatings
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            'ผสม ${DateFormat('dd/MM/yyyy').format(m.matingDate!)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedMating = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: result,
                  decoration: const InputDecoration(labelText: 'ผลตรวจ'),
                  items: ['ตั้งท้อง', 'ไม่ตั้งท้อง']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() => result = v);
                    if (v == 'ตั้งท้อง' && selectedMating?.matingDate != null) {
                      // Auto calculate expected calving (~283 days after mating)
                      expectedCalving = selectedMating!.matingDate!.add(
                        const Duration(days: 283),
                      );
                    }
                  },
                ),
                if (result == 'ตั้งท้อง') ...[
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('คลอดประมาณ'),
                    subtitle: Text(
                      expectedCalving != null
                          ? DateFormat('dd/MM/yyyy').format(expectedCalving!)
                          : 'เลือกวันที่',
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            expectedCalving ??
                            DateTime.now().add(const Duration(days: 283)),
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
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedMating == null || result == null
                        ? null
                        : () {
                            final record = BreedingRecord(
                              id: selectedMating!.id,
                              damId: widget.cow.id,
                              sireId: selectedMating!.sireId,
                              heatDate: selectedMating!.heatDate,
                              matingDate: selectedMating!.matingDate,
                              checkDate: DateTime.now(),
                              pregnancyResult: result,
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
              _buildCurrentStatusCard(context, records),
              const SizedBox(height: 16),
              _buildSummaryCard(context, records),
              const SizedBox(height: 24),
            ],
            Row(
              children: [
                Text(
                  isMale ? 'ประวัติการทำหน้าที่พ่อพันธุ์' : 'ประวัติการผสมพันธุ์',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${records.length} รายการ',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.pets_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        isMale ? 'ยังไม่มีประวัติการผสมกับแม่พันธุ์' : 'ยังไม่มีประวัติการผสมพันธุ์',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...records.map((r) => _buildBreedingCard(r)),
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

  Widget _buildCurrentStatusCard(
    BuildContext context,
    List<BreedingRecord> records,
  ) {
    // Check if there are any recent calving records (within last 60 days)
    final recentCalving = records.where((r) => r.calvingDate != null).toList()
      ..sort((a, b) => b.calvingDate!.compareTo(a.calvingDate!));

    if (recentCalving.isNotEmpty) {
      final lastCalving = recentCalving.first;
      final daysSince = DateTime.now()
          .difference(lastCalving.calvingDate!)
          .inDays;
      final isSuccess = !['แท้ง', 'ลูกตาย'].contains(lastCalving.calvingResult);

      return _buildStatusCard(
        context,
        icon: isSuccess ? Icons.child_care : Icons.sentiment_dissatisfied,
        title: lastCalving.calvingResult ?? 'คลอดแล้ว',
        subtitle: '$daysSince วันที่แล้ว',
        color: isSuccess ? Colors.teal : Colors.red,
        date: lastCalving.calvingDate,
        detail: lastCalving.calfId != null
            ? 'ลูกวัว: ${lastCalving.calfId}'
            : isSuccess
            ? 'คลอดสำเร็จ'
            : 'คลอดไม่สำเร็จ',
      );
    }

    // Find the most recent active record
    final activeRecords = records
        .where(
          (r) =>
              r.heatDate != null &&
              (r.pregnancyResult == null || r.pregnancyResult == 'รอตรวจ'),
        )
        .toList();

    if (activeRecords.isEmpty) {
      // No active breeding cycle
      final lastPregnant =
          records.where((r) => r.pregnancyResult == 'ตั้งท้อง').toList()..sort(
            (a, b) => (b.checkDate ?? DateTime(1900)).compareTo(
              a.checkDate ?? DateTime(1900),
            ),
          );

      if (lastPregnant.isNotEmpty &&
          lastPregnant.first.expectedCalving != null) {
        final daysUntilCalving = lastPregnant.first.expectedCalving!
            .difference(DateTime.now())
            .inDays;
        return _buildStatusCard(
          context,
          icon: Icons.pregnant_woman,
          title: 'รอคลอด',
          subtitle: daysUntilCalving > 0
              ? 'อีก $daysUntilCalving วัน'
              : daysUntilCalving == 0
              ? 'คลอดวันนี้!'
              : 'เลยกำหนด ${-daysUntilCalving} วัน',
          color: Colors.purple,
          date: lastPregnant.first.expectedCalving,
          detail:
              'คลอดประมาณ: ${DateFormat('dd/MM/yyyy').format(lastPregnant.first.expectedCalving!)}',
        );
      }

      return _buildStatusCard(
        context,
        icon: Icons.check_circle_outline,
        title: 'พร้อมผสมพันธุ์',
        subtitle: 'ไม่มีรายการเป็นสัด',
        color: const Color(0xFF5D8A5E),
        detail: 'กด + เพื่อบันทึกเป็นสัด',
      );
    }

    // Sort by most recent heat date
    activeRecords.sort((a, b) => b.heatDate!.compareTo(a.heatDate!));
    final current = activeRecords.first;
    final daysSinceHeat = DateTime.now().difference(current.heatDate!).inDays;

    if (current.matingDate == null) {
      // Heat recorded, waiting for mating
      return _buildStatusCard(
        context,
        icon: Icons.favorite,
        title: 'เป็นสัด',
        subtitle: '$daysSinceHeat วันที่แล้ว',
        color: Colors.pink,
        date: current.heatDate,
        detail: daysSinceHeat > 3
            ? 'ควรผสมพันธุ์โดยเร็ว (เลยช่วง 3 วันแรกแล้ว)'
            : 'ช่วงเวลาที่เหมาะสมสำหรับการผสม',
      );
    } else {
      // Mated, waiting for pregnancy check
      final daysSinceMating = DateTime.now()
          .difference(current.matingDate!)
          .inDays;
      return _buildStatusCard(
        context,
        icon: Icons.hourglass_bottom,
        title: 'รอตรวจท้อง',
        subtitle: 'ผสมแล้ว $daysSinceMating วัน',
        color: Colors.orange,
        date: current.matingDate,
        detail: daysSinceMating >= 60
            ? 'สามารถตรวจท้องได้แล้ว (60+ วัน)'
            : 'รอจนถึง 60 วันเพื่อตรวจท้อง (${60 - daysSinceMating} วัน)',
        sireId: current.sireId,
      );
    }
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    DateTime? date,
    String? detail,
    String? sireId,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // decorative circle top-right
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: 40,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'สถานะปัจจุบัน',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.timelapse,
                          label: subtitle,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoChip(
                            icon: Icons.calendar_today,
                            label: DateFormat('dd/MM/yyyy').format(date),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (sireId != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoChip(
                      icon: Icons.male,
                      label: 'พ่อพันธุ์: $sireId',
                    ),
                  ],
                   if (detail != null) ...[
                    const SizedBox(height: 12),
                    if (title == 'รอคลอด')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.child_care,
                                color: color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'กำหนดคลอดโดยประมาณ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: color.withOpacity(0.8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    detail.replaceAll('คลอดประมาณ: ', ''),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildInfoChip(
                        icon: Icons.lightbulb_outline,
                        label: detail,
                        fullWidth: true,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<BreedingRecord> records) {
    final pregnant = records
        .where((r) => r.pregnancyResult == 'ตั้งท้อง')
        .length;
    final heatOnly = records
        .where((r) => r.heatDate != null && r.matingDate == null)
        .length;
    final mated = records
        .where((r) => r.matingDate != null && r.pregnancyResult == null)
        .length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildStatItem(
              Icons.favorite,
              heatOnly.toString(),
              'เป็นสัด',
              Colors.pink,
            ),
            _buildStatItem(
              Icons.pets,
              mated.toString(),
              'รอตรวจ',
              Colors.orange,
            ),
            _buildStatItem(
              Icons.check_circle,
              pregnant.toString(),
              'ตั้งท้อง',
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
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
    final isMale = widget.cow.gender == 'M';

    if (isMale) {
      final stageColor = record.pregnancyResult == 'ตั้งท้อง'
          ? Colors.green
          : record.pregnancyResult == 'ไม่ตั้งท้อง'
          ? Colors.red
          : Colors.orange;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: stageColor.withOpacity(0.1),
            child: Icon(Icons.female, color: stageColor),
          ),
          title: Text(
            'ผสมกับแม่พันธุ์: ${record.damId}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (record.matingDate != null)
                Text(
                  'วันที่ผสม: ${DateFormat('dd/MM/yyyy HH:mm น.').format(record.matingDate!)}',
                ),
              Text(
                'ผลตรวจท้อง: ${record.pregnancyResult ?? "รอตรวจ"}',
                style: TextStyle(color: stageColor, fontWeight: FontWeight.bold),
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
                  ),
                ),
                Text(
                  'ผลการคลอด: ${record.calvingResult}',
                  style: TextStyle(
                    color: !['แท้ง', 'ลูกตาย'].contains(record.calvingResult)
                        ? Colors.teal
                        : Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final stage = record.pregnancyResult != null
        ? 'ตรวจท้อง: ${record.pregnancyResult}'
        : record.matingDate != null
        ? 'รอตรวจท้อง'
        : record.heatDate != null
        ? 'รอผสม'
        : 'ไม่ระบุ';

    final stageColor = record.pregnancyResult == 'ตั้งท้อง'
        ? Colors.green
        : record.pregnancyResult == 'ไม่ตั้งท้อง'
        ? Colors.red
        : record.matingDate != null
        ? Colors.orange
        : Colors.pink;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: stageColor.withOpacity(0.1),
          child: Icon(Icons.pets, color: stageColor),
        ),
        title: Text(
          stage,
          style: TextStyle(fontWeight: FontWeight.bold, color: stageColor),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red[300]),
          onPressed: () => _confirmDelete(record),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.heatDate != null)
              Text(
                'เป็นสัด: ${DateFormat('dd/MM/yyyy HH:mm น.').format(record.heatDate!)}',
              ),
            if (record.matingDate != null)
              Text(
                'ผสม: ${DateFormat('dd/MM/yyyy HH:mm น.').format(record.matingDate!)} พ่อ: ${record.sireId ?? '-'}',
              ),
            if (record.expectedCalving != null)
              Text(
                'คลอดประมาณ: ${DateFormat('dd/MM/yyyy').format(record.expectedCalving!)}',
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
                ),
              ),
              Text(
                'ผล: ${record.calvingResult}',
                style: TextStyle(
                  color: !['แท้ง', 'ลูกตาย'].contains(record.calvingResult)
                      ? Colors.teal
                      : Colors.red,
                ),
              ),
              if (record.calfId == null && (record.calvingResult == 'คลอดปกติ' || record.calvingResult == 'แฝด')) ...[
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
                        },
                      );
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('ลงทะเบียนลูกวัว', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
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
