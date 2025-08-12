import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecordStorageHelper {
  static const String _key = 'notification_records';

  static Future<void> addRecord(Map<String, dynamic> record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];

    existing.insert(0, jsonEncode(record));

    await prefs.setStringList(_key, existing);
  }

  static Future<List<Map<String, dynamic>>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> clearRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> saveRecords(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = records.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_key, encoded);
  }
}
