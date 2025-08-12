import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grabbit_project/main.dart' show navigatorKey;
import 'package:grabbit_project/service/notification_service.dart';
import 'package:grabbit_project/utils/notification_storage.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  static const String targetDeviceName = "GrabbitESP32";
  static const String SERVICE_UUID     = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String CHAR_WRITE_UUID  = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  static const String CHAR_NOTIFY_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  static const Map<String, String> _nameToUuid = {
    '에어팟': '00000001-abcd-0000-0000-000000000000',
    '지갑'  : '00000002-abcd-0000-0000-000000000000',
    '물통'  : '00000003-abcd-0000-0000-000000000000',
  };
  static Map<String, String> get nameToUuid => Map.unmodifiable(_nameToUuid);

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  StreamSubscription<List<ScanResult>>? _scanSub;
  
  final StringBuffer _notifyBuf = StringBuffer();
  int _braceDepth = 0;
  bool _inString = false;
  bool _escape = false;
  static const int _maxAccumulatedLen = 8192;

  Timer? _debounce;
  String? _lastAcceptedFullJson;
  static const Duration _minGap = Duration(milliseconds: 150);

  void Function(String jsonStr)? onDataReceived;

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  Future<void> connect() async {
    await _requestPermissions();

    if (_device != null) {
      try {
        final s = await _device!.state.first;
        if (s == BluetoothDeviceState.connected) return;
      } catch (_) {}
    }

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        debugPrint("📡 발견: name=${r.device.name}, id=${r.device.id}");
        if (r.device.name == targetDeviceName) {
          _device = r.device;
          await FlutterBluePlus.stopScan();
          debugPrint("✅ GrabbitESP32 발견! 연결 시도...");
          await _device!.connect(autoConnect: false);
          await _discoverServices();
          return;
        }
      }
    });

    debugPrint("🔍 GrabbitESP32 검색 시작");
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;
    try { await _device!.requestMtu(247); } catch (_) {}

    final services = await _device!.discoverServices();
    for (final s in services) {
      if (s.uuid.toString() != SERVICE_UUID) continue;
      for (final c in s.characteristics) {
        final uuid = c.uuid.toString();
        if (uuid == CHAR_WRITE_UUID) {
          _writeChar = c;
        } else if (uuid == CHAR_NOTIFY_UUID) {
          _notifyChar = c;
          await _notifyChar!.setNotifyValue(true);
          _notifyChar!.value.listen(_onNotifyChunk);
        }
      }
    }

    if (_writeChar == null || _notifyChar == null) {
      debugPrint("❌ 서비스/캐릭터리스틱 바인딩 실패");
    } else {
      debugPrint("✅ 서비스/캐릭터리스틱 바인딩 완료");
    }
  }

  void _onNotifyChunk(List<int> bytes) {
    if (bytes.isEmpty) return;

    final part = utf8.decode(bytes, allowMalformed: true);
    if (kDebugMode) debugPrint('📥 NUS raw: $part');

    if (_notifyBuf.length + part.length > _maxAccumulatedLen) {
      _notifyBuf.clear();
      _braceDepth = 0; _inString = false; _escape = false;
    }

    _notifyBuf.write(part);

    final full = _notifyBuf.toString();
    if (full.contains('\n')) {
      final lines = full.split('\n');
      _notifyBuf
        ..clear()
        ..write(lines.removeLast()); // 미완
      for (final line in lines) {
        final s = line.trim();
        if (s.isEmpty) continue;
        final start = s.indexOf('{');
        final end = s.lastIndexOf('}');
        final candidate = (start >= 0 && end > start) ? s.substring(start, end + 1) : s;
        _tryHandleOneJson(candidate);
      }
      return;
    }

    _drainCompletedJsons();
  }

  void _drainCompletedJsons() {
    final buf = _notifyBuf.toString();
    if (buf.isEmpty) return;

    final completed = <String>[];
    int start = -1;
    int lastCompletedEnd = -1;

    for (int i = 0; i < buf.length; i++) {
      final ch = buf[i];

      if (_escape) { _escape = false; continue; }
      if (ch == '\\') { _escape = true; continue; }
      if (ch == '"') { _inString = !_inString; continue; }
      if (_inString) continue;

      if (ch == '{') {
        if (_braceDepth == 0) start = i;
        _braceDepth++;
      } else if (ch == '}') {
        _braceDepth--;
        if (_braceDepth == 0 && start >= 0) {
          completed.add(buf.substring(start, i + 1));
          lastCompletedEnd = i;
          start = -1;
        }
      }
    }

    if (completed.isEmpty) return;

    String remainder = '';
    if (_braceDepth > 0 && start >= 0) {
      remainder = buf.substring(start);
    } else if (lastCompletedEnd + 1 < buf.length) {
      remainder = buf.substring(lastCompletedEnd + 1);
    }
    _notifyBuf
      ..clear()
      ..write(remainder);

    for (final jsonStr in completed) {
      _tryHandleOneJson(jsonStr.trim());
    }
  }

  bool _isDoorEvent(String? event) {
    if (event == null) return false;
    final cleaned = event.replaceAll(RegExp(r'[\s\[\]]'), '');
    return cleaned.contains('문열림') || cleaned.contains('문닫힘');
  }

  void _tryHandleOneJson(String jsonMaybe) {
    if (jsonMaybe.isEmpty) return;
    if (_lastAcceptedFullJson != null && _lastAcceptedFullJson == jsonMaybe) return;

    _debounce?.cancel();
    _debounce = Timer(_minGap, () async {
      try {
        final Map<String, dynamic> data = jsonDecode(jsonMaybe);
        _lastAcceptedFullJson = jsonMaybe;

        if (kDebugMode) debugPrint("📥 Notify 수신(완성): $jsonMaybe");
        onDataReceived?.call(jsonMaybe);

        final event    = (data['이벤트'] ?? '').toString();
        final stateRaw = (data['상태'] ?? '').toString();
        final state    = stateRaw.toUpperCase(); // 정규화
        final missing  = _asStringList(data['누락됨']);
        final detected = _asStringList(data['감지됨']);

        if (state == 'IDLE') {
          final newItem = NotificationItem(
            message: _isDoorEvent(event) ? '' : event,
            timestamp: DateTime.now(),
            state: state,
            detected: detected,
            missing: missing,
          );
          await NotificationStorage.addNotification(newItem);
          if (kDebugMode) debugPrint("📦(IDLE) 알림 저장만 수행");
          return;
        }

        if (missing.isNotEmpty) {
          _showMissingSnackBar(missing, state: state);
        }

        if (missing.isNotEmpty) {
          await NotificationService.showStateBasedNotification(
            state: state,
            missed: missing,
          );
        }

        final newItem = NotificationItem(
          message: _isDoorEvent(event) ? '' : event,
          timestamp: DateTime.now(),
          state: state,
          detected: detected,
          missing: missing,
        );
        await NotificationStorage.addNotification(newItem);
        if (kDebugMode) debugPrint("📦 알림 저장 완료");
      } catch (e) {
        if (kDebugMode) debugPrint("…조립 대기/파싱 보류: $e");
      }
    });
  }

  List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  void _showMissingSnackBar(List<String> missing, {String? state}) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      debugPrint('⚠️ No context for SnackBar');
      return;
    }
    final msg = '누락: ${missing.join(", ")}'
        '${(state != null && state.isNotEmpty) ? " • $state" : ""}';
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _ensureReady({Duration timeout = const Duration(seconds: 6)}) async {
    final start = DateTime.now();
    while (_writeChar == null) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (DateTime.now().difference(start) > timeout) {
        debugPrint("⏱️ BLE 준비 타임아웃");
        return false;
      }
    }
    return true;
  }

  Future<void> sendRoutine(List<String> items, String userId) async {
    if (!await _ensureReady()) {
      debugPrint("❌ WRITE 캐릭터리스틱 준비 실패");
      return;
    }

    final payload = <String, dynamic>{
      "루틴": items,
      "사용자ID": userId,
      "사자ID": userId,    
    };

    final jsonStr = jsonEncode(payload);
    await _writeChar!.write(utf8.encode(jsonStr), withoutResponse: false);
    debugPrint("📤 루틴 전송 완료: $jsonStr");
  }

  // Firestore Load + Fallback
  Future<List<String>> _loadTodayUuidsWithFallback(String uid) async {
    final int weekday = DateTime.now().toLocal().weekday;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('daily_recommendations').doc('$weekday')
          .get();

      final raw = (doc.data()?['items'] as List?) ?? const [];
      final uuids = raw
          .whereType<Map>()
          .map((e) => '${e['uuid'] ?? ''}')
          .where((s) => s.isNotEmpty)
          .toList();

      if (uuids.isNotEmpty) {
        debugPrint('✅ today items from daily_recommendations($weekday): $uuids');
        return uuids;
      }
    } catch (e) {
      debugPrint('daily_recommendations read error: $e');
    }

    try {
      final recDoc = await FirebaseFirestore.instance
          .collection('recommendations').doc('grabbit-user').get();

      final names = (recDoc.data()?['predicted_missing'] as List?)
          ?.whereType<String>()
          .toList() ??
          const [];

      if (names.isEmpty) return <String>[];

      final mapped = <String>[];
      for (final n in names) {
        final u = _nameToUuid[n];
        if (u != null && u.isNotEmpty) mapped.add(u);
      }
      return mapped;
    } catch (e) {
      debugPrint('fallback read error: $e');
      return <String>[];
    }
  }

  Future<void> sendTodayRecommendations(
      String uid, {
        String? userIdOverride,
      }) async {
    try {
      final uuids = await _loadTodayUuidsWithFallback(uid);
      debugPrint('BLE 전송 대상 UUID: $uuids');
      if (uuids.isEmpty) {
        debugPrint("⚠️ 오늘 추천 아이템 비어 있음");
        return;
      }
      final userId = userIdOverride ?? uid;
      await sendRoutine(uuids, userId);
    } catch (e) {
      debugPrint("❌ Firestore 추천 불러오기/전송 실패: $e");
    }
  }
}
