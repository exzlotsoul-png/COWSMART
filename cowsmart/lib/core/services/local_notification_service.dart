import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../../features/calendar/domain/calendar_event.dart';

final localNotificationProvider = Provider((ref) => LocalNotificationService());

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
    }

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
        // Handle notification tap
      },
    );
  }

  Future<void> requestPermission() async {
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
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> syncEventNotifications(List<CalendarEvent> events) async {
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
      }

      if (scheduledTime.isAfter(DateTime.now())) {
        await _schedule(event, scheduledTime);
      }
    }
  }

  Future<void> _schedule(CalendarEvent event, DateTime scheduledTime) async {
    final int id = event.id.hashCode;
    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'cowsmart_events_channel',
      'Cowsmart Events',
      channelDescription: 'Notifications for cowsmart calendar events',
      importance: Importance.max,
      priority: Priority.high,
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
}
