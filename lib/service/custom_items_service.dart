import 'package:cloud_firestore/cloud_firestore.dart';

/// UI 전용 즐겨찾기 목록을 관리하는 서비스.
/// - 문서 경로: users/{uid}/custom_items/list
/// - 스키마: { list: [{ name, memo? }] }
/// ⚠️ BLE 전송용 UUID 매핑은 ble_service.dart의 코드 고정 매핑(_nameToUuid)에서 처리합니다.
class CustomItemsService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid)
          .collection('custom_items').doc('list');

  /// UI 리스트 스트림: list:[{name,memo?}]
  Stream<List<Map<String, dynamic>>> streamCustomItems(String uid) {
    return _doc(uid).snapshots().map((snap) {
      final list = (snap.data()?['list'] as List?) ?? const [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  /// UI 항목 추가 (BLE 감지와 무관)
  Future<void> addItem(String uid, {required String name, String? memo}) async {
    await _doc(uid).set({
      'list': FieldValue.arrayUnion([
        {'name': name, if (memo != null && memo.isNotEmpty) 'memo': memo}
      ])
    }, SetOptions(merge: true));
  }

  /// UI 항목 삭제
  Future<void> removeItem(String uid, {required String name, String? memo}) async {
    await _doc(uid).set({
      'list': FieldValue.arrayRemove([
        {'name': name, if (memo != null && memo.isNotEmpty) 'memo': memo}
      ])
    }, SetOptions(merge: true));
  }
}
