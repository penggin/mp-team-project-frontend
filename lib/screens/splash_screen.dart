import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    // 스플래시가 너무 빨리 사라지지 않도록 짧은 딜레이
    await Future.delayed(const Duration(milliseconds: 600));

    final hasToken = await ApiService.hasValidToken();
    if (!mounted) return;

    if (hasToken) {
      // 토큰 있음 → 메인 화면으로 바로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      // 토큰 없음 → 로그인 화면으로
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon.png', width: 140, height: 140),
            const SizedBox(height: 40),
            CircularProgressIndicator(color: colors.primaryText),
          ],
        ),
      ),
    );
  }
}