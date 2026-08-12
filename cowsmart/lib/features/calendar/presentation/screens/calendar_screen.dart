import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import 'package:cowsmart/features/farm/providers/farm_provider.dart';
import 'package:cowsmart/features/cow/providers/cow_provider.dart';
import '../../domain/calendar_event.dart';
import '../../providers/calendar_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final farmId = ref.read(farmProvider).currentFarm?.id;
      if (farmId != null) {
        ref.read(calendarProvider.notifier).fetchEvents(farmId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final calState = ref.watch(calendarProvider);
    final selectedEvents = calState.eventsForDay(_selectedDay);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ปฏิทินกิจกรรม'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มกิจกรรม', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildFilterChips(calState),
          _buildCalendar(calState),
          const Divider(height: 1),
          Expanded(
            child: calState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildEventList(selectedEvents),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(CalendarState calState) {
    final categories = [
      {'key': 'all', 'label': 'ทั้งหมด', 'icon': Icons.apps, 'color': AppColors.primary},
      {'key': 'general', 'label': 'กิจกรรมทั่วไป', 'icon': Icons.event_note, 'color': AppColors.primary},
      {'key': 'health', 'label': 'นัดหมายสุขภาพ', 'icon': Icons.medical_services_outlined, 'color': Colors.orange[800]},
      {'key': 'breeding', 'label': 'กำหนดคลอด', 'icon': Icons.favorite_outline, 'color': Colors.purple},
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = calState.selectedCategory == cat['key'];
                  final color = cat['color'] as Color?;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      avatar: Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : color,
                      ),
                      label: Text(
                        cat['label'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: color ?? AppColors.primary,
                      backgroundColor: (color ?? AppColors.primary).withValues(alpha: 0.1),
                      side: BorderSide(
                        color: isSelected ? (color ?? AppColors.primary) : (color ?? AppColors.primary).withValues(alpha: 0.3),
                      ),
                      onSelected: (_) {
                        ref.read(calendarProvider.notifier).setCategory(cat['key'] as String);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(CalendarState calState) {
    return Container(
      color: AppColors.surface,
      child: TableCalendar<CalendarEvent>(
        firstDay: DateTime(2020),
        lastDay: DateTime(2030),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        eventLoader: calState.eventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        locale: 'th_TH',
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        onPageChanged: (focused) {
          setState(() {
            _focusedDay = focused;
            _selectedDay = focused;
          });
        },
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          weekendTextStyle: const TextStyle(color: AppColors.error, fontSize: 15),
          defaultTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonShowsNext: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          formatButtonDecoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.primary),
            ),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          formatButtonTextStyle: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        calendarBuilders: CalendarBuilders(
          headerTitleBuilder: (context, day) {
            return Center(
              child: Text(
                AppDateUtils.formatThaiMonthYear(day),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          },
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox();
            return Positioned(
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: events.take(3).map((e) {
                  Color dotColor = AppColors.primary;
                  if (e.eventType == 'health') dotColor = Colors.orange[800]!;
                  if (e.eventType == 'breeding') dotColor = Colors.purple;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventList(List<CalendarEvent> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text(
              'ไม่มีกิจกรรมในหมวดนี้สำหรับวันนี้',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              AppDateUtils.formatThaiDate(_selectedDay, useFullMonth: true),
              style: const TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final event = events[index];
        return _EventCard(
          event: event,
          onTap: () => _showEventDetailSheet(context, event),
          onEdit: () => _showEditEventDialog(context, event),
          onDelete: () => _confirmDelete(context, event),
        );
      },
    );
  }

  void _showAddEventDialog(BuildContext context) {
    _showEventDialog(context, null);
  }

  void _showEditEventDialog(BuildContext context, CalendarEvent event) {
    if (event.eventType == 'breeding') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กำหนดวันคลอดคำนวณจากการผสมพันธุ์แม่วัว หากต้องการแก้ไขให้จัดการที่ประวัติแม่วัวตัวนั้นๆ', style: TextStyle(fontSize: 14)),
        ),
      );
      return;
    }
    _showEventDialog(context, event);
  }

  void _showEventDialog(BuildContext context, CalendarEvent? existing) {
    final farmId = ref.read(farmProvider).currentFarm?.id ?? '';
    final cows = ref.read(cowProvider).allCows;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime selectedDate = existing?.eventDatetime ?? _selectedDay;
    TimeOfDay selectedTime = existing != null
        ? TimeOfDay.fromDateTime(existing.eventDatetime)
        : const TimeOfDay(hour: 8, minute: 0);
    String? selectedCowId = existing?.cowId;
    String? selectedReminder = existing?.reminderSetting ?? 'ก่อน 1 วัน';

    final reminderOptions = [
      'ตรงเวลาที่บันทึก',
      'ก่อน 15 นาที',
      'ก่อน 1 ชั่วโมง',
      'ก่อน 1 วัน',
      'ก่อน 3 วัน',
      'ก่อน 7 วัน',
      'ไม่แจ้งเตือน'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                existing == null ? Icons.add_task : Icons.edit_calendar,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                existing == null ? 'เพิ่มกิจกรรมปฏิทิน' : 'แก้ไขกิจกรรมปฏิทิน',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'ชื่อกิจกรรม *',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.event_note),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                  title: const Text('วันที่', style: TextStyle(fontSize: 16)),
                  subtitle: Text(
                    AppDateUtils.formatThaiDate(selectedDate, useFullMonth: true),
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      helpText: 'เลือกวันที่',
                      cancelText: 'ยกเลิก',
                      confirmText: 'ตกลง',
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, color: AppColors.primary),
                  title: const Text('เวลา', style: TextStyle(fontSize: 16)),
                  subtitle: Text(
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')} น.',
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime,
                      helpText: 'ระบุเวลา',
                      cancelText: 'ยกเลิก',
                      confirmText: 'ตกลง',
                      hourLabelText: 'ชั่วโมง',
                      minuteLabelText: 'นาที',
                    );
                    if (picked != null) setDialogState(() => selectedTime = picked);
                  },
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียด (ไม่บังคับ)',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 12),
                if (cows.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedCowId,
                    style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'เกี่ยวข้องกับวัว (ไม่บังคับ)',
                      labelStyle: TextStyle(fontSize: 15),
                      prefixIcon: Icon(Icons.pets),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('ไม่ระบุ', style: TextStyle(fontSize: 15))),
                      ...cows.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.name} (${c.tagNumber})', style: const TextStyle(fontSize: 15)),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCowId = v),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedReminder,
                  style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'การแจ้งเตือนล่วงหน้า',
                    labelStyle: TextStyle(fontSize: 15),
                    prefixIcon: Icon(Icons.notifications_active_outlined),
                  ),
                  items: reminderOptions.map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: const TextStyle(fontSize: 15)),
                      )).toList(),
                  onChanged: (v) => setDialogState(() => selectedReminder = v),
                ),
              ],
            ),
          ),
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
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

                    bool ok;
                    if (existing == null) {
                      final event = CalendarEvent(
                        id: '',
                        farmId: farmId,
                        title: title,
                        eventDatetime: dt,
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        reminderSetting: selectedReminder,
                        cowId: selectedCowId,
                        eventType: 'general',
                      );
                      ok = await ref.read(calendarProvider.notifier).addEvent(event);
                    } else {
                      ok = await ref
                          .read(calendarProvider.notifier)
                          .updateEvent(existing.copyWith(
                            title: title,
                            eventDatetime: dt,
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            reminderSetting: selectedReminder,
                            cowId: selectedCowId,
                          ));
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'บันทึกกิจกรรมและการแจ้งเตือนแล้ว' : 'เกิดข้อผิดพลาดในการบันทึก', style: const TextStyle(fontSize: 15)),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ));
                    }
                  },
                  child: const Text('บันทึก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CalendarEvent event) {
    if (event.eventType == 'breeding') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กำหนดวันคลอดคำนวณจากการผสมพันธุ์แม่วัว หากต้องการลบให้จัดการที่ประวัติแม่วัวตัวนั้นๆ', style: TextStyle(fontSize: 14)),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบกิจกรรม/นัดหมาย', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text('ต้องการลบ "${event.title}" ใช่หรือไม่? (การแจ้งเตือนที่เกี่ยวข้องจะถูกลบออกด้วย)', style: const TextStyle(fontSize: 16)),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await ref
                      .read(calendarProvider.notifier)
                      .deleteEvent(event.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'ลบการนัดหมายและการแจ้งเตือนแล้ว' : 'เกิดข้อผิดพลาดในการลบ', style: const TextStyle(fontSize: 15)),
                      backgroundColor: ok ? AppColors.success : AppColors.error,
                    ));
                  }
                },
                child: const Text('ลบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _showEventDetailSheet(BuildContext context, CalendarEvent event) {
    Color typeColor = AppColors.primary;
    IconData typeIcon = Icons.event_note;
    String typeLabel = 'กิจกรรมปฏิทิน';

    if (event.eventType == 'health') {
      typeColor = Colors.orange[800]!;
      typeIcon = Icons.medical_services_outlined;
      typeLabel = 'นัดหมายสุขภาพ';
    } else if (event.eventType == 'breeding') {
      typeColor = Colors.purple;
      typeIcon = Icons.favorite_outline;
      typeLabel = 'กำหนดคลอด';
    }

    final allCows = ref.read(cowProvider).allCows;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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
                              const SizedBox(height: 6),
                              Text(
                                event.title,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                      'วันที่',
                      AppDateUtils.formatThaiDate(event.eventDatetime, useFullMonth: true),
                      typeColor,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.access_time_rounded,
                      'เวลา',
                      '${event.eventDatetime.hour.toString().padLeft(2, '0')}:${event.eventDatetime.minute.toString().padLeft(2, '0')} น.',
                      typeColor,
                    ),

                    // Description
                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.notes_rounded,
                        'รายละเอียด',
                        event.description!,
                        typeColor,
                      ),
                    ],

                    // Reminder
                    if (event.reminderSetting != null && event.reminderSetting != 'ไม่แจ้งเตือน') ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.notifications_active_outlined,
                        'แจ้งเตือน',
                        event.reminderSetting!,
                        typeColor,
                      ),
                    ],

                    // Cow info for single cow event
                    if (event.cowId != null && event.cowId!.isNotEmpty && event.cowId != 'null') ...[
                      const SizedBox(height: 12),
                      Builder(builder: (_) {
                        final matches = allCows.where((c) =>
                            c.id == event.cowId || c.tagNumber == event.cowId || c.name == event.cowId
                        ).toList();
                        final cowText = matches.isNotEmpty
                            ? (matches.first.name.isNotEmpty && matches.first.tagNumber.isNotEmpty && matches.first.name != matches.first.tagNumber
                                ? '${matches.first.name} (${matches.first.tagNumber})'
                                : (matches.first.name.isNotEmpty ? matches.first.name : matches.first.tagNumber))
                            : event.cowId!;
                        return _buildDetailRow(Icons.pets_rounded, 'วัว', cowText, typeColor);
                      }),
                    ],

                    // Group cow count
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

                    // Action buttons
                    if (event.eventType == 'general' || event.eventType == 'health')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showEditEventDialog(context, event);
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('แก้ไข', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: typeColor,
                                side: BorderSide(color: typeColor),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _confirmDelete(context, event);
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('ลบ', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildDetailRow(IconData icon, String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  final CalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color typeColor = AppColors.primary;
    IconData typeIcon = Icons.event_note;
    String typeLabel = 'กิจกรรมปฏิทิน';

    if (event.eventType == 'health') {
      typeColor = Colors.orange[800]!;
      typeIcon = Icons.medical_services_outlined;
      typeLabel = 'นัดหมายสุขภาพ';
    } else if (event.eventType == 'breeding') {
      typeColor = Colors.purple;
      typeIcon = Icons.favorite_outline;
      typeLabel = 'กำหนดคลอด';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: typeColor.withValues(alpha: 0.3)),
      ),
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(typeIcon, color: typeColor, size: 22),
              const SizedBox(height: 2),
              Text(
                DateFormat('HH:mm').format(event.eventDatetime),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                event.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
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
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (event.cowId != null && event.cowId!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Builder(builder: (context) {
                final allCows = ref.watch(cowProvider).allCows;
                final matches = allCows.where((c) => c.id == event.cowId || c.tagNumber == event.cowId || c.name == event.cowId).toList();
                final cowText = matches.isNotEmpty
                    ? (matches.first.name.isNotEmpty && matches.first.tagNumber.isNotEmpty && matches.first.name != matches.first.tagNumber
                        ? '${matches.first.name} (${matches.first.tagNumber})'
                        : (matches.first.name.isNotEmpty ? matches.first.name : matches.first.tagNumber))
                    : event.cowId;
                return Row(children: [
                  const Icon(Icons.pets, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    'วัว: $cowText',
                    style: const TextStyle(fontSize: 13, color: AppColors.textHint, fontWeight: FontWeight.w500),
                  ),
                ]);
              }),
            ],
            if (event.reminderSetting != null && event.reminderSetting != 'ไม่แจ้งเตือน') ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.notifications_active_outlined, size: 14, color: typeColor),
                const SizedBox(width: 4),
                Text(
                  'แจ้งเตือน ${event.reminderSetting}',
                  style: TextStyle(fontSize: 12, color: typeColor, fontWeight: FontWeight.bold),
                ),
              ]),
            ],
          ],
        ),
        trailing: (event.eventType == 'general' || event.eventType == 'health')
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 22, color: AppColors.textSecondary),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('แก้ไข', style: TextStyle(fontSize: 15))),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('ลบ', style: TextStyle(color: AppColors.error, fontSize: 15)),
                  ),
                ],
              )
            : null,
      ),
      ),
    );
  }
}

