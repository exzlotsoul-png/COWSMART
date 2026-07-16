import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/health_record.dart';
import 'package:cowsmart/features/cow/domain/growth_record.dart';
import '../../../providers/cow_detail_provider.dart';
import '../../../../health/providers/master_data_provider.dart';
import 'package:cowsmart/core/network/api_client.dart';

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
                      if (record.note != null && record.note!.isNotEmpty)
                        Text(
                          'รายละเอียด: ${record.note}',
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
  final noteController = TextEditingController();
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
  void dispose() {
    costController.dispose();
    adminController.dispose();
    noteController.dispose();
    super.dispose();
  }

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
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'รายละเอียดเพิ่มเติม / หมายเหตุ',
                hintText: 'กรอกรายละเอียดหรือข้อมูลเพิ่มเติม (ถ้ามี)',
                prefixIcon: Icon(Icons.description),
              ),
            ),
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
                          note: noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
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

class CostTab extends ConsumerStatefulWidget {
  final Cow cow;
  const CostTab({super.key, required this.cow});

  @override
  ConsumerState<CostTab> createState() => _CostTabState();
}

class _CostTabState extends ConsumerState<CostTab> {
  Map<String, dynamic>? _costData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCostData();
  }

  Future<void> _fetchCostData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/cow_costs/${widget.cow.id}');
      setState(() {
        _costData = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _costData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('โหลดข้อมูลไม่สำเร็จ', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _fetchCostData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    final summary = _costData!['summary'] as Map<String, dynamic>;
    final breakdown = _costData!['breakdown'] as Map<String, dynamic>;

    final totalCost = _parseDouble(summary['total_cost']);
    final healthCost = _parseDouble(summary['health_cost']);
    final feedCost = _parseDouble(summary['feed_cost']);
    final directCost = _parseDouble(summary['direct_cost']);
    final purchasePrice = _parseDouble(summary['purchase_price']);
    final totalIncome = _parseDouble(summary['total_income']);
    final netCost = _parseDouble(summary['net_cost']);

    // Health details
    final healthDetails = (breakdown['health'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    // Feed details
    final feedDetails = (breakdown['feed'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    // Direct cost details
    final directDetails = (breakdown['direct'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Cost breakdown for proportion bar
    final costParts = <_CostPart>[
      if (purchasePrice > 0) _CostPart('ราคาซื้อวัว', purchasePrice, Colors.purple, Icons.payments_outlined),
      if (healthCost > 0) _CostPart('ค่ารักษา/วัคซีน', healthCost, AppColors.error, Icons.medical_services_outlined),
      if (feedCost > 0) _CostPart('ค่าอาหาร (เฉลี่ยตามโซน)', feedCost, Colors.green, Icons.grass_outlined),
      if (directCost > 0) _CostPart('ค่าใช้จ่ายตรง', directCost, Colors.blue, Icons.receipt_long_outlined),
    ];

    return RefreshIndicator(
      onRefresh: _fetchCostData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total cost card
          _buildTotalCostCard(totalCost, totalIncome, netCost),
          const SizedBox(height: 12),

          // Estimated value comparison
          _buildValueComparisonCard(totalCost, widget.cow),
          const SizedBox(height: 16),

          // Summary cards row
          Row(
            children: [
              Expanded(child: _buildMiniSummary('ราคาซื้อ', purchasePrice, Colors.purple)),
              const SizedBox(width: 6),
              Expanded(child: _buildMiniSummary('ค่ารักษา', healthCost, AppColors.error)),
              const SizedBox(width: 6),
              Expanded(child: _buildMiniSummary('ค่าอาหาร', feedCost, Colors.green)),
              const SizedBox(width: 6),
              Expanded(child: _buildMiniSummary('อื่นๆ', directCost, Colors.blue)),
            ],
          ),
          const SizedBox(height: 20),

          // Proportion bar
          if (costParts.isNotEmpty) ...[
            _buildSectionTitle('สัดส่วนต้นทุน'),
            const SizedBox(height: 8),
            _buildProportionBar(costParts, totalCost),
            const SizedBox(height: 20),
          ],

          // Health cost history
          if (healthDetails.isNotEmpty) ...[
            _buildSectionTitle('ประวัติค่ารักษา/วัคซีน (${healthDetails.length} รายการ)'),
            const SizedBox(height: 8),
            ...healthDetails.map((h) => _buildHealthDetailCard(h)),
            const SizedBox(height: 16),
          ],

          // Feed cost history
          if (feedDetails.isNotEmpty) ...[
            _buildSectionTitle('ประวัติค่าอาหาร (เฉลี่ยตามโซน)'),
            const SizedBox(height: 8),
            ...feedDetails.take(10).map((f) => _buildFeedDetailCard(f)),
            if (feedDetails.length > 10)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'แสดง 10 จาก ${feedDetails.length} รายการ',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
          ],

          // Direct costs
          if (directDetails.isNotEmpty) ...[
            _buildSectionTitle('ค่าใช้จ่ายตรงรายตัว (${directDetails.length} รายการ)'),
            const SizedBox(height: 8),
            ...directDetails.map((d) => _buildDirectCostCard(d)),
            const SizedBox(height: 16),
          ],

          // Empty state
          if (healthDetails.isEmpty && feedDetails.isEmpty && directDetails.isEmpty && purchasePrice <= 0)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีข้อมูลค่าใช้จ่ายของวัวตัวนี้',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'เมื่อมีการบันทึกค่ารักษาพยาบาล ค่าอาหาร\nหรือค่าใช้จ่ายอื่นๆ จะแสดงที่นี่',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 80), // FAB clearance
        ],
      ),
    );
  }

  Widget _buildTotalCostCard(double total, double income, double net) {
    return Card(
      elevation: 3,
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
                SizedBox(width: 6),
                Text('ค่าเลี้ยงดูสะสมทั้งหมด', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${NumberFormat('#,##0').format(total)} ฿',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (income > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'รายได้: ${NumberFormat('#,##0').format(income)} ฿  |  สุทธิ: ${NumberFormat('#,##0').format(net)} ฿',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSummary(String label, double amount, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                label.contains('รักษา') ? Icons.medical_services_outlined
                    : label.contains('อาหาร') ? Icons.grass_outlined
                    : label.contains('ซื้อ') ? Icons.payments_outlined
                    : Icons.receipt_long_outlined,
                color: color, size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[750], fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${NumberFormat('#,##0').format(amount)} ฿',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: amount > 0 ? AppColors.textPrimary : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
    );
  }

  Widget _buildProportionBar(List<_CostPart> parts, double total) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: parts.map((p) {
                    final ratio = p.amount / total;
                    return Expanded(
                      flex: (ratio * 100).round().clamp(1, 100),
                      child: Container(color: p.color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            ...parts.map((p) {
              final pct = total > 0 ? (p.amount / total * 100).toStringAsFixed(0) : '0';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: p.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(p.icon, size: 16, color: p.color),
                    const SizedBox(width: 6),
                    Expanded(child: Text(p.label, style: const TextStyle(fontSize: 13))),
                    Text(
                      '${NumberFormat('#,##0').format(p.amount)} ฿ ($pct%)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthDetailCard(Map<String, dynamic> h) {
    final date = h['record_date'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(h['record_date'].toString()))
        : '-';
    final cost = _parseDouble(h['cost']);
    final disease = h['disease_name'];
    final medicine = h['medicine_name'];
    final vaccine = h['vaccine_name'];

    String description = '';
    if (disease != null) description += 'โรค: $disease';
    if (medicine != null) description += '${description.isNotEmpty ? ' | ' : ''}ยา: $medicine';
    if (vaccine != null) description += '${description.isNotEmpty ? ' | ' : ''}วัคซีน: $vaccine';
    if (description.isEmpty) description = 'บันทึกสุขภาพ';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: false,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.medical_services_outlined, color: AppColors.error, size: 20),
        ),
        title: Text(description, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(date, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: Text(
          '${NumberFormat('#,##0').format(cost)} ฿',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildFeedDetailCard(Map<String, dynamic> f) {
    final rawDate = f['date'] ?? '-';
    final feedType = f['type'] ?? 'อาหาร';
    final costPerCow = _parseDouble(f['cost_per_cow']);
    final totalCost = _parseDouble(f['cost']);

    String displayDate = rawDate.toString();
    if (rawDate != '-') {
      try {
        final parsedDate = DateTime.parse(rawDate.toString());
        displayDate = DateFormat('dd/MM/yyyy').format(parsedDate);
      } catch (e) {
        // Fallback to raw string if parsing fails
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: false,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.grass_outlined, color: Colors.green, size: 20),
        ),
        title: Text(feedType, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        subtitle: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(displayDate, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Text(
              '(ทั้งโซน ${NumberFormat('#,##0').format(totalCost)} ฿)',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Text(
          '${NumberFormat('#,##0').format(costPerCow)} ฿',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildDirectCostCard(Map<String, dynamic> d) {
    final date = d['transaction_date'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(d['transaction_date'].toString()))
        : '-';
    final amount = _parseDouble(d['amount']);
    final title = d['title'] ?? d['category'] ?? 'ค่าใช้จ่าย';
    final notes = d['notes'];

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: false,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_long_outlined, color: Colors.blue, size: 20),
        ),
        title: Text(title.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(date, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
            if (notes != null && notes.toString().isNotEmpty)
              Text(notes.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Text(
          '${NumberFormat('#,##0').format(amount)} ฿',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildValueComparisonCard(double totalCost, Cow cow) {
    final estimatedValue = cow.estimatedValue;
    final profit = estimatedValue - totalCost;
    final isProfitable = profit >= 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, size: 22, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'การวิเคราะห์ความคุ้มค่า',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('มูลค่าประมาณ', style: TextStyle(fontSize: 13, color: Colors.grey[750], fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,##0').format(estimatedValue)} ฿',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green),
                      ),
                      Text(
                        '(${cow.latestWeight.toStringAsFixed(0)} กก. × 120 ฿/กก.)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey[200],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('ค่าเลี้ยงดูสะสม', style: TextStyle(fontSize: 13, color: Colors.grey[750], fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,##0').format(totalCost)} ฿',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: (isProfitable ? Colors.green : Colors.red).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isProfitable ? Icons.trending_up : Icons.trending_down,
                    color: isProfitable ? Colors.green : AppColors.error,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isProfitable
                        ? 'กำไรประมาณ ${NumberFormat('#,##0').format(profit)} ฿'
                        : 'ขาดทุนประมาณ ${NumberFormat('#,##0').format(profit.abs())} ฿',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isProfitable ? Colors.green : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostPart {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  _CostPart(this.label, this.amount, this.color, this.icon);
}
