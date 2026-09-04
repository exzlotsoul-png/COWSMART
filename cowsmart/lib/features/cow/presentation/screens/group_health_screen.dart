import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/health/providers/master_data_provider.dart';

class GroupHealthScreen extends ConsumerStatefulWidget {
  const GroupHealthScreen({super.key});

  @override
  ConsumerState<GroupHealthScreen> createState() => _GroupHealthScreenState();
}

class _GroupHealthScreenState extends ConsumerState<GroupHealthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _costController = TextEditingController();
  final _noteController = TextEditingController();
  final _adminController = TextEditingController();

  final _customDiseaseController = TextEditingController();
  final _customVaccineController = TextEditingController();
  final _customMedicineController = TextEditingController();

  // Mode Selection: 'equal' (เท่ากันทุกตัว ไม่หาร), 'custom' (ระบุแยกรายตัว)
  String _costAllocationMode = 'equal';

  // Per-Cow Per-Item Controllers & State for Mode 2 ('custom')
  final Map<String, TextEditingController> _cowItemAmountControllers = {};
  final Map<String, TextEditingController> _cowItemCostControllers = {};
  final Map<String, String?> _cowItemUnitIds = {};
  final Set<String> _expandedCowIds = {};

  TextEditingController _getCowItemAmountController(String cowId, String itemId) {
    final key = '${cowId}_$itemId';
    return _cowItemAmountControllers.putIfAbsent(key, () => TextEditingController());
  }

  TextEditingController _getCowItemCostController(String cowId, String itemId) {
    final key = '${cowId}_$itemId';
    return _cowItemCostControllers.putIfAbsent(key, () => TextEditingController());
  }

  int _currentStep = 1; // 1: Select Cows, 2: Record Details
  final Set<String> _selectedCowIds = {};

  // Filters for Step 1
  String _searchQuery = '';
  String? _selectedZoneId;

  // Form fields for Step 2
  String _selectedType = 'CT01'; // CT01: ตรวจสุขภาพ, CT02: ฉีดวัคซีน, CT03: ให้ยา
  DateTime _selectedDate = DateTime.now();
  String _selectedHealthStatus = 'normal'; // normal, sick, injured

  // Multi-select Sets
  final Set<String> _selectedDiseaseIds = {};
  final Set<String> _selectedVaccineIds = {};
  final Set<String> _selectedMedicineIds = {};

  String? _selectedUnitId;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        ref.read(cowProvider.notifier).fetchCows(currentFarm.id);
        ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
      }
      ref.read(masterDataProvider.notifier).fetchAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _costController.dispose();
    _noteController.dispose();
    _adminController.dispose();
    _customDiseaseController.dispose();
    _customVaccineController.dispose();
    _customMedicineController.dispose();

    for (var c in _cowItemAmountControllers.values) {
      c.dispose();
    }
    for (var c in _cowItemCostControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submitGroupHealthRecord() async {
    if (_selectedCowIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกวัวอย่างน้อย 1 ตัวที่ต้องการบันทึกสุขภาพ', style: TextStyle(fontSize: 15)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedType == 'CT02' && _selectedVaccineIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกวัคซีนอย่างน้อย 1 รายการ', style: TextStyle(fontSize: 15)),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedType == 'CT03' && _selectedMedicineIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกยารักษาอย่างน้อย 1 รายการ', style: TextStyle(fontSize: 15)),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiClientProvider);
      final masterData = ref.read(masterDataProvider);

      // 1. Build Base items_json
      final List<Map<String, dynamic>> baseItemsPayload = [];
      String? primaryDiseaseId;
      String? primaryVacId;
      String? primaryMedId;

      // Diseases
      if (_selectedType == 'CT01' || _selectedType == 'CT03') {
        for (final dId in _selectedDiseaseIds) {
          if (dId == 'other') {
            final customName = _customDiseaseController.text.trim();
            if (customName.isNotEmpty) {
              baseItemsPayload.add({
                'item_type': 'disease',
                'item_id': 'other',
                'item_name': customName,
              });
            }
          } else {
            final matches = masterData.diseases.where((d) => d.id == dId).toList();
            final dName = matches.isNotEmpty ? matches.first.name : dId;
            if (primaryDiseaseId == null) primaryDiseaseId = dId;
            baseItemsPayload.add({
              'item_type': 'disease',
              'item_id': dId,
              'item_name': dName,
            });
          }
        }
      }

      // Vaccines
      if (_selectedType == 'CT02') {
        for (final vId in _selectedVaccineIds) {
          if (vId == 'other') {
            final customName = _customVaccineController.text.trim();
            if (customName.isNotEmpty) {
              baseItemsPayload.add({
                'item_type': 'vaccine',
                'item_id': 'other',
                'item_name': customName,
              });
            }
          } else {
            final matches = masterData.vaccines.where((v) => v.id == vId).toList();
            final vName = matches.isNotEmpty ? matches.first.name : vId;
            if (primaryVacId == null) primaryVacId = vId;
            baseItemsPayload.add({
              'item_type': 'vaccine',
              'item_id': vId,
              'item_name': vName,
            });
          }
        }
      }

      // Medicines
      if (_selectedType == 'CT03') {
        for (final mId in _selectedMedicineIds) {
          if (mId == 'other') {
            final customName = _customMedicineController.text.trim();
            if (customName.isNotEmpty) {
              baseItemsPayload.add({
                'item_type': 'medicine',
                'item_id': 'other',
                'item_name': customName,
              });
            }
          } else {
            final matches = masterData.medicines.where((m) => m.id == mId).toList();
            final mName = matches.isNotEmpty ? matches.first.name : mId;
            if (primaryMedId == null) primaryMedId = mId;
            baseItemsPayload.add({
              'item_type': 'medicine',
              'item_id': mId,
              'item_name': mName,
            });
          }
        }
      }

      // Format Notes
      List<String> extraNotes = [];
      if (_selectedDiseaseIds.contains('other') && _customDiseaseController.text.trim().isNotEmpty) {
        extraNotes.add('โรคระบุเอง: ${_customDiseaseController.text.trim()}');
      }
      if (_selectedVaccineIds.contains('other') && _customVaccineController.text.trim().isNotEmpty) {
        extraNotes.add('วัคซีนระบุเอง: ${_customVaccineController.text.trim()}');
      }
      if (_selectedMedicineIds.contains('other') && _customMedicineController.text.trim().isNotEmpty) {
        extraNotes.add('ยาระบุเอง: ${_customMedicineController.text.trim()}');
      }

      String noteText = _noteController.text.trim();
      if (extraNotes.isNotEmpty) {
        final extraStr = extraNotes.join(', ');
        noteText = noteText.isNotEmpty ? '$noteText ($extraStr)' : extraStr;
      }

      final String formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate);
      final List<Map<String, dynamic>> recordsPayload = [];

      // ── MODE 1: EQUAL RATE PER COW (เท่ากันทุกตัว ไม่หาร) ──
      if (_selectedType == 'CT01' || _costAllocationMode == 'equal') {
        final defaultAmount = double.tryParse(_amountController.text.trim());
        final costPerCow = double.tryParse(_costController.text.trim());

        for (final cowId in _selectedCowIds) {
          final Map<String, dynamic> itemData = {
            'cow_id': cowId,
            'checkup_type_id': _selectedType,
            'record_date': formattedDate,
            'status': _selectedType == 'CT01' ? _selectedHealthStatus : null,
            'disease_id': primaryDiseaseId,
            'disease_ids': _selectedDiseaseIds.isNotEmpty ? _selectedDiseaseIds.toList() : null,
            'vac_id': primaryVacId,
            'vac_ids': _selectedVaccineIds.isNotEmpty ? _selectedVaccineIds.toList() : null,
            'med_id': primaryMedId,
            'med_ids': _selectedMedicineIds.isNotEmpty ? _selectedMedicineIds.toList() : null,
            'items_json': baseItemsPayload.isNotEmpty ? baseItemsPayload : null,
            'amount': defaultAmount,
            'unit_id': _selectedUnitId,
            'cost': costPerCow,
            'note': noteText.isNotEmpty ? noteText : null,
            'admin_name': _adminController.text.trim().isNotEmpty ? _adminController.text.trim() : null,
          };
          recordsPayload.add(itemData);
        }
      } 
      // ── MODE 2: PER-COW CUSTOM (ระบุแยกรายตัว และแยกตามวัคซีน/ยาแต่ละรายการ) ──
      else {
        final List<String> targetItemIds = _selectedType == 'CT02'
            ? _selectedVaccineIds.toList()
            : _selectedMedicineIds.toList();

        for (final cowId in _selectedCowIds) {
          final List<Map<String, dynamic>> cowItemsPayload = [];
          double totalCowCost = 0.0;
          double totalCowAmt = 0.0;

          for (final itemId in targetItemIds) {
            final amt = double.tryParse(_getCowItemAmountController(cowId, itemId).text.trim());
            final cost = double.tryParse(_getCowItemCostController(cowId, itemId).text.trim());
            final unit = _cowItemUnitIds['${cowId}_$itemId'] ?? _selectedUnitId;

            String itemName;
            if (itemId == 'other') {
              itemName = _selectedType == 'CT02'
                  ? _customVaccineController.text.trim()
                  : _customMedicineController.text.trim();
              if (itemName.isEmpty) itemName = 'อื่นๆ';
            } else {
              if (_selectedType == 'CT02') {
                final match = masterData.vaccines.where((v) => v.id == itemId).toList();
                itemName = match.isNotEmpty ? match.first.name : itemId;
              } else {
                final match = masterData.medicines.where((m) => m.id == itemId).toList();
                itemName = match.isNotEmpty ? match.first.name : itemId;
              }
            }

            cowItemsPayload.add({
              'item_type': _selectedType == 'CT02' ? 'vaccine' : 'medicine',
              'item_id': itemId,
              'item_name': itemName,
              'amount': amt,
              'unit_id': unit,
              'cost': cost,
            });

            if (cost != null) totalCowCost += cost;
            if (amt != null) totalCowAmt += amt;
          }

          final Map<String, dynamic> itemData = {
            'cow_id': cowId,
            'checkup_type_id': _selectedType,
            'record_date': formattedDate,
            'status': _selectedType == 'CT01' ? _selectedHealthStatus : null,
            'disease_id': primaryDiseaseId,
            'disease_ids': _selectedDiseaseIds.isNotEmpty ? _selectedDiseaseIds.toList() : null,
            'vac_id': primaryVacId,
            'vac_ids': _selectedVaccineIds.isNotEmpty ? _selectedVaccineIds.toList() : null,
            'med_id': primaryMedId,
            'med_ids': _selectedMedicineIds.isNotEmpty ? _selectedMedicineIds.toList() : null,
            'items_json': cowItemsPayload.isNotEmpty ? cowItemsPayload : baseItemsPayload,
            'amount': totalCowAmt > 0 ? totalCowAmt : null,
            'unit_id': _selectedUnitId,
            'cost': totalCowCost > 0 ? totalCowCost : null,
            'note': noteText.isNotEmpty ? noteText : null,
            'admin_name': _adminController.text.trim().isNotEmpty ? _adminController.text.trim() : null,
          };
          recordsPayload.add(itemData);
        }
      }

      await api.post('/health_records', data: {'records': recordsPayload});

      // Refresh state
      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        await ref.read(cowProvider.notifier).fetchCows(currentFarm.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกสุขภาพกลุ่มสำเร็จจำนวน ${recordsPayload.length} ตัว', style: const TextStyle(fontSize: 15)),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึก: $e', style: const TextStyle(fontSize: 14)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cowState = ref.watch(cowProvider);
    final zoneState = ref.watch(zoneProvider);

    final availableCows = cowState.allCows.where((cow) {
      if (cow.status == CowStatus.deceased || cow.status == CowStatus.sold || cow.status == CowStatus.removed) {
        return false;
      }
      if (_selectedZoneId != null && cow.zoneId != _selectedZoneId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return cow.tagNumber.toLowerCase().contains(q) || cow.name.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // เรียงลำดับให้วัวที่ป่วยขึ้นมาก่อนเป็นอันดับแรก (Sort sick cows first)
    availableCows.sort((a, b) {
      final aIsSick = a.status == CowStatus.sick || (a.latestDiseaseName != null && a.latestDiseaseName!.isNotEmpty && a.status != CowStatus.normal);
      final bIsSick = b.status == CowStatus.sick || (b.latestDiseaseName != null && b.latestDiseaseName!.isNotEmpty && b.status != CowStatus.normal);
      if (aIsSick && !bIsSick) return -1;
      if (!aIsSick && bIsSick) return 1;
      return a.tagNumber.compareTo(b.tagNumber);
    });

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'บันทึกการรักษากลุ่ม',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _currentStep == 1
                  ? 'ขั้นตอนที่ 1: เลือกวัว (${_selectedCowIds.length} ตัว)'
                  : 'ขั้นตอนที่ 2: กรอกข้อมูลการรักษา',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('กำลังบันทึกข้อมูลการรักษา...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Column(
              children: [
                // Step Indicator Bar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: AppColors.cardBg(context),
                  child: Row(
                    children: [
                      _buildStepBadge(1, 'เลือกวัว', _currentStep == 1, () {
                        setState(() => _currentStep = 1);
                      }),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep == 2 ? AppColors.primary : AppColors.brd(context),
                        ),
                      ),
                      _buildStepBadge(2, 'ระบุข้อมูลการรักษา', _currentStep == 2, () {
                        if (_selectedCowIds.isNotEmpty) {
                          setState(() => _currentStep = 2);
                        }
                      }),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.div(context)),

                Expanded(
                  child: _currentStep == 1
                      ? _buildStep1CowSelection(availableCows, zoneState.zones)
                      : _buildStep2RecordForm(),
                ),
              ],
            ),
      bottomNavigationBar: _isSubmitting
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: _currentStep == 1
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: _selectedCowIds.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _currentStep = 2;
                                  // Default expand the first cow in mode 2
                                  if (_selectedCowIds.isNotEmpty) {
                                    _expandedCowIds.add(_selectedCowIds.first);
                                  }
                                });
                              },
                        child: Text(
                          'ถัดไป: กรอกข้อมูลการรักษา (${_selectedCowIds.length} ตัว)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                side: const BorderSide(color: AppColors.primary),
                              ),
                              onPressed: () {
                                setState(() => _currentStep = 1);
                              },
                              child: const Text('ย้อนกลับ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: _submitGroupHealthRecord,
                              child: const Text(
                                'บันทึกการรักษากลุ่ม',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
    );
  }

  Widget _buildStepBadge(int step, String title, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: isActive ? AppColors.primary : AppColors.surfAlt(context),
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.subText(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.text(context) : AppColors.subText(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 1: COW SELECTION ──
  Widget _buildStep1CowSelection(List<Cow> availableCows, List<dynamic> zones) {
    final isAllSelected = availableCows.isNotEmpty && availableCows.every((c) => _selectedCowIds.contains(c.id));

    return Column(
      children: [
        // Search & Filter Container
        Container(
          padding: const EdgeInsets.all(14),
          color: AppColors.cardBg(context),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ค้นหาด้วยชื่อ หรือรหัสหูวัว...',
                  hintStyle: TextStyle(fontSize: 14.5, color: AppColors.hint(context)),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfAlt(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('ทุกโซน', style: TextStyle(fontSize: 14)),
                      selected: _selectedZoneId == null,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfAlt(context),
                      side: BorderSide(color: _selectedZoneId == null ? AppColors.primary : AppColors.brd(context)),
                      labelStyle: TextStyle(
                        color: _selectedZoneId == null ? Colors.white : AppColors.text(context),
                        fontWeight: _selectedZoneId == null ? FontWeight.bold : FontWeight.w500,
                      ),
                      onSelected: (_) => setState(() => _selectedZoneId = null),
                    ),
                    const SizedBox(width: 8),
                    ...zones.map((zone) {
                      final isSelected = _selectedZoneId == zone.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(zone.name, style: const TextStyle(fontSize: 14)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfAlt(context),
                          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.brd(context)),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.text(context),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (_) => setState(() => _selectedZoneId = zone.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Select All Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surfAlt(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'พบวัวทั้งหมด ${availableCows.length} ตัว',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.subText(context)),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (isAllSelected) {
                      _selectedCowIds.clear();
                    } else {
                      for (var c in availableCows) {
                        _selectedCowIds.add(c.id);
                      }
                    }
                  });
                },
                icon: Icon(
                  isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
                label: Text(
                  isAllSelected ? 'ยกเลิกการเลือก' : 'เลือกทั้งหมด',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        // Cows List
        Expanded(
          child: availableCows.isEmpty
              ? const Center(
                  child: Text('ไม่พบรายการวัวตรงตามเงื่อนไข', style: TextStyle(color: AppColors.textHint)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: availableCows.length,
                  itemBuilder: (ctx, index) {
                    final cow = availableCows[index];
                    final isChecked = _selectedCowIds.contains(cow.id);
                    final isCowSick = cow.status == CowStatus.sick ||
                        (cow.latestDiseaseName != null &&
                            cow.latestDiseaseName!.isNotEmpty &&
                            cow.status != CowStatus.normal);
                    final diseaseName = cow.latestDiseaseName;

                    final genderDisplay = (cow.gender == 'M' || cow.gender == 'ผู้' || cow.gender == 'male') ? 'ผู้' : 'เมีย';
                    final breedDisplay = cow.breed.isNotEmpty ? cow.breed : '-';

                    final isDark = Theme.of(context).brightness == Brightness.dark;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : isCowSick
                                ? (isDark ? const Color(0xFF2C1616) : const Color(0xFFFEF2F2))
                                : AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isChecked
                              ? AppColors.primary
                              : isCowSick
                                  ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))
                                  : AppColors.brd(context),
                          width: isChecked ? 1.5 : (isCowSick ? 1.2 : 1),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isChecked) {
                              _selectedCowIds.remove(cow.id);
                            } else {
                              _selectedCowIds.add(cow.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              // Cow Image Avatar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  color: AppColors.surfAlt(context),
                                  child: (cow.imageFullUrl != null || cow.imageUrl != null)
                                      ? Image.network(
                                          cow.imageFullUrl ?? cow.imageUrl!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: CowIcon(size: 24, color: AppColors.hint(context)),
                                          ),
                                        )
                                      : Center(
                                          child: CowIcon(size: 24, color: AppColors.hint(context)),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Cow Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            cow.name.isNotEmpty ? cow.name : cow.tagNumber,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text(context)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            cow.tagNumber,
                                            style: TextStyle(fontSize: 12.5, color: AppColors.text(context), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'สายพันธุ์: $breedDisplay • เพศ: $genderDisplay',
                                      style: TextStyle(fontSize: 13.5, color: AppColors.subText(context)),
                                    ),
                                    if (isCowSick) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.error.withValues(alpha: 0.35), width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.coronavirus_outlined, size: 14, color: AppColors.error),
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text(
                                                (diseaseName != null && diseaseName.isNotEmpty)
                                                    ? 'ป่วย: $diseaseName'
                                                    : 'สถานะ: ป่วย',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.error,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Checkbox
                              Checkbox(
                                value: isChecked,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedCowIds.add(cow.id);
                                    } else {
                                      _selectedCowIds.remove(cow.id);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── STEP 2: RECORD FORM ──
  Widget _buildStep2RecordForm() {
    final masterData = ref.watch(masterDataProvider);
    final cowState = ref.watch(cowProvider);
    final selectedCowsList = cowState.allCows.where((c) => _selectedCowIds.contains(c.id)).toList();

    final List<String> targetItemIds = _selectedType == 'CT02'
        ? _selectedVaccineIds.toList()
        : _selectedMedicineIds.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Cow Summary Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'เตรียมบันทึกสุขภาพให้วัวจำนวน ${_selectedCowIds.length} ตัว',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Record Type Selection Cards
            const Text('เลือกประเภทการบันทึก', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeCard('CT01', 'ตรวจสุขภาพ', Icons.health_and_safety_outlined, AppColors.success),
                const SizedBox(width: 8),
                _buildTypeCard('CT02', 'ฉีดวัคซีน', Icons.vaccines_outlined, AppColors.info),
                const SizedBox(width: 8),
                _buildTypeCard('CT03', 'ให้ยารักษา', Icons.medication_outlined, AppColors.warning),
              ],
            ),
            const SizedBox(height: 18),

            // Date Picker
            InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brd(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text('วันที่บันทึก:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(context))),
                      ],
                    ),
                    Text(
                      AppDateUtils.formatThaiDate(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── COST & DOSAGE ALLOCATION MODE SELECTION (Vaccines & Medicines only) ──
            if (_selectedType != 'CT01') ...[
              const Text('รูปแบบการคิดราคาและปริมาณยา', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _costAllocationMode = 'equal'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _costAllocationMode == 'equal' ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _costAllocationMode == 'equal' ? AppColors.primary : AppColors.brd(context),
                            width: _costAllocationMode == 'equal' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.equalizer_rounded,
                              color: _costAllocationMode == 'equal' ? AppColors.primary : AppColors.subText(context),
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'แบบที่ 1: เท่ากันทุกตัว',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _costAllocationMode == 'equal' ? FontWeight.bold : FontWeight.normal,
                                color: _costAllocationMode == 'equal' ? AppColors.primary : AppColors.text(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ปริมาณและราคาเท่ากันทุกตัว (ไม่หาร)',
                              style: TextStyle(fontSize: 10.5, color: AppColors.subText(context)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _costAllocationMode = 'custom'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _costAllocationMode == 'custom' ? AppColors.secondaryDark.withValues(alpha: 0.15) : AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _costAllocationMode == 'custom' ? AppColors.secondaryDark : AppColors.brd(context),
                            width: _costAllocationMode == 'custom' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: _costAllocationMode == 'custom' ? AppColors.secondaryDark : AppColors.subText(context),
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'แบบที่ 2: กรอกแยกรายตัว',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _costAllocationMode == 'custom' ? FontWeight.bold : FontWeight.normal,
                                color: _costAllocationMode == 'custom' ? AppColors.secondaryDark : AppColors.text(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ระบุ cc และราคาของแต่ละตัว',
                              style: TextStyle(fontSize: 10.5, color: AppColors.subText(context)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],

            // ── TYPE CT01: HEALTH CHECKUP FIELDS ──
            if (_selectedType == 'CT01') ...[
              const Text('สถานะสุขภาพวัว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusChip('normal', 'ปกติ', AppColors.success),
                  const SizedBox(width: 8),
                  _buildStatusChip('sick', 'ป่วย', AppColors.error),
                  const SizedBox(width: 8),
                  _buildStatusChip('injured', 'บาดเจ็บ', const Color(0xFFD97706)),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdownChecklistSelector(
                title: 'เลือกโรคที่พบ / ที่รักษา *',
                icon: Icons.coronavirus_outlined,
                color: AppColors.primary,
                selectedIds: _selectedDiseaseIds,
                options: [
                  ...masterData.diseases.map((d) => {'id': d.id, 'name': d.name}),
                  {'id': 'other', 'name': 'อื่นๆ (ระบุเอง)'},
                ],
                customController: _customDiseaseController,
                hintText: 'แตะเพื่อเลือกโรค...',
                onChanged: (newSet) => setState(() {
                  _selectedDiseaseIds.clear();
                  _selectedDiseaseIds.addAll(newSet);
                }),
              ),
            ],

            // ── TYPE CT02: VACCINE FIELDS ──
            if (_selectedType == 'CT02') ...[
              _buildDropdownChecklistSelector(
                title: 'เลือกวัคซีนที่ฉีด *',
                icon: Icons.vaccines_outlined,
                color: AppColors.info,
                selectedIds: _selectedVaccineIds,
                options: [
                  ...masterData.vaccines.map((v) => {'id': v.id, 'name': v.name, 'category': v.category ?? ''}),
                  {'id': 'other', 'name': 'อื่นๆ (ระบุเอง)', 'category': ''},
                ],
                customController: _customVaccineController,
                hintText: 'แตะเพื่อเลือกวัคซีน...',
                onChanged: (newSet) => setState(() {
                  _selectedVaccineIds.clear();
                  _selectedVaccineIds.addAll(newSet);
                }),
              ),
            ],

            // ── TYPE CT03: MEDICINE FIELDS ──
            if (_selectedType == 'CT03') ...[
              _buildDropdownChecklistSelector(
                title: 'เลือกโรคที่พบ / ที่รักษา *',
                icon: Icons.coronavirus_outlined,
                color: AppColors.primary,
                selectedIds: _selectedDiseaseIds,
                options: [
                  ...masterData.diseases.map((d) => {'id': d.id, 'name': d.name}),
                  {'id': 'other', 'name': 'อื่นๆ (ระบุเอง)'},
                ],
                customController: _customDiseaseController,
                hintText: 'แตะเพื่อเลือกโรค...',
                onChanged: (newSet) => setState(() {
                  _selectedDiseaseIds.clear();
                  _selectedDiseaseIds.addAll(newSet);
                }),
              ),
              const SizedBox(height: 16),
              _buildDropdownChecklistSelector(
                title: 'เลือกยารักษาที่ใช้ *',
                icon: Icons.medication_outlined,
                color: const Color(0xFFD97706),
                selectedIds: _selectedMedicineIds,
                options: [
                  ...masterData.medicines.map((m) => {'id': m.id, 'name': m.name, 'category': m.category ?? ''}),
                  {'id': 'other', 'name': 'อื่นๆ (ระบุเอง)', 'category': ''},
                ],
                customController: _customMedicineController,
                hintText: 'แตะเพื่อเลือกยารักษา...',
                onChanged: (newSet) => setState(() {
                  _selectedMedicineIds.clear();
                  _selectedMedicineIds.addAll(newSet);
                }),
              ),
            ],

            const SizedBox(height: 16),

            // ── MODE 1 OR CT01 INPUTS ──
            if (_selectedType == 'CT01' || _costAllocationMode == 'equal') ...[
              if (_selectedType != 'CT01') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'ปริมาณยาที่ใช้ (ต่อตัว)',
                          hintText: 'เช่น 2',
                          filled: true,
                          fillColor: AppColors.surfAlt(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        dropdownColor: AppColors.cardBg(context),
                        initialValue: _selectedUnitId,
                        style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'หน่วย',
                          filled: true,
                          fillColor: AppColors.surfAlt(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: masterData.units
                            .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedUnitId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              TextFormField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                decoration: InputDecoration(
                  labelText: _selectedType == 'CT01' ? 'ค่าตรวจสุขภาพต่อตัว (บาท)' : 'ค่าใช้จ่ายต่อตัว (บาท)',
                  hintText: 'บันทึกราคานี้ให้กับวัวทั้ง ${_selectedCowIds.length} ตัวเท่ากันหมด (ไม่หาร)',
                  filled: true,
                  fillColor: AppColors.surfAlt(context),
                  prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── MODE 2 INPUTS: PER-COW CUSTOM WITH EXPANDABLE CARDS & PER-ITEM INPUTS ──
            if (_selectedType != 'CT01' && _costAllocationMode == 'custom') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.secondaryDark.withValues(alpha: 0.5)),
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
                              const Icon(Icons.tune_rounded, color: AppColors.secondaryDark, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'กรอกปริมาณและราคาเฉพาะวัวแต่ละตัว (${selectedCowsList.length} ตัว)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_expandedCowIds.length == selectedCowsList.length) {
                                _expandedCowIds.clear();
                              } else {
                                for (var c in selectedCowsList) {
                                  _expandedCowIds.add(c.id);
                                }
                              }
                            });
                          },
                          child: Text(
                            _expandedCowIds.length == selectedCowsList.length ? 'ย่อทั้งหมด' : 'ขยายทั้งหมด',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...selectedCowsList.map((cow) {
                      final isExpanded = _expandedCowIds.contains(cow.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isExpanded ? AppColors.surfAlt(context) : AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isExpanded ? AppColors.secondaryDark : AppColors.brd(context)),
                        ),
                        child: Column(
                          children: [
                            // Accordion Header
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedCowIds.remove(cow.id);
                                  } else {
                                    _expandedCowIds.add(cow.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            color: AppColors.surfAlt(context),
                                            child: (cow.imageFullUrl != null || cow.imageUrl != null)
                                                ? Image.network(
                                                    cow.imageFullUrl ?? cow.imageUrl!,
                                                    width: 32,
                                                    height: 32,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: CowIcon(size: 16, color: AppColors.primaryDark),
                                                    ),
                                                  )
                                                : const Center(
                                                    child: CowIcon(size: 16, color: AppColors.primaryDark),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cow.name.isNotEmpty ? cow.name : 'วัว ${cow.tagNumber}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(context)),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('(${cow.tagNumber})', style: TextStyle(fontSize: 12, color: AppColors.subText(context))),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondaryDark.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${targetItemIds.length} รายการ',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryDark),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                          color: AppColors.subText(context),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Accordion Content (Per-Item Inputs)
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    ...targetItemIds.map((itemId) {
                                      String itemName;
                                      String? itemCategory;
                                      if (itemId == 'other') {
                                        itemName = _selectedType == 'CT02'
                                            ? (_customVaccineController.text.trim().isNotEmpty ? _customVaccineController.text.trim() : 'อื่นๆ (ระบุเอง)')
                                            : (_customMedicineController.text.trim().isNotEmpty ? _customMedicineController.text.trim() : 'อื่นๆ (ระบุเอง)');
                                      } else {
                                        if (_selectedType == 'CT02') {
                                          final match = masterData.vaccines.where((v) => v.id == itemId).toList();
                                          itemName = match.isNotEmpty ? match.first.name : itemId;
                                          itemCategory = match.isNotEmpty ? match.first.category : null;
                                        } else {
                                          final match = masterData.medicines.where((m) => m.id == itemId).toList();
                                          itemName = match.isNotEmpty ? match.first.name : itemId;
                                          itemCategory = match.isNotEmpty ? match.first.category : null;
                                        }
                                      }

                                      return Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardBg(context),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.brd(context)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Icon(
                                                    _selectedType == 'CT02' ? Icons.vaccines_outlined : Icons.medication_outlined,
                                                    size: 16,
                                                    color: _selectedType == 'CT02' ? AppColors.info : const Color(0xFFD97706),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        itemName,
                                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                                                      ),
                                                      if (itemCategory != null && itemCategory.isNotEmpty)
                                                        Text(
                                                          'หมวดหมู่: $itemCategory',
                                                          style: TextStyle(fontSize: 11, color: AppColors.subText(context)),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: TextFormField(
                                                    controller: _getCowItemAmountController(cow.id, itemId),
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    style: TextStyle(color: AppColors.text(context), fontSize: 14),
                                                    decoration: InputDecoration(
                                                      labelText: 'ปริมาณยาที่ใช้',
                                                      hintText: 'เช่น 1.5',
                                                      hintStyle: TextStyle(color: AppColors.hint(context)),
                                                      filled: true,
                                                      fillColor: AppColors.surfAlt(context),
                                                      isDense: true,
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  flex: 2,
                                                  child: DropdownButtonFormField<String>(
                                                    isExpanded: true,
                                                    dropdownColor: AppColors.cardBg(context),
                                                    initialValue: _cowItemUnitIds['${cow.id}_$itemId'] ?? _selectedUnitId,
                                                    style: TextStyle(color: AppColors.text(context), fontSize: 14),
                                                    decoration: InputDecoration(
                                                      labelText: 'หน่วย',
                                                      filled: true,
                                                      fillColor: AppColors.surfAlt(context),
                                                      isDense: true,
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                    items: masterData.units
                                                        .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name, overflow: TextOverflow.ellipsis)))
                                                        .toList(),
                                                    onChanged: (val) {
                                                      setState(() => _cowItemUnitIds['${cow.id}_$itemId'] = val);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _getCowItemCostController(cow.id, itemId),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: TextStyle(color: AppColors.text(context), fontSize: 14),
                                              decoration: InputDecoration(
                                                labelText: 'ราคาเฉพาะรายการนี้ (บาท)',
                                                hintText: 'เช่น 150',
                                                hintStyle: TextStyle(color: AppColors.hint(context)),
                                                prefixIcon: const Icon(Icons.attach_money_rounded, size: 16, color: AppColors.secondaryDark),
                                                filled: true,
                                                fillColor: AppColors.surfAlt(context),
                                                isDense: true,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Shared Fields: Note
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              style: TextStyle(fontSize: 15, color: AppColors.text(context)),
              decoration: InputDecoration(
                labelText: 'หมายเหตุเพิ่มเติม',
                filled: true,
                fillColor: AppColors.surfAlt(context),
                prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Shared Fields: Admin Name
            TextFormField(
              controller: _adminController,
              style: TextStyle(fontSize: 15, color: AppColors.text(context)),
              decoration: InputDecoration(
                labelText: 'ชื่อผู้ดำเนินการ / สัตวแพทย์',
                filled: true,
                fillColor: AppColors.surfAlt(context),
                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownChecklistSelector({
    required String title,
    required IconData icon,
    required Color color,
    required Set<String> selectedIds,
    required List<Map<String, String>> options,
    required TextEditingController customController,
    required String hintText,
    required ValueChanged<Set<String>> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final result = await showDialog<Set<String>>(
              context: context,
              builder: (ctx) {
                final tempSelected = Set<String>.from(selectedIds);
                return StatefulBuilder(
                  builder: (ctx, setDialogState) {
                    String searchQuery = '';
                    final filteredOptions = options.where((item) {
                      if (searchQuery.isEmpty) return true;
                      return item['name']!.toLowerCase().contains(searchQuery.toLowerCase());
                    }).toList();

                    return AlertDialog(
                      backgroundColor: AppColors.cardBg(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: [
                          Icon(icon, color: color, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                            ),
                          ),
                        ],
                      ),
                      content: SizedBox(
                        width: double.maxFinite,
                        height: MediaQuery.of(context).size.height * 0.65,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              onChanged: (val) {
                                setDialogState(() {
                                  searchQuery = val.trim();
                                });
                              },
                              style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                              decoration: InputDecoration(
                                hintText: 'ค้นหา...',
                                hintStyle: TextStyle(fontSize: 13, color: AppColors.hint(context)),
                                prefixIcon: Icon(Icons.search, size: 20, color: color),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                filled: true,
                                fillColor: AppColors.surfAlt(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: filteredOptions.isEmpty
                                  ? Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: AppColors.hint(context), fontSize: 13)))
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredOptions.length,
                                      itemBuilder: (ctx, index) {
                                        final item = filteredOptions[index];
                                        final id = item['id']!;
                                        final name = item['name']!;
                                        final category = item['category'];
                                        final checked = tempSelected.contains(id);

                                        return CheckboxListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                          title: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: id == 'other' ? FontWeight.bold : FontWeight.w600,
                                              color: id == 'other' ? color : AppColors.text(context),
                                            ),
                                          ),
                                          subtitle: (category != null && category.isNotEmpty)
                                              ? Text(
                                                  'หมวดหมู่: $category',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.subText(context),
                                                  ),
                                                )
                                              : null,
                                          value: checked,
                                          activeColor: color,
                                          onChanged: (val) {
                                            setDialogState(() {
                                              if (val == true) {
                                                tempSelected.add(id);
                                              } else {
                                                tempSelected.remove(id);
                                              }
                                            });
                                          },
                                        );
                                      },
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
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  side: BorderSide(color: AppColors.brd(context)),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'ยกเลิก',
                                  style: TextStyle(color: AppColors.subText(context), fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                onPressed: () => Navigator.pop(ctx, tempSelected),
                                child: Text(
                                  'ตกลง (${tempSelected.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            );

            if (result != null) {
              onChanged(result);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: title,
              labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text(context)),
              filled: true,
              fillColor: AppColors.surfAlt(context),
              prefixIcon: Icon(icon, color: color, size: 22),
              suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.subText(context), size: 28),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: selectedIds.isEmpty
                ? Text(hintText, style: TextStyle(fontSize: 14, color: AppColors.hint(context)))
                : Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: selectedIds.map((id) {
                      String itemName;
                      if (id == 'other') {
                        itemName = customController.text.trim().isNotEmpty
                            ? customController.text.trim()
                            : 'อื่นๆ (ระบุเอง)';
                      } else {
                        final found = options.where((o) => o['id'] == id).toList();
                        itemName = found.isNotEmpty ? found.first['name']! : id;
                      }
                      return Chip(
                        label: Text(itemName, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: id == 'other' ? AppColors.secondaryDark : color,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
          ),
        ),
        if (selectedIds.contains('other')) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: customController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 15, color: AppColors.text(context)),
            decoration: InputDecoration(
              labelText: 'ระบุเพิ่มเติม (อื่นๆ) *',
              hintText: 'พิมพ์ข้อมูลเพิ่มเติมที่นี่...',
              filled: true,
              fillColor: AppColors.surfAlt(context),
              isDense: true,
              prefixIcon: Icon(Icons.edit_note_rounded, color: color, size: 22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeCard(String typeId, String label, IconData icon, Color color) {
    final isSelected = _selectedType == typeId;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = typeId),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.brd(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : AppColors.subText(context), size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : AppColors.text(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, String label, Color color) {
    final isSelected = _selectedHealthStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: AppColors.surfAlt(context),
      side: BorderSide(color: isSelected ? color : AppColors.brd(context)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.text(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _selectedHealthStatus = status),
    );
  }
}
