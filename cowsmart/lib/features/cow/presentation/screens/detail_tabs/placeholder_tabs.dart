import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/health_record.dart';
import 'package:cowsmart/features/cow/domain/growth_record.dart';
import '../../../providers/cow_detail_provider.dart';
import '../../../../health/providers/master_data_provider.dart';

class HealthTab extends ConsumerStatefulWidget {
  final Cow cow;
  const HealthTab({super.key, required this.cow});

  @override
  ConsumerState<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends ConsumerState<HealthTab> {
  @override
  void initState() {
    super.initState();
    // Load master data when tab opens
    Future.microtask(() {
      ref.read(masterDataProvider.notifier).fetchAll();
    });
  }

  void _showAddHealthRecordDialog() {
    // Get master data - load if needed
    var masterData = ref.read(masterDataProvider);
    if (masterData.diseases.isEmpty &&
        masterData.medicines.isEmpty &&
        masterData.vaccines.isEmpty &&
        !masterData.isLoading) {
      ref.read(masterDataProvider.notifier).fetchAll();
    }

    showDialog(
      context: context,
      builder: (ctx) => _HealthRecordDialog(
        cow: widget.cow,
        masterData: masterData,
        onSave: (record) async {
          await ref.read(cowDetailProvider.notifier).addHealthRecord(record);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(cowDetailProvider);
    final records = detailState.healthRecords;

    ref.listen<CowDetailState>(cowDetailProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกการรักษาสำเร็จ!'),
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

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            _buildSummaryCard(context, records),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'ประวัติการรักษาและฉีดวัคซีน',
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'ไม่มีข้อมูลประวัติสุขภาพ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...records.map((r) => _buildHealthCard(context, r)),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: detailState.isSaving ? null : _showAddHealthRecordDialog,
            backgroundColor: AppColors.primary,
            icon: detailState.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'บันทึกการรักษา',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<dynamic> records) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'ตรวจสุขภาพ',
              records.length.toString(),
              Icons.health_and_safety,
            ),
            _buildStatItem(
              'วัคซีนล่าสุด',
              '12 มี.ค. 67',
              Icons.vaccines_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHealthCard(BuildContext context, HealthRecord record) {
    final typeLabels = {
      'CT01': 'ตรวจสุขภาพทั่วไป',
      'CT02': 'ฉีดวัคซีน',
      'CT03': 'รักษาโรค',
      'CT04': 'ถ่ายพยาธิ',
    };

    IconData getIcon() {
      switch (record.checkupTypeId) {
        case 'CT02':
          return Icons.vaccines;
        case 'CT03':
          return Icons.medical_services;
        case 'CT04':
          return Icons.bug_report;
        default:
          return Icons.health_and_safety;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(record.recordDate),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (record.cost != null && record.cost! > 0)
                  Text(
                    '${record.cost!.toStringAsFixed(0)} ฿',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(getIcon(), color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabels[record.checkupTypeId] ?? 'ตรวจสุขภาพ',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Show vaccine/disease/medicine details
                      if (record.vaccineName != null)
                        Text(
                          'วัคซีน: ${record.vaccineName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (record.diseaseName != null)
                        Text(
                          'รักษา: ${record.diseaseName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (record.medicineName != null)
                        Text(
                          'ยา: ${record.medicineName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (record.adminName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ผู้ดำเนินการ: ${record.adminName}',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog สำหรับเพิ่มบันทึกสุขภาพ
class _HealthRecordDialog extends StatefulWidget {
  final Cow cow;
  final MasterDataState masterData;
  final Function(HealthRecord) onSave;

  const _HealthRecordDialog({
    required this.cow,
    required this.masterData,
    required this.onSave,
  });

  @override
  State<_HealthRecordDialog> createState() => _HealthRecordDialogState();
}

class _HealthRecordDialogState extends State<_HealthRecordDialog> {
  final costController = TextEditingController();
  final adminController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String selectedType = 'CT01';
  String? selectedVaccineId;
  String? selectedDiseaseId;
  String? selectedMedicineId;

  final checkupTypes = [
    {'id': 'CT01', 'name': 'ตรวจสุขภาพทั่วไป'},
    {'id': 'CT02', 'name': 'ฉีดวัคซีน'},
    {'id': 'CT03', 'name': 'ให้ยารักษา'},
  ];

  @override
  Widget build(BuildContext context) {
    final showVaccine = selectedType == 'CT02';
    final showDisease = selectedType == 'CT03';
    final showMedicine = selectedType == 'CT03';

    return AlertDialog(
      title: const Text('บันทึกการรักษา'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('วันที่'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => selectedDate = picked);
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(
                labelText: 'ประเภทการตรวจ',
                prefixIcon: Icon(Icons.category),
              ),
              items: checkupTypes.map((type) {
                return DropdownMenuItem(
                  value: type['id'],
                  child: Text(type['name']!),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    selectedType = val;
                    selectedVaccineId = null;
                    selectedDiseaseId = null;
                    selectedMedicineId = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (widget.masterData.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (showVaccine && !widget.masterData.isLoading)
              DropdownButtonFormField<String>(
                initialValue: selectedVaccineId,
                decoration: const InputDecoration(
                  labelText: 'วัคซีน',
                  prefixIcon: Icon(Icons.vaccines),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('เลือกวัคซีน'),
                  ),
                  ...widget.masterData.vaccines.map((v) {
                    return DropdownMenuItem(value: v.id, child: Text(v.name));
                  }),
                ],
                onChanged: (val) => setState(() => selectedVaccineId = val),
              ),
            if (showDisease && !widget.masterData.isLoading)
              DropdownButtonFormField<String>(
                initialValue: selectedDiseaseId,
                decoration: const InputDecoration(
                  labelText: 'โรค',
                  prefixIcon: Icon(Icons.coronavirus),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('เลือกโรค')),
                  ...widget.masterData.diseases.map((d) {
                    return DropdownMenuItem(value: d.id, child: Text(d.name));
                  }),
                ],
                onChanged: (val) => setState(() => selectedDiseaseId = val),
              ),
            if (showMedicine && !widget.masterData.isLoading) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedMedicineId,
                decoration: const InputDecoration(
                  labelText: 'ยา',
                  prefixIcon: Icon(Icons.medication),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('เลือกยา')),
                  ...widget.masterData.medicines.map((m) {
                    return DropdownMenuItem(value: m.id, child: Text(m.name));
                  }),
                ],
                onChanged: (val) => setState(() => selectedMedicineId = val),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ค่าใช้จ่าย (บาท)',
                prefixIcon: Icon(Icons.payments),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: adminController,
              decoration: const InputDecoration(
                labelText: 'ผู้ดำเนินการ (ชื่อ)',
                prefixIcon: Icon(Icons.person),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.masterData.isLoading
                    ? null
                    : () {
                        final cost = double.tryParse(costController.text);
                        final record = HealthRecord(
                          id: 'HR${DateTime.now().millisecondsSinceEpoch % 1000000}',
                          cowId: widget.cow.id,
                          recordDate: selectedDate,
                          checkupTypeId: selectedType,
                          vacId: selectedVaccineId,
                          diseaseId: selectedDiseaseId,
                          medId: selectedMedicineId,
                          cost: cost,
                          adminName: adminController.text.trim().isEmpty
                              ? null
                              : adminController.text.trim(),
                        );
                        widget.onSave(record);
                        Navigator.pop(context);
                      },
                child: const Text('บันทึก'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class GrowthTab extends ConsumerStatefulWidget {
  final Cow cow;
  const GrowthTab({super.key, required this.cow});

  @override
  ConsumerState<GrowthTab> createState() => _GrowthTabState();
}

class _GrowthTabState extends ConsumerState<GrowthTab> {
  void _showAddWeightSheet(BuildContext context) {
    final weightCtrl = TextEditingController();
    final girthCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.monitor_weight_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'บันทึกน้ำหนักใหม่',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'น้ำหนัก (กก.) *',
                            prefixIcon: Icon(Icons.scale),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: girthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'รอบอก (ซม.)',
                            prefixIcon: Icon(Icons.straighten),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'วันที่ชั่ง',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      final w = double.tryParse(weightCtrl.text);
                      if (w == null || w <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('กรุณากรอกน้ำหนักให้ถูกต้อง'),
                          ),
                        );
                        return;
                      }
                      final record = GrowthRecord(
                        id: 'GR${DateTime.now().millisecondsSinceEpoch % 1000000}',
                        cowId: widget.cow.id,
                        recordDate: selectedDate,
                        weight: w,
                        girth: double.tryParse(girthCtrl.text),
                      );
                      ref
                          .read(cowDetailProvider.notifier)
                          .addGrowthRecord(record);
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึก', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(cowDetailProvider);
    final records = detailState.growthRecords;

    ref.listen<CowDetailState>(cowDetailProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกน้ำหนักเรียบร้อยแล้ว!'),
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

    // Use growth records as source of truth; fallback to cow.latestWeight if none recorded yet
    final hasFallback = records.isEmpty && widget.cow.latestWeight > 0;
    final latestWeight = records.isNotEmpty
        ? records.first.weight
        : widget.cow.latestWeight;
    final prevWeight = records.length > 1 ? records[1].weight : null;
    final weightDiff = prevWeight != null ? latestWeight - prevWeight : null;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // Latest weight summary card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'น้ำหนักล่าสุด',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latestWeight > 0
                          ? '${latestWeight.toStringAsFixed(1)} กก.'
                          : '- กก.',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (weightDiff != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            weightDiff >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: weightDiff >= 0
                                ? AppColors.success
                                : AppColors.error,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${weightDiff >= 0 ? '+' : ''}${weightDiff.toStringAsFixed(1)} กก. จากครั้งก่อน',
                            style: TextStyle(
                              color: weightDiff >= 0
                                  ? AppColors.success
                                  : AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (records.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'บันทึกล่าสุด: ${DateFormat('dd/MM/yyyy').format(records.first.recordDate)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ] else if (hasFallback) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'น้ำหนักเริ่มต้น (ยังไม่มีประวัติการชั่ง)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'ประวัติการชั่งน้ำหนัก',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  hasFallback
                      ? '1 ครั้ง (เริ่มต้น)'
                      : '${records.length} ครั้ง',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (records.isEmpty && !hasFallback)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.monitor_weight_outlined,
                        size: 48,
                        color: AppColors.textHint,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'ยังไม่มีประวัติน้ำหนัก',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'กดปุ่ม + เพื่อบันทึกน้ำหนักแรก',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (hasFallback)
              // Fallback card: show initial weight entered when adding cow
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: AppColors.primary.withOpacity(0.04),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.flag_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'น้ำหนักเริ่มต้น',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'ที่กรอกไว้ตอนเพิ่มวัว',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${widget.cow.latestWeight.toStringAsFixed(1)} กก.',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...records.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final prev = i < records.length - 1
                    ? records[i + 1].weight
                    : null;
                final diff = prev != null ? r.weight - prev : null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.monitor_weight_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(r.recordDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (r.girth != null)
                                Text(
                                  'รอบอก: ${r.girth!.toStringAsFixed(1)} ซม.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${r.weight.toStringAsFixed(1)} กก.',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            if (diff != null)
                              Text(
                                '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: diff >= 0
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: detailState.isSaving
                ? null
                : () => _showAddWeightSheet(context),
            backgroundColor: AppColors.primary,
            icon: detailState.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'บันทึกน้ำหนัก',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class CostTab extends ConsumerWidget {
  final Cow cow;
  const CostTab({super.key, required this.cow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(cowDetailProvider);

    // Calculate total cost from health records (just for example)
    double totalHealthCost = detailState.healthRecords.fold(
      0,
      (sum, item) => sum + (item.cost ?? 0),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: AppColors.primary,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'ต้นทุนสะสมทั้งหมด',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  '${totalHealthCost + 15000} ฿',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  '(รวมค่าตัววัว 15,000 ฿)',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'แจกแจงต้นทุน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildCostItem(
          'ค่ารักษา/วัคซีน',
          totalHealthCost,
          Icons.medical_services_outlined,
          AppColors.error,
        ),
        _buildCostItem(
          'ค่าอาหาร (โดยประมาณ)',
          2450.0,
          Icons.grass_outlined,
          Colors.green,
        ),
        _buildCostItem(
          'ค่าแรง/อื่นๆ',
          800.0,
          Icons.engineering_outlined,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildCostItem(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        trailing: Text(
          '${NumberFormat('#,###').format(amount)} ฿',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
