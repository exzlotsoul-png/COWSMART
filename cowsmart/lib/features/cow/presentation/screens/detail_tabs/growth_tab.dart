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

// Custom Painter for Visual Growth Trend Chart
class _GrowthChartPainter extends CustomPainter {
  final List<GrowthRecord> records; // Chronological (oldest to newest)
  final bool isDark;
  _GrowthChartPainter({required this.records, this.isDark = false});

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
      ..color = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final labelStyle = TextStyle(
      fontSize: 11,
      color: isDark ? AppColors.darkTextSecondary : Colors.grey[600],
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

    final primaryThemeColor = isDark ? AppColors.primaryLight : AppColors.primary;

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
        primaryThemeColor.withValues(alpha: 0.25),
        primaryThemeColor.withValues(alpha: 0.02),
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
      ..color = primaryThemeColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Draw data points & X-axis date labels
    final dotOuterPaint = Paint()..color = primaryThemeColor;
    final dotInnerPaint = Paint()..color = isDark ? AppColors.darkSurface : Colors.white;

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
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) =>
      oldDelegate.records != records || oldDelegate.isDark != isDark;
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.text(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          onChanged: (val) {
                            final girthVal = double.tryParse(val);
                            if (girthVal != null && girthVal > 50) {
                              // Standard chest girth estimation formula: Weight (kg) = (Girth cm ^ 2.8) / 10000 approx or standard equation:
                              // Formula: W = (Girth * Girth * 1.5) / 100 or standard cattle estimation: (girth / 100)^3 * 80
                              final estWeight = (girthVal * girthVal * girthVal) / 28000;
                              setSheetState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (girthCtrl.text.isNotEmpty && double.tryParse(girthCtrl.text) != null && (double.tryParse(girthCtrl.text)! > 50)) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        final g = double.parse(girthCtrl.text);
                        final estWeight = (g * g * g) / 27000;
                        setSheetState(() {
                          weightCtrl.text = estWeight.toStringAsFixed(1);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber[700]!, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 22, color: Colors.amber[900]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ประมาณการน้ำหนัก: ${((double.parse(girthCtrl.text) * double.parse(girthCtrl.text) * double.parse(girthCtrl.text)) / 27000).toStringAsFixed(1)} กก.',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'กดเพื่อใช้',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '*คำนวณตามสูตรมาตรฐานปศุสัตว์: (รอบอก ซม.)³ ÷ 27,000',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.amber[900]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                        AppFeedback.showError(context, 'กรุณากรอกน้ำหนักให้ถูกต้อง');
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
                              final range = await CustomDateRangePicker.show(
                                ctx,
                                initialRange: selectedRange ??
                                    DateTimeRange(
                                      start: DateTime.now().subtract(
                                        const Duration(days: 90),
                                      ),
                                      end: DateTime.now(),
                                    ),
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
                                  color: AppColors.textSecondary,
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
        AppFeedback.showSuccess(context, 'บันทึกน้ำหนักเรียบร้อยแล้ว!');
        ref.read(cowDetailProvider.notifier).clearFlags();
      } else if (next.error != null && prev?.error != next.error) {
        AppFeedback.showError(context, next.error!);
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
    final double? latestGirth = records.isNotEmpty ? records.first.girth : null;
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
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (latestGirth != null && latestGirth > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.straighten, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'รอบอก: ${latestGirth.toStringAsFixed(1)} ซม.',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      'ชั่งล่าสุดเมื่อ: ${AppDateUtils.formatThaiDate(records.first.recordDate)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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

            /*
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
            */

            // 3. Visual Growth Line Chart Widget (if >= 2 records)
            if (chronologicalRecords.length >= 2) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 190,
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.brd(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: AppColors.isDark(context) ? 0.2 : 0.03),
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
                        Icon(Icons.show_chart, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'กราฟแนวโน้มน้ำหนัก',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.text(context),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${chronologicalRecords.length} จุดชั่ง',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _GrowthChartPainter(
                          records: chronologicalRecords,
                          isDark: AppColors.isDark(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 22,
                  color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ประวัติการชั่งน้ำหนัก',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                      extra: {'cow': widget.cow, 'initialTab': 'growth'},
                    );
                  },
                  icon: Icon(Icons.arrow_forward, size: 16, color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary),
                  label: Text(
                    'ดูทั้งหมด (${records.length})',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary,
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
                            Text(
                              'น้ำหนักเริ่มต้น',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.text(context),
                              ),
                            ),
                            Text(
                              'ที่กรอกไว้ตอนเพิ่มวัว',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.subText(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${widget.cow.latestWeight.toStringAsFixed(1)} กก.',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary,
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
                            color: (AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.monitor_weight_outlined,
                            color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppDateUtils.formatThaiDate(r.recordDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.text(context),
                                ),
                              ),
                              if (r.girth != null)
                                Text(
                                  'รอบอก: ${r.girth!.toStringAsFixed(1)} ซม.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.subText(context),
                                  ),
                                ),
                              if (periodAdg != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'ADG ช่วงนี้: ${periodAdg >= 0 ? '+' : ''}${periodAdg.toStringAsFixed(2)} กก./วัน ($periodDays วัน)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: periodAdg >= 0
                                        ? (AppColors.isDark(context) ? const Color(0xFF8FD475) : AppColors.primary)
                                        : AppColors.error,
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
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary,
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
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: diff >= 0
                                        ? (AppColors.isDark(context) ? const Color(0xFF8FD475) : AppColors.success)
                                        : AppColors.error,
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
                    onPressed: () {
                      context.push(
                        '/cow_history_list',
                        extra: {'cow': widget.cow, 'initialTab': 'growth'},
                      );
                    },
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
            heroTag: 'add_weight_fab',
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
