import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:grabbit_project/utils/notification_storage.dart';




class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  static const String targetDeviceName = "GrabbitESP32";

  static const String SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String CHAR_WRITE_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  static const String CHAR_NOTIFY_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;

  /// ✅ 외부에서 설정하는 Notify 수신 콜백
  void Function(String jsonStr)? onDataReceived;

  /// ✅ BLE 연결 + 서비스 검색
  Future<void> connect() async {
    await _requestPermissions();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    print("🔍 GrabbitESP32 검색 중...");

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        print("📡 발견된 장치: 이름=${r.device.name}, MAC=${r.device.id}");
        if (r.device.name == targetDeviceName) {
          _device = r.device;
          await FlutterBluePlus.stopScan();
          print("✅ GrabbitESP32 발견! 연결 중...");
          await _device!.connect();
          await _discoverServices();
          break;
        }
      }
    });
  }

  /// ✅ 서비스 및 캐릭터리스틱 탐색
  Future<void> _discoverServices() async {
    List<BluetoothService> services = await _device!.discoverServices();

    for (var service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        for (var c in service.characteristics) {
          if (c.uuid.toString() == CHAR_WRITE_UUID) {
            _writeChar = c;
          } else if (c.uuid.toString() == CHAR_NOTIFY_UUID) {
            _notifyChar = c;
            await _notifyChar!.setNotifyValue(true);
            _notifyChar!.value.listen((value) async {
              final decoded = utf8.decode(value);
              print("📥 Notify 수신: $decoded");

              if (onDataReceived != null) {
                onDataReceived!(decoded);
              }

              try {
                final Map<String, dynamic> jsonData = jsonDecode(decoded);

                final newItem = NotificationItem(
                  message: jsonData['이벤트'] ?? '',
                  timestamp: DateTime.now(),
                  state: jsonData['상태'] ?? '',
                  detected: List<String>.from(jsonData['감지됨'] ?? []),
                  missing: List<String>.from(jsonData['누락됨'] ?? []),
                );

                await NotificationStorage.addNotification(newItem);
                print("📦 알림 저장 완료: $newItem");
              } catch (e) {
                print("❌ JSON 파싱 실패: $e");
              }
            });



          }
        }
      }
    }
  }

  /// ✅ 루틴 및 사용자 ID 전송
  Future<void> sendRoutine(List<String> items, String userId) async {
    if (_writeChar == null) {
      print("❌ WRITE 캐릭터리스틱 없음");
      return;
    }

    final Map<String, dynamic> payload = {
      "루틴": items,
      "사용자ID": userId,
    };

    final String jsonStr = jsonEncode(payload);
    await _writeChar!.write(utf8.encode(jsonStr), withoutResponse: true);
    print("📤 루틴 전송 완료: $jsonStr");
  }

  /// ✅ Android BLE 권한 요청
  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }
}