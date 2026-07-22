import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';
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
            content: Text(
              'บันทึกการรักษาสำเร็จ!',
              style: TextStyle(fontSize: 15),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(cowDetailProvider.notifier).clearFlags();
      } else if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!, style: const TextStyle(fontSize: 15)),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            _buildSummaryCard(context, records),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.history,
                  size: 22,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                const Text(
                  'ประวัติการรักษาและฉีดวัคซีน',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${records.length} รายการ',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (records.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        size: 64,
                        color: Colors.grey[350],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ยังไม่มีข้อมูลประวัติสุขภาพ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
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
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add, color: Colors.white, size: 24),
            label: const Text(
              'บันทึกการรักษา',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<dynamic> records) {
    // Count by type
    int vaccineCount = 0;
    int treatCount = 0;
    int checkupCount = 0;
    for (final r in records) {
      if (r.checkupTypeId == 'CT02') {
        vaccineCount++;
      } else if (r.checkupTypeId == 'CT03') {
        treatCount++;
      } else {
        checkupCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5D7552), Color(0xFF4A6040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 12,
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.monitor_heart,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'สรุปสุขภาพ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'ทั้งหมด',
                    records.length.toString(),
                    Icons.assignment,
                    color: Colors.white,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(
                  child: _buildStatItem(
                    'ตรวจสุขภาพ',
                    checkupCount.toString(),
                    Icons.health_and_safety,
                    color: const Color(0xFF7BF562), // Bright green
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(
                  child: _buildStatItem(
                    'วัคซีน',
                    vaccineCount.toString(),
                    Icons.vaccines,
                    color: const Color(0xFF64B5F6), // Bright blue
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(
                  child: _buildStatItem(
                    'รักษาโรค',
                    treatCount.toString(),
                    Icons.medical_services,
                    color: const Color(0xFFFF6B6B), // Coral red
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    Color color = Colors.white,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color == Colors.white ? Colors.white70 : color,
          size: 22,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: color != Colors.white
                ? FontWeight.w500
                : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
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

    Color getTypeColor() {
      switch (record.checkupTypeId) {
        case 'CT02':
          return AppColors.info;
        case 'CT03':
          return AppColors.error;
        case 'CT04':
          return AppColors.warning;
        default:
          return AppColors.success;
      }
    }

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

    final typeColor = getTypeColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: typeColor, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: date badge + cost
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(getIcon(), color: typeColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabels[record.checkupTypeId] ?? 'ตรวจสุขภาพ',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'dd/MM/yyyy',
                              ).format(record.recordDate),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (record.cost != null && record.cost! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${NumberFormat('#,##0').format(record.cost)} ฿',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryDark,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                    onSelected: (val) async {
                      if (val == 'edit') {
                        final masterData = ref.read(masterDataProvider);
                        showDialog(
                          context: context,
                          builder: (ctx) => _HealthRecordDialog(
                            cow: widget.cow,
                            masterData: masterData,
                            initialRecord: record,
                            onSave: (updatedRecord) {
                              ref.read(cowDetailProvider.notifier).updateHealthRecord(updatedRecord);
                            },
                          ),
                        );
                      } else if (val == 'delete') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('ยืนยันการลบ'),
                            content: const Text('คุณต้องการลบข้อมูลประวัติสุขภาพนี้ใช่หรือไม่? การดำเนินการนี้ไม่สามารถย้อนกลับได้'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('ยกเลิก'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref.read(cowDetailProvider.notifier).deleteHealthRecord(record.id);
                                  Navigator.pop(ctx);
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('ลบ'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text('แก้ไขประวัติ'),
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
                ],
              ),

              // Detail rows
              if (record.vaccineName != null ||
                  record.diseaseName != null ||
                  record.medicineName != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (record.vaccineName != null)
                        _buildDetailRow(
                          Icons.vaccines,
                          'วัคซีน',
                          record.vaccineName!,
                        ),
                      if (record.diseaseName != null)
                        _buildDetailRow(
                          Icons.coronavirus,
                          'โรค',
                          record.diseaseName!,
                        ),
                      if (record.medicineName != null)
                        _buildDetailRow(
                          Icons.medication,
                          'ยา',
                          record.medicineName!,
                        ),
                    ],
                  ),
                ),
              ],

              if (record.images.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: record.images.length,
                    itemBuilder: (context, index) {
                      String raw = record.images[index];
                      String finalImgUrl = raw;
                      bool isLocalBlob = raw.contains('blob:');

                      if (!isLocalBlob) {
                        if (raw.contains('/storage/http')) {
                          raw = raw.substring(raw.indexOf('/storage/http') + 9);
                        }
                        if (raw.startsWith('http://') || raw.startsWith('https://')) {
                          finalImgUrl = raw.replaceAll('http://127.0.0.1:8000/storage/', 'http://127.0.0.1:8000/api/storage/');
                        } else {
                          finalImgUrl = 'http://127.0.0.1:8000/api/storage/' + raw.replaceAll(RegExp(r'^/?storage/'), '');
                        }
                      }

                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(10),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  InteractiveViewer(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        finalImgUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Container(
                                          padding: const EdgeInsets.all(20),
                                          color: Colors.white,
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                              SizedBox(height: 8),
                                              Text('ไม่สามารถโหลดรูปภาพได้'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white),
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: finalImgUrl.startsWith('http')
                                ? Image.network(
                                    finalImgUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print('❌ Image.network failed for URL: "$finalImgUrl" | Error: $error');
                                      return const Icon(Icons.broken_image, color: Colors.grey);
                                    },
                                  )
                                : Image.file(
                                    File(finalImgUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print('❌ Image.file failed for Path: "$finalImgUrl" | Error: $error');
                                      return const Icon(Icons.broken_image, color: Colors.grey);
                                    },
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (record.note != null && record.note!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.note!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (record.adminName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ผู้ดำเนินการ: ${record.adminName}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog สำหรับเพิ่ม/แก้ไขบันทึกสุขภาพ
class _HealthRecordDialog extends ConsumerStatefulWidget {
  final Cow cow;
  final MasterDataState masterData;
  final HealthRecord? initialRecord;
  final Function(HealthRecord) onSave;

  const _HealthRecordDialog({
    required this.cow,
    required this.masterData,
    this.initialRecord,
    required this.onSave,
  });

  @override
  ConsumerState<_HealthRecordDialog> createState() => _HealthRecordDialogState();
}

class _HealthRecordDialogState extends ConsumerState<_HealthRecordDialog> {
  final costController = TextEditingController();
  final adminController = TextEditingController();
  final noteController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String selectedType = 'CT01';
  List<String> selectedVaccineIds = [];
  String? selectedDiseaseId;
  List<String> selectedMedicineIds = [];
  List<XFile> selectedImageFiles = [];
  List<String> existingImageUrls = [];
  bool isUploading = false;

  final checkupTypes = [
    {'id': 'CT01', 'name': 'ตรวจสุขภาพทั่วไป'},
    {'id': 'CT02', 'name': 'ฉีดวัคซีน'},
    {'id': 'CT03', 'name': 'ให้ยารักษา'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRecord != null) {
      final r = widget.initialRecord!;
      selectedDate = r.recordDate;
      selectedType = r.checkupTypeId;
      selectedVaccineIds = List<String>.from(r.vacIds);
      if (selectedVaccineIds.isEmpty && r.vacId != null) selectedVaccineIds.add(r.vacId!);
      selectedDiseaseId = r.diseaseId;
      selectedMedicineIds = List<String>.from(r.medIds);
      if (selectedMedicineIds.isEmpty && r.medId != null) selectedMedicineIds.add(r.medId!);
      existingImageUrls = List<String>.from(r.images);
      noteController.text = r.note ?? '';
      costController.text = r.cost != null ? r.cost!.toStringAsFixed(0) : '';
      adminController.text = r.adminName ?? '';
    }
  }

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
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medical_services,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'บันทึกการรักษา',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.calendar_today, size: 22),
              title: const Text('วันที่', style: TextStyle(fontSize: 16)),
              subtitle: Text(
                DateFormat('dd/MM/yyyy').format(selectedDate),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                labelText: 'ประเภทการตรวจ',
                labelStyle: TextStyle(fontSize: 15),
                prefixIcon: Icon(Icons.category, size: 22),
              ),
              items: checkupTypes.map((type) {
                return DropdownMenuItem(
                  value: type['id'],
                  child: Text(
                    type['name']!,
                    style: const TextStyle(fontSize: 15),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    selectedType = val;
                    selectedVaccineIds = [];
                    selectedDiseaseId = null;
                    selectedMedicineIds = [];
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
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            
            // Multiple Vaccines Selection (Select Box)
            if (showVaccine && !widget.masterData.isLoading) ...[
              InkWell(
                onTap: () async {
                  final result = await showDialog<List<String>>(
                    context: context,
                    builder: (ctx) {
                      final tempSelected = List<String>.from(selectedVaccineIds);
                      return StatefulBuilder(
                        builder: (ctx, setDialogState) {
                          return AlertDialog(
                            title: const Text('เลือกวัคซีน (เลือกได้หลายรายการ)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView(
                                shrinkWrap: true,
                                children: widget.masterData.vaccines.map((v) {
                                  final checked = tempSelected.contains(v.id);
                                  return CheckboxListTile(
                                    title: Text(v.name, style: const TextStyle(fontSize: 15)),
                                    value: checked,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val == true) {
                                          tempSelected.add(v.id);
                                        } else {
                                          tempSelected.remove(v.id);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, selectedVaccineIds),
                                child: const Text('ยกเลิก'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, tempSelected),
                                child: const Text('ตกลง'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                  if (result != null) {
                    setState(() => selectedVaccineIds = result);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'วัคซีน (เลือกได้หลายรายการ)',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.vaccines, size: 22),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: selectedVaccineIds.isEmpty
                      ? const Text('แตะเพื่อเลือกวัคซีน...', style: TextStyle(fontSize: 15, color: AppColors.textHint))
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: selectedVaccineIds.map((id) {
                            final name = widget.masterData.vaccines.firstWhere((v) => v.id == id, orElse: () => widget.masterData.vaccines.first).name;
                            return Chip(
                              label: Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
                              backgroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (showDisease && !widget.masterData.isLoading)
              DropdownButtonFormField<String>(
                initialValue: selectedDiseaseId,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  labelText: 'โรค',
                  labelStyle: TextStyle(fontSize: 15),
                  prefixIcon: Icon(Icons.coronavirus, size: 22),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('เลือกโรค', style: TextStyle(fontSize: 15)),
                  ),
                  ...widget.masterData.diseases.map((d) {
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(d.name, style: const TextStyle(fontSize: 15)),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => selectedDiseaseId = val),
              ),

            // Multiple Medicines Selection (Select Box)
            if (showMedicine && !widget.masterData.isLoading) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final result = await showDialog<List<String>>(
                    context: context,
                    builder: (ctx) {
                      final tempSelected = List<String>.from(selectedMedicineIds);
                      return StatefulBuilder(
                        builder: (ctx, setDialogState) {
                          return AlertDialog(
                            title: const Text('เลือกยา (เลือกได้หลายรายการ)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView(
                                shrinkWrap: true,
                                children: widget.masterData.medicines.map((m) {
                                  final checked = tempSelected.contains(m.id);
                                  return CheckboxListTile(
                                    title: Text(m.name, style: const TextStyle(fontSize: 15)),
                                    value: checked,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val == true) {
                                          tempSelected.add(m.id);
                                        } else {
                                          tempSelected.remove(m.id);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, selectedMedicineIds),
                                child: const Text('ยกเลิก'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, tempSelected),
                                child: const Text('ตกลง'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                  if (result != null) {
                    setState(() => selectedMedicineIds = result);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'ยาที่ใช้ (เลือกได้หลายรายการ)',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.medication, size: 22),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: selectedMedicineIds.isEmpty
                      ? const Text('แตะเพื่อเลือกยา...', style: TextStyle(fontSize: 15, color: AppColors.textHint))
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: selectedMedicineIds.map((id) {
                            final name = widget.masterData.medicines.firstWhere((m) => m.id == id, orElse: () => widget.masterData.medicines.first).name;
                            return Chip(
                              label: Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
                              backgroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (selectedType == 'CT01') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'รูปภาพแผล/อาการป่วย (สูงสุด 3 รูป):',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${existingImageUrls.length + selectedImageFiles.length}/3',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ...existingImageUrls.asMap().entries.map((entry) {
                    final index = entry.key;
                    String url = entry.value;
                    if (!url.startsWith('blob:')) {
                      if (url.contains('/storage/http')) {
                        url = url.substring(url.indexOf('/storage/http') + 9);
                      }
                      if (url.startsWith('http://') || url.startsWith('https://')) {
                        url = url.replaceAll('http://127.0.0.1:8000/storage/', 'http://127.0.0.1:8000/api/storage/');
                      } else {
                        url = 'http://127.0.0.1:8000/api/storage/' + url.replaceAll(RegExp(r'^/?storage/'), '');
                      }
                    }
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                existingImageUrls.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  ...selectedImageFiles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final xfile = entry.value;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: FutureBuilder<Uint8List>(
                              future: xfile.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                }
                                return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedImageFiles.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (existingImageUrls.length + selectedImageFiles.length < 3)
                    InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                        if (picked != null) {
                          setState(() {
                            selectedImageFiles.add(picked);
                          });
                        }
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: AppColors.primary, size: 22),
                            SizedBox(height: 2),
                            Text('เพิ่มรูป', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'รายละเอียดเพิ่มเติม / หมายเหตุ',
                labelStyle: TextStyle(fontSize: 15),
                hintText: 'กรอกรายละเอียดหรือข้อมูลเพิ่มเติม (ถ้ามี)',
                hintStyle: TextStyle(fontSize: 14),
                prefixIcon: Icon(Icons.description, size: 22),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'ค่าใช้จ่าย (บาท)',
                labelStyle: TextStyle(fontSize: 15),
                prefixIcon: Icon(Icons.payments, size: 22),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: adminController,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'ผู้ดำเนินการ (ชื่อ)',
                labelStyle: TextStyle(fontSize: 15),
                prefixIcon: Icon(Icons.person, size: 22),
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
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('ยกเลิก'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: (widget.masterData.isLoading || isUploading)
                    ? null
                    : () async {
                        setState(() => isUploading = true);
                        List<String> imageUrls = List<String>.from(existingImageUrls);
                        if (selectedImageFiles.isNotEmpty) {
                          try {
                            final uploadService = ref.read(imageUploadServiceProvider);
                            for (final xfile in selectedImageFiles) {
                              final res = await uploadService.uploadImage(
                                type: 'health',
                                entityId: widget.cow.id,
                                imageFile: xfile,
                              );
                              if (res['url'] != null) {
                                imageUrls.add(res['url']);
                              } else if (res['path'] != null) {
                                imageUrls.add(res['path']);
                              }
                            }
                          } catch (e) {
                            print('❌ Error uploading image: $e');
                          }
                        }

                        final cost = double.tryParse(costController.text);
                        final record = HealthRecord(
                          id: widget.initialRecord?.id ?? 'HR${DateTime.now().millisecondsSinceEpoch % 1000000}',
                          cowId: widget.cow.id,
                          recordDate: selectedDate,
                          checkupTypeId: selectedType,
                          vacId: selectedVaccineIds.isNotEmpty ? selectedVaccineIds.first : null,
                          diseaseId: selectedDiseaseId,
                          medId: selectedMedicineIds.isNotEmpty ? selectedMedicineIds.first : null,
                          vacIds: selectedVaccineIds,
                          medIds: selectedMedicineIds,
                          images: imageUrls,
                          cost: cost,
                          adminName: adminController.text.trim().isEmpty
                              ? null
                              : adminController.text.trim(),
                          note: noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                        );
                        widget.onSave(record);
                        if (mounted) Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('บันทึก'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Custom Painter for Visual Growth Trend Chart
class _GrowthChartPainter extends CustomPainter {
  final List<GrowthRecord> records; // Chronological (oldest to newest)
  _GrowthChartPainter({required this.records});

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    const double leftPadding = 48.0;
    const double bottomPadding = 24.0;
    const double topPadding = 16.0;
    const double rightPadding = 16.0;

    final double drawWidth = size.width - leftPadding - rightPadding;
    final double drawHeight = size.height - topPadding - bottomPadding;

    double minW = records.map((r) => r.weight).reduce((a, b) => a < b ? a : b);
    double maxW = records.map((r) => r.weight).reduce((a, b) => a > b ? a : b);

    if (minW == maxW) {
      minW = (minW - 5).clamp(0.0, double.infinity);
      maxW = maxW + 5;
    } else {
      final pad = (maxW - minW) * 0.15;
      minW = (minW - pad).clamp(0.0, double.infinity);
      maxW = maxW + pad;
    }

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final labelStyle = TextStyle(
      fontSize: 11,
      color: Colors.grey[600],
      fontWeight: FontWeight.w500,
    );

    // Draw horizontal grid lines (3 lines)
    for (int i = 0; i <= 2; i++) {
      final yRatio = i / 2.0;
      final yPos = topPadding + drawHeight * (1 - yRatio);
      final weightVal = minW + (maxW - minW) * yRatio;

      canvas.drawLine(
        Offset(leftPadding, yPos),
        Offset(size.width - rightPadding, yPos),
        gridPaint,
      );

      final textSpan = TextSpan(text: '${weightVal.toStringAsFixed(0)} กก.', style: labelStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 6, yPos - textPainter.height / 2),
      );
    }

    // Points calculation
    final points = <Offset>[];
    for (int i = 0; i < records.length; i++) {
      final xRatio = records.length == 1 ? 0.5 : i / (records.length - 1);
      final xPos = leftPadding + drawWidth * xRatio;

      final wRatio = (records[i].weight - minW) / (maxW - minW);
      final yPos = topPadding + drawHeight * (1 - wRatio);

      points.add(Offset(xPos, yPos));
    }

    // Draw filled gradient area below line
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height - bottomPadding);
    for (var p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height - bottomPadding);
    fillPath.close();

    final fillGradient = LinearGradient(
      colors: [
        AppColors.primary.withValues(alpha: 0.22),
        AppColors.primary.withValues(alpha: 0.02),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(
        Rect.fromLTRB(leftPadding, topPadding, size.width - rightPadding, size.height - bottomPadding),
      );

    canvas.drawPath(fillPath, fillPaint);

    // Draw connecting line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Draw data points & X-axis date labels
    final dotOuterPaint = Paint()..color = AppColors.primary;
    final dotInnerPaint = Paint()..color = Colors.white;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];

      canvas.drawCircle(p, 4.5, dotOuterPaint);
      canvas.drawCircle(p, 2.2, dotInnerPaint);

      // Label first, last, and middle points
      if (i == 0 || i == points.length - 1 || (points.length >= 4 && i == points.length ~/ 2)) {
        final dateStr = DateFormat('dd/MM').format(records[i].recordDate);
        final dateSpan = TextSpan(text: dateStr, style: labelStyle);
        final datePainter = TextPainter(
          text: dateSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        double xOffset = p.dx - datePainter.width / 2;
        if (i == 0) xOffset = p.dx;
        if (i == points.length - 1) xOffset = p.dx - datePainter.width;

        datePainter.paint(
          canvas,
          Offset(xOffset, size.height - bottomPadding + 6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) => oldDelegate.records != records;
}

class GrowthTab extends ConsumerStatefulWidget {
  final Cow cow;
  const GrowthTab({super.key, required this.cow});

  @override
  ConsumerState<GrowthTab> createState() => _GrowthTabState();
}

class _GrowthTabState extends ConsumerState<GrowthTab> {
  void _showAddWeightSheet(BuildContext context, {GrowthRecord? initialRecord}) {
    final weightCtrl = TextEditingController(
      text: initialRecord != null ? initialRecord.weight.toStringAsFixed(1) : '',
    );
    final girthCtrl = TextEditingController(
      text: initialRecord?.girth != null ? initialRecord!.girth!.toStringAsFixed(1) : '',
    );
    DateTime selectedDate = initialRecord?.recordDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          initialRecord != null ? Icons.edit_outlined : Icons.monitor_weight_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        initialRecord != null ? 'แก้ไขประวัติน้ำหนัก' : 'บันทึกน้ำหนักใหม่',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.textPrimary,
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
                          style: const TextStyle(fontSize: 16),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'น้ำหนัก (กก.) *',
                            labelStyle: TextStyle(fontSize: 15),
                            prefixIcon: Icon(Icons.scale, size: 22),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: girthCtrl,
                          style: const TextStyle(fontSize: 16),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'รอบอก (ซม.)',
                            labelStyle: TextStyle(fontSize: 15),
                            prefixIcon: Icon(Icons.straighten, size: 22),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                        labelStyle: TextStyle(fontSize: 15),
                        prefixIcon: Icon(Icons.calendar_today, size: 22),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: () {
                      final w = double.tryParse(weightCtrl.text);
                      if (w == null || w <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'กรุณากรอกน้ำหนักให้ถูกต้อง',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        );
                        return;
                      }
                      final record = GrowthRecord(
                        id: initialRecord?.id ?? 'GR${DateTime.now().millisecondsSinceEpoch % 1000000}',
                        cowId: widget.cow.id,
                        recordDate: selectedDate,
                        weight: w,
                        girth: double.tryParse(girthCtrl.text),
                      );
                      if (initialRecord != null) {
                        ref.read(cowDetailProvider.notifier).updateGrowthRecord(record);
                      } else {
                        ref.read(cowDetailProvider.notifier).addGrowthRecord(record);
                      }
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.save_outlined, size: 22),
                    label: const Text(
                      'บันทึก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  void _showAllGrowthHistorySheet(
    BuildContext context,
    List<GrowthRecord> allRecords,
  ) {
    DateTimeRange? selectedRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            List<GrowthRecord> filteredRecords = allRecords;
            if (selectedRange != null) {
              final start = DateTime(
                selectedRange!.start.year,
                selectedRange!.start.month,
                selectedRange!.start.day,
              );
              final end = DateTime(
                selectedRange!.end.year,
                selectedRange!.end.month,
                selectedRange!.end.day,
                23,
                59,
                59,
              );
              filteredRecords = allRecords.where((r) {
                return r.recordDate.isAfter(
                      start.subtract(const Duration(seconds: 1)),
                    ) &&
                    r.recordDate.isBefore(end.add(const Duration(seconds: 1)));
              }).toList();
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.history,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ประวัติการชั่งน้ำหนักทั้งหมด',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'แสดง ${filteredRecords.length} จาก ${allRecords.length} รายการ',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedRange == null
                                ? 'เลือกช่วงวันที่ / เดือน ที่จะดู'
                                : '${DateFormat('dd/MM/yyyy').format(selectedRange!.start)} - ${DateFormat('dd/MM/yyyy').format(selectedRange!.end)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: selectedRange != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selectedRange != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (selectedRange != null)
                          GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedRange = null;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'ล้าง',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () async {
                              final range = await showDateRangePicker(
                                context: ctx,
                                initialDateRange:
                                    selectedRange ??
                                    DateTimeRange(
                                      start: DateTime.now().subtract(
                                        const Duration(days: 90),
                                      ),
                                      end: DateTime.now(),
                                    ),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: AppColors.primary,
                                        onPrimary: Colors.white,
                                        surface: AppColors.surface,
                                        onSurface: AppColors.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (range != null) {
                                setSheetState(() {
                                  selectedRange = range;
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.filter_alt_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'เลือกวัน',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // History list
                  Expanded(
                    child: filteredRecords.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.grey[350],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'ไม่พบประวัติในช่วงเวลาที่เลือก',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredRecords.length,
                            itemBuilder: (context, index) {
                              final r = filteredRecords[index];
                              // Find actual index in allRecords to compute diff correctly
                              final actualIdx = allRecords.indexOf(r);
                              final prev = (actualIdx >= 0 && actualIdx < allRecords.length - 1)
                                  ? allRecords[actualIdx + 1].weight
                                  : null;
                              final diff = prev != null ? r.weight - prev : null;

                              final periodDays = (actualIdx >= 0 && actualIdx < allRecords.length - 1)
                                  ? r.recordDate.difference(allRecords[actualIdx + 1].recordDate).inDays
                                  : null;
                              final periodAdg = (diff != null && periodDays != null && periodDays > 0)
                                  ? diff / periodDays
                                  : null;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 1.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.monitor_weight_outlined,
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateFormat(
                                                'dd MMM yyyy',
                                                'th_TH',
                                              ).format(r.recordDate),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            if (r.girth != null)
                                              Text(
                                                'รอบอก: ${r.girth!.toStringAsFixed(1)} ซม.',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            if (periodAdg != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'ADG ช่วงนี้: ${periodAdg >= 0 ? '+' : ''}${periodAdg.toStringAsFixed(2)} กก./วัน ($periodDays วัน)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: periodAdg >= 0 ? AppColors.primary : AppColors.error,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${r.weight.toStringAsFixed(1)} กก.',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          if (diff != null)
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: (diff >= 0 ? AppColors.success : AppColors.error)
                                                    .withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: diff >= 0 ? AppColors.success : AppColors.error,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            Navigator.pop(ctx);
                                            _showAddWeightSheet(context, initialRecord: r);
                                          } else if (val == 'delete') {
                                            showDialog(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                title: const Text('ยืนยันการลบ'),
                                                content: const Text('คุณต้องการลบข้อมูลประวัติน้ำหนักนี้ใช่หรือไม่? การดำเนินการนี้ไม่สามารถย้อนกลับได้'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(c),
                                                    child: const Text('ยกเลิก'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      ref.read(cowDetailProvider.notifier).deleteGrowthRecord(r.id);
                                                      Navigator.pop(c);
                                                      setSheetState(() {});
                                                    },
                                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                    child: const Text('ลบ'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                        itemBuilder: (c) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, color: AppColors.primary, size: 20),
                                                SizedBox(width: 8),
                                                Text('แก้ไขประวัติ'),
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
                                    ],
                                  ),
                                ),
                              );
                            },
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
            content: Text(
              'บันทึกน้ำหนักเรียบร้อยแล้ว!',
              style: TextStyle(fontSize: 15),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(cowDetailProvider.notifier).clearFlags();
      } else if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!, style: const TextStyle(fontSize: 15)),
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

    // Recent ADG (between last 2 records)
    double? recentAdg;
    if (records.length >= 2) {
      final latest = records.first;
      final previous = records[1];
      final days = latest.recordDate.difference(previous.recordDate).inDays;
      if (days > 0) {
        recentAdg = (latest.weight - previous.weight) / days;
      }
    }

    // Overall ADG & Total Weight Gain (from oldest record to latest)
    double? overallAdg;
    double? totalWeightGain;
    int? totalDays;
    if (records.length >= 2) {
      final latest = records.first;
      final oldest = records.last;
      totalDays = latest.recordDate.difference(oldest.recordDate).inDays;
      totalWeightGain = latest.weight - oldest.weight;
      if (totalDays > 0) {
        overallAdg = totalWeightGain / totalDays;
      }
    } else if (records.isNotEmpty && widget.cow.birthDate != null) {
      final latest = records.first;
      totalDays = latest.recordDate.difference(widget.cow.birthDate!).inDays;
      if (totalDays > 0) {
        totalWeightGain = latest.weight;
        overallAdg = latest.weight / totalDays;
      }
    }

    // Evaluation Badge based on recentAdg or overallAdg
    final evalAdg = recentAdg ?? overallAdg;
    String statusTitle = 'ยังไม่มีข้อมูลเพียงพอ';
    String statusSubtitle = 'บันทึกอย่างน้อย 2 ครั้งเพื่อประเมิน ADG';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.info_outline;

    if (evalAdg != null) {
      final isMinorDecrease = (weightDiff != null && weightDiff < 0 && weightDiff.abs() <= 5.0) || (evalAdg < 0 && evalAdg >= -0.3);

      if (evalAdg >= 1.0) {
        statusTitle = 'การเติบโตดีเยี่ยม';
        statusSubtitle = 'อัตราการเจริญเติบโตสูงกว่าเกณฑ์มาตรฐาน';
        statusColor = const Color(0xFF2E7D32); // Emerald Green
        statusIcon = Icons.stars;
      } else if (evalAdg >= 0.6) {
        statusTitle = 'ตามเกณฑ์มาตรฐาน';
        statusSubtitle = 'วัวมีอัตราการเจริญเติบโตสม่ำเสมอในระดับดี';
        statusColor = Colors.teal;
        statusIcon = Icons.thumb_up_alt_outlined;
      } else if (evalAdg >= 0.0) {
        statusTitle = 'เติบโตช้ากว่าเกณฑ์';
        statusSubtitle = 'พัฒนาการค่อนข้างช้า ควรพิจารณาเสริมโภชนาการ';
        statusColor = Colors.orange[800]!;
        statusIcon = Icons.trending_up;
      } else if (isMinorDecrease) {
        statusTitle = 'น้ำหนักทรงตัว / ลดลงเล็กน้อย';
        statusSubtitle = 'น้ำหนักเปลี่ยนแปลงเล็กน้อยตามธรรมชาติ ติดตามต่อในการชั่งครั้งถัดไป';
        statusColor = Colors.amber[800]!;
        statusIcon = Icons.trending_down;
      } else {
        statusTitle = 'น้ำหนักลดลงอย่างมีนัยสำคัญ';
        statusSubtitle = 'ควรตรวจสอบปริมาณอาหาร โภชนาการ หรือตรวจเช็คสุขภาพ';
        statusColor = Colors.red[700]!;
        statusIcon = Icons.warning_amber_rounded;
      }
    }

    // Chronological records (oldest to newest) for chart
    final chronologicalRecords = records.reversed.toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            // 1. Latest weight & ADG summary card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5D7552), Color(0xFF4A6040)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.scale,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'น้ำหนักปัจจุบัน',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    latestWeight > 0
                        ? '${latestWeight.toStringAsFixed(1)} กก.'
                        : '- กก.',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (weightDiff != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: (weightDiff >= 0
                                    ? const Color(0xFF7BF562)
                                    : const Color(0xFFFF6B6B))
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                weightDiff >= 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: weightDiff >= 0
                                    ? const Color(0xFF7BF562)
                                    : const Color(0xFFFF6B6B),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${weightDiff >= 0 ? '+' : ''}${weightDiff.toStringAsFixed(1)} กก. จากครั้งก่อน',
                                style: TextStyle(
                                  color: weightDiff >= 0
                                      ? const Color(0xFF7BF562)
                                      : const Color(0xFFFF6B6B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (recentAdg != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.speed,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ADG ล่าสุด: ${recentAdg >= 0 ? '+' : ''}${recentAdg.toStringAsFixed(2)} กก./วัน',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (overallAdg != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timeline,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ADG รวมสะสม: ${overallAdg >= 0 ? '+' : ''}${overallAdg.toStringAsFixed(2)} กก./วัน',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (records.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'ชั่งล่าสุดเมื่อ: ${DateFormat('dd MMM yyyy', 'th_TH').format(records.first.recordDate)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ] else if (hasFallback) ...[
                    const SizedBox(height: 10),
                    Text(
                      'น้ำหนักเริ่มต้น (ยังไม่มีประวัติการชั่งย้อนหลัง)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Growth Evaluation Performance Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusSubtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Visual Growth Line Chart Widget (if >= 2 records)
            if (chronologicalRecords.length >= 2) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 190,
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
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
                        const Icon(Icons.show_chart, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'กราฟแนวโน้มน้ำหนัก',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${chronologicalRecords.length} จุดชั่ง',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _GrowthChartPainter(records: chronologicalRecords),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.history,
                  size: 22,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                const Text(
                  'ประวัติการชั่งน้ำหนัก',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasFallback
                        ? '1 ครั้ง (เริ่มต้น)'
                        : '${records.length} ครั้ง',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (records.isEmpty && !hasFallback)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.monitor_weight_outlined,
                        size: 64,
                        color: Colors.grey[350],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ยังไม่มีประวัติน้ำหนัก',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'กดปุ่ม + เพื่อบันทึกน้ำหนักแรก',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (hasFallback)
              Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: AppColors.primary.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.flag_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'น้ำหนักเริ่มต้น',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'ที่กรอกไว้ตอนเพิ่มวัว',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${widget.cow.latestWeight.toStringAsFixed(1)} กก.',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Display max 5 records in main tab
              ...records.take(5).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final prev = i < records.length - 1 ? records[i + 1].weight : null;
                final diff = prev != null ? r.weight - prev : null;
                
                final periodDays = (i < records.length - 1)
                    ? r.recordDate.difference(records[i + 1].recordDate).inDays
                    : null;
                final periodAdg = (diff != null && periodDays != null && periodDays > 0)
                    ? diff / periodDays
                    : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.monitor_weight_outlined,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy', 'th_TH').format(r.recordDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (r.girth != null)
                                Text(
                                  'รอบอก: ${r.girth!.toStringAsFixed(1)} ซม.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              if (periodAdg != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'ADG ช่วงนี้: ${periodAdg >= 0 ? '+' : ''}${periodAdg.toStringAsFixed(2)} กก./วัน ($periodDays วัน)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: periodAdg >= 0 ? AppColors.primary : AppColors.error,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${r.weight.toStringAsFixed(1)} กก.',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            if (diff != null)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (diff >= 0 ? AppColors.success : AppColors.error)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: diff >= 0 ? AppColors.success : AppColors.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showAddWeightSheet(context, initialRecord: r);
                            } else if (val == 'delete') {
                              showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('ยืนยันการลบ'),
                                  content: const Text('คุณต้องการลบข้อมูลประวัติน้ำหนักนี้ใช่หรือไม่? การดำเนินการนี้ไม่สามารถย้อนกลับได้'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('ยกเลิก'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        ref.read(cowDetailProvider.notifier).deleteGrowthRecord(r.id);
                                        Navigator.pop(c);
                                      },
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('ลบ'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          itemBuilder: (c) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: AppColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text('แก้ไขประวัติ'),
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
                      ],
                    ),
                  ),
                );
              }),

              if (records.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _showAllGrowthHistorySheet(context, records),
                    icon: const Icon(Icons.history, size: 20),
                    label: Text(
                      'ดูประวัติทั้งหมด (${records.length} รายการ)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
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
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add, color: Colors.white, size: 24),
            label: const Text(
              'บันทึกน้ำหนัก',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
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
            Text(
              'โหลดข้อมูลไม่สำเร็จ',
              style: TextStyle(color: Colors.grey[500]),
            ),
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
    final healthDetails =
        (breakdown['health'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    // Feed details
    final feedDetails =
        (breakdown['feed'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    // Direct cost details
    final directDetails =
        (breakdown['direct'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Cost breakdown for proportion bar
    final costParts = <_CostPart>[
      if (purchasePrice > 0)
        _CostPart(
          'ราคาซื้อวัว',
          purchasePrice,
          Colors.purple,
          Icons.payments_outlined,
        ),
      if (healthCost > 0)
        _CostPart(
          'ค่ารักษา/วัคซีน',
          healthCost,
          AppColors.error,
          Icons.medical_services_outlined,
        ),
      if (directCost > 0)
        _CostPart(
          'ค่าใช้จ่ายตรง',
          directCost,
          Colors.blue,
          Icons.receipt_long_outlined,
        ),
    ];

    final isBornInFarm =
        purchasePrice <= 0 &&
        (widget.cow.motherId != null ||
            widget.cow.type == CowType.calf ||
            widget.cow.purchasePrice <= 0);

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
              Expanded(
                child: _buildMiniSummary(
                  'ราคาซื้อ',
                  purchasePrice,
                  Colors.purple,
                  isBornInFarm: isBornInFarm,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniSummary(
                  'ค่ารักษา',
                  healthCost,
                  AppColors.error,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniSummary('ค่าอาหาร', feedCost, Colors.green),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniSummary('อื่นๆ', directCost, Colors.blue),
              ),
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
            _buildSectionTitle(
              'ประวัติค่ารักษา/วัคซีน (${healthDetails.length} รายการ)',
            ),
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
            _buildSectionTitle(
              'ค่าใช้จ่ายตรงรายตัว (${directDetails.length} รายการ)',
            ),
            const SizedBox(height: 8),
            ...directDetails.map((d) => _buildDirectCostCard(d)),
            const SizedBox(height: 16),
          ],

          // Empty state
          if (healthDetails.isEmpty &&
              feedDetails.isEmpty &&
              directDetails.isEmpty &&
              purchasePrice <= 0)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: Colors.grey[300],
                  ),
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
                Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white70,
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  'ค่าเลี้ยงดูสะสมทั้งหมด',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'รายได้: ${NumberFormat('#,##0').format(income)} ฿  |  สุทธิ: ${NumberFormat('#,##0').format(net)} ฿',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildMiniSummary(
    String label,
    double amount,
    Color color, {
    bool isBornInFarm = false,
  }) {
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
                color: (isBornInFarm ? Colors.teal : color).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                label.contains('รักษา')
                    ? Icons.medical_services_outlined
                    : label.contains('อาหาร')
                    ? Icons.grass_outlined
                    : isBornInFarm
                    ? Icons.child_care_outlined
                    : label.contains('ซื้อ')
                    ? Icons.payments_outlined
                    : Icons.receipt_long_outlined,
                color: isBornInFarm ? Colors.teal : color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[750],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            isBornInFarm
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'เกิดในฟาร์ม',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.teal,
                      ),
                    ),
                  )
                : Text(
                    '${NumberFormat('#,##0').format(amount)} ฿',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: amount > 0
                          ? AppColors.textPrimary
                          : Colors.grey[400],
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
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
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
              final pct = total > 0
                  ? (p.amount / total * 100).toStringAsFixed(0)
                  : '0';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: p.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(p.icon, size: 16, color: p.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
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
        ? DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.parse(h['record_date'].toString()))
        : '-';
    final cost = _parseDouble(h['cost']);
    final disease = h['disease_name'];
    final medicine = h['medicine_name'];
    final vaccine = h['vaccine_name'];

    String description = '';
    if (disease != null) description += 'โรค: $disease';
    if (medicine != null)
      description += '${description.isNotEmpty ? ' | ' : ''}ยา: $medicine';
    if (vaccine != null)
      description += '${description.isNotEmpty ? ' | ' : ''}วัคซีน: $vaccine';
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
          child: const Icon(
            Icons.medical_services_outlined,
            color: AppColors.error,
            size: 20,
          ),
        ),
        title: Text(
          description,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              date,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Text(
          '${NumberFormat('#,##0').format(cost)} ฿',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.error,
            fontSize: 16,
          ),
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
          child: const Icon(
            Icons.grass_outlined,
            color: Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          feedType,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              displayDate,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(ทั้งโซน ${NumberFormat('#,##0').format(totalCost)} ฿)',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Text(
          '${NumberFormat('#,##0').format(costPerCow)} ฿',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDirectCostCard(Map<String, dynamic> d) {
    final date = d['transaction_date'] != null
        ? DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.parse(d['transaction_date'].toString()))
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
          child: const Icon(
            Icons.receipt_long_outlined,
            color: Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          title.toString(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (notes != null && notes.toString().isNotEmpty)
              Text(
                notes.toString(),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Text(
          '${NumberFormat('#,##0').format(amount)} ฿',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            fontSize: 16,
          ),
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
                Icon(
                  Icons.analytics_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'การวิเคราะห์ความคุ้มค่า',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'มูลค่าประมาณ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[750],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,##0').format(estimatedValue)} ฿',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '(${cow.latestWeight.toStringAsFixed(0)} กก. × 120 ฿/กก.)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(height: 40, width: 1, color: Colors.grey[200]),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'ค่าเลี้ยงดูสะสม',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[750],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,##0').format(totalCost)} ฿',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.error,
                        ),
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
                color: (isProfitable ? Colors.green : Colors.red).withValues(
                  alpha: 0.08,
                ),
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
