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
    setState(() {
      _records = loaded;
    });
  }

  Future<void> _clearAll() async {
    await RecordStorageHelper.clearRecords();
    _loadRecords();
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

  Widget _buildRecord(Map<String, dynamic> record, int index) {
    final event = record["event"] ?? "이벤트 없음";
    final state = record["state"] ?? "상태 없음";
    final detected = List<String>.from(record["detected"] ?? []);
    final missed = List<String>.from(record["missed"] ?? []);
    final timeStr = _formatTime(record["timestamp"] ?? "");

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text("[$event] $state"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("⏰ $timeStr"),
            if (detected.isNotEmpty)
              Text("🟢 감지됨: ${detected.join(', ')}"),
            if (missed.isNotEmpty)
              Text("🔴 누락됨: ${missed.join(', ')}"),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteOne(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📋 알림 기록"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _records.isEmpty
                ? null
                : () {
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
                      onPressed: () {
                        Navigator.pop(context);
                        _clearAll();
                      },
                      child: const Text("삭제"),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: _records.isEmpty
          ? const Center(child: Text("저장된 기록이 없어요."))
          : ListView.builder(
        itemCount: _records.length,
        itemBuilder: (_, index) => _buildRecord(_records[index], index),
      ),
    );
  }
}