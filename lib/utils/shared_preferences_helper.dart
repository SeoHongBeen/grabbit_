import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/routine.dart';
import '../models/ble_tag.dart';

class SharedPreferencesHelper {
  static const _routineKey = 'routine_items';
  static const _bleTagsKey = 'ble_tags'; 

  //루틴 저장
  static Future<void> saveRoutineItems(List<RoutineItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = items.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_routineKey, jsonList);
  }

  //루틴 불러오기
  static Future<List<RoutineItem>> loadRoutineItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_routineKey) ?? [];
    return jsonList.map((e) => RoutineItem.fromJson(jsonDecode(e))).toList();
  }

  //BLE 태그 저장
  static Future<void> saveBleTags(List<BleTag> tags) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tags.map((tag) => tag.toJson()).toList());
    await prefs.setString(_bleTagsKey, encoded);
  }

  //BLE 태그 불러오기
  static Future<List<BleTag>> loadBleTags() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_bleTagsKey);
    if (encoded == null) return [];

    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.map((json) => BleTag.fromJson(json)).toList();
  }
}
