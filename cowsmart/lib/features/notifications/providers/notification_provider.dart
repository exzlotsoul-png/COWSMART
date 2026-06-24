import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/app_notification.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? errorMessage;

  NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  late final ApiClient _api;

  @override
  NotificationState build() {
    _api = ref.watch(apiClientProvider);
    return NotificationState();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.get('/notifications');
      final list = (response.data as List<dynamic>)
          .map((j) => AppNotification.fromJson(j))
          .toList();
      list.sort(
        (a, b) => (b.notifyDatetime ?? DateTime(0)).compareTo(
          a.notifyDatetime ?? DateTime(0),
        ),
      );
      state = state.copyWith(notifications: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _api.put('/notifications/$id', data: {'is_read': 1});
      final updated = state.notifications.map((n) {
        return n.id == id ? n.copyWith(isRead: true) : n;
      }).toList();
      state = state.copyWith(notifications: updated);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final unread = state.notifications.where((n) => !n.isRead).toList();
    for (final n in unread) {
      await markAsRead(n.id);
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _api.delete('/notifications/$id');
      final updated = state.notifications.where((n) => n.id != id).toList();
      state = state.copyWith(notifications: updated);
    } catch (_) {}
  }

  Future<bool> createTestNotification() async {
    try {
      await _api.post(
        '/notifications',
        data: {
          'title': 'ทดสอบการแจ้งเตือน',
          'message': 'ระบบแจ้งเตือนทำงานปกติ ✓',
          'notify_datetime': DateTime.now().toIso8601String(),
          'is_read': 0,
        },
      );
      await fetchNotifications();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(() {
      return NotificationNotifier();
    });
