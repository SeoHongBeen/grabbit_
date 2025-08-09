import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:grabbit_project/models/item.dart';
import 'package:grabbit_project/models/ble_tag.dart';
import 'package:grabbit_project/service/routine_manager.dart';
import 'package:grabbit_project/service/ble_service.dart';
import 'package:grabbit_project/utils/shared_preferences_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// 기록 저장
import 'package:grabbit_project/utils/record_storage_helper.dart';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  // 최근 문 이벤트/상태
  String? _lastEvent; // "문 열림" | "문 닫힘"
  String? _lastState; // IDLE/GOING_OUT/AWAY/RETURNED

  // 루틴 전송 직후, 문 이벤트가 바뀔 때까지 화면 반영/스낵바 억제
  bool _suppressUntilDoorChange = false;

  // AWAY 상태에서 “이전 감지 집합” (감지 수 감소 = 분실)
  Set<String>? _awayDetectedSnapshot;

  final List<ChecklistItem> _items = [];
  final TextEditingController _textController = TextEditingController();
  String _selectedDay = DateFormat.E('ko_KR').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _initializeForSelectedDay();

    final ble = BleService();
    ble.connect();
    ble.onDataReceived = _handleNotifyData; // Notify 수신 → 화면 반영
  }

  void _initializeForSelectedDay() {
    _items.clear();
    _items.addAll([
      ChecklistItem(name: '우산', isSuggested: true),
      ChecklistItem(name: '손세정제', isSuggested: true),
    ]);
    _loadBleTags();
    _loadExtraItems();
  }

  void _loadBleTags() async {
    final tags = await SharedPreferencesHelper.loadBleTags();
    setState(() {
      for (var tag in tags) {
        final alreadyExists = _items.any((item) => item.bleUuid == tag.uuid);
        if (!alreadyExists) {
          _items.add(ChecklistItem(name: tag.name, bleUuid: tag.uuid));
        }
      }
    });
  }

  Future<void> _loadExtraItems() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'extraItems_${_engWeekday()}';
    final saved = prefs.getStringList(key) ?? [];
    setState(() {
      for (var name in saved) {
        _items.add(ChecklistItem(name: name));
      }
    });
  }

  Future<void> _saveExtraItems() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'extraItems_${_engWeekday()}';
    final extraItems = _items
        .where((i) => !i.isRoutine && !i.isSuggested && i.bleUuid == null)
        .map((e) => e.name)
        .toList();
    await prefs.setStringList(key, extraItems);
  }

  String _engWeekday() {
    const map = {
      '월': 'Monday',
      '화': 'Tuesday',
      '수': 'Wednesday',
      '목': 'Thursday',
      '금': 'Friday',
      '토': 'Saturday',
      '일': 'Sunday',
    };
    return map[_selectedDay]!;
  }

  void _toggleItem(ChecklistItem item) {
    setState(() {
      item.isChecked = !item.isChecked;
    });
  }

  void _addItem() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _items.add(ChecklistItem(name: text));
        _textController.clear();
      });
      _saveExtraItems();
    }
  }

  void _deleteItem(ChecklistItem item) {
    setState(() {
      _items.remove(item);
    });
    _saveExtraItems();
  }

  Widget _buildSection(String title, List<ChecklistItem> items, {bool editable = false}) {
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...items.map((item) => CheckboxListTile(
          title: Text(
            item.name,
            style: TextStyle(
              color: item.bleUuid != null && !item.isBleDetected ? Colors.red : null,
              fontWeight: item.isBleDetected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: item.isBleDetected ? const Text('✅ BLE 감지됨') : null,
          value: item.isChecked,
          onChanged: (_) => _toggleItem(item),
          secondary: editable
              ? IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteItem(item),
          )
              : null,
        )),
      ],
    );
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
            onSelected: (_) {
              setState(() {
                _selectedDay = day;
                _initializeForSelectedDay();
              });
            },
            selectedColor: Colors.green,
          );
        }).toList(),
      ),
    );
  }

  void _sendRoutineToEsp32() async {
    final itemsToSend = _items
        .where((item) => item.bleUuid != null)
        .map((item) => item.name)
        .toList();

    _suppressUntilDoorChange = true; // 문 이벤트 바뀔 때까지 일반 반영/스낵바 억제
    await BleService().sendRoutine(itemsToSend, "grabbit-user");

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📤 루틴 정보를 ESP32에 전송했어요!')),
      );
    }
  }

  /// ESP32에서 Notify 받은 JSON 처리
  void _handleNotifyData(String jsonStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final event = data["이벤트"] as String? ?? "이벤트 없음";  // "문 열림"/"문 닫힘"
      final state = data["상태"]  as String? ?? "UNKNOWN";
      final detected = List<String>.from(data["감지됨"] ?? []);
      final missed   = List<String>.from(data["누락됨"] ?? []);
      final timestamp = DateTime.now().toIso8601String();

      // ---------- 0) 기록은 항상 저장 ----------
      RecordStorageHelper.addRecord({
        "timestamp": timestamp,
        "event": event,
        "state": state,
        "detected": detected,
        "missed": missed,
      });

      // ---------- 1) AWAY 중 “감지 수 감소” = 외출 중 분실 감지 ----------
      if (state == "AWAY") {
        final curr = detected.toSet();
        if (_lastState != "AWAY") {
          // AWAY에 갓 진입 → 스냅샷 초기화
          _awayDetectedSnapshot = curr;
        } else {
          // 이전에 감지되던 것이 사라졌는지 비교
          if (_awayDetectedSnapshot != null) {
            final lostNow = _awayDetectedSnapshot!.difference(curr).toList();
            if (lostNow.isNotEmpty && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ 외출 중 분실 감지: ${lostNow.join(", ")}'),
                  backgroundColor: Colors.orange.shade600,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
          _awayDetectedSnapshot = curr; // 스냅샷 갱신
        }
      }

      // ---------- 2) 루틴 전송 직후, 문 이벤트가 바뀔 때까지 일반 반영 억제 ----------
      final doorChanged = (_lastEvent == null) ? true : (_lastEvent != event);
      if (_suppressUntilDoorChange && !doorChanged) {
        // 분실 감지는 위에서 이미 처리했으니 여기서는 조용히 종료
        return;
      }
      if (_suppressUntilDoorChange && doorChanged) {
        _suppressUntilDoorChange = false; // 게이트 해제
      }

      // ---------- 3) 이벤트/상태 둘 다 이전과 같으면(중복) 일반 반영 생략 ----------
      if (_lastEvent == event && _lastState == state) {
        // 단, 위의 분실 감지는 이미 처리됨
        return;
      }

      // ---------- 4) 화면 반영 ----------
      setState(() {
        for (var item in _items) {
          if (detected.contains(item.name)) {
            item.isChecked = true;
            item.isBleDetected = true;
          } else if (missed.contains(item.name)) {
            item.isChecked = false;
            item.isBleDetected = false;
          }
        }
      });

      // 문 이벤트 변화 시 “감지 안 된 항목” 스낵바 (일반 케이스)
      if (doorChanged && missed.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ 감지 안 된 항목: ${missed.join(', ')}'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // ---------- 5) 마지막 상태 저장 ----------
      _lastEvent = event;
      _lastState = state;
    } catch (e) {
      // JSON 깨짐 등
      debugPrint("❌ Notify JSON 파싱 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final formattedDate = DateFormat('yyyy/MM/dd (E)', 'ko_KR').format(today);

    final routineItems = RoutineManager().getItemsForDay(_selectedDay);
    final additionalItems = _items.where((i) => !i.isRoutine && !i.isSuggested).toList();
    final suggestedItems = _items.where((i) => i.isSuggested).toList();

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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '추가 물건 입력',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addItem,
                  child: const Text('추가'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildSection('✅ 루틴 물건 ($_selectedDay요일)', routineItems),
                _buildSection('➕ 추가 물건', additionalItems, editable: true),
                _buildSection('🌟 추천 물건', suggestedItems),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
