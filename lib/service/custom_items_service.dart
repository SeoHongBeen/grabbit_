import 'package:cloud_firestore/cloud_firestore.dart';

class CustomItemsService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid)
          .collection('custom_items').doc('list');

  Stream<List<Map<String, dynamic>>> streamCustomItems(String uid) {
    return _doc(uid).snapshots().map((snap) {
      final list = (snap.data()?['list'] as List?) ?? const [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  Future<void> addItem(String uid, {required String name, String? memo}) async {
    await _doc(uid).set({
      'list': FieldValue.arrayUnion([
        {'name': name, if (memo != null && memo.isNotEmpty) 'memo': memo}
      ])
    }, SetOptions(merge: true));
  }

  Future<void> removeItem(String uid, {required String name, String? memo}) async {
    await _doc(uid).set({
      'list': FieldValue.arrayRemove([
        {'name': name, if (memo != null && memo.isNotEmpty) 'memo': memo}
      ])
    }, SetOptions(merge: true));
  }
}
