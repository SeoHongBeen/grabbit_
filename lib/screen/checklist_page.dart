import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:grabbit_project/models/item.dart';
import 'package:grabbit_project/models/ble_tag.dart';
import 'package:grabbit_project/service/ble_service.dart';
import 'package:grabbit_project/service/routine_manager.dart';
import 'package:grabbit_project/utils/shared_preferences_helper.dart';
import 'package:grabbit_project/utils/record_storage_helper.dart';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});
  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  // 중복 알림/깜빡임 방지 상태
  String? _lastEvent;   // "문 열림"/"문 닫힘"
  String? _lastState;   // IDLE/GOING_OUT/AWAY/RETURNED
  bool _suppressUntilDoorChange = false; // 루틴 전송 직후 문 이벤트 변할 때까지 화면 반영 막기

  final List<ChecklistItem> _routineItems = [];
  String _selectedDay = DateFormat.E('ko_KR').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadRoutineForSelectedDay();

    final ble = BleService();
    ble.connect();
    ble.onDataReceived = _handleNotifyData;
  }

  // 요일 변경 시 루틴만 로드 (추가/추천 섹션 X)
  Future<void> _loadRoutineForSelectedDay() async {
    _routineItems.clear();

    // 1) 루틴 이름들 (요일별)
    final names = RoutineManager().getItemsForDay(_selectedDay).map((e) => e.name).toList();

    // 2) 저장된 BLE 태그 불러와서 "이름→UUID" 매핑
    final List<BleTag> tags = await SharedPreferencesHelper.loadBleTags();
    final Map<String, String> nameToUuid = {
      for (final t in tags) t.name: t.uuid,
    };

    // 3) 화면용 아이템 구성 (루틴에 없거나 BLE 태그 없는 건 uuid null)
    setState(() {
      for (final name in names) {
        _routineItems.add(
          ChecklistItem(
            name: name,
            bleUuid: nameToUuid[name], // null일 수 있음
            isRoutine: true,
          ),
        );
      }
    });
  }

  // 요일 한글 → 영문 (RoutineManager가 필요하면 사용)
  String _engWeekday(String kr) {
    const map = {
      '월': 'Monday',
      '화': 'Tuesday',
      '수': 'Wednesday',
      '목': 'Thursday',
      '금': 'Friday',
      '토': 'Saturday',
      '일': 'Sunday',
    };
    return map[kr]!;
  }

  // BLE로 현재 루틴만 전송 (BLE 태그가 있는 항목만)
  Future<void> _sendRoutineToEsp32() async {
    final itemsToSend = _routineItems
        .where((i) => i.bleUuid != null)
        .map((i) => i.name)
        .toList();

    _suppressUntilDoorChange = true;
    await BleService().sendRoutine(itemsToSend, "grabbit-user");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📤 루틴 정보를 ESP32에 전송했어요!')),
      );
    }
  }

  /// ESP32 Notify 수신 처리 (루틴 섹션만 반영)
  void _handleNotifyData(String jsonStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final event = data["이벤트"] as String? ?? "이벤트 없음";  // "문 열림"/"문 닫힘"
      final state = data["상태"]  as String? ?? "UNKNOWN";

      // 루틴 전송 직후에는 문 이벤트가 바뀔 때까지 무시
      if (_suppressUntilDoorChange) {
        final doorChanged = (_lastEvent == null) ? true : (_lastEvent != event);
        if (!doorChanged) return;
        _suppressUntilDoorChange = false;
      }

      // 같은 이벤트/상태면 무시
      if (_lastEvent == event && _lastState == state) return;

      _lastEvent = event;
      _lastState = state;

      final detected = List<String>.from(data["감지됨"] ?? []);
      final missed   = List<String>.from(data["누락됨"] ?? []);
      final timestamp = DateTime.now().toIso8601String();

      // 기록 저장
      RecordStorageHelper.addRecord({
        "timestamp": timestamp,
        "event": event,
        "state": state,
        "detected": detected,
        "missed": missed,
      });

      // 화면 반영: 루틴 항목만
      setState(() {
        for (final item in _routineItems) {
          if (detected.contains(item.name)) {
            item.isChecked = true;
            item.isBleDetected = true;
          } else if (missed.contains(item.name)) {
            item.isChecked = false;
            item.isBleDetected = false;
          } else {
            // 감지도 누락도 안온 항목은 상태 유지
          }
        }
      });

      // 스낵바: 문 이벤트 변화가 있을 때만, 누락 있을 때 띄움
      if (missed.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ 감지 안 된 항목: ${missed.join(', ')}'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // 파싱 실패는 조용히 로그만
      // print("❌ Notify JSON 파싱 실패: $e");
    }
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
              await _loadRoutineForSelectedDay();
            },
            selectedColor: Colors.green,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoutineSection() {
    if (_routineItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('루틴에 등록된 물건이 없어요. 설정 > 루틴 설정에서 추가해 주세요.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('✅ 루틴 물건 ($_selectedDay요일)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ..._routineItems.map((item) => CheckboxListTile(
          title: Text(
            item.name,
            style: TextStyle(
              color: (item.bleUuid != null && !item.isBleDetected) ? Colors.red : null,
              fontWeight: item.isBleDetected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: item.isBleDetected
              ? const Text('✅ BLE 감지됨')
              : (item.bleUuid == null ? const Text('⚠️ 이 항목은 BLE 태그가 설정되지 않았어요') : null),
          value: item.isChecked,
          onChanged: (_) {
            setState(() => item.isChecked = !item.isChecked);
          },
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final formattedDate = DateFormat('yyyy/MM/dd (E)', 'ko_KR').format(today);

    return Scaffold(
      appBar: AppBar(title: Text('오늘의 체크리스트 - $formattedDate')),
      body: Column(
        children: [
          _buildDaySelector(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _sendRoutineToEsp32,
                icon: const Icon(Icons.sync),
                label: const Text('BLE로 루틴 전송'),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildRoutineSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
