import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/splash_screen.dart'; // ✅ login_screen → splash_screen 으로 변경
import 'app_colors.dart';
import 'services/api_service.dart';
import 'services/notification_processing.dart';
import 'services/sms_event_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'payment_tracker',
      channelName: '결제 감지 중',
      channelDescription: '결제 내역을 자동으로 기록합니다',
      onlyAlertOnce: true,
      playSound: false,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(15000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
    ),
  );

  unawaited(SmsEventService.startListening(_handleIncomingSms));

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MoneyTrackerApp(),
    ),
  );
}

Future<void> _handleIncomingSms(SmsEvent event) async {
  final text = event.body.trim();
  if (!NotificationProcessing.isPaymentText(text)) return;

  print('SMS 감지(event): $text');

  final parsed = await ApiService.parseTransaction(text);
  if (parsed == null) return;

  await ApiService.createLedgerEntry(parsed);
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
      home: const SplashScreen(), // ✅ 변경
      debugShowCheckedModeBanner: false,
    );
  }
}
