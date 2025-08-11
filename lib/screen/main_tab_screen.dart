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

  final List<Widget> _pages = const [
    ChecklistPage(),
    RecordPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // uid는 로그인 정보에서 가져오거나 로컬 저장된 사용자 ID 사용
      DailySuggest.showIfNeeded(context, 'user123');
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
