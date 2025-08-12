import 'package:flutter/material.dart';
import 'checklist_page.dart';
import 'record_page.dart';
import 'settings/settings_page.dart';
import 'package:grabbit_project/screen/daily_suggest.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [ChecklistPage(), RecordPage(), SettingsPage()];

  @override
  void initState() {
    super.initState();
    // 프레임 이후 실행 + State.mounted로만 체크 (context.mounted 쓰지 않음)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await DailySuggest.showIfNeeded(context, 'qhPEkSGHK9PsfmUD4Yyg6YOp8c63');
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box),
            label: '체크리스트',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: '알림기록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
