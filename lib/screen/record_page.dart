import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:grabbit_project/utils/record_storage_helper.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final loaded = await RecordStorageHelper.loadRecords();
    if (!mounted) return;
    setState(() {
      _records = loaded;
    });
  }

  Future<void> _clearAll() async {
    await RecordStorageHelper.clearRecords();
    await _loadRecords();
  }

  Future<void> _deleteOne(int index) async {
    setState(() {
      _records.removeAt(index);
    });
    await RecordStorageHelper.saveRecords(_records);
  }

  String _formatTime(String isoTime) {
    final dt = DateTime.tryParse(isoTime);
    return dt == null ? '알 수 없음' : DateFormat('yyyy.MM.dd HH:mm').format(dt);
  }

  /// 상태 코드 → 표시 문자열 매핑
  String _displayState(String raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'GOING_OUT':
        return '외출 준비🐰';
      case 'AWAY':
        return '외출🐰';
      case 'RETURNED':
        return '귀가 중🐰';
      case 'IDLE':
        return '🏠';
      default:
        return raw?.isNotEmpty == true ? raw : '상태 없음';
    }
  }

  /// "문 열림/문 닫힘" 같은 문구는 아예 숨김
  String _sanitizeEvent(String? event) {
    if (event == null) return '';
    final e = event.replaceAll(' ', '');
    if (e.contains('문열림') || e.contains('문닫힘')) {
      return '';
    }
    return event;
  }

  Widget _buildRecord(Map<String, dynamic> record, int index) {
    // final event = record["event"] ?? "이벤트 없음";  // ← 사용 안 함(숨김)
    final state = record["state"] ?? "상태 없음";
    final detected = List<String>.from(record["detected"] ?? []);
    final missed = List<String>.from(record["missed"] ?? []);
    final timeStr = _formatTime(record["timestamp"] ?? "");

    // 제목은 상태만 보이도록 변경 (문 열림/닫힘 제거)
    final titleStr = _displayState(state);

    // 필요 시 다른 이벤트를 쓰고 싶다면 아래처럼 사용:
    // final otherEvent = _sanitizeEvent(record["event"]);
    // final titleStr = otherEvent.isEmpty ? _displayState(state) : '[$otherEvent] ${_displayState(state)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(titleStr, style: const TextStyle(fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("⏰ $timeStr"),
            if (detected.isNotEmpty) Text("🟢 감지됨: ${detected.join(', ')}"),
            if (missed.isNotEmpty) Text("🔴 누락됨: ${missed.join(', ')}"),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteOne(index),
          tooltip: '이 기록 삭제',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = _records.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text("📋 알림 기록"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: hasAny
                ? () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("기록 삭제"),
                  content: const Text("모든 기록을 삭제할까요?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("취소"),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _clearAll();
                      },
                      child: const Text("삭제"),
                    ),
                  ],
                ),
              );
            }
                : null,
            tooltip: '모든 기록 삭제',
          )
        ],
      ),
      body: hasAny
          ? ListView.builder(
        itemCount: _records.length,
        itemBuilder: (_, index) => _buildRecord(_records[index], index),
      )
          : const Center(child: Text("저장된 기록이 없어요.")),
    );
  }
}
