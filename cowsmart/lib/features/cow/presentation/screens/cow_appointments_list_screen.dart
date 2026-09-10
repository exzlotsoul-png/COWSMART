import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/features/calendar/providers/calendar_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';

class CowAppointmentsListScreen extends ConsumerStatefulWidget {
  final Cow cow;

  const CowAppointmentsListScreen({
    super.key,
    required this.cow,
  });

  @override
  ConsumerState<CowAppointmentsListScreen> createState() => _CowAppointmentsListScreenState();
}

class _CowAppointmentsListScreenState extends ConsumerState<CowAppointmentsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL'; // ALL, VACCINE, CHECKUP, BREED, TREATMENT, OTHER
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/health_appointments', query: {'cow_id': widget.cow.id});
      if (res.data is List && mounted) {
        final list = (res.data as List).cast<Map<String, dynamic>>();
        // เรียงลำดับตามวันเวลานัดหมายจากใกล้สุดไปไกลสุด
        // กรณีวันและเวลาเดียวกัน ให้เรียงรายการที่สร้างใหม่กว่า (created_at หรือ id ล่าสุด) ขึ้นก่อน
        list.sort((a, b) {
          final dtA = DateTime.tryParse(a['appoint_datetime']?.toString() ?? '');
          final dtB = DateTime.tryParse(b['appoint_datetime']?.toString() ?? '');
          if (dtA != null && dtB != null) {
            final cmp = dtA.compareTo(dtB);
            if (cmp != 0) return cmp;
          } else if (dtA != null) {
            return -1;
          } else if (dtB != null) {
            return 1;
          }

          // กรณีวันที่และเวลาตรงกัน ให้ดู created_at จากใหม่ไปเก่า (ลงไปเก่า)
          final createdA = DateTime.tryParse(a['created_at']?.toString() ?? '');
          final createdB = DateTime.tryParse(b['created_at']?.toString() ?? '');
          if (createdA != null && createdB != null) {
            final createdCmp = createdB.compareTo(createdA); // ใหม่ลงไปเก่า
            if (createdCmp != 0) return createdCmp;
          }

          // Fallback ด้วย id จากมากไปน้อย (id ใหม่ลงไปเก่า)
          final idA = a['health_appointment_id'] ?? a['id'];
          final idB = b['health_appointment_id'] ?? b['id'];
          if (idA != null && idB != null) {
            final numA = num.tryParse(idA.toString());
            final numB = num.tryParse(idB.toString());
            if (numA != null && numB != null) {
              return numB.compareTo(numA);
            }
            return idB.toString().compareTo(idA.toString());
          }
          return 0;
        });
        setState(() {
          _appointments = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppFeedback.showError(context, 'โหลดข้อมูลนัดหมายไม่สำเร็จ');
      }
    }
  }

  Future<void> _showEditAppointmentDialog(Map<String, dynamic> appt) async {
    final rawDesc = appt['description']?.toString() ?? '';
    final cleanDesc = rawDesc.replaceAll(RegExp(r'^\[CT\d+\]\s*'), '').trim();

    // แยกหัวข้อและรายละเอียด (ถ้ามีขึ้นบรรทัดใหม่ หรือ format "หัวข้อ: รายละเอียด")
    String initialTitle = cleanDesc;
    String initialDetail = '';
    if (cleanDesc.contains('\n')) {
      final parts = cleanDesc.split('\n');
      initialTitle = parts.first.trim();
      initialDetail = parts.sublist(1).join('\n').trim();
    } else if (cleanDesc.startsWith('นัดหมาย: ') && cleanDesc.length > 25) {
      // อาจจะเป็นรูปแบบ "นัดหมาย: ตรวจระบบสืบพันธุ์ testset..."
      // พยายามแยกประเภทที่รู้จัก
      final knownTypes = [
        'ฉีดวัคซีน/ถ่ายพยาธิ',
        'ตรวจสุขภาพประจำปี/ประจำเดือน',
        'ตรวจระบบสืบพันธุ์',
        'ติดตามผลการรักษา',
        'อื่นๆ',
      ];
      for (final t in knownTypes) {
        if (cleanDesc.startsWith('นัดหมาย: $t')) {
          initialTitle = 'นัดหมาย: $t';
          initialDetail = cleanDesc.substring('นัดหมาย: $t'.length).trim();
          break;
        }
      }
    }

    final titleCtrl = TextEditingController(text: initialTitle);
    final descCtrl = TextEditingController(text: initialDetail);
    DateTime selectedDate = appt['appoint_datetime'] != null
        ? (DateTime.tryParse(appt['appoint_datetime'].toString()) ?? DateTime.now())
        : DateTime.now();

    TimeOfDay selectedTime = appt['appoint_datetime'] != null
        ? TimeOfDay.fromDateTime(
            DateTime.tryParse(appt['appoint_datetime'].toString()) ?? DateTime.now(),
          )
        : const TimeOfDay(hour: 9, minute: 0);

    String selectedReminder = appt['reminder_setting']?.toString() ?? 'ก่อน 1 วัน';

    final reminderOptions = [
      'ตรงเวลาที่บันทึก',
      'ก่อน 15 นาที',
      'ก่อน 1 ชั่วโมง',
      'ก่อน 1 วัน',
      'ก่อน 3 วัน',
      'ก่อน 7 วัน',
      'ไม่แจ้งเตือน'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'แก้ไขนัดหมายสุขภาพ',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.div(context)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                          decoration: const InputDecoration(
                            labelText: 'หัวข้อนัดหมาย *',
                            labelStyle: TextStyle(fontSize: 15),
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.calendar_today, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary),
                          title: Text('วันนัดหมาย', style: TextStyle(fontSize: 15, color: AppColors.text(context))),
                          subtitle: Text(
                            AppDateUtils.formatThaiDate(selectedDate, useFullMonth: true),
                            style: TextStyle(fontSize: 14, color: AppColors.text(context), fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2040),
                              helpText: 'เลือกวันที่',
                              cancelText: 'ยกเลิก',
                              confirmText: 'ตกลง',
                            );
                            if (picked != null) setDialogState(() => selectedDate = picked);
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.access_time, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary),
                          title: Text('เวลานัดหมาย', style: TextStyle(fontSize: 15, color: AppColors.text(context))),
                          subtitle: Text(
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')} น.',
                            style: TextStyle(fontSize: 14, color: AppColors.text(context), fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime,
                              helpText: 'เลือกเวลา',
                              cancelText: 'ยกเลิก',
                              confirmText: 'ตกลง',
                            );
                            if (picked != null) setDialogState(() => selectedTime = picked);
                          },
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: descCtrl,
                          maxLines: 2,
                          style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                          decoration: const InputDecoration(
                            labelText: 'รายละเอียด/หมายเหตุ (ไม่บังคับ)',
                            labelStyle: TextStyle(fontSize: 15),
                            prefixIcon: Icon(Icons.notes),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedReminder,
                          style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                          decoration: const InputDecoration(
                            labelText: 'แจ้งเตือนล่วงหน้า',
                            labelStyle: TextStyle(fontSize: 15),
                            prefixIcon: Icon(Icons.notifications_active_outlined),
                          ),
                          items: reminderOptions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(fontSize: 15, color: AppColors.text(context))))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedReminder = v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.div(context)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ยกเลิก', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;
                          final detail = descCtrl.text.trim();
                          final fullDesc = detail.isNotEmpty ? '$title\n$detail' : title;

                          final dt = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );

                          Navigator.pop(ctx);

                          try {
                            final api = ref.read(apiClientProvider);
                            final farmId = ref.read(farmProvider).currentFarm?.id ?? '';
                            final apptId = appt['health_appointment_id'] ?? appt['id'];

                            if (apptId != null) {
                              await api.put('/health_appointments/$apptId', data: {
                                'cow_id': widget.cow.id,
                                'appoint_datetime': dt.toIso8601String(),
                                'description': fullDesc,
                                'reminder_setting': selectedReminder,
                                'status': appt['status'] ?? 0,
                              });
                            }

                            if (farmId.isNotEmpty) {
                              ref.read(calendarProvider.notifier).fetchEvents(farmId);
                            }
                            _fetchAppointments();

                            if (mounted) {
                              AppFeedback.showSuccess(context, 'อัปเดตวันนัดหมายสุขภาพเรียบร้อยแล้ว');
                            }
                          } catch (e) {
                            if (mounted) {
                              AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการบันทึกนัดหมาย: $e');
                            }
                          }
                        },
                        child: const Text('อัปเดต', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAppointment(Map<String, dynamic> appt) async {
    final rawDesc = appt['description']?.toString() ?? 'นัดหมายนี้';
    final desc = rawDesc.replaceAll(RegExp(r'^\[CT\d+\]\s*'), '').trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('ยืนยันการลบนัดหมาย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text('คุณต้องการลบนัดหมาย "$desc" ใช่หรือไม่?\nการดำเนินการนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('ลบนัดหมาย', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final apptId = appt['health_appointment_id'] ?? appt['id'];
      if (apptId == null) return;
      try {
        final api = ref.read(apiClientProvider);
        await api.delete('/health_appointments/$apptId');
        final currentFarm = ref.read(farmProvider).currentFarm;
        if (currentFarm != null) {
          ref.read(calendarProvider.notifier).fetchEvents(currentFarm.id);
        }
        _fetchAppointments();
        if (mounted) {
          AppFeedback.showSuccess(context, 'ลบนัดหมายเรียบร้อยแล้ว');
        }
      } catch (e) {
        if (mounted) {
          AppFeedback.showError(context, 'ไม่สามารถลบนัดหมายได้: $e');
        }
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredAppointments() {
    return _appointments.where((appt) {
      final rawDesc = (appt['description']?.toString() ?? '').toLowerCase();
      final cleanDesc = rawDesc.replaceAll(RegExp(r'^\[ct\d+\]\s*'), '').trim();

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        if (!cleanDesc.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // Category filter
      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'VACCINE') {
        return cleanDesc.contains('วัคซีน') || rawDesc.contains('[ct02]');
      }
      if (_selectedFilter == 'CHECKUP') {
        return cleanDesc.contains('ตรวจสุขภาพ') || cleanDesc.contains('ตรวจ');
      }
      if (_selectedFilter == 'BREED') {
        return cleanDesc.contains('สืบพันธุ์') || cleanDesc.contains('ผสม') || cleanDesc.contains('คลอด');
      }
      if (_selectedFilter == 'TREATMENT') {
        return cleanDesc.contains('รักษา') || cleanDesc.contains('ยา') || cleanDesc.contains('ติดตาม');
      }
      if (_selectedFilter == 'OTHER') {
        final isVaccine = cleanDesc.contains('วัคซีน') || rawDesc.contains('[ct02]');
        final isCheckup = cleanDesc.contains('ตรวจสุขภาพ') || cleanDesc.contains('ตรวจ');
        final isBreed = cleanDesc.contains('สืบพันธุ์') || cleanDesc.contains('ผสม') || cleanDesc.contains('คลอด');
        final isTreatment = cleanDesc.contains('รักษา') || cleanDesc.contains('ยา') || cleanDesc.contains('ติดตาม');
        return !isVaccine && !isCheckup && !isBreed && !isTreatment;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredAppointments();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 68.0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'นัดหมายสุขภาพทั้งหมด',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${widget.cow.name} (${widget.cow.tagNumber})',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter & Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                  decoration: InputDecoration(
                    hintText: 'ค้นหานัดหมาย (เช่น วัคซีน, ตรวจสุขภาพ)...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.hint(context)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ทั้งหมด (${_appointments.length})', 'ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('ฉีดวัคซีน', 'VACCINE'),
                      const SizedBox(width: 8),
                      _buildFilterChip('ตรวจสุขภาพ', 'CHECKUP'),
                      const SizedBox(width: 8),
                      _buildFilterChip('ผสมพันธุ์/คลอด', 'BREED'),
                      const SizedBox(width: 8),
                      _buildFilterChip('รักษา/ติดตามผล', 'TREATMENT'),
                      const SizedBox(width: 8),
                      _buildFilterChip('อื่นๆ', 'OTHER'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) => _buildAppointmentCard(filtered[idx]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfAlt(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.brd(context),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.subText(context),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final isDark = AppColors.isDark(context);
    final dtStr = appt['appoint_datetime']?.toString() ?? '';
    final dt = DateTime.tryParse(dtStr);
    final rawDesc = appt['description']?.toString() ?? 'นัดหมายสุขภาพ';
    final desc = rawDesc.replaceAll(RegExp(r'^\[CT\d+\]\s*'), '').trim();
    final reminder = appt['reminder_setting']?.toString() ?? '';
    final isVaccine = rawDesc.contains('วัคซีน') || rawDesc.contains('[CT02]');

    // แยกหัวข้อหลักและรายละเอียด/หมายเหตุ เพื่อให้แสดงผลแตกต่างกันชัดเจน
    String titleText = desc;
    String? noteText;
    if (desc.contains('\n')) {
      final parts = desc.split('\n');
      titleText = parts.first.trim();
      noteText = parts.sublist(1).join('\n').trim();
    } else if (desc.startsWith('นัดหมาย: ') && desc.length > 25) {
      final knownTypes = [
        'ฉีดวัคซีน/ถ่ายพยาธิ',
        'ตรวจสุขภาพประจำปี/ประจำเดือน',
        'ตรวจระบบสืบพันธุ์',
        'ติดตามผลการรักษา',
        'อื่นๆ',
      ];
      for (final t in knownTypes) {
        if (desc.startsWith('นัดหมาย: $t')) {
          final remainder = desc.substring('นัดหมาย: $t'.length).trim();
          if (remainder.isNotEmpty) {
            titleText = 'นัดหมาย: $t';
            noteText = remainder;
          }
          break;
        }
      }
    }

    final iconColor = isVaccine ? const Color(0xFF0284C7) : const Color(0xFFDC2626);
    final iconData = isVaccine ? Icons.vaccines_rounded : Icons.medical_services_outlined;

    // คำนวณจำนวนวันที่เหลือจนถึงวันนัดหมาย และกำหนดสีตามระยะเวลา
    String? countdownLabel;
    Color countdownColor = AppColors.text(context);
    if (dt != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final apptDay = DateTime(dt.year, dt.month, dt.day);
      final diffDays = apptDay.difference(today).inDays;

      if (diffDays < 0) {
        countdownLabel = 'เลยกำหนด ${-diffDays} วัน';
        countdownColor = const Color(0xFF9E9E9E); // สีเทา (เลยกำหนด)
      } else if (diffDays == 0) {
        countdownLabel = 'วันนี้!';
        countdownColor = const Color(0xFFE11D48); // สีแดงสดจัด/กุหลาบ (วันนี้)
      } else if (diffDays == 1) {
        countdownLabel = 'พรุ่งนี้ (1 วัน)';
        countdownColor = const Color(0xFFEA580C); // สีส้มแดงจัด (เหลือ 1 วัน)
      } else if (diffDays <= 3) {
        countdownLabel = 'อีก $diffDays วัน';
        countdownColor = const Color(0xFFF59E0B); // สีส้มอมเหลือง/อำพัน (ไม่เกิน 3 วัน)
      } else if (diffDays < 7) {
        countdownLabel = 'อีก $diffDays วัน';
        countdownColor = const Color(0xFF0284C7); // สีฟ้าคราม (ไม่ถึงสัปดาห์)
      } else {
        countdownLabel = 'อีก $diffDays วัน';
        countdownColor = AppColors.subText(context); // สีปกติ (1 สัปดาห์ขึ้นไป)
      }
    }

    return InkWell(
      onTap: () => _showEditAppointmentDialog(appt),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isVaccine
                ? const Color(0xFF0284C7).withValues(alpha: 0.35)
                : const Color(0xFFDC2626).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconData, color: iconColor, size: 20),
                    if (dt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isVaccine ? 'นัดฉีดวัคซีน' : 'นัดหมายสุขภาพ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      titleText,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (noteText != null && noteText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        noteText,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.normal,
                          color: AppColors.subText(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 14,
                              color: AppColors.subText(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dt != null ? AppDateUtils.formatThaiDate(dt) : '-',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.subText(context),
                              ),
                            ),
                          ],
                        ),
                        if (countdownLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: countdownColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: countdownColor.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined, size: 12, color: countdownColor),
                                const SizedBox(width: 3),
                                Text(
                                  countdownLabel,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: countdownColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (reminder.isNotEmpty && reminder != 'ไม่แจ้งเตือน')
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 14,
                                color: Colors.amber[800],
                              ),
                              const SizedBox(width: 3),
                              Text(
                                reminder,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.amber[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 22, color: AppColors.subText(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'edit') {
                    _showEditAppointmentDialog(appt);
                  } else if (val == 'delete') {
                    _confirmDeleteAppointment(appt);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 20),
                        SizedBox(width: 8),
                        Text('แก้ไข'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 8),
                        Text('ลบ', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _appointments.isEmpty
                  ? 'ยังไม่มีรายการนัดหมายสำหรับวัวตัวนี้'
                  : 'ไม่พบนัดหมายที่ตรงกับเงื่อนไขการค้นหา',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _appointments.isEmpty
                  ? 'คุณสามารถเพิ่มการนัดหมายได้ที่แท็บสุขภาพ'
                  : 'ลองเปลี่ยนคำค้นหาหรือเลือกแท็บฟิลเตอร์อื่น',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subText(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
