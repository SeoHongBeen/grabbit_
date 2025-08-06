import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// 초기화
  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  /// BLE에서 사용할 즉시 알림용 함수 (외부용 별칭)
  static Future<void> showNotification(String title, String body) async {
    await showInstantNotification(title, body);
  }

  /// 내부용 즉시 알림 함수
  static Future<void> showInstantNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_channel',
      'Instant Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// 매일 오전 7시 알림 예약 (오늘 챙길 물건 목록)
  static Future<void> scheduleDailyChecklistReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final weekday = DateFormat('EEEE', 'en_US').format(now); // ex: Monday

    final routineKey = 'routineItems_$weekday';
    final extraKey = 'extraItems_$weekday';

    final routineItems = prefs.getStringList(routineKey) ?? [];
    final extraItems = prefs.getStringList(extraKey) ?? [];

    final allItems = [...routineItems, ...extraItems];
    if (allItems.isEmpty) return;

    final message = StringBuffer("오늘 챙길 물건 목록이에요:\n");
    for (int i = 0; i < allItems.length; i++) {
      message.writeln("${i + 1}. ${allItems[i]}");
    }

    await _notificationsPlugin.zonedSchedule(
      777,
      'Grabbit',
      message.toString(),
      _next7AM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel_id',
          'Daily Checklist',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 다음 오전 7시 계산
  static tz.TZDateTime _next7AM() {
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7);
    return scheduled.isBefore(now) ? scheduled.add(const Duration(days: 1)) : scheduled;
  }

  /// 모든 알림 취소
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}