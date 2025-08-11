import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // flutterfire configure가 생성
// recommendation_service.dart

import 'package:grabbit_project/screen/login_screen.dart';
import 'package:grabbit_project/screen/main_tab_screen.dart';
import 'package:grabbit_project/service/notification_service.dart';

class SplashScreen extends StatelessWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // (선택) 스플래시 로고 미리 로드
      // precacheImage(const AssetImage('assets/grabbit_logo.png'), context);

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
          // 🔴 경로 수정: lib/assets → assets
          'assets/grabbit_logo.png',
          width: 220,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔴 Firebase 초기화: google-services.json + flutterfire 설정이 있다면 반드시 호출
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 한국어 날짜 포맷 초기화
  await initializeDateFormatting('ko_KR', null);

  // 알림 초기화 및 매일 리마인더
  await NotificationService.initialize();
  await NotificationService.scheduleDailyChecklistReminder();

  // 자동로그인 상태 로드
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
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.green, foregroundColor: Colors.white),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green, foregroundColor: Colors.white),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
      ),
    );

    final afterSplash = isLoggedIn ? const MainTabScreen() : const LoginScreen();

    return MaterialApp(
      title: 'Grabbit',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(next: afterSplash),
    );
  }
}

