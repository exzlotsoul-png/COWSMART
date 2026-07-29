import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cowsmart/core/theme/app_colors.dart';
import '../../providers/notification_provider.dart';
import '../../domain/app_notification.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllAsRead(),
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: const Text(
                'อ่านทั้งหมด',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationProvider.notifier).fetchNotifications(),
              child: state.notifications.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: state.notifications.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final notif = state.notifications[index];
                        return _NotificationTile(
                          notification: notif,
                          onTap: () => _onTap(notif),
                          onDismiss: () => ref
                              .read(notificationProvider.notifier)
                              .deleteNotification(notif.id),
                        );
                      },
                    ),
            ),
    );
  }

  void _onTap(AppNotification notif) {
    if (!notif.isRead) {
      ref.read(notificationProvider.notifier).markAsRead(notif.id);
    }
    final isCalendarNotif = notif.title.contains('ปฏิทิน') ||
        notif.message.contains('[ref:cal_') ||
        notif.title.contains('กิจกรรม');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isCalendarNotif ? Icons.calendar_month : Icons.notifications_active,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notif.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notif.message.replaceAll(RegExp(r'\[ref:.*?\]'), '').trim(),
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (notif.notifyDatetime != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy HH:mm').format(notif.notifyDatetime!),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              if (isCalendarNotif) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/calendar');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('เปิดดูในปฏิทิน', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('ปิด', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 72,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            'ไม่มีการแจ้งเตือน',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'การแจ้งเตือนใหม่จะแสดงที่นี่',
            style: TextStyle(color: AppColors.textHint, fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await ref
                  .read(notificationProvider.notifier)
                  .createTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'สร้างการแจ้งเตือนทดสอบแล้ว' : 'เกิดข้อผิดพลาด',
                      style: const TextStyle(fontSize: 15),
                    ),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.science_outlined),
            label: const Text('ทดสอบการแจ้งเตือน', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                _iconForTitle(notification.title),
                color: AppColors.primary,
                size: 22,
              ),
            ),
            if (!notification.isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              notification.message.replaceAll(RegExp(r'\[ref:.*?\]'), '').trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            if (notification.createdAt != null || notification.notifyDatetime != null) ...[
              const SizedBox(height: 4),
              Text(
                _timeAgo(notification.createdAt ?? notification.notifyDatetime!),
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ],
        ),
        tileColor: notification.isRead
            ? null
            : AppColors.primary.withValues(alpha: 0.03),
      ),
    );
  }

  IconData _iconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('ปฏิทิน') || t.contains('กิจกรรม') || t.contains('calendar')) {
      return Icons.calendar_month_outlined;
    }
    if (t.contains('สุขภาพ') || t.contains('ป่วย') || t.contains('health')) {
      return Icons.medical_services_outlined;
    }
    if (t.contains('วัคซีน') || t.contains('vaccine')) {
      return Icons.vaccines_outlined;
    }
    if (t.contains('คลอด') || t.contains('ผสม') || t.contains('breed')) {
      return Icons.favorite_outline;
    }
    if (t.contains('อาหาร') || t.contains('feed')) {
      return Icons.grass_outlined;
    }
    if (t.contains('การเงิน') || t.contains('finance')) {
      return Icons.attach_money;
    }
    return Icons.notifications_outlined;
  }

  String _timeAgo(DateTime dt) {
    final localDt = dt.isUtc ? dt.toLocal() : dt;
    final diff = DateTime.now().difference(localDt);
    if (diff.isNegative || diff.inSeconds < 60) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return DateFormat('dd MMM yyyy').format(localDt);
  }
}
