import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RecommendationService {
  static final _db = FirebaseFirestore.instance;

  static const String _defaultGlobalDocId = 'grabbit-user';

  static Future<List<Map<String, dynamic>>> fetchLatest(
      String uid, {
        String? globalDocId,
        bool onlyToday = true,
      }) async {
    try {
      final a = await _readUserToday(uid);
      if (a.isNotEmpty) return a;

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

  static DocumentReference<Map<String, dynamic>> _userTodayRef(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('recommendations')
        .doc('today');
  }

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

  static DateTime? _readTs(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
