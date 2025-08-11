// lib/screen/daily_suggest.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grabbit_project/service/recommendation_service.dart';

import 'package:grabbit_project/service/ble_service.dart'; // 전송 붙일 때 사용

class DailySuggest {
  static String _key(String uid, DateTime d)
  => 'daily-suggest-$uid-${d.year}-${d.month}-${d.day}';

  static Future<void> showIfNeeded(BuildContext context, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(uid, DateTime.now());
    if (prefs.getBool(key) == true) return;

    final items = await RecommendationService.fetchLatest(uid);
    if (items.isEmpty) { await prefs.setBool(key, true); return; }

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('앗! 오늘 추천 아이템', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...items.map((m) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline),
                title: Text((m['name'] ?? '').toString()),
                subtitle: (m['required'] == true)
                    ? const Text('필수', style: TextStyle(color: Colors.red))
                    : null,
              )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('오늘은 그만보기'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        // BLE로 전송하려면 주석 해제
                        // await BleService.instance.sendRoutine(items);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.bluetooth),
                      label: const Text('BLE로 바로 전송'),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );

    await prefs.setBool(key, true); // 오늘은 1회만
  }
}
