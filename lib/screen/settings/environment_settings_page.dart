import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_screen.dart';

class EnvironmentSettingsPage extends StatefulWidget {
  const EnvironmentSettingsPage({super.key});

  @override
  State<EnvironmentSettingsPage> createState() => _EnvironmentSettingsPageState();
}

class _EnvironmentSettingsPageState extends State<EnvironmentSettingsPage> {
  bool isWeatherSyncOn = true;
  double uvThreshold = 6.0;
  bool isAutoLoginOn = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isWeatherSyncOn = prefs.getBool('isWeatherSyncOn') ?? true;
      uvThreshold = prefs.getDouble('uvThreshold') ?? 6.0;
      isAutoLoginOn = prefs.getBool('isAutoLoginOn') ?? false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  void _showUvDialog() async {
    double tempValue = uvThreshold;
    double? result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('자외선 기준값 설정'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: 11,
                divisions: 11,
                value: tempValue,
                label: tempValue.toStringAsFixed(1),
                onChanged: (val) => setState(() => tempValue = val),
              ),
              Text("현재 설정: ${tempValue.toStringAsFixed(1)}"),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          TextButton(onPressed: () => Navigator.pop(context, tempValue), child: const Text("확인")),
        ],
      ),
    );

    if (result != null) {
      setState(() => uvThreshold = result);
      _saveSetting('uvThreshold', result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('환경 설정')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('현재 위치 기반 날씨 연동'),
            value: isWeatherSyncOn,
            onChanged: (val) {
              setState(() => isWeatherSyncOn = val);
              _saveSetting('isWeatherSyncOn', val);
            },
          ),
          ListTile(
            title: const Text('자외선 기준값 설정'),
            subtitle: Text("현재 기준: ${uvThreshold.toStringAsFixed(1)}"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _showUvDialog,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('자동 로그인'),
            value: isAutoLoginOn,
            onChanged: (val) {
              setState(() => isAutoLoginOn = val);
              _saveSetting('isAutoLoginOn', val);
            },
          ),
          const Divider(),
          ListTile(
            title: const Center(
              child: Text("로그아웃", style: TextStyle(color: Colors.red)),
            ),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}