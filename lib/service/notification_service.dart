// lib/service/notification_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  // ✅ 단일 인스턴스만 사용
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  // Android 채널 ID(고정)
  static const String _channelIdInstant = 'grabbit_channel_id';
  static const String _channelIdDaily = 'daily_channel_id';

  // 템플릿 기본값 (설정 페이지와 동일)
  static const String _defaultGoingOut  = '앗! 챙기셨나요? 🐰 {items} · 외출 중';
  static const String _defaultReturned  = '귀가 · 외출 중 분실 감지 ⚠️ {items}';

  /// 초기화
  static Future<void> initialize() async {
    tz.initializeTimeZones();

    // Android init
    const AndroidInitializationSettings initAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: initAndroid);

    // Android 13+ 권한
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }

    await _plugin.initialize(initSettings);

    // ✅ 채널 보장 생성
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelIdInstant,
      'Grabbit 알림',
      description: '즉시 누락 알림 등',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelIdDaily,
      'Daily Checklist',
      description: '매일 아침 체크리스트',
      importance: Importance.high,
    ));
  }

  /// 외부에서 쓰는 즉시 알림 (알림 기록에도 남음)
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelIdInstant,
      'Grabbit 알림',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // 고유 ID
      title,
      body,
      details,
    );
  }

  /// 상태/누락목록 기반 즉시 알림
  /// state: 'GOING_OUT' | 'RETURNED' 등
  /// ⚠️ 문 열림/닫힘 같은 이벤트 문구는 넣지 않음(요청사항 반영)
  static Future<void> showStateBasedNotification({
    required String state,
    required List<String> missed,
    String title = 'Grabbit 알림',
  }) async {
    // 저장된 템플릿 로드
    final prefs = await SharedPreferences.getInstance();
    final goingOutTpl = prefs.getString('templateGoingOut') ?? _defaultGoingOut;
    final returnedTpl = prefs.getString('templateReturned') ?? _defaultReturned;

    final items = missed.join(', ');

    String body;
    if (state == 'GOING_OUT') {
      body = goingOutTpl.replaceAll('{items}', items);
    } else if (state == 'RETURNED') {
      body = returnedTpl.replaceAll('{items}', items);
    } else {
      // 다른 상태는 기본 문구 (필요 시 확장)
      body = missed.isEmpty ? '' : '감지 안 된 항목: $items';
    }

    if (body.isEmpty) return;
    await showNotification(title: title, body: body);
  }

  /// 매일 오전 7시 알림
  static Future<void> scheduleDailyChecklistReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final weekday = DateFormat('EEEE', 'en_US').format(now); // Monday..

    final routineKey = 'routineItems_$weekday';
    final extraKey = 'extraItems_$weekday';

    final routineItems = prefs.getStringList(routineKey) ?? [];
    final extraItems = prefs.getStringList(extraKey) ?? [];
    final allItems = [...routineItems, ...extraItems];
    if (allItems.isEmpty) return;

    final msg = StringBuffer('오늘 챙길 물건 목록이에요:\n');
    for (int i = 0; i < allItems.length; i++) {
      msg.writeln('${i + 1}. ${allItems[i]}');
    }

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      _channelIdDaily,
      'Daily Checklist',
      channelDescription: 'Grabbit 매일 아침 체크리스트',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      777,
      'Grabbit',
      msg.toString(),
      _next7AM(),
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _next7AM() {
    final now = tz.TZDateTime.now(tz.local);
    final target = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7);
    return target.isBefore(now) ? target.add(const Duration(days: 1)) : target;
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
