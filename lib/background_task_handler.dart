import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PaymentTaskHandler());
}

class PaymentTaskHandler extends TaskHandler {
  int _smsCheckCount = 0;
  bool _listenerStarted = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('백그라운드 서비스 시작');
    await _initDB();
    await _startNotificationListener();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    _smsCheckCount++;

    if (_smsCheckCount >= 20) {
      await _checkNewSms();
      _smsCheckCount = 0;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('백그라운드 서비스 종료');
  }

  Future<void> _initDB() async {
    final db = await openDatabase(
      'payments.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT,
            category TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
    await db.close();
  }

  Future<void> _startNotificationListener() async {
    if (_listenerStarted) return;
    _listenerStarted = true;

    NotificationListenerService.notificationsStream.listen((event) async {
      final parsed = _parsePaymentMessage(event.content ?? '');
      if (parsed != null) {
        await _saveToLocalDB(parsed);
        FlutterForegroundTask.sendDataToMain(parsed);
      }
    });
  }

  Future<void> _checkNewSms() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt('last_sms_check') ?? 0;

    final query = SmsQuery();
    final messages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 20,
    );

    for (final sms in messages) {
      final smsTime = sms.date?.millisecondsSinceEpoch ?? 0;
      if (smsTime <= lastCheck) continue;

      final body = sms.body ?? '';
      if (!_isPaymentSms(body)) continue;

      final parsed = _parsePaymentMessage(body);
      if (parsed != null) {
        await _saveToLocalDB(parsed);
        FlutterForegroundTask.sendDataToMain(parsed);
      }
    }

    await prefs.setInt(
      'last_sms_check',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool _isPaymentSms(String text) {
    return text.contains('원 승인') ||
        text.contains('원 결제') ||
        text.contains('출금완료');
  }

  Map<String, dynamic>? _parsePaymentMessage(String text) {
    if (text.isEmpty) return null;
    return {
      'content': text,
      'category': '미분류',
    };
  }

  Future<void> _saveToLocalDB(Map<String, dynamic> data) async {
    final db = await openDatabase('payments.db');
    await db.insert('payments', {
      'content': data['content'],
      'category': data['category'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await db.close();
  }
}
