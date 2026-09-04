import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/features/calendar/providers/calendar_provider.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/farm/providers/zone_provider.dart';
import 'package:cowsmart/features/calendar/providers/appointment_type_provider.dart';

class GroupAppointmentScreen extends ConsumerStatefulWidget {
  const GroupAppointmentScreen({super.key});

  @override
  ConsumerState<GroupAppointmentScreen> createState() => _GroupAppointmentScreenState();
}

class _GroupAppointmentScreenState extends ConsumerState<GroupAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _titleController = TextEditingController(text: 'นัดหมายฉีดวัคซีน/ตรวจสุขภาพ');
  final _noteController = TextEditingController();

  int _currentStep = 1; // 1: Select Cows, 2: Appointment Details
  bool _isWholeFarm = false; // true if whole farm / general appointment
  final Set<String> _selectedCowIds = {};

  // Filters for Step 1
  String _searchQuery = '';
  String? _selectedZoneId;

  // Form fields for Step 2
  String _selectedType = 'ฉีดวัคซีน/ถ่ายพยาธิ';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _selectedReminder = 'ก่อน 1 วัน';

  bool _isSubmitting = false;

  final List<String> _appointmentTypes = [
    'ฉีดวัคซีน/ถ่ายพยาธิ',
    'ตรวจสุขภาพ/ผสมพันธุ์',
    'ติดตามอาการ/รักษา',
    'อื่นๆ',
  ];

  final List<String> _reminderOptions = [
    'ในวันนัดหมาย',
    'ก่อน 1 วัน',
    'ก่อน 2 วัน',
    'ก่อน 3 วัน',
    'ก่อน 1 สัปดาห์',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        ref.read(cowProvider.notifier).fetchCows(currentFarm.id);
        ref.read(zoneProvider.notifier).fetchZones(currentFarm.id);
      }
      ref.read(appointmentTypeProvider.notifier).fetchAppointmentTypes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submitGroupAppointment() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุหัวข้อการนัดหมาย', style: TextStyle(fontSize: 15)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_isWholeFarm && _selectedCowIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกวัวอย่างน้อย 1 ตัว หรือเลือก "ทั้งฟาร์ม"', style: TextStyle(fontSize: 15)),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiClientProvider);
      final currentFarm = ref.read(farmProvider).currentFarm;

      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final noteStr = _noteController.text.trim();
      final fullDescription = noteStr.isNotEmpty
          ? '[$_selectedType] $title ($noteStr)'
          : '[$_selectedType] $title';

      if (_isWholeFarm || _selectedCowIds.isEmpty) {
        await api.post('/health_appointments', data: {
          'cow_id': null,
          'appoint_datetime': dt.toIso8601String(),
          'description': fullDescription,
          'reminder_setting': _selectedReminder,
          'status': 0,
        });
      } else {
        // Generate a unique group_id so all appointments from the same batch
        // are merged into a single calendar card
        final groupId = DateTime.now().millisecondsSinceEpoch.toRadixString(36)
            + _selectedCowIds.length.toRadixString(36);

        for (final cowId in _selectedCowIds) {
          await api.post('/health_appointments', data: {
            'cow_id': cowId,
            'appoint_datetime': dt.toIso8601String(),
            'description': fullDescription,
            'reminder_setting': _selectedReminder,
            'status': 0,
            'group_id': groupId,
          });
        }
      }

      if (currentFarm != null) {
        ref.read(calendarProvider.notifier).fetchEvents(currentFarm.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isWholeFarm || _selectedCowIds.isEmpty
                  ? 'บันทึกวันนัดหมายสุขภาพทั้งฟาร์มสำเร็จแล้ว'
                  : 'บันทึกวันนัดหมายสุขภาพสำหรับวัว ${_selectedCowIds.length} ตัวสำเร็จแล้ว',
              style: const TextStyle(fontSize: 15),
            ),
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
              'สร้างนัดหมายกลุ่ม',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _currentStep == 1
                  ? (_isWholeFarm ? 'ขั้นตอนที่ 1: เลือกทั้งฟาร์ม' : 'ขั้นตอนที่ 1: เลือกวัว (${_selectedCowIds.length} ตัว)')
                  : 'ขั้นตอนที่ 2: ระบุรายละเอียดนัดหมาย',
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
                  Text('กำลังบันทึกข้อมูลนัดหมาย...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                      _buildStepBadge(1, 'เลือกวัว / ทั้งฟาร์ม', _currentStep == 1, () {
                        setState(() => _currentStep = 1);
                      }),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep == 2 ? AppColors.primary : AppColors.brd(context),
                        ),
                      ),
                      _buildStepBadge(2, 'รายละเอียดนัดหมาย', _currentStep == 2, () {
                        if (_isWholeFarm || _selectedCowIds.isNotEmpty) {
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
                      : _buildStep2AppointmentForm(),
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
                        onPressed: (!_isWholeFarm && _selectedCowIds.isEmpty)
                            ? null
                            : () {
                                setState(() => _currentStep = 2);
                              },
                        child: Text(
                          _isWholeFarm
                              ? 'ถัดไป: ระบุรายละเอียดนัดหมาย (ทั้งฟาร์ม)'
                              : 'ถัดไป: ระบุรายละเอียดนัดหมาย (${_selectedCowIds.length} ตัว)',
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
                              onPressed: _submitGroupAppointment,
                              child: const Text(
                                'บันทึกนัดหมาย',
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

  // ── STEP 1: COW SELECTION / WHOLE FARM ──
  Widget _buildStep1CowSelection(List<Cow> availableCows, List<dynamic> zones) {
    final isAllSelected = availableCows.isNotEmpty && availableCows.every((c) => _selectedCowIds.contains(c.id));

    return Column(
      children: [
        // Whole Farm Option Switch
        Container(
          padding: const EdgeInsets.all(14),
          color: AppColors.cardBg(context),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _isWholeFarm ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfAlt(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isWholeFarm ? AppColors.primary : AppColors.brd(context),
                    width: _isWholeFarm ? 1.5 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  value: _isWholeFarm,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onChanged: (val) {
                    setState(() {
                      _isWholeFarm = val ?? false;
                      if (_isWholeFarm) {
                        _selectedCowIds.clear();
                      }
                    });
                  },
                  title: Text(
                    'ทั้งฟาร์ม / ไม่เจาะจงวัว',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text(context)),
                  ),
                  subtitle: Text(
                    'สร้างนัดหมายรวมสำหรับทั้งฟาร์ม ไม่ได้ระบุตัววัวเฉพาะเจาะจง',
                    style: TextStyle(fontSize: 12, color: AppColors.subText(context)),
                  ),
                  secondary: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(Icons.home_work_outlined, color: AppColors.primary, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (!_isWholeFarm) ...[
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
            ],
          ),
        ),

        if (!_isWholeFarm) ...[
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

                      final genderDisplay = (cow.gender == 'M' || cow.gender == 'ผู้' || cow.gender == 'male') ? 'ผู้' : 'เมีย';
                      final breedDisplay = cow.breed.isNotEmpty ? cow.breed : '-';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isChecked ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isChecked ? AppColors.primary : AppColors.brd(context),
                            width: isChecked ? 1.5 : 1,
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
        ] else
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_work_outlined, size: 50, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text('เลือกสร้างนัดหมายสำหรับทั้งฟาร์มเรียบร้อยแล้ว', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  Text('กดปุ่ม "ถัดไป" ด้านล่างเพื่อระบุรายละเอียดนัดหมาย', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── STEP 2: APPOINTMENT DETAILS FORM ──
  Widget _buildStep2AppointmentForm() {
    final dbAppointmentTypes = ref.watch(appointmentTypeProvider);
    final availableTypes = dbAppointmentTypes.isNotEmpty
        ? dbAppointmentTypes.map((t) => t.name).toList()
        : _appointmentTypes;

    final currentSelectedType = availableTypes.contains(_selectedType)
        ? _selectedType
        : (availableTypes.isNotEmpty ? availableTypes.first : _selectedType);

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
                  const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isWholeFarm
                          ? 'สร้างนัดหมายสำหรับ: ทั้งฟาร์ม / ไม่เจาะจงวัว'
                          : 'สร้างนัดหมายให้วัวจำนวน ${_selectedCowIds.length} ตัว',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Appointment Type Selection
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: AppColors.cardBg(context),
              initialValue: currentSelectedType,
              style: TextStyle(fontSize: 15, color: AppColors.text(context)),
              decoration: InputDecoration(
                labelText: 'ประเภทนัดหมาย *',
                filled: true,
                fillColor: AppColors.surfAlt(context),
                prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: availableTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedType = val;
                    _titleController.text = 'นัดหมาย$val';
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // Appointment Title Input
            TextFormField(
              controller: _titleController,
              style: TextStyle(fontSize: 15, color: AppColors.text(context)),
              decoration: InputDecoration(
                labelText: 'หัวข้อการนัดหมาย *',
                hintText: 'เช่น นัดหมายฉีดวัคซีนปากเท้าเปื่อย',
                filled: true,
                fillColor: AppColors.surfAlt(context),
                prefixIcon: const Icon(Icons.title_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Date & Time Pickers Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.brd(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('วันนัดหมาย', style: TextStyle(fontSize: 11, color: AppColors.subText(context))),
                                Text(
                                  AppDateUtils.formatThaiDate(_selectedDate),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.brd(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('เวลานัดหมาย', style: TextStyle(fontSize: 11, color: AppColors.subText(context))),
                                Text(
                                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} น.',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Advance Reminder Selection
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: AppColors.cardBg(context),
              initialValue: _selectedReminder,
              style: TextStyle(fontSize: 15, color: AppColors.text(context)),
              decoration: InputDecoration(
                labelText: 'แจ้งเตือนล่วงหน้า',
                filled: true,
                fillColor: AppColors.surfAlt(context),
                prefixIcon: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _reminderOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedReminder = val);
                }
              },
            ),
            const SizedBox(height: 14),

            // Details / Notes Input
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              style: TextStyle(fontSize: 15, color: AppColors.text(context)),
              decoration: InputDecoration(
                labelText: 'รายละเอียด / หมายเหตุเพิ่มเติม',
                hintText: 'พิมพ์รายละเอียดการนัดหมาย เช่น ชื่อยาที่ใช้, สัตวแพทย์ผู้นัด ฯลฯ',
                hintStyle: TextStyle(color: AppColors.hint(context)),
                filled: true,
                fillColor: AppColors.surfAlt(context),
                prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
