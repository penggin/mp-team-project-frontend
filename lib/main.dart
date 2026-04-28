import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart'; // 💡 처음 켜질 화면(Login)만 import 하면 됩니다!
import 'screens/settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MoneyTrackerApp(),
    ),
  );
}

class MoneyTrackerApp extends StatelessWidget {
  const MoneyTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '가계부 키우기',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}