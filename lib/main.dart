// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'package:grabbit_project/screen/login_screen.dart';
import 'package:grabbit_project/screen/main_tab_screen.dart';
import 'package:grabbit_project/service/notification_service.dart';

/// 전역 navigatorKey: 어떤 화면에서도 스낵바/다이얼로그 띄우기 위함
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 간단한 페이드 스플래시
class SplashScreen extends StatelessWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  Widget build(BuildContext context) {
    // 첫 프레임 이후 1.2초 기다렸다가 화면 전환
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, __, ___) => next,
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          // 현재 트리 기준: lib/assets/grabbit_logo.png
          'lib/assets/grabbit_logo.png',
          width: 220,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 로케일 데이터 (ko_KR 날짜 포맷)
  await initializeDateFormatting('ko_KR', null);

  // 로컬 알림 초기화 + 매일 체크리스트 알림 스케줄
  await NotificationService.initialize();
  await NotificationService.scheduleDailyChecklistReminder();

  // 자동로그인 플래그
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isAutoLoginOn') ?? false;

  runApp(GrabbitApp(isLoggedIn: isLoggedIn));
}

class GrabbitApp extends StatelessWidget {
  final bool isLoggedIn;
  const GrabbitApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
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
    );

    final afterSplash =
    isLoggedIn ? const MainTabScreen() : const LoginScreen();

    return MaterialApp(
      title: 'Grabbit',
      theme: theme,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // 전역 스낵바/다이얼로그용
      home: SplashScreen(next: afterSplash),
    );
  }
}
