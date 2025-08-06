import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecordStorageHelper {
  static const String _key = 'notification_records';

  /// ✅ 기록 추가 (최신순)
  static Future<void> addRecord(Map<String, dynamic> record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];

    // 최신 순으로 기록 추가
    existing.insert(0, jsonEncode(record));

    await prefs.setStringList(_key, existing);
  }

  /// ✅ 전체 기록 불러오기
  static Future<List<Map<String, dynamic>>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// ✅ 전체 기록 삭제
  static Future<void> clearRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// ✅ 기록 전체 저장 (리스트 덮어쓰기용)
  static Future<void> saveRecords(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = records.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_key, encoded);
  }
}