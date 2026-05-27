import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'payment_ingestion_workflow.dart';

typedef ForegroundNotificationUpdater =
    Future<void> Function({required String title, required String body});

class PaymentPushNotificationService {
  PaymentPushNotificationService({
    ForegroundNotificationUpdater? foregroundNotificationUpdater,
  }) : _foregroundNotificationUpdater =
           foregroundNotificationUpdater ??
           _updateForegroundServiceNotification;

  static final PaymentPushNotificationService instance =
      PaymentPushNotificationService();

  final ForegroundNotificationUpdater _foregroundNotificationUpdater;

  Future<void> requestPermissions() async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  Future<void> showSavedPayment(PaymentIngestionResult result) async {
    final notification = _notificationFor(result);
    await _foregroundNotificationUpdater(
      title: notification.title,
      body: notification.body,
    );
  }

  static Future<void> _updateForegroundServiceNotification({
    required String title,
    required String body,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: body,
    );
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
