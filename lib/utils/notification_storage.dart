import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationItem {
  final String message;
  final DateTime timestamp;
  final String state;
  final List<String> detected;
  final List<String> missing;

  NotificationItem({
    required this.message,
    required this.timestamp,
    required this.state,
    required this.detected,
    required this.missing,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      message: json['이벤트'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      state: json['상태'] ?? '',
      detected: List<String>.from(json['감지됨'] ?? []),
      missing: List<String>.from(json['누락됨'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '이벤트': message,
      'timestamp': timestamp.toIso8601String(),
      '상태': state,
      '감지됨': detected,
      '누락됨': missing,
    };
  }

  static String encodeList(List<NotificationItem> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  static List<NotificationItem> decodeList(String jsonStr) {
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => NotificationItem.fromJson(e)).toList();
  }
}

class NotificationStorage {
  static const _key = 'notification_items';

  static Future<void> addNotification(NotificationItem newItem) async {
    final items = await loadNotifications();
    items.add(newItem);
    await saveNotifications(items);
  }

  static Future<List<NotificationItem>> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    return NotificationItem.decodeList(jsonStr);
  }

  static Future<void> saveNotifications(List<NotificationItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = NotificationItem.encodeList(items);
    await prefs.setString(_key, encoded);
  }

  static Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> deleteNotification(NotificationItem targetItem) async {
    final items = await loadNotifications();
    items.removeWhere((item) =>
    item.message == targetItem.message &&
        item.timestamp.toIso8601String() == targetItem.timestamp.toIso8601String());
    await saveNotifications(items);
  }
}
