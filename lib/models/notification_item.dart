import 'dart:convert';

class NotificationItem {
  final String message;
  final DateTime timestamp;
  final String type;

  NotificationItem({
    required this.message,
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'],
    );
  }

  static String encodeList(List<NotificationItem> items) =>
      json.encode(items.map((e) => e.toJson()).toList());

  static List<NotificationItem> decodeList(String jsonStr) =>
      (json.decode(jsonStr) as List)
          .map((e) => NotificationItem.fromJson(e))
          .toList();
}