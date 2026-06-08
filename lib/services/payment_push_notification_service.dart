import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'payment_ingestion_workflow.dart';

typedef UserNotificationPresenter =
    Future<void> Function({required String title, required String body});

class PaymentPushNotificationService {
  PaymentPushNotificationService({
    UserNotificationPresenter? userNotificationPresenter,
  }) : _userNotificationPresenter =
           userNotificationPresenter ?? _showUserVisibleNotification;

  static final PaymentPushNotificationService instance =
      PaymentPushNotificationService();

  static const String _channelId = 'payment_saved_alerts';
  static const String _channelName = '결제 처리 알림';
  static const String _channelDescription = '백그라운드에서 저장된 결제 내역을 알려줍니다';
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;
  static int _nextNotificationId = 3000;

  final UserNotificationPresenter _userNotificationPresenter;

  Future<void> requestPermissions() async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    await _ensureLocalNotificationsInitialized();
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showSavedPayment(PaymentIngestionResult result) async {
    final notification = _notificationFor(result);
    await _userNotificationPresenter(
      title: notification.title,
      body: notification.body,
    );
  }

  static Future<void> _showUserVisibleNotification({
    required String title,
    required String body,
  }) async {
    await _ensureLocalNotificationsInitialized();
    await _localNotifications.show(
      id: _nextNotificationId++,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.status,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  static Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsInitialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );

    await _localNotifications.initialize(settings: initializationSettings);
    _localNotificationsInitialized = true;
  }

  _PaymentNotificationContent _notificationFor(PaymentIngestionResult result) {
    final transaction = result.parsed?['normalized_transaction'];
    final transactionMap = transaction is Map ? transaction : const {};
    final merchantName = _nonEmpty(transactionMap['merchant_name']) ?? '결제 내역';
    final amount = _intValue(transactionMap['amount']);
    final typeLabel = _transactionTypeLabel(
      transactionMap['transaction_type']?.toString(),
    );

    final amountText = amount == null ? '' : ' ${_formatAmount(amount)}원';
    return _PaymentNotificationContent(
      title: '결제 내역 저장 완료',
      body: '$merchantName$amountText $typeLabel이 저장됐어요.',
    );
  }

  String _transactionTypeLabel(String? type) {
    switch (type) {
      case 'income':
        return '입금';
      case 'transfer':
        return '이체';
      case 'expense':
      default:
        return '지출';
    }
  }

  String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}

class _PaymentNotificationContent {
  final String title;
  final String body;

  const _PaymentNotificationContent({required this.title, required this.body});
}
