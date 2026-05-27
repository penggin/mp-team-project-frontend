import 'api_service.dart';
import 'notification_processing.dart';

enum PaymentIngestionSource { notification, sms }

extension PaymentIngestionSourceApiValue on PaymentIngestionSource {
  String get apiValue {
    switch (this) {
      case PaymentIngestionSource.notification:
        return 'notification';
      case PaymentIngestionSource.sms:
        return 'sms';
    }
  }
}

enum PaymentIngestionStatus {
  ignoredByPreflight,
  parseFailed,
  skippedCancellation,
  invalidParsedTransaction,
  saveFailed,
  saved,
}

class PaymentIngestionResult {
  final PaymentIngestionStatus status;
  final String rawText;
  final Map<String, dynamic>? parsed;

  const PaymentIngestionResult({
    required this.status,
    required this.rawText,
    this.parsed,
  });

  bool get saved => status == PaymentIngestionStatus.saved;
}

class PaymentIngestionWorkflow {
  static Future<PaymentIngestionResult> processCandidate(
    PaymentNotificationCandidate candidate, {
    DateTime? receivedAt,
  }) {
    return processText(
      candidate.rawText,
      source: PaymentIngestionSource.notification,
      receivedAt: receivedAt,
    );
  }

  static Future<PaymentIngestionResult> processText(
    String text, {
    required PaymentIngestionSource source,
    DateTime? receivedAt,
  }) async {
    final rawText = NotificationProcessing.normalizeText(text);
    if (!NotificationProcessing.isPaymentText(rawText)) {
      return PaymentIngestionResult(
        status: PaymentIngestionStatus.ignoredByPreflight,
        rawText: rawText,
      );
    }

    final parsed = await ApiService.parseTransaction(
      rawText,
      source: source.apiValue,
      receivedAt: receivedAt,
    );
    if (parsed == null) {
      return PaymentIngestionResult(
        status: PaymentIngestionStatus.parseFailed,
        rawText: rawText,
      );
    }

    final blockingStatus = _blockingStatusForParsedTransaction(parsed);
    if (blockingStatus != null) {
      return PaymentIngestionResult(
        status: blockingStatus,
        rawText: rawText,
        parsed: parsed,
      );
    }

    final saved = await ApiService.createLedgerEntry(
      parsed,
      source: source.apiValue,
    );

    return PaymentIngestionResult(
      status: saved
          ? PaymentIngestionStatus.saved
          : PaymentIngestionStatus.saveFailed,
      rawText: rawText,
      parsed: parsed,
    );
  }

  static PaymentIngestionStatus? _blockingStatusForParsedTransaction(
    Map<String, dynamic> parsed,
  ) {
    final transaction = parsed['normalized_transaction'];
    if (transaction is! Map) {
      return PaymentIngestionStatus.invalidParsedTransaction;
    }

    if (transaction['is_canceled'] == true) {
      return PaymentIngestionStatus.skippedCancellation;
    }

    final amount = transaction['amount'];
    final parsedAmount = amount is int ? amount : int.tryParse('$amount');
    if (parsedAmount == null || parsedAmount <= 0) {
      return PaymentIngestionStatus.invalidParsedTransaction;
    }

    final type = transaction['transaction_type']?.toString();
    if (type != 'expense' && type != 'income' && type != 'transfer') {
      return PaymentIngestionStatus.invalidParsedTransaction;
    }

    return null;
  }
}
