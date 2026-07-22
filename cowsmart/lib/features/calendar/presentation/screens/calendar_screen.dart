import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
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
        onPageChanged: (focused) => setState(() => _focusedDay = focused),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: AppColors.secondary,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          weekendTextStyle: const TextStyle(color: AppColors.error),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonShowsNext: false,
          titleCentered: true,
          formatButtonDecoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.primary),
            ),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          formatButtonTextStyle: TextStyle(color: AppColors.primary),
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
            Icon(Icons.event_available, size: 52, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              'ไม่มีกิจกรรมวันนี้',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('dd MMMM yyyy').format(_selectedDay),
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final event = events[index];
        return _EventCard(
          event: event,
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
    String? selectedReminder = existing?.reminderSetting;

    final reminderOptions = ['ก่อน 1 วัน', 'ก่อน 3 วัน', 'ก่อน 7 วัน', 'ไม่แจ้งเตือน'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'เพิ่มกิจกรรม' : 'แก้ไขกิจกรรม'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อกิจกรรม *',
                    prefixIcon: Icon(Icons.event_note),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                  title: const Text('วันที่'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, color: AppColors.primary),
                  title: const Text('เวลา'),
                  subtitle: Text(selectedTime.format(ctx)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime,
                    );
                    if (picked != null) setDialogState(() => selectedTime = picked);
                  },
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียด (ไม่บังคับ)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 12),
                if (cows.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedCowId,
                    decoration: const InputDecoration(
                      labelText: 'เกี่ยวข้องกับวัว (ไม่บังคับ)',
                      prefixIcon: Icon(Icons.pets),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
                      ...cows.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.name} (${c.tagNumber})'),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCowId = v),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedReminder,
                  decoration: const InputDecoration(
                    labelText: 'การแจ้งเตือนล่วงหน้า',
                    prefixIcon: Icon(Icons.notifications_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
                    ...reminderOptions.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r),
                        )),
                  ],
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
                  child: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
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
                        content: Text(ok ? 'บันทึกกิจกรรมแล้ว' : 'เกิดข้อผิดพลาด'),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ));
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CalendarEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบกิจกรรม'),
        content: Text('ต้องการลบ "${event.title}" ใช่หรือไม่?'),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
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
                      content: Text(ok ? 'ลบกิจกรรมแล้ว' : 'เกิดข้อผิดพลาด'),
                      backgroundColor: ok ? AppColors.success : AppColors.error,
                    ));
                  }
                },
                child: const Text('ลบ'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              DateFormat('HH:mm').format(event.eventDatetime),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        title: Text(
          event.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                event.description!,
                style: const TextStyle(
                  fontSize: 12,
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
                  const Icon(Icons.pets, size: 12, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    'วัว: $cowText',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ]);
              }),
            ],
            if (event.reminderSetting != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.notifications_outlined, size: 12, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  'แจ้งเตือน ${event.reminderSetting}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ]),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
            PopupMenuItem(
              value: 'delete',
              child: Text('ลบ', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}
