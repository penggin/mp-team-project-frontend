import 'api_service.dart';
import 'location_service.dart';
import 'notification_processing.dart';

typedef PaymentCoordinateProvider = Future<({double? x, double? y})> Function();

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
    double? x,
    double? y,
    PaymentCoordinateProvider? coordinateProvider,
  }) {
    return processText(
      candidate.rawText,
      source: PaymentIngestionSource.notification,
      receivedAt: receivedAt,
      x: x,
      y: y,
      coordinateProvider: coordinateProvider,
    );
  }

  static Future<PaymentIngestionResult> processText(
    String text, {
    required PaymentIngestionSource source,
    DateTime? receivedAt,
    double? x,
    double? y,
    PaymentCoordinateProvider? coordinateProvider,
  }) async {
    final rawText = NotificationProcessing.normalizeText(text);
    if (!NotificationProcessing.isPaymentText(rawText)) {
      return PaymentIngestionResult(
        status: PaymentIngestionStatus.ignoredByPreflight,
        rawText: rawText,
      );
    }

    final coordinates = await _coordinatesForParser(
      x: x,
      y: y,
      coordinateProvider: coordinateProvider,
    );

    final parsed = await ApiService.parseTransaction(
      rawText,
      source: source.apiValue,
      receivedAt: receivedAt,
      x: coordinates.x,
      y: coordinates.y,
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

  static Future<({double? x, double? y})> _coordinatesForParser({
    double? x,
    double? y,
    PaymentCoordinateProvider? coordinateProvider,
  }) async {
    if (x != null && y != null) return (x: x, y: y);

    final provider = coordinateProvider ?? LocationService.currentCoordinates;
    try {
      final current = await provider();
      return (x: x ?? current.x, y: y ?? current.y);
    } catch (_) {
      return (x: x, y: y);
    }
  }
}
