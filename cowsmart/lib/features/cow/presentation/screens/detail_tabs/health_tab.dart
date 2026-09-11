import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/core/widgets/custom_date_range_picker.dart';
import 'package:cowsmart/core/services/image_upload_service.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/cow/domain/health_record.dart';
import 'package:cowsmart/features/cow/domain/growth_record.dart';
import 'package:cowsmart/features/calendar/domain/calendar_event.dart';
import 'package:cowsmart/core/widgets/image_picker_widget.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/features/calendar/providers/appointment_type_provider.dart';
import 'package:cowsmart/features/calendar/providers/calendar_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import '../../../providers/cow_detail_provider.dart';
import '../../../../health/providers/master_data_provider.dart';
import 'package:cowsmart/features/market/providers/market_price_provider.dart';
import 'package:cowsmart/features/cow/providers/breed_provider.dart';
import 'package:cowsmart/features/cow/domain/breed.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:cowsmart/features/health/presentation/widgets/calf_vaccine_dialog.dart';
import 'package:cowsmart/features/health/services/calf_vaccine_schedule_service.dart';

class HealthTab extends ConsumerStatefulWidget {
  final Cow cow;
  const HealthTab({super.key, required this.cow});

  @override
  ConsumerState<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends ConsumerState<HealthTab> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoadingAppointments = true;
  bool _hasFetchedAppointments = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _fetchAppointments();
    });
  }

  Future<void> _fetchAppointments() async {
    if (!mounted) return;
    setState(() => _isLoadingAppointments = true);
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
          _isLoadingAppointments = false;
          _hasFetchedAppointments = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAppointments = false;
          _hasFetchedAppointments = true;
        });
      }
    }
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HealthRecordDialog(
        cow: widget.cow,
        masterData: masterData,
        onSave: (record) async {
          await ref.read(cowDetailProvider.notifier).addHealthRecord(record);
        },
      ),
    );
  }

  Future<void> _showAddHealthAppointmentDialog({Map<String, dynamic>? existingAppt}) async {
    final rawDesc = existingAppt?['description']?.toString() ?? '';
    final cleanDesc = rawDesc.replaceAll(RegExp(r'^\[CT\d+\]\s*'), '').trim();

    // แยกหัวข้อและรายละเอียด (ถ้ามีขึ้นบรรทัดใหม่ หรือ format ประเภท)
    String initialTitle = cleanDesc;
    String initialDetail = '';
    if (cleanDesc.contains('\n')) {
      final parts = cleanDesc.split('\n');
      initialTitle = parts.first.trim();
      initialDetail = parts.sublist(1).join('\n').trim();
    } else if (cleanDesc.startsWith('นัดหมาย: ') && cleanDesc.length > 25) {
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

    final titleCtrl = TextEditingController(
      text: existingAppt != null
          ? (initialTitle.isNotEmpty ? initialTitle : 'นัดหมายฉีดวัคซีน/ตรวจสุขภาพ')
          : 'นัดหมายฉีดวัคซีน/ตรวจสุขภาพ',
    );
    final descCtrl = TextEditingController(text: initialDetail);

    DateTime selectedDate = existingAppt != null && existingAppt['appoint_datetime'] != null
        ? (DateTime.tryParse(existingAppt['appoint_datetime'].toString()) ??
            DateTime.now().add(const Duration(days: 7)))
        : DateTime.now().add(const Duration(days: 7));

    TimeOfDay selectedTime = existingAppt != null && existingAppt['appoint_datetime'] != null
        ? TimeOfDay.fromDateTime(
            DateTime.tryParse(existingAppt['appoint_datetime'].toString()) ?? DateTime.now(),
          )
        : const TimeOfDay(hour: 9, minute: 0);

    String selectedReminder = existingAppt?['reminder_setting']?.toString() ?? 'ก่อน 1 วัน';
    String selectedType = 'ฉีดวัคซีน/ถ่ายพยาธิ';

    List<String> types = [
      'ฉีดวัคซีน/ถ่ายพยาธิ',
      'ตรวจสุขภาพประจำปี/ประจำเดือน',
      'ตรวจระบบสืบพันธุ์',
      'ติดตามผลการรักษา',
      'อื่นๆ',
    ];

    // Fetch appointment types from API only when creating new appointment
    if (existingAppt == null) {
      try {
        final api = ref.read(apiClientProvider);
        final res = await api.get('/appointment_types');
        final apiTypes = (res.data as List<dynamic>)
            .map((e) => e['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        if (apiTypes.isNotEmpty) {
          types = apiTypes;
          selectedType = types.first;
          titleCtrl.text = 'นัดหมาย${types.first}';
        }
      } catch (_) {}
    }

    final reminderOptions = [
      'ตรงเวลาที่บันทึก',
      'ก่อน 15 นาที',
      'ก่อน 1 ชั่วโมง',
      'ก่อน 1 วัน',
      'ก่อน 3 วัน',
      'ก่อน 7 วัน',
      'ไม่แจ้งเตือน'
    ];

    if (!mounted) return;
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
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          existingAppt != null ? Icons.edit_calendar_rounded : Icons.medical_services_outlined,
                          color: const Color(0xFFDC2626),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          existingAppt != null ? 'แก้ไขนัดหมายสุขภาพ' : 'นัดหมายตรวจสุขภาพ / ฉีดวัคซีน',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        if (existingAppt == null) ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedType,
                            style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                            decoration: const InputDecoration(
                              labelText: 'ประเภทนัดหมาย *',
                              labelStyle: TextStyle(fontSize: 15),
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 15, color: AppColors.text(context))))).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() {
                                  selectedType = v;
                                  titleCtrl.text = 'นัดหมาย: $v';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: titleCtrl,
                          style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                          decoration: InputDecoration(
                            labelText: existingAppt != null ? 'หัวข้อนัดหมาย *' : 'หัวข้อการนัดหมาย *',
                            labelStyle: const TextStyle(fontSize: 15),
                            prefixIcon: const Icon(Icons.title),
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
                              helpText: 'ระบุเวลา (24 ชั่วโมง)',
                              cancelText: 'ยกเลิก',
                              confirmText: 'ตกลง',
                              hourLabelText: 'ชั่วโมง',
                              minuteLabelText: 'นาที',
                              builder: (context, child) {
                                return MediaQuery(
                                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                );
                              },
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
                            final apptId = existingAppt?['health_appointment_id'] ?? existingAppt?['id'];

                            final detail = descCtrl.text.trim();
                            final fullDesc = detail.isNotEmpty ? '$title\n$detail' : title;

                            if (existingAppt != null && apptId != null) {
                              await api.put('/health_appointments/$apptId', data: {
                                'cow_id': widget.cow.id,
                                'appoint_datetime': dt.toIso8601String(),
                                'description': fullDesc,
                                'reminder_setting': selectedReminder,
                                'status': existingAppt['status'] ?? 0,
                              });
                            } else {
                              await api.post('/health_appointments', data: {
                                'cow_id': widget.cow.id,
                                'appoint_datetime': dt.toIso8601String(),
                                'description': fullDesc,
                                'reminder_setting': selectedReminder,
                                'status': 0,
                              });
                            }

                            if (farmId.isNotEmpty) {
                              ref.read(calendarProvider.notifier).fetchEvents(farmId);
                            }
                            _fetchAppointments();

                            if (mounted) {
                              AppFeedback.showSuccess(
                                context,
                                existingAppt != null
                                    ? 'อัปเดตวันนัดหมายสุขภาพเรียบร้อยแล้ว'
                                    : 'บันทึกวันนัดหมายสุขภาพและการแจ้งเตือนลงปฏิทินแล้ว',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการบันทึกนัดหมาย: $e');
                            }
                          }
                        },
                        child: const Text('บันทึกนัดหมาย', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(cowDetailProvider);
    final records = detailState.healthRecords;

    ref.listen<CowDetailState>(cowDetailProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess == false) {
        AppFeedback.showSuccess(context, 'บันทึกการรักษาสำเร็จ!');
        ref.read(cowDetailProvider.notifier).clearFlags();
      } else if (next.error != null && prev?.error != next.error) {
        AppFeedback.showError(context, next.error!);
        ref.read(cowDetailProvider.notifier).clearFlags();
      }
    });

    if (detailState.isLoading || !_hasFetchedAppointments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
          children: [
            _buildSummaryCard(context, records),
            Builder(
              builder: (context) {
                final isCalfOrYoung = widget.cow.type == CowType.calf ||
                    DateTime.now().difference(widget.cow.birthDate).inDays <= 365;
                if (!isCalfOrYoung) return const SizedBox.shrink();

                final allSchedule = CalfVaccineScheduleService.generateSchedule(
                  birthDate: widget.cow.birthDate,
                  gender: widget.cow.gender,
                );
                final remaining = CalfVaccineScheduleService.filterRemainingSchedule(
                  allItems: allSchedule,
                  existingAppointments: _appointments,
                );

                // ถ้าเลือกหรือตั้งนัดหมายครบทุกเข็มแล้ว ให้แถบนี้หายไปตามความต้องการของผู้ใช้
                if (remaining.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildCalfVaccineBanner(context, remainingCount: remaining.length),
                );
              },
            ),

            // ── นัดหมายสุขภาพและวัคซีนที่จะถึง ──
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF57C00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFFF57C00)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ตารางนัดหมายสุขภาพและวัคซีน',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_appointments.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () async {
                      await context.push('/cow_appointments_list', extra: widget.cow);
                      _fetchAppointments();
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFFF57C00)),
                    label: Text(
                      'ดูทั้งหมด (${_appointments.length})',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFFF57C00),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (_isLoadingAppointments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_appointments.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfAlt(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.brd(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 30, color: AppColors.hint(context)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ยังไม่มีนัดหมายสุขภาพสำหรับวัวตัวนี้',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'กด "ตั้งนัดหมาย" จากแถบโปรแกรมวัคซีนด้านบน หรือกดปุ่มปฏิทินสีส้มด้านล่าง',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.subText(context),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._appointments.take(5).map((appt) => _buildAppointmentCard(context, appt)),

            // ── ประวัติการรักษาและตรวจสุขภาพ ──
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'ประวัติการรักษาและตรวจสุขภาพ',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () {
                    context.push(
                      '/cow_history_list',
                      extra: {'cow': widget.cow, 'initialTab': 'health'},
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.primary),
                  label: Text(
                    'ดูทั้งหมด (${records.length})',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              Card(
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        size: 48,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ยังไม่มีประวัติการรักษา',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'กดปุ่มด้านล่างเพื่อเพิ่มประวัติหรือวันนัดหมาย',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              ...records.take(5).map((r) => _buildHealthCard(context, r)),
              if (records.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push(
                        '/cow_history_list',
                        extra: {'cow': widget.cow, 'initialTab': 'health'},
                      );
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: Text('ดูประวัติการรักษาทั้งหมด (${records.length} รายการ)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'add_health_appt_fab',
                onPressed: _showAddHealthAppointmentDialog,
                backgroundColor: const Color(0xFFF57C00),
                child: const Icon(Icons.event_available, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'add_health_record_fab',
                onPressed: detailState.isSaving ? null : _showAddHealthRecordDialog,
                backgroundColor: AppColors.primary,
                child: detailState.isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(BuildContext context, Map<String, dynamic> appt) {
    final isDark = AppColors.isDark(context);
    final dtStr = appt['appoint_datetime']?.toString() ?? '';
    final dt = DateTime.tryParse(dtStr);
    final rawDesc = appt['description']?.toString() ?? 'นัดหมายสุขภาพ';
    final desc = rawDesc.replaceAll(RegExp(r'^\[CT\d+\]\s*'), '').trim();
    final reminder = appt['reminder_setting']?.toString() ?? '';
    final isVaccine = rawDesc.contains('วัคซีน') || rawDesc.contains('[CT02]');

    final iconColor = isVaccine ? const Color(0xFF0284C7) : const Color(0xFFDC2626);
    final iconData = isVaccine ? Icons.vaccines_rounded : Icons.medical_services_outlined;

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
      onTap: () => _showAddHealthAppointmentDialog(existingAppt: appt),
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
                onSelected: (val) async {
                  if (val == 'edit') {
                    _showAddHealthAppointmentDialog(existingAppt: appt);
                  } else if (val == 'delete') {
                    final apptId = appt['health_appointment_id'] ?? appt['id'];
                    if (apptId == null) return;

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

  Widget _buildCalfVaccineBanner(BuildContext context, {int? remainingCount}) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF1F6EC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.vaccines_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'โปรแกรมวัคซีนสำหรับลูกวัว',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'ตั้งตารางนัดหมายฉีดวัคซีนตามเกณฑ์มาตรฐานกรมปศุสัตว์',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (remainingCount != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'เหลือ $remainingCount เข็ม',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
              ],
              ElevatedButton(
                onPressed: () async {
                  final res = await CalfVaccineDialog.show(
                    context,
                    widget.cow,
                    existingAppointments: _appointments,
                  );
                  if (res == true) {
                    _fetchAppointments();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  elevation: 0,
                ),
                child: const Text('ตั้งนัดหมาย', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
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
    final isDark = AppColors.isDark(context);
    final typeLabels = {
      'CT01': 'ตรวจสุขภาพทั่วไป',
      'CT02': 'ฉีดวัคซีน',
      'CT03': 'รักษาโรค',
      'CT04': 'ถ่ายพยาธิ',
    };

    Color getTypeColor() {
      switch (record.checkupTypeId) {
        case 'CT02':
          return const Color(0xFF0284C7); // ฟ้าครามสดใส (วัคซีน)
        case 'CT03':
          return const Color(0xFFDC2626); // แดง (รักษาโรค)
        case 'CT04':
          return const Color(0xFFD97706); // ส้มอำพัน (ถ่ายพยาธิ)
        default:
          return const Color(0xFF16A34A); // เขียว (ตรวจสุขภาพทั่วไป)
      }
    }

    IconData getIcon() {
      switch (record.checkupTypeId) {
        case 'CT02':
          return Icons.vaccines_rounded;
        case 'CT03':
          return Icons.medical_services_outlined;
        case 'CT04':
          return Icons.bug_report_outlined;
        default:
          return Icons.health_and_safety_outlined;
      }
    }

    final typeColor = getTypeColor();
    final typeName = typeLabels[record.checkupTypeId] ?? 'บันทึกสุขภาพ';

    String? statusText;
    Color statusBgColor = const Color(0xFF16A34A);
    // Only display status tag for General Checkup (CT01)
    if (record.checkupTypeId == 'CT01') {
      if (record.status == 'normal') {
        statusText = 'ปกติ';
        statusBgColor = const Color(0xFF16A34A);
      } else if (record.status == 'sick') {
        statusText = 'ป่วย';
        statusBgColor = const Color(0xFFDC2626);
      } else if (record.status == 'injured') {
        statusText = 'บาดเจ็บ';
        statusBgColor = const Color(0xFFD97706);
      }
    }

    return InkWell(
      onTap: () {
        final masterData = ref.read(masterDataProvider);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _HealthRecordDialog(
            cow: widget.cow,
            masterData: masterData,
            initialRecord: record,
            onSave: (updatedRecord) {
              ref.read(cowDetailProvider.notifier).updateHealthRecord(updatedRecord);
            },
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: typeColor.withValues(alpha: 0.35),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Leading Icon Box + Title/Category + Cost & Popup Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 48x48 rounded icon container with record tag
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(getIcon(), color: typeColor, size: 20),
                      const SizedBox(height: 2),
                      Text(
                        'บันทึก',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge category tag
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ),
                          if (statusText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusBgColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusBgColor.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusBgColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        typeName,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 14,
                            color: AppColors.subText(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppDateUtils.formatThaiDate(record.recordDate),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.subText(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (record.cost != null && record.cost! > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (AppColors.isDark(context) ? AppColors.warning : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (AppColors.isDark(context) ? AppColors.warning : const Color(0xFFF59E0B)).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${NumberFormat('#,##0').format(record.cost)} ฿',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.isDark(context) ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 22, color: AppColors.subText(context)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) async {
                    if (val == 'edit') {
                      final masterData = ref.read(masterDataProvider);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
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
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        ref.read(cowDetailProvider.notifier).deleteHealthRecord(record.id);
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

              // Detail rows & items
              if (record.items.isNotEmpty ||
                  record.vaccineName != null ||
                  record.diseaseName != null ||
                  record.medicineName != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.isDark(context) ? AppColors.darkSurfaceAlt : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.isDark(context) ? AppColors.darkBorder : Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (record.items.isNotEmpty) ...[
                        ...record.items.map((item) {
                          String amtStr = '';
                          if (item.amount != null && item.amount! > 0) {
                            final a = item.amount!;
                            amtStr = ' (${a % 1 == 0 ? a.toInt() : a} ${item.unitAbbreviation ?? item.unitName ?? ''})'.trimRight();
                          }
                          String costStr = '';
                          if (item.cost != null && item.cost! > 0) {
                            costStr = ' - ${NumberFormat('#,##0').format(item.cost)} ฿';
                          }

                          IconData iconData = Icons.medication;
                          String labelText = 'ยา';
                          if (item.itemType == 'vaccine') {
                            iconData = Icons.vaccines;
                            labelText = 'วัคซีน';
                          } else if (item.itemType == 'disease') {
                            iconData = Icons.coronavirus;
                            labelText = 'โรค';
                          }

                          return _buildDetailRow(
                            context,
                            iconData,
                            labelText,
                            '${item.itemName}$amtStr$costStr',
                          );
                        }),
                      ] else ...[
                        if (record.vaccineName != null)
                          _buildDetailRow(
                            context,
                            Icons.vaccines,
                            'วัคซีน',
                            record.vaccineName!,
                          ),
                        if (record.diseaseName != null)
                          _buildDetailRow(
                            context,
                            Icons.coronavirus,
                            'โรค',
                            record.diseaseName!,
                          ),
                        if (record.medicineName != null)
                          _buildDetailRow(
                            context,
                            Icons.medication,
                            'ยา',
                            record.medicineName!,
                          ),
                      ],
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
                                          color: AppColors.cardBg(context),
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
                            border: Border.all(color: AppColors.brd(context)),
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
                    Icon(Icons.notes, size: 16, color: AppColors.subText(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.note!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.text(context),
                          fontWeight: FontWeight.w500,
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
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppColors.subText(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ผู้ดำเนินการ: ${record.adminName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text(context),
                        fontWeight: FontWeight.w500,
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

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.subText(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.text(context),
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
  final amountController = TextEditingController();
  int? selectedUnitId;
  DateTime selectedDate = DateTime.now();
  String selectedType = 'CT01';
  CowStatus selectedHealthStatus = CowStatus.normal;
  List<String> selectedVaccineIds = [];
  List<String> selectedDiseaseIds = [];
  List<String> selectedMedicineIds = [];
  List<XFile> selectedImageFiles = [];
  List<String> existingImageUrls = [];
  bool isUploading = false;
  int currentStep = 1;

  final Map<String, TextEditingController> _itemAmountControllers = {};
  final Map<String, int?> _itemUnitIds = {};
  final Map<String, TextEditingController> _itemCostControllers = {};
  final Map<String, TextEditingController> _customItemNameControllers = {};

  TextEditingController _getItemAmountController(String id) {
    return _itemAmountControllers.putIfAbsent(id, () => TextEditingController());
  }

  TextEditingController _getItemCostController(String id) {
    return _itemCostControllers.putIfAbsent(id, () => TextEditingController());
  }

  TextEditingController _getCustomItemNameController(String id) {
    return _customItemNameControllers.putIfAbsent(id, () => TextEditingController());
  }

  final checkupTypes = [
    {'id': 'CT01', 'name': 'ตรวจสุขภาพทั่วไป'},
    {'id': 'CT02', 'name': 'ฉีดวัคซีน'},
    {'id': 'CT03', 'name': 'ให้ยารักษา'},
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final current = ref.read(masterDataProvider);
      if (current.diseases.isEmpty &&
          current.medicines.isEmpty &&
          current.vaccines.isEmpty &&
          !current.isLoading) {
        ref.read(masterDataProvider.notifier).fetchAll();
      }
    });
    selectedHealthStatus = widget.cow.status;
    if (selectedHealthStatus != CowStatus.normal &&
        selectedHealthStatus != CowStatus.sick &&
        selectedHealthStatus != CowStatus.injured) {
      selectedHealthStatus = CowStatus.normal;
    }
    if (widget.initialRecord != null) {
      final r = widget.initialRecord!;
      selectedDate = r.recordDate;
      selectedType = r.checkupTypeId;
      
      selectedVaccineIds = List<String>.from(r.vacIds);
      if (selectedVaccineIds.isEmpty && r.vacId != null) selectedVaccineIds.add(r.vacId!);
      
      if (r.diseaseId != null) selectedDiseaseIds.add(r.diseaseId!);
      
      selectedMedicineIds = List<String>.from(r.medIds);
      if (selectedMedicineIds.isEmpty && r.medId != null) selectedMedicineIds.add(r.medId!);

      // Populate item details from r.items if available
      if (r.items.isNotEmpty) {
        for (var item in r.items) {
          if (item.itemType == 'vaccine' && !selectedVaccineIds.contains(item.itemId)) {
            selectedVaccineIds.add(item.itemId);
          } else if (item.itemType == 'medicine' && !selectedMedicineIds.contains(item.itemId)) {
            selectedMedicineIds.add(item.itemId);
          }

          if (item.amount != null) {
            _getItemAmountController(item.itemId).text = item.amount! % 1 == 0 ? item.amount!.toInt().toString() : item.amount!.toString();
          }
          if (item.cost != null) {
            _getItemCostController(item.itemId).text = item.cost! % 1 == 0 ? item.cost!.toInt().toString() : item.cost!.toString();
          }
          if (item.unitId != null) {
            _itemUnitIds[item.itemId] = item.unitId;
          }
        }
      }

      existingImageUrls = List<String>.from(r.images);
      noteController.text = r.note ?? '';
      costController.text = r.cost != null ? r.cost!.toStringAsFixed(0) : '';
      adminController.text = r.adminName ?? '';
      if (r.amount != null) {
        amountController.text = r.amount! % 1 == 0 ? r.amount!.toInt().toString() : r.amount!.toString();
      }
      selectedUnitId = r.unitId;
    }
  }

  @override
  void dispose() {
    costController.dispose();
    adminController.dispose();
    noteController.dispose();
    amountController.dispose();
    for (var c in _itemAmountControllers.values) {
      c.dispose();
    }
    for (var c in _itemCostControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<List<String>?> _showMultiSelectModal({
    required String title,
    required String searchHint,
    required List<Map<String, String>> options,
    required List<String> currentSelected,
  }) async {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final tempSelected = List<String>.from(currentSelected);
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = options.where((item) {
              if (searchQuery.isEmpty) return true;
              return (item['name'] ?? '').toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
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
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(ctx, currentSelected),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: AppColors.div(context)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val.trim();
                          });
                        },
                        style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: AppColors.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: AppColors.textHint, fontSize: 13)))
                          : ListView(
                              children: filtered.map((item) {
                                final itemId = item['id']!;
                                final itemName = item['name']!;
                                final itemCat = item['category'];
                                final checked = tempSelected.contains(itemId);
                                return CheckboxListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                  title: Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: itemId == 'other' ? FontWeight.bold : FontWeight.w600,
                                      color: itemId == 'other' ? AppColors.primary : AppColors.text(context),
                                    ),
                                  ),
                                  subtitle: (itemCat != null && itemCat.isNotEmpty)
                                      ? Text('หมวดหมู่: $itemCat', style: TextStyle(fontSize: 12, color: AppColors.subText(context)))
                                      : null,
                                  value: checked,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        tempSelected.add(itemId);
                                      } else {
                                        tempSelected.remove(itemId);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                    Divider(height: 1, color: AppColors.div(context)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => Navigator.pop(ctx, currentSelected),
                              child: const Text('ยกเลิก', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final masterData = ref.watch(masterDataProvider);
    final showVaccine = selectedType == 'CT02';
    final showDisease = selectedType == 'CT03' || (selectedType == 'CT01' && selectedHealthStatus == CowStatus.sick);
    final showMedicine = selectedType == 'CT03';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                      Expanded(
                        child: Text(
                          widget.initialRecord == null ? 'บันทึกสุขภาพและการรักษา' : 'แก้ไขบันทึกสุขภาพและการรักษา',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: currentStep >= 1 ? AppColors.primary : AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: currentStep >= 2 ? AppColors.primary : AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentStep == 1 ? 'ขั้นตอนที่ 1/2: ข้อมูลพื้นฐานและการรักษา' : 'ขั้นตอนที่ 2/2: จำนวน หน่วยวัด และค่าใช้จ่าย',
                    style: TextStyle(fontSize: 12, color: AppColors.subText(context), fontWeight: FontWeight.w500),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            if (currentStep == 1) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(Icons.calendar_today, size: 22, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary),
                title: Text('วันที่', style: TextStyle(fontSize: 16, color: AppColors.text(context))),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy').format(selectedDate),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
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
                value: checkupTypes.any((type) => type['id'] == selectedType)
                    ? selectedType
                    : (checkupTypes.isNotEmpty ? checkupTypes.first['id'] : null),
                isExpanded: true,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.text(context),
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
                      style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedType = val;
                      selectedVaccineIds = [];
                      selectedDiseaseIds = [];
                      selectedMedicineIds = [];
                    });
                  }
                },
              ),
              if (selectedType == 'CT01') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<CowStatus>(
                  value: selectedHealthStatus,
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.text(context),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'สถานะสุขภาพวัว',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.health_and_safety_outlined, size: 22),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: CowStatus.normal,
                      child: Text('ปกติ', style: TextStyle(fontSize: 15, color: AppColors.text(context))),
                    ),
                    DropdownMenuItem(
                      value: CowStatus.sick,
                      child: Text('ป่วย', style: TextStyle(fontSize: 15, color: AppColors.text(context))),
                    ),
                    DropdownMenuItem(
                      value: CowStatus.injured,
                      child: Text('บาดเจ็บ', style: TextStyle(fontSize: 15, color: AppColors.text(context))),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedHealthStatus = val;
                        if (val != CowStatus.sick && selectedType == 'CT01') {
                          selectedDiseaseIds = [];
                        }
                      });
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              if (masterData.isLoading)
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
              if (showVaccine && !masterData.isLoading) ...[
                InkWell(
                  onTap: () async {
                    final options = [
                      ...masterData.vaccines.map((v) => {'id': v.id, 'name': v.name, 'category': v.category ?? ''}),
                      {'id': 'other', 'name': 'อื่นๆ (ระบุเอง)', 'category': ''},
                    ];
                    final result = await _showMultiSelectModal(
                      title: 'เลือกวัคซีน (เลือกได้หลายรายการ)',
                      searchHint: 'ค้นหาวัคซีน...',
                      options: options,
                      currentSelected: selectedVaccineIds,
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
                              String name;
                              if (id == 'other') {
                                name = 'อื่นๆ (ระบุเอง)';
                              } else {
                                name = masterData.vaccines.firstWhere((v) => v.id == id, orElse: () => masterData.vaccines.first).name;
                              }
                              return Chip(
                                label: Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
                                backgroundColor: id == 'other' ? Colors.orange[800] : AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (showDisease && !masterData.isLoading) ...[
                InkWell(
                  onTap: () async {
                    final options = [
                      ...masterData.diseases.map((d) => {'id': d.id, 'name': d.name, 'category': ''}),
                      {'id': 'other', 'name': 'อื่นๆ (ระบุเอง)', 'category': ''},
                    ];
                    final result = await _showMultiSelectModal(
                      title: 'เลือกโรค (เลือกได้หลายรายการ)',
                      searchHint: 'ค้นหาโรค...',
                      options: options,
                      currentSelected: selectedDiseaseIds,
                    );
                    if (result != null) {
                      setState(() => selectedDiseaseIds = result);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'โรค (เลือกได้หลายรายการ)',
                      labelStyle: TextStyle(fontSize: 15),
                      prefixIcon: Icon(Icons.coronavirus, size: 22),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: selectedDiseaseIds.isEmpty
                        ? const Text('แตะเพื่อเลือกโรค...', style: TextStyle(fontSize: 15, color: AppColors.textHint))
                        : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: selectedDiseaseIds.map((id) {
                              String name;
                              if (id == 'other') {
                                name = 'อื่นๆ (ระบุเอง)';
                              } else {
                                final matches = masterData.diseases.where((d) => d.id == id);
                                name = matches.isNotEmpty ? matches.first.name : id;
                              }
                              return Chip(
                                label: Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
                                backgroundColor: id == 'other' ? Colors.orange[800] : AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                  ),
                ),
                if (selectedDiseaseIds.contains('other')) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _getCustomItemNameController('other_disease'),
                    decoration: const InputDecoration(
                      labelText: 'ระบุชื่อโรคอื่นๆ *',
                      hintText: 'พิมพ์ชื่อโรคเพิ่มเติมที่นี่...',
                      prefixIcon: Icon(Icons.edit_note, size: 22, color: AppColors.primary),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // Multiple Medicines Selection (Select Box)
              if (showMedicine && !masterData.isLoading) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final options = [
                      ...masterData.medicines.map((m) => {'id': m.id, 'name': m.name, 'category': m.category ?? ''}),
                      {'id': 'other', 'name': 'อื่นๆ (ระบุเอง)', 'category': ''},
                    ];
                    final result = await _showMultiSelectModal(
                      title: 'เลือกยา (เลือกได้หลายรายการ)',
                      searchHint: 'ค้นหายา...',
                      options: options,
                      currentSelected: selectedMedicineIds,
                    );
                    if (result != null) {
                      setState(() => selectedMedicineIds = result);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'ยา (เลือกได้หลายรายการ)',
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
                              String name;
                              if (id == 'other') {
                                name = 'อื่นๆ (ระบุเอง)';
                              } else {
                                name = masterData.medicines.firstWhere((m) => m.id == id, orElse: () => masterData.medicines.first).name;
                              }
                              return Chip(
                                label: Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
                                backgroundColor: id == 'other' ? Colors.orange[800] : AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: adminController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'ผู้ดำเนินการ (ชื่อ)',
                  labelStyle: TextStyle(fontSize: 15),
                  prefixIcon: Icon(Icons.person, size: 22),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 2,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'รายละเอียดเพิ่มเติม / หมายเหตุ',
                  labelStyle: TextStyle(fontSize: 15),
                  hintText: 'กรอกรายละเอียดหรือข้อมูลเพิ่มเติม (ถ้ามี)',
                  hintStyle: TextStyle(fontSize: 14),
                  prefixIcon: Icon(Icons.description, size: 22),
                ),
              ),
            ] else ...[
              // Step 2: Per-item details (Amount, Unit, Cost)
              if (selectedType == 'CT02' && selectedVaccineIds.isNotEmpty) ...[
                Text(
                  'กรอกรายละเอียดปริมาณและราคาของแต่ละวัคซีน:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primaryDark),
                ),
                const SizedBox(height: 10),
                ...selectedVaccineIds.map((vId) {
                  final isOther = vId == 'other';
                  final vName = isOther ? 'วัคซีนอื่นๆ' : masterData.vaccines.firstWhere((v) => v.id == vId, orElse: () => masterData.vaccines.first).name;
                  final customNameCtrl = _getCustomItemNameController(vId);
                  final amtCtrl = _getItemAmountController(vId);
                  final costCtrl = _getItemCostController(vId);
                  final unitVal = _itemUnitIds[vId];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfAlt(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isOther ? Colors.orange[800]! : AppColors.brd(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.vaccines, size: 18, color: isOther ? Colors.orange[800] : AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                vName,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isOther ? Colors.orange[800] : AppColors.text(context)),
                              ),
                            ),
                          ],
                        ),
                        if (isOther) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: customNameCtrl,
                            style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                            decoration: const InputDecoration(
                              labelText: 'ระบุชื่อวัคซีน',
                              labelStyle: TextStyle(fontSize: 13),
                              hintText: 'พิมพ์ชื่อวัคซีน...',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: amtCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                                decoration: const InputDecoration(
                                  labelText: 'จำนวนที่ใช้',
                                  labelStyle: TextStyle(fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<int?>(
                                value: unitVal,
                                isExpanded: true,
                                style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                                decoration: const InputDecoration(
                                  labelText: 'หน่วยวัด',
                                  labelStyle: TextStyle(fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('เลือกหน่วย', style: TextStyle(fontSize: 13, color: AppColors.subText(context))),
                                  ),
                                  ...masterData.units.map((unit) {
                                    final idInt = int.tryParse(unit.id);
                                    final abbr = unit.abbreviation != null && unit.abbreviation!.isNotEmpty
                                        ? ' (${unit.abbreviation})'
                                        : '';
                                    return DropdownMenuItem<int?>(
                                      value: idInt,
                                      child: Text(
                                        '${unit.name}$abbr',
                                        style: TextStyle(fontSize: 13, color: AppColors.text(context)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) => setState(() => _itemUnitIds[vId] = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                          decoration: const InputDecoration(
                            labelText: 'ราคา/ค่าใช้จ่าย (บาท)',
                            labelStyle: TextStyle(fontSize: 13),
                            prefixIcon: Icon(Icons.payments, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else if (selectedType == 'CT03' && selectedMedicineIds.isNotEmpty) ...[
                Text(
                  'กรอกรายละเอียดปริมาณและราคาของแต่ละยาที่ใช้:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primaryDark),
                ),
                const SizedBox(height: 10),
                ...selectedMedicineIds.map((mId) {
                  final isOther = mId == 'other';
                  final mName = isOther ? 'ยาอื่นๆ' : masterData.medicines.firstWhere((m) => m.id == mId, orElse: () => masterData.medicines.first).name;
                  final customNameCtrl = _getCustomItemNameController(mId);
                  final amtCtrl = _getItemAmountController(mId);
                  final costCtrl = _getItemCostController(mId);
                  final unitVal = _itemUnitIds[mId];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfAlt(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isOther ? Colors.orange[800]! : AppColors.brd(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.medication, size: 18, color: isOther ? Colors.orange[800] : AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                mName,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isOther ? Colors.orange[800] : AppColors.text(context)),
                              ),
                            ),
                          ],
                        ),
                        if (isOther) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: customNameCtrl,
                            style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                            decoration: const InputDecoration(
                              labelText: 'ระบุชื่อยา',
                              labelStyle: TextStyle(fontSize: 13),
                              hintText: 'พิมพ์ชื่อยา...',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: amtCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                                decoration: const InputDecoration(
                                  labelText: 'จำนวนที่ใช้',
                                  labelStyle: TextStyle(fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<int?>(
                                value: unitVal,
                                isExpanded: true,
                                style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                                decoration: const InputDecoration(
                                  labelText: 'หน่วยวัด',
                                  labelStyle: TextStyle(fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('เลือกหน่วย', style: TextStyle(fontSize: 13, color: AppColors.subText(context))),
                                  ),
                                  ...masterData.units.map((unit) {
                                    final idInt = int.tryParse(unit.id);
                                    final abbr = unit.abbreviation != null && unit.abbreviation!.isNotEmpty
                                        ? ' (${unit.abbreviation})'
                                        : '';
                                    return DropdownMenuItem<int?>(
                                      value: idInt,
                                      child: Text(
                                        '${unit.name}$abbr',
                                        style: TextStyle(fontSize: 13, color: AppColors.text(context)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) => setState(() => _itemUnitIds[mId] = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                          decoration: const InputDecoration(
                            labelText: 'ราคา/ค่าใช้จ่าย (บาท)',
                            labelStyle: TextStyle(fontSize: 13),
                            prefixIcon: Icon(Icons.payments, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                // For CT01 (General Checkup) without multi items
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 15, color: AppColors.text(context)),
                  decoration: const InputDecoration(
                    labelText: 'ค่าใช้จ่ายรวม (บาท)',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.payments, size: 22),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (selectedType == 'CT01') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'รูปภาพแผล/อาการป่วย (สูงสุด 3 รูป):',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                    ),
                    Text(
                      '${existingImageUrls.length + selectedImageFiles.length}/3',
                      style: TextStyle(fontSize: 13, color: AppColors.subText(context)),
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
                              border: Border.all(color: AppColors.primary, width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: kIsWeb
                                  ? Image.network(
                                      xfile.path,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                                    )
                                  : Image.file(
                                      File(xfile.path),
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
                          final uploadService = ref.read(imageUploadServiceProvider);
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (ctx) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.photo_library, color: AppColors.primary),
                                    title: const Text('เลือกจากคลังภาพ'),
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      final picked = await uploadService.pickImageFromGallery();
                                      if (picked != null) {
                                        setState(() {
                                          selectedImageFiles.add(picked);
                                        });
                                      }
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                                    title: const Text('ถ่ายภาพด้วยกล้อง'),
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      final picked = await uploadService.pickImageFromCamera();
                                      if (picked != null) {
                                        setState(() {
                                          selectedImageFiles.add(picked);
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
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
            ],
          ],
        ),
      ),
    ),
    Divider(height: 1, color: AppColors.div(context)),
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                if (currentStep == 2) {
                  setState(() => currentStep = 1);
                } else {
                  Navigator.pop(context);
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: Text(currentStep == 2 ? 'ย้อนกลับ' : 'ยกเลิก'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
                onPressed: (masterData.isLoading || isUploading)
                    ? null
                    : () async {
                        if (currentStep == 1) {
                          setState(() => currentStep = 2);
                          return;
                        }

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
                            if (mounted) {
                              AppFeedback.showError(context, 'อัปโหลดรูปไม่สำเร็จ: $e');
                            }
                          }
                        }

                        final adminName = adminController.text.trim().isEmpty ? null : adminController.text.trim();
                        final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();

                        List<HealthRecordItem> itemsList = [];
                        double totalCost = 0.0;

                        if (selectedType == 'CT02' && selectedVaccineIds.isNotEmpty) {
                          for (var vId in selectedVaccineIds) {
                            String vName;
                            if (vId == 'other') {
                              final customName = _getCustomItemNameController(vId).text.trim();
                              vName = customName.isNotEmpty ? customName : 'วัคซีนอื่นๆ';
                            } else {
                              vName = masterData.vaccines.firstWhere((item) => item.id == vId, orElse: () => masterData.vaccines.first).name;
                            }

                            final c = double.tryParse(_itemCostControllers[vId]?.text ?? '');
                            final a = double.tryParse(_itemAmountControllers[vId]?.text ?? '');
                            final uId = _itemUnitIds[vId];

                            if (c != null && c > 0) totalCost += c;

                            itemsList.add(HealthRecordItem(
                              itemId: vId,
                              itemName: vName,
                              itemType: 'vaccine',
                              amount: a,
                              unitId: uId,
                              cost: c,
                            ));
                          }
                        } else if (selectedType == 'CT03' && selectedMedicineIds.isNotEmpty) {
                          for (var mId in selectedMedicineIds) {
                            String mName;
                            if (mId == 'other') {
                              final customName = _getCustomItemNameController(mId).text.trim();
                              mName = customName.isNotEmpty ? customName : 'ยาอื่นๆ';
                            } else {
                              mName = masterData.medicines.firstWhere((item) => item.id == mId, orElse: () => masterData.medicines.first).name;
                            }

                            final c = double.tryParse(_itemCostControllers[mId]?.text ?? '');
                            final a = double.tryParse(_itemAmountControllers[mId]?.text ?? '');
                            final uId = _itemUnitIds[mId];

                            if (c != null && c > 0) totalCost += c;

                            itemsList.add(HealthRecordItem(
                              itemId: mId,
                              itemName: mName,
                              itemType: 'medicine',
                              amount: a,
                              unitId: uId,
                              cost: c,
                            ));
                          }
                        } else {
                          totalCost = double.tryParse(costController.text) ?? 0.0;
                        }

                        String? primaryDiseaseId;
                        if (selectedDiseaseIds.isNotEmpty) {
                          final validList = selectedDiseaseIds.where((id) => id != 'other').toList();
                          if (validList.isNotEmpty) primaryDiseaseId = validList.first;
                        }

                        if ((selectedType == 'CT01' || selectedType == 'CT03') && selectedDiseaseIds.isNotEmpty) {
                          for (var dId in selectedDiseaseIds) {
                            String dName;
                            if (dId == 'other') {
                              final customName = _getCustomItemNameController('other_disease').text.trim();
                              dName = customName.isNotEmpty ? customName : 'โรคอื่นๆ';
                            } else {
                              final matches = masterData.diseases.where((item) => item.id == dId);
                              dName = matches.isNotEmpty ? matches.first.name : dId;
                            }

                            itemsList.add(HealthRecordItem(
                              itemId: dId,
                              itemName: dName,
                              itemType: 'disease',
                            ));
                          }
                        }

                        final record = HealthRecord(
                          id: widget.initialRecord?.id ?? 'HR${DateTime.now().millisecondsSinceEpoch % 1000000}',
                          cowId: widget.cow.id,
                          recordDate: selectedDate,
                          checkupTypeId: selectedType,
                          status: selectedHealthStatus.name,
                          diseaseId: primaryDiseaseId,
                          vacId: selectedVaccineIds.isNotEmpty ? selectedVaccineIds.first : null,
                          medId: selectedMedicineIds.isNotEmpty ? selectedMedicineIds.first : null,
                          vacIds: selectedVaccineIds,
                          medIds: selectedMedicineIds,
                          items: itemsList,
                          images: imageUrls,
                          cost: totalCost > 0 ? totalCost : null,
                          amount: itemsList.isNotEmpty ? itemsList.first.amount : double.tryParse(amountController.text),
                          unitId: itemsList.isNotEmpty ? itemsList.first.unitId : selectedUnitId,
                          adminName: adminName,
                          note: note,
                        );

                        await widget.onSave(record);

                        ref
                            .read(cowProvider.notifier)
                            .updateCowStatus(widget.cow.id, selectedHealthStatus);
                        if (mounted) Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    : Text(currentStep == 1 ? 'ถัดไป' : 'บันทึก'),
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
