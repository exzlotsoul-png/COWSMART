import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/core/widgets/cow_icon.dart';
import 'package:cowsmart/features/calendar/domain/calendar_event.dart';
import 'package:cowsmart/features/calendar/providers/calendar_provider.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';

class CalendarHistoryScreen extends ConsumerStatefulWidget {
  const CalendarHistoryScreen({super.key});

  @override
  ConsumerState<CalendarHistoryScreen> createState() => _CalendarHistoryScreenState();
}

class _CalendarHistoryScreenState extends ConsumerState<CalendarHistoryScreen> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calState = ref.watch(calendarProvider);
    final pastEvents = calState.filteredPastEvents;

    // Filter by search query if any
    final displayEvents = pastEvents.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final titleMatch = e.title.toLowerCase().contains(q);
      final descMatch = e.description?.toLowerCase().contains(q) ?? false;
      final cowMatch = e.cowId?.toLowerCase().contains(q) ?? false;
      return titleMatch || descMatch || cowMatch;
    }).toList();

    // Sort descending (most recent past event first)
    displayEvents.sort((a, b) => b.eventDatetime.compareTo(a.eventDatetime));

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('ประวัติกิจกรรมย้อนหลัง'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final farmId = ref.read(farmProvider).currentFarm?.id;
              if (farmId != null) {
                ref.read(calendarProvider.notifier).fetchEvents(farmId);
              }
            },
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          _buildSearchAndFilters(calState),
          const Divider(height: 1),

          // Count summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surfAlt(context),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: AppColors.subText(context)),
                const SizedBox(width: 8),
                Text(
                  'กิจกรรมที่ผ่านมาทั้งหมด: ${displayEvents.length} รายการ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subText(context),
                  ),
                ),
              ],
            ),
          ),

          // Event list
          Expanded(
            child: calState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayEvents.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: displayEvents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final event = displayEvents[index];
                          return _HistoryEventCard(
                            event: event,
                            onTap: () => _showEventDetailSheet(context, event),
                            onDelete: () => _confirmDelete(context, event),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(CalendarState calState) {
    final categories = [
      {'key': 'all', 'label': 'ทั้งหมด', 'icon': Icons.apps_rounded, 'color': AppColors.primary},
      {'key': 'general', 'label': 'กิจกรรมทั่วไป', 'icon': Icons.event_note_rounded, 'color': const Color(0xFF0284C7)},
      {'key': 'health', 'label': 'นัดหมายสุขภาพ', 'icon': Icons.medical_services_rounded, 'color': const Color(0xFFDC2626)},
      {'key': 'breeding', 'label': 'กำหนดคลอด', 'icon': Icons.favorite_rounded, 'color': const Color(0xFF9333EA)},
    ];

    return Container(
      color: AppColors.cardBg(context),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          // Search input field
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาประวัติกิจกรรม, วัว...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: AppColors.surfAlt(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
            },
          ),
          const SizedBox(height: 10),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = calState.selectedCategory == cat['key'];
                final color = cat['color'] as Color;

                final int count = cat['key'] == 'all'
                    ? calState.pastEvents.length
                    : calState.pastEvents.where((e) => e.eventType == cat['key']).length;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        ref.read(calendarProvider.notifier).setCategory(cat['key'] as String);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                        decoration: BoxDecoration(
                          color: isSelected ? color : AppColors.surfAlt(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? color : AppColors.brd(context).withValues(alpha: 0.8),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              size: 16,
                              color: isSelected ? Colors.white : color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.text(context),
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : color,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfAlt(context),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_toggle_off_rounded, size: 64, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          Text(
            'ไม่มีประวัติกิจกรรมย้อนหลัง',
            style: TextStyle(
              color: AppColors.text(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'เมื่อกิจกรรมผ่านพ้นวันไปแล้ว ระบบจะรวบรวมมาไว้ที่นี่',
            style: TextStyle(color: AppColors.subText(context), fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showEventDetailSheet(BuildContext context, CalendarEvent event) {
    Color typeColor = const Color(0xFF0284C7);
    IconData typeIcon = Icons.event_note;
    String typeLabel = 'กิจกรรมทั่วไป';

    if (event.eventType == 'health') {
      typeColor = const Color(0xFFDC2626);
      typeIcon = Icons.medical_services_outlined;
      typeLabel = 'นัดหมายสุขภาพ';
    } else if (event.eventType == 'breeding') {
      typeColor = Colors.purple;
      typeIcon = Icons.favorite_outline;
      typeLabel = 'กำหนดคลอด';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.brd(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(typeIcon, color: typeColor, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      typeLabel,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: typeColor),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'ผ่านไปแล้ว',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                event.title,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Date & Time
                    _buildDetailRow(
                      Icons.calendar_today_rounded,
                      'วันที่ดำเนินการ',
                      AppDateUtils.formatThaiDate(event.eventDatetime),
                      typeColor,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.access_time_rounded,
                      'เวลา',
                      DateFormat('HH:mm น.').format(event.eventDatetime),
                      typeColor,
                    ),

                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.notes_rounded,
                        'รายละเอียด',
                        event.description!,
                        typeColor,
                      ),
                    ],

                    if (event.cowId != null && event.cowId!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Consumer(builder: (context, ref, _) {
                        final allCows = ref.watch(cowProvider).allCows;
                        final matches = allCows.where((c) => c.id == event.cowId || c.tagNumber == event.cowId || c.name == event.cowId).toList();
                        final cowText = matches.isNotEmpty
                            ? (matches.first.name.isNotEmpty && matches.first.tagNumber.isNotEmpty && matches.first.name != matches.first.tagNumber
                                ? '${matches.first.name} (${matches.first.tagNumber})'
                                : (matches.first.name.isNotEmpty ? matches.first.name : matches.first.tagNumber))
                            : event.cowId!;
                        return _buildDetailRow(Icons.pets_rounded, 'วัวที่เกี่ยวข้อง', cowText, typeColor);
                      }),
                    ],

                    if (event.isGrouped && event.cowCount != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.groups_rounded,
                        'จำนวนวัวในกลุ่ม',
                        '${event.cowCount} ตัว',
                        typeColor,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Delete button
                    if (event.eventType == 'general' || event.eventType == 'health')
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDelete(context, event);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('ลบรายการนี้ออกจากประวัติ', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(dynamic icon, String label, String value, Color accentColor) {
    final Widget iconWidget = icon is Widget
        ? icon
        : (icon == Icons.pets || icon == Icons.pets_rounded || icon == Icons.pets_outlined)
            ? CowIcon(size: 20, color: accentColor)
            : Icon(icon as IconData, size: 20, color: accentColor);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfAlt(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AppColors.hint(context))),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, CalendarEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบประวัติกิจกรรม'),
        content: Text('คุณต้องการลบ "${event.title}" ออกจากประวัติใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(calendarProvider.notifier).deleteEvent(event.id);
              if (mounted) {
                if (ok) {
                  AppFeedback.showSuccess(context, 'ลบกิจกรรมสำเร็จ');
                } else {
                  AppFeedback.showError(context, 'เกิดข้อผิดพลาดในการลบ');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('ลบ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _HistoryEventCard extends ConsumerWidget {
  final CalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryEventCard({
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color typeColor = const Color(0xFF0284C7);
    IconData typeIcon = Icons.calendar_month_outlined;
    String typeLabel = 'กิจกรรมปฏิทิน';

    if (event.eventType == 'health') {
      typeColor = const Color(0xFFDC2626);
      typeIcon = Icons.medical_services_outlined;
      typeLabel = 'นัดหมายสุขภาพ';
    } else if (event.eventType == 'breeding') {
      typeColor = Colors.purple;
      typeIcon = Icons.favorite_outline;
      typeLabel = 'กำหนดคลอด';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.brd(context).withValues(alpha: 0.8)),
      ),
      color: AppColors.cardBg(context),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: typeColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(typeIcon, color: typeColor, size: 20),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd/MM').format(event.eventDatetime),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                event.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.text(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event_available_outlined, size: 13, color: AppColors.text(context)),
                const SizedBox(width: 4),
                Text(
                  AppDateUtils.formatThaiDate(event.eventDatetime),
                  style: TextStyle(fontSize: 12, color: AppColors.text(context)),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('HH:mm น.').format(event.eventDatetime),
                  style: TextStyle(fontSize: 12, color: AppColors.text(context)),
                ),
              ],
            ),
            if (event.cowId != null && event.cowId!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Builder(builder: (context) {
                final allCows = ref.watch(cowProvider).allCows;
                final matches = allCows.where((c) => c.id == event.cowId || c.tagNumber == event.cowId || c.name == event.cowId).toList();
                final cowText = matches.isNotEmpty
                    ? (matches.first.name.isNotEmpty && matches.first.tagNumber.isNotEmpty && matches.first.name != matches.first.tagNumber
                        ? '${matches.first.name} (${matches.first.tagNumber})'
                        : (matches.first.name.isNotEmpty ? matches.first.name : matches.first.tagNumber))
                    : event.cowId;
                return Text(
                  'วัว: $cowText',
                  style: TextStyle(fontSize: 12, color: AppColors.text(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              }),
            ],
          ],
        ),
        trailing: (event.eventType == 'general' || event.eventType == 'health')
            ? IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textHint),
                onPressed: onDelete,
                tooltip: 'ลบออกจากประวัติ',
              )
            : null,
      ),
    );
  }
}
