import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart'; // 날짜 포맷용
import 'package:grabbit_project/screen/login_screen.dart';
import 'package:grabbit_project/screen/main_tab_screen.dart';
import 'package:grabbit_project/service/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📅 한국어 날짜 포맷 초기화
  await initializeDateFormatting('ko_KR', null);

  // 🔔 알림 초기화 및 예약
  await NotificationService.initialize();
  await NotificationService.scheduleDailyChecklistReminder();

  // 🧠 SharedPreferences 로드
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isAutoLoginOn') ?? false;

  runApp(GrabbitApp(isLoggedIn: isLoggedIn));
}

class GrabbitApp extends StatelessWidget {
  final bool isLoggedIn;
  const GrabbitApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grabbit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: isLoggedIn ? const MainTabScreen() : const LoginScreen(),
    );
  }
}