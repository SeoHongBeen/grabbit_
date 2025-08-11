// lib/service/recommendation_service.dart
//
// Firestore에 Colab이 쓴 추천 데이터를 읽어오는 서비스.
// 기본 구조:
//   users/{uid}/recommendations/{autoId or yyyy-MM-dd}
//     - items: [{id, name, required}, ...]
//     - updatedAt: serverTimestamp()

import 'package:cloud_firestore/cloud_firestore.dart';

class RecommendationService {
  RecommendationService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 최신 추천 1건(items 배열)만 반환.
  /// 없으면 빈 리스트.
  static Future<List<Map<String, dynamic>>> fetchLatest(String uid) async {
    final qs = await _db
        .collection('users').doc(uid)
        .collection('recommendations')
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return [];
    final data = qs.docs.first.data();
    final raw = (data['items'] ?? []) as List;
    // List<dynamic> -> List<Map<String, dynamic>>
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 요일/시간대 기준으로 가장 최신 추천을 가져오고 싶으면 사용.
  /// 예: weekday='tue', timeslot='morning'
  static Future<List<Map<String, dynamic>>> fetchBySlot(
      String uid, {
        required String weekday, // mon,tue,wed,thu,fri,sat,sun
        required String timeslot, // morning, afternoon, evening ...
      }) async {
    final qs = await _db
        .collection('users').doc(uid)
        .collection('recommendations')
        .where('weekday', isEqualTo: weekday)
        .where('timeslot', isEqualTo: timeslot)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return [];
    final data = qs.docs.first.data();
    final raw = (data['items'] ?? []) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 테스트/디버그용: 추천이 없을 때 임시 데이터 한 번 써넣기.
  /// (앱에서 직접 쓰지 말고 개발 중 확인용으로만!)
  static Future<void> seedIfEmpty(String uid) async {
    final ref = _db
        .collection('users').doc(uid)
        .collection('recommendations');

    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    await ref.add({
      'items': [
        {'id': 'wallet', 'name': '지갑', 'required': true},
        {'id': 'umbrella', 'name': '우산', 'required': false},
        {'id': 'airpods', 'name': '에어팟', 'required': false},
      ],
      'weekday': _weekdayNow(),
      'timeslot': _timeSlotNow(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 오늘 요일 문자열 (mon..sun)
  static String _weekdayNow() {
    const map = {
      DateTime.monday: 'mon',
      DateTime.tuesday: 'tue',
      DateTime.wednesday: 'wed',
      DateTime.thursday: 'thu',
      DateTime.friday: 'fri',
      DateTime.saturday: 'sat',
      DateTime.sunday: 'sun',
    };
    return map[DateTime.now().weekday] ?? 'mon';
  }

  /// 현재 시간대 구분 (필요시 규칙 바꿔도 됨)
  static String _timeSlotNow() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 18) return 'afternoon';
    return 'evening';
  }
}
