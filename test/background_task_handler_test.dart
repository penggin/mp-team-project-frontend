import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';

import 'package:first/background_task_handler.dart';
import 'package:first/services/notification_processing.dart';
import 'package:first/services/payment_ingestion_workflow.dart';
import 'package:first/services/payment_push_notification_service.dart';

class FakePaymentPushNotificationService
    implements PaymentPushNotificationService {
  final notifiedResults = <PaymentIngestionResult>[];

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> showSavedPayment(PaymentIngestionResult result) async {
    notifiedResults.add(result);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'background handler sends a push notification after saving a payment',
    () async {
      final notifier = FakePaymentPushNotificationService();
      final handler = PaymentTaskHandler(
        tokenLifecycleMaintainer: () async => true,
        candidateProcessor: (PaymentNotificationCandidate candidate) async {
          return const PaymentIngestionResult(
            status: PaymentIngestionStatus.saved,
            rawText: 'KB국민카드 스타벅스 5,600원 승인',
            parsed: {
              'normalized_transaction': {
                'transaction_type': 'expense',
                'amount': 5600,
                'merchant_name': '스타벅스',
              },
            },
          );
        },
        pushNotificationService: notifier,
        sendDataToMain: (_) {},
      );

      await handler.processNotificationForTest(
        ServiceNotificationEvent(
          id: 10,
          packageName: 'com.card.app',
          title: 'KB국민카드',
          content: '스타벅스 5,600원 승인',
          onGoing: false,
          hasRemoved: false,
        ),
      );

      expect(notifier.notifiedResults, hasLength(1));
      expect(notifier.notifiedResults.single.saved, isTrue);
    },
  );

  test(
    'background handler does not send a push notification when save fails',
    () async {
      final notifier = FakePaymentPushNotificationService();
      final handler = PaymentTaskHandler(
        tokenLifecycleMaintainer: () async => true,
        candidateProcessor: (PaymentNotificationCandidate candidate) async {
          return const PaymentIngestionResult(
            status: PaymentIngestionStatus.saveFailed,
            rawText: 'KB국민카드 스타벅스 5,600원 승인',
          );
        },
        pushNotificationService: notifier,
        sendDataToMain: (_) {},
      );

      await handler.processNotificationForTest(
        ServiceNotificationEvent(
          id: 10,
          packageName: 'com.card.app',
          title: 'KB국민카드',
          content: '스타벅스 5,600원 승인',
          onGoing: false,
          hasRemoved: false,
        ),
      );

      expect(notifier.notifiedResults, isEmpty);
    },
  );
}
