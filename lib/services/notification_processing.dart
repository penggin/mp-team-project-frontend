import 'package:notification_listener_service/notification_event.dart';

class PaymentNotificationCandidate {
  final String rawText;
  final String fingerprint;

  const PaymentNotificationCandidate({
    required this.rawText,
    required this.fingerprint,
  });
}

class NotificationProcessing {
  static const String ownPackageName = 'com.example.first';

  static const List<String> _paymentKeywords = [
    '승인',
    '결제',
    '출금',
    '입금',
    '이체',
    '취소',
    '카드',
  ];

  static final RegExp _amountPattern = RegExp(r'\d[\d,]*\s*원');

  static String textFromEvent(ServiceNotificationEvent event) {
    return normalizeText(
      [
        event.title,
        event.content,
      ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' '),
    );
  }

  static bool isPaymentText(String text) {
    final normalizedText = normalizeText(text);
    if (normalizedText.isEmpty) return false;

    final hasKeyword = _paymentKeywords.any(normalizedText.contains);
    if (!hasKeyword) return false;

    final hasAmount = _amountPattern.hasMatch(normalizedText);
    final hasTransactionVerb = [
      '승인',
      '결제',
      '출금',
      '입금',
      '이체',
      '취소',
      '일시불',
      '할부',
    ].any(normalizedText.contains);

    if (!hasTransactionVerb) return false;
    return hasAmount;
  }

  static PaymentNotificationCandidate? candidateFromEvent(
    ServiceNotificationEvent event, {
    String ownPackageName = ownPackageName,
  }) {
    if (event.hasRemoved == true) return null;
    if (event.onGoing == true) return null;
    if (event.packageName == ownPackageName) return null;

    final rawText = textFromEvent(event);
    if (rawText.isEmpty || !isPaymentText(rawText)) return null;

    return PaymentNotificationCandidate(
      rawText: rawText,
      fingerprint: _fingerprintFor(event, rawText),
    );
  }

  static String _fingerprintFor(ServiceNotificationEvent event, String text) {
    final packageName = event.packageName ?? 'unknown-package';
    final notificationId = event.id?.toString() ?? 'unknown-id';
    return '$packageName|$notificationId|$text';
  }

  static String normalizeText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
