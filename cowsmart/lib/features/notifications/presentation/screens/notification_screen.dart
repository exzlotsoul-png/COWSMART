import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cowsmart/core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
import '../../providers/notification_provider.dart';
import '../../domain/app_notification.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  String _selectedFilter = 'all'; // 'all', 'unread', 'broadcast', 'calving', 'health', 'calendar'

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

    final filteredNotifications = state.notifications.where((n) {
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'unread') return !n.isRead;

      final t = n.title.toLowerCase();
      final m = n.message.toLowerCase();

      final isBroadcast = m.contains('[broadcast:') ||
          t.contains('ประกาศ') ||
          t.contains('ประชาสัมพันธ์') ||
          t.contains('admin') ||
          t.contains('แอดมิน') ||
          t.contains('เตือนภัย');

      if (_selectedFilter == 'broadcast') return isBroadcast;

      if (_selectedFilter == 'calving') {
        return !isBroadcast && (t.contains('คลอด') || t.contains('ผสม') || t.contains('breed'));
      }

      if (_selectedFilter == 'health') {
        return !isBroadcast && (t.contains('สุขภาพ') || t.contains('ป่วย') || t.contains('health') || t.contains('วัคซีน') || t.contains('vaccine') || t.contains('ยา'));
      }

      if (_selectedFilter == 'calendar') {
        return !isBroadcast && (t.contains('ปฏิทิน') || t.contains('กิจกรรม') || m.contains('[ref:cal_') || t.contains('calendar'));
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text(
          'การแจ้งเตือน',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllAsRead(),
              icon: const Icon(Icons.done_all, color: Colors.white, size: 20),
              label: const Text(
                'อ่านทั้งหมด',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header summary bar
          _buildSummaryBar(state),

          // Filter Chips bar
          _buildFilterChips(state),

          // Notification list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(notificationProvider.notifier).fetchNotifications(),
                    child: filteredNotifications.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: filteredNotifications.length,
                            itemBuilder: (context, index) {
                              final notif = filteredNotifications[index];
                              return _NotificationCard(
                                notification: notif,
                                onTap: () => _onTap(notif),
                                onDismiss: () => ref
                                    .read(notificationProvider.notifier)
                                    .deleteNotification(notif.id),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(NotificationState state) {
    final filterCategories = [
      {
        'key': 'all',
        'label': 'ทั้งหมด',
        'icon': Icons.apps,
        'color': AppColors.primary,
      },
      {
        'key': 'unread',
        'label': 'ยังไม่อ่าน',
        'icon': Icons.mark_email_unread_outlined,
        'color': AppColors.error,
      },
      {
        'key': 'broadcast',
        'label': 'ประกาศ / แอดมิน',
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFFD97706),
      },
      {
        'key': 'calving',
        'label': 'กำหนดคลอด',
        'icon': Icons.favorite_outline,
        'color': const Color(0xFF9333EA),
      },
      {
        'key': 'health',
        'label': 'สุขภาพ / นัดหมาย',
        'icon': Icons.medical_services_outlined,
        'color': const Color(0xFFDC2626),
      },
      {
        'key': 'calendar',
        'label': 'กิจกรรมปฏิทิน',
        'icon': Icons.calendar_month_outlined,
        'color': const Color(0xFF0284C7),
      },
    ];

    return Container(
      color: AppColors.surf(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filterCategories.map((cat) {
            final isSelected = _selectedFilter == cat['key'];
            final color = cat['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
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
                    color: isSelected ? Colors.white : AppColors.text(context),
                  ),
                ),
                selected: isSelected,
                selectedColor: color,
                backgroundColor: color.withValues(alpha: 0.08),
                side: BorderSide(
                  color: isSelected ? color : color.withValues(alpha: 0.25),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = cat['key'] as String;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryBar(NotificationState state) {
    final total = state.notifications.length;
    final unread = state.unreadCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_active, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ทั้งหมด $total รายการ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unread > 0 ? 'ยังไม่อ่าน $unread รายการ' : 'อ่านครบทุกรายการแล้ว',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
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

    final isBroadcast = notif.message.contains('[broadcast:') ||
        notif.title.contains('ประกาศ') ||
        notif.title.contains('admin') ||
        notif.title.contains('แอดมิน');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isBroadcast ? const Color(0xFFD97706) : AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isBroadcast
                    ? Icons.campaign_rounded
                    : (isCalendarNotif ? Icons.calendar_month : Icons.notifications_active),
                color: isBroadcast ? const Color(0xFFD97706) : AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notif.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Text(
              notif.message.replaceAll(RegExp(r'\[ref:.*?\]'), '').trim(),
              style: const TextStyle(fontSize: 17, height: 1.5, color: AppColors.textPrimary),
            ),
            if (notif.notifyDatetime != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      AppDateUtils.formatThaiDate(notif.notifyDatetime!, includeTime: true),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.calendar_month, size: 20),
                    label: const Text('เปิดดูในปฏิทิน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ปิด', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    if (_selectedFilter != 'all') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.filter_list_off_rounded,
                  size: 64,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ไม่พบการแจ้งเตือนในหมวดนี้',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ลองเปลี่ยนหมวดหมู่หรือเลือกดูทั้งหมด',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedFilter = 'all';
                  });
                },
                icon: const Icon(Icons.apps, size: 18),
                label: const Text('ดูการแจ้งเตือนทั้งหมด', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_outlined,
              size: 80,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ไม่มีการแจ้งเตือน',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'การแจ้งเตือนใหม่จะแสดงที่นี่',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final ok = await ref
                  .read(notificationProvider.notifier)
                  .createTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'สร้างการแจ้งเตือนทดสอบแล้ว' : 'เกิดข้อผิดพลาด',
                      style: const TextStyle(fontSize: 16),
                    ),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            icon: const Icon(Icons.science_outlined, size: 20),
            label: const Text('ทดสอบการแจ้งเตือน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text('ลบ', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        child: Material(
          color: isUnread
              ? (AppColors.isDark(context) ? AppColors.darkSurfaceAlt : AppColors.surface)
              : AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          elevation: isUnread ? 2 : 1,
          shadowColor: isUnread
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.05),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: isUnread
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    )
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.brd(context),
                        width: 1,
                      ),
                    ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon section
                  _buildIconBadge(),
                  const SizedBox(width: 14),

                  // Content section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: 18,
                            color: AppColors.text(context),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Message
                        Text(
                          notification.message.replaceAll(RegExp(r'\[ref:.*?\]'), '').trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            color: isUnread
                                ? AppColors.subText(context)
                                : AppColors.hint(context),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Time
                        if (notification.createdAt != null ||
                            notification.notifyDatetime != null)
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: isUnread
                                    ? AppColors.primary
                                    : AppColors.textHint,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _timeAgo(notification.createdAt ??
                                    notification.notifyDatetime!),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isUnread
                                      ? AppColors.primary
                                      : AppColors.textHint,
                                  fontWeight: isUnread
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Unread indicator
                  if (isUnread)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'ใหม่',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge() {
    final isBroadcast = notification.message.contains('[broadcast:') ||
        notification.title.contains('ประกาศ') ||
        notification.title.contains('ประชาสัมพันธ์') ||
        notification.title.contains('admin') ||
        notification.title.contains('แอดมิน');

    final iconData = isBroadcast ? Icons.campaign_rounded : _iconForTitle(notification.title);
    final isUnread = !notification.isRead;
    final iconColor = isBroadcast ? const Color(0xFFD97706) : _colorForTitle(notification.title);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: isUnread
            ? Border.all(color: iconColor.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Icon(iconData, color: iconColor, size: 26),
    );
  }

  Color _colorForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('ประกาศ') || t.contains('ประชาสัมพันธ์') || t.contains('admin') || t.contains('แอดมิน') || t.contains('เตือนภัย')) {
      return const Color(0xFFD97706); // Amber Gold for Broadcast Announcements
    }
    if (t.contains('ปฏิทิน') || t.contains('กิจกรรม') || t.contains('calendar')) {
      return AppColors.info;
    }
    if (t.contains('สุขภาพ') || t.contains('ป่วย') || t.contains('health')) {
      return AppColors.error;
    }
    if (t.contains('วัคซีน') || t.contains('vaccine')) {
      return const Color(0xFF7B61FF); // Purple
    }
    if (t.contains('คลอด') || t.contains('ผสม') || t.contains('breed')) {
      return const Color(0xFF9333EA); // Purple
    }
    if (t.contains('อาหาร') || t.contains('feed')) {
      return AppColors.success;
    }
    if (t.contains('การเงิน') || t.contains('finance')) {
      return AppColors.warning;
    }
    return AppColors.primary;
  }

  IconData _iconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('ประกาศ') || t.contains('ประชาสัมพันธ์') || t.contains('admin') || t.contains('แอดมิน') || t.contains('เตือนภัย')) {
      return Icons.campaign_rounded; // Megaphone for Broadcast Announcements
    }
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
    return AppDateUtils.formatThaiDate(localDt);
  }
}
