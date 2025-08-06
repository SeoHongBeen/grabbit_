import 'package:flutter/material.dart';
import 'routine_settings_page.dart';
import 'ble_settings_page.dart';
import 'notification_settings_page.dart';
import 'environment_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('루틴 설정'),
            onTap: () => _navigate(context, const RoutineSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('BLE 태그 설정'),
            onTap: () => _navigate(context, const BleSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('알림 설정'),
            onTap: () => _navigate(context, const NotificationSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('환경 설정'),
            onTap: () => _navigate(context, const EnvironmentSettingsPage()),
          ),
        ],
      ),
    );
  }
}