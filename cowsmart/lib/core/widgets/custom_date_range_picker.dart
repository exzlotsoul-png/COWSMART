import 'package:flutter/material.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';

class CustomDateRangePicker {
  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTimeRange? initialRange,
  }) async {
    final now = DateTime.now();
    DateTime tempStart = initialRange?.start ?? DateTime(now.year, now.month, 1);
    DateTime tempEnd = initialRange?.end ?? now;

    return await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final daysCount = tempEnd.difference(tempStart).inDays + 1;

            void applyPreset(DateTime start, DateTime end) {
              setModalState(() {
                tempStart = start;
                tempEnd = end;
              });
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'เลือกช่วงเวลา',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text(context),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: Icon(Icons.close_rounded, color: AppColors.subText(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Presets Label
                    Text(
                      'ตัวเลือกด่วน',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.subText(context),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Preset Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip(
                          context,
                          label: '7 วันล่าสุด',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(today.subtract(const Duration(days: 6)), today);
                          },
                        ),
                        _buildPresetChip(
                          context,
                          label: '30 วันล่าสุด',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(today.subtract(const Duration(days: 29)), today);
                          },
                        ),
                        _buildPresetChip(
                          context,
                          label: 'เดือนนี้',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(DateTime(today.year, today.month, 1), today);
                          },
                        ),
                        _buildPresetChip(
                          context,
                          label: 'เดือนที่แล้ว',
                          onTap: () {
                            final today = DateTime.now();
                            final firstOfLastMonth = DateTime(today.year, today.month - 1, 1);
                            final lastOfLastMonth = DateTime(today.year, today.month, 0);
                            applyPreset(firstOfLastMonth, lastOfLastMonth);
                          },
                        ),
                        _buildPresetChip(
                          context,
                          label: 'ปีนี้ (พ.ศ. ${now.year + 543})',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(DateTime(today.year, 1, 1), today);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Custom Date Pickers Label
                    Text(
                      'ระบุช่วงวันที่เอง',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.subText(context),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        // Start Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                helpText: 'เลือกวันที่เริ่มต้น',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempStart = picked;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempEnd = tempStart;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfAlt(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ตั้งแต่วันที่',
                                    style: TextStyle(fontSize: 11, color: AppColors.hint(context), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          AppDateUtils.formatThaiDate(tempStart),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward_rounded, color: AppColors.hint(context), size: 18),
                        ),
                        // End Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd,
                                firstDate: tempStart,
                                lastDate: DateTime(2100),
                                helpText: 'เลือกวันที่สิ้นสุด',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempEnd = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfAlt(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.brd(context).withValues(alpha: 0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ถึงวันที่',
                                    style: TextStyle(fontSize: 11, color: AppColors.hint(context), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          AppDateUtils.formatThaiDate(tempEnd),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Days Count Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.text(context)),
                          const SizedBox(width: 6),
                          Text(
                            'รวมระยะเวลาเลือกทั้งหมด $daysCount วัน',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Apply Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalContext, DateTimeRange(start: tempStart, end: tempEnd));
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('ตกลง', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildPresetChip(BuildContext context, {required String label, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text(context))),
      backgroundColor: AppColors.surfAlt(context),
      side: BorderSide(color: AppColors.brd(context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
    );
  }
}
