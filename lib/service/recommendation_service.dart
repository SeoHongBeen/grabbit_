// lib/service/recommendation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore 양쪽 스키마를 모두 지원:
///  A) 기존 앱 스키마: users/{uid}/recommendations/today  { createdAt, items:[{name,required}] }
///  B) 현재 DB 스키마: recommendations/{docId}  { predicted_missing:[String], timestamp:String|Timestamp }
///
/// 우선순위: A가 있으면 A 사용 → 없으면 B 사용.
/// B의 docId는 기본 'grabbit-user'를 본다(필요하면 파라미터로 바꿔 호출).
class RecommendationService {
  static final _db = FirebaseFirestore.instance;

  /// 외부에서 바꾸고 싶으면 이 값만 수정하거나, fetchLatest 호출 시 인자로 넘겨.
  static const String _defaultGlobalDocId = 'grabbit-user';

  // ────────────────────────────────────────────────────────────────────────────
  // Public API
  // ────────────────────────────────────────────────────────────────────────────

  /// 오늘 추천(이름/required)을 가져온다.
  /// 1) users/{uid}/recommendations/today → items 배열
  /// 2) (비어있으면) recommendations/{globalDocId} → predicted_missing 배열
  ///
  /// [onlyToday]가 true면 timestamp가 오늘이 아닐 경우 빈 배열 반환.
  /// false면 오늘이 아니어도 최신 예측을 사용.
  static Future<List<Map<String, dynamic>>> fetchLatest(
      String uid, {
        String? globalDocId,
        bool onlyToday = true,
      }) async {
    try {
      // 1) 기존 앱 스키마 우선
      final a = await _readUserToday(uid);
      if (a.isNotEmpty) return a;

      // 2) 글로벌(현재 DB) 스키마 폴백
      final docId = (globalDocId ?? _defaultGlobalDocId).trim();
      final b = await _readGlobalPredicted(docId, onlyToday: onlyToday);
      return b;
    } catch (e, st) {
      if (kDebugMode) {
        print('❌ fetchLatest error: $e\n$st');
      }
      return const [];
    }
  }

  /// 이름 배열만 뽑아서 쓰기 좋은 헬퍼.
  static Future<List<String>> fetchLatestNames(
      String uid, {
        String? globalDocId,
        bool onlyToday = true,
      }) async {
    final items = await fetchLatest(
      uid,
      globalDocId: globalDocId,
      onlyToday: onlyToday,
    );
    return items
        .map((m) => (m['name'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 기존 앱 스키마(A안)에 오늘 문서가 없으면 만들어 준다.
  static Future<void> pushIfNotExists(
      String uid,
      List<Map<String, dynamic>> items,
      ) async {
    try {
      final ref = _userTodayRef(uid);
      final snap = await ref.get();
      if (snap.exists) return;

      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'items': items
            .map((m) => {
          'name': (m['name'] ?? '').toString(),
          'required': m['required'] == true,
        })
            .toList(),
      });
    } catch (e, st) {
      if (kDebugMode) {
        print('❌ pushIfNotExists error: $e\n$st');
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ────────────────────────────────────────────────────────────────────────────

  static DocumentReference<Map<String, dynamic>> _userTodayRef(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('recommendations')
        .doc('today');
  }

  /// A) users/{uid}/recommendations/today → items 읽기
  static Future<List<Map<String, dynamic>>> _readUserToday(String uid) async {
    final snap = await _userTodayRef(uid).get();
    if (!snap.exists) {
      if (kDebugMode) print('ℹ️ no users/$uid/recommendations/today');
      return const [];
    }

    final data = snap.data() ?? {};
    final raw = data['items'];
    if (raw is! List) {
      if (kDebugMode) {
        print('⚠️ items is not List on users/$uid/today: ${raw.runtimeType}');
      }
      return const [];
    }

    final items = raw.whereType<Map>().map<Map<String, dynamic>>((m) {
      return {
        'name': (m['name'] ?? '').toString(),
        'required': (m['required'] is bool) ? m['required'] : false,
      };
    }).where((m) => (m['name'] as String).isNotEmpty).toList();

    if (kDebugMode) {
      print('✅ A-schema items: $items');
    }
    return items;
  }

  /// B) recommendations/{docId} → predicted_missing + timestamp 읽기
  ///    timestamp는 String(ISO8601) 또는 Firestore Timestamp 모두 허용
  static Future<List<Map<String, dynamic>>> _readGlobalPredicted(
      String docId, {
        required bool onlyToday,
      }) async {
    final snap = await _db.collection('recommendations').doc(docId).get();
    if (!snap.exists) {
      if (kDebugMode) print('ℹ️ no recommendations/$docId');
      return const [];
    }

    final data = snap.data() ?? {};
    if (kDebugMode) {
      print('🧩 global data keys: ${data.keys}');
      print('   predicted_missing type: ${data['predicted_missing']?.runtimeType}');
      print('   timestamp type: ${data['timestamp']?.runtimeType}');
    }

    // timestamp(오늘인지) 판정 — 옵션화
    final ts = _readTs(data['timestamp']);
    if (onlyToday) {
      if (ts == null) {
        if (kDebugMode) {
          print('⚠️ timestamp null/invalid but onlyToday=true → returning []');
        }
        return const [];
      }
      if (!_isSameDay(ts, DateTime.now())) {
        if (kDebugMode) print('ℹ️ timestamp is not today: $ts → returning []');
        return const [];
      }
    } else {
      if (ts == null) {
        if (kDebugMode) print('ℹ️ timestamp null/invalid → proceed w/o day filter');
      } else {
        if (kDebugMode) print('ℹ️ timestamp exists: $ts (onlyToday=false → proceed)');
      }
    }

    final list = (data['predicted_missing'] as List?) ?? const [];
    final items = list
        .map((e) => (e?.toString() ?? '').trim())
        .where((name) => name.isNotEmpty)
        .map((name) => {'name': name, 'required': false})
        .toList();

    if (kDebugMode) {
      print('✅ B-schema items from predicted_missing: $items');
    }
    return items;
  }

  /// timestamp 파싱: Firestore Timestamp | String(ISO8601) 모두 지원
  static DateTime? _readTs(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
