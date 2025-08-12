import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'package:grabbit_project/screen/login_screen.dart';
import 'package:grabbit_project/screen/main_tab_screen.dart';
import 'package:grabbit_project/service/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SplashScreen extends StatelessWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  Widget build(BuildContext context) {
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

  await initializeDateFormatting('ko_KR', null);

  await NotificationService.initialize();
  await NotificationService.scheduleDailyChecklistReminder();

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
      navigatorKey: navigatorKey,
      home: SplashScreen(next: afterSplash),
    );
  }
}
