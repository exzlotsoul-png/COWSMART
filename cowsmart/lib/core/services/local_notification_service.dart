import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../../features/calendar/domain/calendar_event.dart';

// Background FCM message handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] Received message: ${message.messageId} | ${message.notification?.title}');
}

final localNotificationProvider = Provider((ref) => LocalNotificationService());

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false);

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('[LocalNotification] Tap response: ${response.payload}');
      },
    );

    // Create High Importance Android Notification Channel for Heads-up / Screen-wake
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'cowsmart_push_channel',
        'Cowsmart Alerts',
        description: 'Notifications for broadcast alerts and real-time updates',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      const AndroidNotificationChannel eventsChannel = AndroidNotificationChannel(
        'cowsmart_events_channel',
        'Cowsmart Events',
        description: 'Notifications for cowsmart calendar events and reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.createNotificationChannel(eventsChannel);
    }

    // Initialize Firebase Core & Messaging
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Listen to foreground FCM messages and display local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Received: ${message.notification?.title}');
        final notif = message.notification;
        if (notif != null) {
          showNotification(
            title: notif.title ?? 'แจ้งเตือนจากระบบ',
            body: notif.body ?? '',
            payload: message.data['type'] ?? '',
          );
        }
      });

      // Fetch FCM Token
      _fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM Token] Generated: $_fcmToken');

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[FCM Token Refresh]: $_fcmToken');
      });
    } catch (e) {
      debugPrint('[FCM Init Error]: $e');
    }
  }

  Future<void> requestPermission() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      await Permission.notification.request();
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } else if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> syncEventNotifications(List<CalendarEvent> events) async {
    if (kIsWeb) return;
    await cancelAll();

    for (final event in events) {
      DateTime scheduledTime = event.eventDatetime;
      final setting = event.reminderSetting ?? 'ตรงเวลาที่บันทึก';

      if (setting == 'ก่อน 15 นาที') {
        scheduledTime = scheduledTime.subtract(const Duration(minutes: 15));
      } else if (setting == 'ก่อน 1 ชั่วโมง') {
        scheduledTime = scheduledTime.subtract(const Duration(hours: 1));
      } else if (setting == 'ก่อน 1 วัน') {
        scheduledTime = scheduledTime.subtract(const Duration(days: 1));
      } else if (setting == 'ก่อน 3 วัน') {
        scheduledTime = scheduledTime.subtract(const Duration(days: 3));
      } else if (setting == 'ก่อน 7 วัน') {
        scheduledTime = scheduledTime.subtract(const Duration(days: 7));
      } else if (setting == 'ก่อน 14 วัน') {
        scheduledTime = scheduledTime.subtract(const Duration(days: 14));
      } else if (setting == 'ก่อน 30 วัน') {
        scheduledTime = scheduledTime.subtract(const Duration(days: 30));
      }

      if (scheduledTime.isAfter(DateTime.now())) {
        await _schedule(event, scheduledTime);
      }
    }
  }

  Future<void> _schedule(CalendarEvent event, DateTime scheduledTime) async {
    if (kIsWeb) return;

    final int id = event.id.hashCode;
    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'cowsmart_events_channel',
      'Cowsmart Events',
      channelDescription: 'Notifications for cowsmart calendar events',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'ถึงเวลากิจกรรม: ${event.title}',
      event.description ?? 'กิจกรรมปฏิทินที่กำหนดไว้ใกล้มาถึงแล้ว',
      tzTime,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: event.id,
    );
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'cowsmart_push_channel',
      'Cowsmart Alerts',
      channelDescription: 'Notifications for broadcast alerts and real-time updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Sync FCM token to backend database if token is available
  Future<void> syncFcmTokenToBackend(dynamic apiClient) async {
    if (kIsWeb) return;
    try {
      final token = _fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _fcmToken = token;
        await apiClient.post('/user/fcm-token', data: {'fcm_token': token});
        debugPrint('[FCM Token Synced]: $token');
      }
    } catch (e) {
      debugPrint('[FCM Token Sync Error]: $e');
    }
  }
}
