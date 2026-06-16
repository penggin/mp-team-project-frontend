import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'services/api_service.dart';
import 'services/experience_service.dart';
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
  // 중복 처리 방지: 이미 처리 중인 핵결 텍스트 집합
  final Set<String> _processingFingerprints = {};
  // 최근 처리 완료 지문 (30초 내 동일 알림 재수신 방지)
  final Map<String, DateTime> _recentFingerprints = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('백그라운드 서비스 시작');
    await _maintainTokenLifecycle();
    await _startNotificationListener();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    await _maintainTokenLifecycle();
    // 스트림이 종료되었을 때만 재연결, 살아있으면 참여 안 함
    if (!_listenerStarted) {
      await _startNotificationListener();
    }
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

    // 기존 구독이 남아있으면 먼저 취소
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _listenerStarted = true;
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

    // 이미 처리 중이거나 30초 이내 중복 알림 방지
    final fp = candidate.fingerprint;
    final now = DateTime.now();
    if (_processingFingerprints.contains(fp)) {
      debugPrint('중복 알림 무시 (이미 처리 중): $fp');
      return;
    }
    final lastSeen = _recentFingerprints[fp];
    if (lastSeen != null && now.difference(lastSeen).inSeconds < 30) {
      debugPrint('중복 알림 무시 (30초 이내 재수신): $fp');
      return;
    }

    _processingFingerprints.add(fp);
    try {
      if (!await _maintainTokenLifecycle()) return;

      debugPrint('백그라운드 알림 감지: ${candidate.rawText}');

      final candidateProcessor = _candidateProcessor;
      final result = await (candidateProcessor != null
          ? candidateProcessor(candidate)
          : PaymentIngestionWorkflow.processCandidate(candidate));

      if (!result.saved) {
        debugPrint('백그라운드 알림 처리 결과: ${result.status.name}');
        return;
      }

      // 성공 시 지문 등록
      _recentFingerprints[fp] = now;
      // 오래된 지문 정리 (1분 이상 지난 항목)
      _recentFingerprints.removeWhere(
        (_, ts) => now.difference(ts).inSeconds >= 60,
      );

      try {
        await _pushNotificationService.showSavedPayment(result);
      } catch (e) {
        debugPrint('백그라운드 결제 처리 알림 전송 실패: $e');
      }

      // UI 측에 갱신 신호 전송 (결제 금액 포함)
      final amount = result.parsed?['normalized_transaction']?['amount'];
      final parsedAmount =
          amount is int ? amount : int.tryParse('$amount') ?? 0;

      // SharedPreferences에도 저장 — 앱 종료 후 재실행 시에도 팝업 표시 가능
      await ExperienceService.savePendingAlert(parsedAmount);

      // 포그라운드 실행 중이면 즉시 전달
      _sendDataToMain({'action': 'refresh', 'amount': parsedAmount});
    } finally {
      _processingFingerprints.remove(fp);
    }
  }
}
