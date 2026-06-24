import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(notif.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notif.message),
            if (notif.notifyDatetime != null) ...[
              const SizedBox(height: 12),
              Text(
                DateFormat('dd MMM yyyy HH:mm').format(notif.notifyDatetime!),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
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
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'การแจ้งเตือนใหม่จะแสดงที่นี่',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
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
                    ),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.science_outlined),
            label: const Text('ทดสอบการแจ้งเตือน'),
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
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: notification.isRead
                    ? AppColors.border
                    : AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForTitle(notification.title),
                color: notification.isRead
                    ? AppColors.textHint
                    : AppColors.primary,
                size: 22,
              ),
            ),
            if (!notification.isRead)
              Positioned(
                top: 0,
                right: 0,
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
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              notification.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (notification.notifyDatetime != null) ...[
              const SizedBox(height: 4),
              Text(
                _timeAgo(notification.notifyDatetime!),
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ],
        ),
        tileColor: notification.isRead
            ? null
            : AppColors.primary.withOpacity(0.03),
      ),
    );
  }

  IconData _iconForTitle(String title) {
    final t = title.toLowerCase();
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
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return DateFormat('dd MMM yyyy').format(dt);
  }
}
