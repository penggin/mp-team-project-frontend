import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:sqflite/sqflite.dart';
import 'services/notification_processing.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PaymentTaskHandler());
}

class PaymentTaskHandler extends TaskHandler {
  bool _listenerStarted = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('백그라운드 서비스 시작');
    await _initDB();
    await _startNotificationListener();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}

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

    NotificationListenerService.notificationsStream.listen(
      _processNotification,
    );
  }

  Future<void> _processNotification(ServiceNotificationEvent event) async {
    final candidate = NotificationProcessing.candidateFromEvent(event);
    if (candidate == null) return;

    final parsed = _parsePaymentMessage(candidate.rawText);
    if (parsed != null) {
      await _saveToLocalDB(parsed);
      FlutterForegroundTask.sendDataToMain(parsed);
    }
  }

  Map<String, dynamic>? _parsePaymentMessage(String text) {
    if (text.isEmpty) return null;
    return {'content': text, 'category': '미분류'};
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
