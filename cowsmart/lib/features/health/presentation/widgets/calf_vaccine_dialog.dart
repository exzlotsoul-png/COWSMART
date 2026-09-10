import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/features/calendar/providers/calendar_provider.dart';
import 'package:cowsmart/features/cow/domain/cow.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import '../../services/calf_vaccine_schedule_service.dart';

class CalfVaccineDialog extends ConsumerStatefulWidget {
  final Cow cow;
  final List<dynamic>? existingAppointments;

  const CalfVaccineDialog({
    super.key,
    required this.cow,
    this.existingAppointments,
  });

  static Future<bool?> show(
    BuildContext context,
    Cow cow, {
    List<dynamic>? existingAppointments,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CalfVaccineDialog(
        cow: cow,
        existingAppointments: existingAppointments,
      ),
    );
  }

  @override
  ConsumerState<CalfVaccineDialog> createState() => _CalfVaccineDialogState();
}

class _CalfVaccineDialogState extends ConsumerState<CalfVaccineDialog> {
  late List<CalfVaccineScheduleItem> _scheduleItems;
  String _selectedReminder = 'ก่อน 3 วัน';
  bool _isSaving = false;

  final List<String> _reminderOptions = [
    'ในวันนัดหมาย',
    'ก่อน 1 วัน',
    'ก่อน 3 วัน',
    'ก่อน 7 วัน',
  ];

  @override
  void initState() {
    super.initState();
    final allSchedule = CalfVaccineScheduleService.generateSchedule(
      birthDate: widget.cow.birthDate,
      gender: widget.cow.gender,
    );

    if (widget.existingAppointments != null && widget.existingAppointments!.isNotEmpty) {
      _scheduleItems = CalfVaccineScheduleService.filterRemainingSchedule(
        allItems: allSchedule,
        existingAppointments: widget.existingAppointments!,
      );
    } else {
      _scheduleItems = allSchedule;
    }
  }

  int get _selectedCount => _scheduleItems.where((i) => i.isSelected).length;

  Future<void> _pickDateForItem(int index) async {
    final item = _scheduleItems[index];
    final picked = await showDatePicker(
      context: context,
      initialDate: item.scheduledDate,
      firstDate: widget.cow.birthDate,
      lastDate: widget.cow.birthDate.add(const Duration(days: 365 * 3)),
      helpText: 'เลือกวันนัดหมาย ${item.vaccineName}',
      confirmText: 'ตกลง',
      cancelText: 'ยกเลิก',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.cardBg(context),
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _scheduleItems[index].scheduledDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          9,
          0,
        );
      });
    }
  }

  Future<void> _saveAppointments() async {
    if (_selectedCount == 0) {
      AppFeedback.showWarning(context, 'กรุณาเลือกวัคซีนอย่างน้อย 1 รายการ');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      final savedCount = await CalfVaccineScheduleService.saveAppointments(
        api: api,
        cowId: widget.cow.id,
        items: _scheduleItems,
        reminderSetting: _selectedReminder,
      );

      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        ref.read(calendarProvider.notifier).fetchEvents(currentFarm.id);
      }

      if (mounted) {
        AppFeedback.showSuccess(
          context,
          'บันทึกตารางนัดหมายวัคซีนสำเร็จ $savedCount รายการ',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการบันทึกตารางวัคซีน: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.cardBg(context);
    final displayName = widget.cow.name.isNotEmpty
        ? widget.cow.name
        : (widget.cow.tagNumber.isNotEmpty ? widget.cow.tagNumber : widget.cow.id);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.vaccines_rounded,
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
                          'โปรแกรมวัคซีนแนะนำสำหรับลูกวัว',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ลูกวัว: $displayName • เกิดเมื่อ: ${AppDateUtils.formatThaiDate(widget.cow.birthDate)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Sub-info banner ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_outlined, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'คำนวณวันฉีดตามเกณฑ์กรมปศุสัตว์จากวันเกิด คุณสามารถติ๊กเลือก หรือแตะที่วันที่เพื่อปรับเปลี่ยนวันนัดหมายตามต้องการได้',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Vaccine List ──
            Flexible(
              child: _scheduleItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 54, color: AppColors.primary),
                          const SizedBox(height: 12),
                          const Text(
                            'ได้ทำการตั้งนัดหมายครบทุกเข็มแล้ว',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ลูกวัวตัวนี้มีนัดหมายวัคซีนตามโปรแกรมครบถ้วนแล้ว คุณสามารถดูหรือจัดการวันนัดได้จากตารางนัดหมายด้านล่าง',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shrinkWrap: true,
                      itemCount: _scheduleItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _scheduleItems[index];
                        return _buildVaccineItemCard(item, index, isDark);
                      },
                    ),
            ),

            if (_scheduleItems.isNotEmpty) ...[
              const Divider(height: 1),

              // ── Reminder Setting ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'แจ้งเตือนล่วงหน้า:',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedReminder,
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            dropdownColor: cardBg,
                            items: _reminderOptions.map((opt) {
                              return DropdownMenuItem(value: opt, child: Text(opt));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedReminder = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Action Buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _scheduleItems.isEmpty
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('ปิดหน้าต่าง', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.divider,
                              ),
                            ),
                            child: Text(
                              'ข้ามไปก่อน',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveAppointments,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline, size: 18),
                            label: Text(
                              _isSaving ? 'กำลังบันทึก...' : 'บันทึกนัดหมาย ($_selectedCount)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
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
  }

  Widget _buildVaccineItemCard(
    CalfVaccineScheduleItem item,
    int index,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: item.isSelected
            ? (isDark ? AppColors.darkSurfaceAlt : Colors.white)
            : (isDark ? AppColors.darkSurface : const Color(0xFFF7F5F0)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isSelected
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.border),
          width: item.isSelected ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            Checkbox(
              value: item.isSelected,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              onChanged: (val) {
                setState(() {
                  _scheduleItems[index].isSelected = val ?? false;
                });
              },
            ),

            // Vaccine Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.recommendedAgeLabel,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (item.targetGender == 'female')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.pink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'เฉพาะเพศเมีย',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.pink,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.vaccineName,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: item.isSelected
                          ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                          : (isDark ? AppColors.darkTextHint : AppColors.textHint),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.doseLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Date picker button chip
            InkWell(
              onTap: item.isSelected ? () => _pickDateForItem(index) : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: item.isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: item.isSelected
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : (isDark ? AppColors.darkBorder : AppColors.divider),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 14,
                      color: item.isSelected ? AppColors.primary : AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppDateUtils.formatThaiDate(item.scheduledDate),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: item.isSelected
                            ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                            : (isDark ? AppColors.darkTextHint : AppColors.textHint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
