import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool isNotificationOn = true;
  bool isRecommendationOn = true;
  bool isReminderTextOn = true;

  // 문구 템플릿
  final _goingOutCtrl = TextEditingController();
  final _returnedCtrl = TextEditingController();

  // 기본 템플릿(서비스와 동일)
  static const String _defaultGoingOut =
      '앗! 챙기셨나요? 🐰 {items} · 외출 중';
  static const String _defaultReturned =
      '귀가 · 외출 중 분실 감지 ⚠️ {items}';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _goingOutCtrl.dispose();
    _returnedCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isNotificationOn = prefs.getBool('isNotificationOn') ?? true;
      isRecommendationOn = prefs.getBool('isRecommendationOn') ?? true;
      isReminderTextOn = prefs.getBool('isReminderTextOn') ?? true;

      _goingOutCtrl.text =
          prefs.getString('templateGoingOut') ?? _defaultGoingOut;
      _returnedCtrl.text =
          prefs.getString('templateReturned') ?? _defaultReturned;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('templateGoingOut', _goingOutCtrl.text.trim());
    await prefs.setString('templateReturned', _returnedCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('알림 문구 저장 완료')));
  }

  Future<void> _restoreDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('templateGoingOut', _defaultGoingOut);
    await prefs.setString('templateReturned', _defaultReturned);
    setState(() {
      _goingOutCtrl.text = _defaultGoingOut;
      _returnedCtrl.text = _defaultReturned;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('기본 문구로 복원했어요')));
  }

  String _preview(String template) {
    const sample = ['지갑', '에어팟']; // 미리보기용
    return template.replaceAll('{items}', sample.join(', '));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 설정'),
        actions: [
          TextButton.icon(
            onPressed: _saveTemplates,
            icon: const Icon(Icons.save),
            label: const Text('저장'),
          )
        ],
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('전체 알림 받기'),
            value: isNotificationOn,
            onChanged: (val) {
              setState(() => isNotificationOn = val);
              _saveSetting('isNotificationOn', val);
            },
          ),
          SwitchListTile(
            title: const Text('추천 물건 알림 받기'),
            value: isRecommendationOn,
            onChanged: (val) {
              setState(() => isRecommendationOn = val);
              _saveSetting('isRecommendationOn', val);
            },
          ),
          SwitchListTile(
            title: const Text('“물건 챙기세요!” 알림 받기'),
            value: isReminderTextOn,
            onChanged: (val) {
              setState(() => isReminderTextOn = val);
              _saveSetting('isReminderTextOn', val);
            },
          ),

          const Divider(height: 24),

          // ===== 인앱 알림 문구 커스터마이즈 =====
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '상단 알림 문구 설정',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '• {items} 에 누락 물품 목록이 들어갑니다.\n'
                  '• 예: "앗! 챙기셨나요? 🐰 {items} · 외출 중"',
              style: TextStyle(color: Colors.black54),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _goingOutCtrl,
              decoration: const InputDecoration(
                labelText: '외출 중(GOING_OUT) 알림 문구',
                hintText: '앗! 챙기셨나요? 🐰 {items} · 외출 중',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 2,
              onSubmitted: (_) => _saveTemplates(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Text(
              '미리보기: ${_preview(_goingOutCtrl.text)}',
              style: const TextStyle(color: Colors.black54),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _returnedCtrl,
              decoration: const InputDecoration(
                labelText: '귀가(RETURNED) 알림 문구',
                hintText: '귀가 · 외출 중 분실 감지 ⚠️ {items}',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 2,
              onSubmitted: (_) => _saveTemplates(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Text(
              '미리보기: ${_preview(_returnedCtrl.text)}',
              style: const TextStyle(color: Colors.black54),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _saveTemplates,
                  icon: const Icon(Icons.save),
                  label: const Text('문구 저장'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _restoreDefaults,
                  icon: const Icon(Icons.restore),
                  label: const Text('기본값 복원'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
