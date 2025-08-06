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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isNotificationOn = prefs.getBool('isNotificationOn') ?? true;
      isRecommendationOn = prefs.getBool('isRecommendationOn') ?? true;
      isReminderTextOn = prefs.getBool('isReminderTextOn') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
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
        ],
      ),
    );
  }
}