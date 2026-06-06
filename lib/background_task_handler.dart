import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/notification_processing.dart';
import 'services/payment_ingestion_workflow.dart';
import 'services/payment_push_notification_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  DartPluginRegistrant.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(PaymentTaskHandler());
}

typedef TokenLifecycleMaintainer = Future<bool> Function();
typedef PaymentCandidateProcessor =
    Future<PaymentIngestionResult> Function(PaymentNotificationCandidate);
typedef TaskDataSender = void Function(Object data);

class PaymentTaskHandler extends TaskHandler {
  PaymentTaskHandler({
    TokenLifecycleMaintainer? tokenLifecycleMaintainer,
    PaymentCandidateProcessor? candidateProcessor,
    PaymentPushNotificationService? pushNotificationService,
    TaskDataSender? sendDataToMain,
  }) : _tokenLifecycleMaintainer = tokenLifecycleMaintainer,
       _candidateProcessor = candidateProcessor,
       _pushNotificationService =
           pushNotificationService ?? PaymentPushNotificationService.instance,
       _sendDataToMain = sendDataToMain ?? FlutterForegroundTask.sendDataToMain;

  final TokenLifecycleMaintainer? _tokenLifecycleMaintainer;
  final PaymentCandidateProcessor? _candidateProcessor;
  final PaymentPushNotificationService _pushNotificationService;
  final TaskDataSender _sendDataToMain;

  bool _listenerStarted = false;
  StreamSubscription<ServiceNotificationEvent>? _notificationSubscription;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('백그라운드 서비스 시작');
    await _maintainTokenLifecycle();
    await _startNotificationListener();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    await _maintainTokenLifecycle();
    await _startNotificationListener();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _listenerStarted = false;
    debugPrint('백그라운드 서비스 종료');
  }

  Future<void> _startNotificationListener() async {
    if (_listenerStarted) return;

    final hasPermission =
        await NotificationListenerService.isPermissionGranted();
    if (!hasPermission) {
      debugPrint('알림 리스너 권한 없음 — 다음 반복 이벤트에서 재시도');
      return;
    }

    _listenerStarted = true;
    await _notificationSubscription?.cancel();
    _notificationSubscription = NotificationListenerService.notificationsStream
        .listen(
          _processNotification,
          onError: (e) {
            debugPrint('알림 스트림 에러: $e');
            _listenerStarted = false;
          },
          onDone: () {
            debugPrint('알림 스트림 종료 — 재연결 대기 중');
            _listenerStarted = false;
          },
        );
    debugPrint('알림 리스너 시작됨');
  }

  Future<bool> _maintainTokenLifecycle() async {
    final tokenLifecycleMaintainer = _tokenLifecycleMaintainer;
    if (tokenLifecycleMaintainer != null) {
      return tokenLifecycleMaintainer();
    }

    final hasToken = await ApiService.hasValidToken();
    if (!hasToken) {
      debugPrint('백그라운드 인증 만료: 다시 로그인이 필요합니다');
      _sendDataToMain({'action': 'authExpired'});
    }
    return hasToken;
  }

  @visibleForTesting
  Future<void> processNotificationForTest(ServiceNotificationEvent event) {
    return _processNotification(event);
  }

  Future<void> _processNotification(ServiceNotificationEvent event) async {
    final candidate = NotificationProcessing.candidateFromEvent(event);
    if (candidate == null) return;
    if (!await _maintainTokenLifecycle()) return;

    debugPrint('백그라운드 알림 감지: ${candidate.rawText}');

    // GPS 좌표 조회 (카테고라이징 정밀도 향상용, 실패 시 null로 진행)
    final coords = await LocationService.currentCoordinates();

    final candidateProcessor = _candidateProcessor;
    final result = await (candidateProcessor != null
        ? candidateProcessor(candidate)
        : PaymentIngestionWorkflow.processCandidate(
            candidate,
            x: coords.x,
            y: coords.y,
          ));
    if (!result.saved) {
      debugPrint('백그라운드 알림 처리 결과: ${result.status.name}');
      return;
    }

    try {
      await _pushNotificationService.showSavedPayment(result);
    } catch (e) {
      debugPrint('백그라운드 결제 처리 알림 전송 실패: $e');
    }

    // UI 측에 갱신 신호 전송
    _sendDataToMain({'action': 'refresh'});
  }
}
