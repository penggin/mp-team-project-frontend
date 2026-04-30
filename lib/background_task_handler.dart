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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('백그라운드 서비스 시작');
    await _initDB();
    await _startNotificationListener();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    _smsCheckCount++;

    // 15초 * 20 = 5분마다 SMS 체크
    if (_smsCheckCount >= 20) {
      await _checkNewSms();
      _smsCheckCount = 0;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('백그라운드 서비스 종료');
  }

  // DB 초기화
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

  // 알림 리스너 시작
  Future<void> _startNotificationListener() async {
    NotificationListenerService.notificationsStream.listen((event) {

      // ── 필터링 버전 (실배포 시 아래 주석 해제) ──────────────────
      // if (!_isPaymentApp(event.packageName)) return;
      // ────────────────────────────────────────────────────────────

      // 모든 알림 수신 (테스트용)
      final parsed = _parsePaymentMessage(event.content ?? '');
      if (parsed != null) {
        _saveToLocalDB(parsed);
        FlutterForegroundTask.sendDataToMain(parsed);
      }
    });
  }

  // SMS 체크
  Future<void> _checkNewSms() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt('last_sms_check') ?? 0;

    final query = SmsQuery();
    final messages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 20,
    );

    for (var sms in messages) {
      final smsTime = sms.date?.millisecondsSinceEpoch ?? 0;
      if (smsTime <= lastCheck) continue;

      final body = sms.body ?? '';
      if (!_isPaymentSms(body)) continue;

      final parsed = _parsePaymentMessage(body);
      if (parsed != null) {
        _saveToLocalDB(parsed);
        FlutterForegroundTask.sendDataToMain(parsed);
      }
    }

    await prefs.setInt(
      'last_sms_check',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── 결제 앱 필터 (실배포 시 사용) ───────────────────────────────
  // bool _isPaymentApp(String? pkg) {
  //   const apps = [
  //     'com.kakao.talk',
  //     'viva.republica.toss',
  //     'com.nhn.android.naverpay',
  //   ];
  //   return apps.contains(pkg);
  // }
  // ────────────────────────────────────────────────────────────────

  // 결제 SMS 필터
  bool _isPaymentSms(String text) {
    return text.contains('원 승인') ||
        text.contains('원 결제') ||
        text.contains('출금완료');
  }

  // 메시지 파싱
  // ── 필터링 버전 (실배포 시 아래로 교체) ─────────────────────────
  // Map<String, dynamic>? _parsePaymentMessage(String text) {
  //   if (text.isEmpty) return null;
  //   if (!_isPaymentSms(text)) return null; // 결제 문자만 통과
  //   return {
  //     'content': text,
  //     'category': '미분류',
  //   };
  // }
  // ────────────────────────────────────────────────────────────────

  // 모든 알림 통과 (테스트용)
  Map<String, dynamic>? _parsePaymentMessage(String text) {
    if (text.isEmpty) return null;
    return {
      'content': text,
      'category': '미분류',
    };
  }

  // 로컬 DB에 저장
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