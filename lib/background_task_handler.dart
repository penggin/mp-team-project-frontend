import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'services/api_service.dart';
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
    await _startNotificationListener();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('백그라운드 서비스 종료');
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

    debugPrint('백그라운드 알림 감지: ${candidate.rawText}');

    final parsed = await ApiService.parseTransaction(candidate.rawText);
    if (parsed == null) return;

    final saved = await ApiService.createLedgerEntry(parsed);
    if (!saved) return;

    // UI 측에 갱신 신호 전송
    FlutterForegroundTask.sendDataToMain({'action': 'refresh'});
  }
}
