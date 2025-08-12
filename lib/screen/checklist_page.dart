// 체크리스트 화면: Firestore 추천(요일별) + 사용자 추가 물건 + BLE

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grabbit_project/service/ble_service.dart';
import 'package:grabbit_project/utils/record_storage_helper.dart';
import 'package:grabbit_project/service/recommendation_service.dart';
import 'package:grabbit_project/service/notification_service.dart';
import 'package:flutter/foundation.dart'; // kDebugMode

const String kDevUID = 'qhPEkSGHK9PsfmUD4Yyg6YOp8c63';

Future<void> seedTodayRecommendationsOnce(String uid, int weekday) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_recommendations')
      .doc('$weekday')
      .set({
    'items': [
      {'name': '에어팟', 'uuid': BleService.nameToUuid['에어팟'] ?? ''},
      {'name': '지갑', 'uuid': BleService.nameToUuid['지갑'] ?? ''},
    ],
  }, SetOptions(merge: true));
}

class _RecoItem {
  final String name;
  final String? uuid;
  bool isChecked;
  bool isBleDetected;

  _RecoItem({
    required this.name,
    required this.uuid,
    this.isChecked = false,
    this.isBleDetected = false,
  });
}

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  String _uid = kDevUID;
  final List<_RecoItem> _recoItems = [];

  String? _lastEvent;
  String? _lastState;
  bool _suppressUntilDoorChange = false;

  String _selectedDay = DateFormat.E('ko_KR').format(DateTime.now());

  String? _footerMessage;
  Timer? _footerTimer;

  //덮어쓰기 방지용 우선순위 & 만료시각
  int _footerPriority = -1;
  DateTime _footerExpireAt = DateTime.now();

  int _weekdayNumberFromKR(String kr) {
    const map = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
    return map[kr] ?? DateTime.now().weekday;
  }

  DocumentReference<Map<String, dynamic>> get _recoDoc {
    final wd = _weekdayNumberFromKR(_selectedDay);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('daily_recommendations')
        .doc('$wd');
  }

  DocumentReference<Map<String, dynamic>> get _customDoc {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('custom_items')
        .doc('list');
  }

  @override
  void initState() {
    super.initState();

    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) {
      _uid = authUid;
    }

    //핸들러 먼저
    BleService().onDataReceived = _handleNotifyData;

    //연결 + 전송
    BleService().connect();
    BleService().sendTodayRecommendations(_uid, userIdOverride: _uid);

    _syncRecommendedFromGlobalToDaily();
    _loadRecoFromFirestoreOnce();
  }

  Future<void> _syncRecommendedFromGlobalToDaily() async {
    try {
      final names = await RecommendationService.fetchLatestNames(
        _uid,
        onlyToday: false,
      );

      final map = BleService.nameToUuid;
      final items = names.map((n) => {
        'name': n,
        'uuid': map[n] ?? '',
      }).toList();

      await _recoDoc.set({'items': items}, SetOptions(merge: true));

      setState(() {
        _recoItems
          ..clear()
          ..addAll(items.map((m) => _RecoItem(
            name: (m['name'] ?? '').toString(),
            uuid: ((m['uuid'] ?? '') as String).isEmpty
                ? null
                : (m['uuid'] as String),
          )));
      });
    } catch (e) {
      if (kDebugMode) debugPrint('sync recommended error: $e');
    }
  }

  Future<void> _loadRecoFromFirestoreOnce() async {
    try {
      final snap = await _recoDoc.get();
      final list = (snap.data()?['items'] as List?) ?? const [];
      setState(() {
        _recoItems
          ..clear()
          ..addAll(list.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final name = (m['name'] ?? '').toString();
            final uuidRaw = (m['uuid'] ?? '').toString();
            return _RecoItem(name: name, uuid: uuidRaw.isEmpty ? null : uuidRaw);
          }));
      });
    } catch (_) {}
  }
  
  void _setFooterSafely(String text, int priority, {int seconds = 6}) {
    final now = DateTime.now();

    if (now.isBefore(_footerExpireAt) && priority < _footerPriority) {
      return;
    }

    // 갱신
    _footerTimer?.cancel();
    setState(() {
      _footerMessage = text;
      _footerPriority = priority;
      _footerExpireAt = now.add(Duration(seconds: seconds));
    });
    _footerTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      setState(() {
        _footerMessage = null;
        _footerPriority = -1;
        _footerExpireAt = DateTime.now();
      });
    });
  }

  void _handleNotifyData(String jsonStr) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final event = (data['이벤트'] as String? ?? '이벤트 없음').trim();
      final stateRaw = (data['상태'] as String? ?? 'UNKNOWN').trim();
      final state = stateRaw.toUpperCase(); // 정규화: going_out → GOING_OUT

      //루틴 전송 직후엔 문 상태 바뀔 때까지 무시
      if (_suppressUntilDoorChange) {
        final doorChanged = (_lastEvent == null) ? true : (_lastEvent != event);
        if (!doorChanged) return;
        _suppressUntilDoorChange = false;
      }

      // 동일 이벤트/상태 중복 무시
      if (_lastEvent == event && _lastState == state) return;
      _lastEvent = event;
      _lastState = state;

      final nameToUuid = BleService.nameToUuid;
      final uuidToName = {for (final e in nameToUuid.entries) e.value: e.key};

      List<String> _normalize(dynamic raw) {
        final list =
            (raw as List?)?.map((e) => e.toString()).toList() ?? const [];
        return list.map((s) => uuidToName[s] ?? s).toList();
      }

      final detected = _normalize(data['감지됨']);
      final missed = _normalize(data['누락됨']);

      RecordStorageHelper.addRecord({
        'timestamp': DateTime.now().toIso8601String(),
        'event': event,
        'state': state,
        'detected': detected,
        'missed': missed,
      });

      setState(() {
        for (final item in _recoItems) {
          if (detected.contains(item.name)) {
            item.isChecked = true;
            item.isBleDetected = true;
          } else if (missed.contains(item.name)) {
            item.isChecked = false;
            item.isBleDetected = false;
          }
        }
      });

      if (state == 'IDLE') {
        _footerTimer?.cancel();
        if (_footerMessage != null) {
          setState(() => _footerMessage = null);
        }
        return;
      }

      String footer = '';
      int priority = 0; // 기본
      final missedText = missed.join(', ');

      if (state == 'GOING_OUT') {
        if (missed.isNotEmpty) {
          footer = '앗! 챙기셨나요? 🐰 $missedText · 외출 중';
          priority = 3; // 최우선
        } else {
          footer = '외출 중';
          priority = 1;
        }
      } else if (state == 'RETURNED') {
        if (missed.isNotEmpty) {
          footer = '귀가 · 외출 중 분실 감지 ⚠️ $missedText';
          priority = 2; // 두 번째 우선
        } else {
          footer = '귀가';
          priority = 1;
        }
      } else {
        // 기타 상태: 필요 시만 표시
        if (missed.isNotEmpty) {
          footer = '앗! 챙기셨나요? 🐰 $missedText';
          priority = 1;
        } else {
          footer = ''; // 표시 안 함
          priority = 0;
        }
      }

      if (missed.isNotEmpty) {
        await NotificationService.showStateBasedNotification(
          state: state,
          missed: missed,
        );
      }

      if (footer.isEmpty) {
        // 비우기(덮어쓰지 않음)
        _setFooterSafely('', -1, seconds: 0); // 즉시 클리어
      } else {
        _setFooterSafely(footer, priority, seconds: 6);
      }
    } catch (_) {}
  }

  Widget _buildDaySelector() {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: days.map((day) {
          final isSelected = day == _selectedDay;
          return ChoiceChip(
            label: Text(day),
            selected: isSelected,
            onSelected: (_) async {
              setState(() => _selectedDay = day);
              await BleService()
                  .sendTodayRecommendations(_uid, userIdOverride: _uid);
              await _syncRecommendedFromGlobalToDaily();
              await _loadRecoFromFirestoreOnce();
            },
            selectedColor: Colors.green,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecommendationSection() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _recoDoc.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('표시 오류(추천): ${snap.error}'),
          );
        }

        final list = (snap.data?.data()?['items'] as List?) ?? const [];

        final temp = <_RecoItem>[];
        for (final e in list) {
          final m = Map<String, dynamic>.from(e as Map);
          final name = (m['name'] ?? '').toString();
          final uuidRaw = (m['uuid'] ?? '').toString();
          final prev = _recoItems.firstWhereOrNull((x) => x.name == name);
          temp.add(_RecoItem(
            name: name,
            uuid: uuidRaw.isEmpty ? null : uuidRaw,
            isChecked: prev?.isChecked ?? false,
            isBleDetected: prev?.isBleDetected ?? false,
          ));
        }
        _recoItems
          ..clear()
          ..addAll(temp);

        if (_recoItems.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('추천 아이템이 없습니다.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '✅ 루틴 물건(추천, 감지 대상)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ..._recoItems.map((item) => CheckboxListTile(
              title: Text(
                item.name,
                style: TextStyle(
                  color: (item.uuid != null && !item.isBleDetected)
                      ? Colors.red
                      : null,
                  fontWeight: item.isBleDetected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: item.isBleDetected
                  ? const Text('✅ BLE 감지됨')
                  : (item.uuid == null
                  ? const Text('📝 사용자 추가 물건')
                  : null),
              value: item.isChecked,
              onChanged: (_) {
                setState(() => item.isChecked = !item.isChecked);
              },
            )),
          ],
        );
      },
    );
  }

  Widget _buildCustomSection() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _customDoc.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('표시 오류(사용자 추가): ${snap.error}'),
          );
        }

        final list = (snap.data?.data()?['list'] as List?) ?? const [];
        final items =
        list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('사용자 추가 물건',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('아직 추가한 물건이 없어요. 아래 + 버튼으로 추가하세요.'),
              )
            else
              ...items.map((e) => ListTile(
                title: Text(e['name'] ?? ''),
                subtitle: (e['memo'] != null &&
                    (e['memo'] as String).trim().isNotEmpty)
                    ? Text(e['memo'])
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await _customDoc.set({
                      'list': FieldValue.arrayRemove([
                        {
                          'name': e['name'] ?? '',
                          if ((e['memo'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            'memo': e['memo']
                        }
                      ])
                    }, SetOptions(merge: true));
                  },
                ),
              )),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Future<void> _showAddCustomItemDialog() async {
    final nameCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('사용자 추가 물건'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '이름(예: 우산)')),
            TextField(
                controller: memoCtrl,
                decoration: const InputDecoration(labelText: '메모(선택)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('추가')),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        await _customDoc.set({
          'list': FieldValue.arrayUnion([
            {
              'name': nameCtrl.text.trim(),
              if (memoCtrl.text.trim().isNotEmpty) 'memo': memoCtrl.text.trim(),
            }
          ])
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('추가 완료')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
        }
      }
    }
  }

  Future<void> _resendToEsp32() async {
    _suppressUntilDoorChange = true;
    await BleService().sendTodayRecommendations(_uid, userIdOverride: _uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📤 오늘 추천을 ESP32에 전송했어요!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final formattedDate = DateFormat('yyyy/MM/dd (E)', 'ko_KR').format(today);

    return Scaffold(
      appBar: AppBar(
        title: Text('오늘의 체크리스트 - $formattedDate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: '추천 시드',
            onPressed: () async {
              final wd = _weekdayNumberFromKR(_selectedDay);
              await seedTodayRecommendationsOnce(_uid, wd);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('추천 시드 완료')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildDaySelector(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _resendToEsp32,
                icon: const Icon(Icons.sync),
                label: const Text('BLE로 루틴 전송'),
              ),
            ),
          ),
          _buildRecommendationSection(),
          _buildCustomSection(),
        ],
      ),

      bottomNavigationBar: (_footerMessage == null || _footerMessage!.isEmpty)
          ? null
          : Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.black87,
        child: SafeArea(
          top: false,
          child: Text(
            _footerMessage!,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomItemDialog,
        tooltip: '사용자 추가 물건',
        child: const Icon(Icons.add),
      ),
    );
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E e) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
