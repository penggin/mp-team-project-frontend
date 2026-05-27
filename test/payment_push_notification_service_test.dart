import 'package:flutter_test/flutter_test.dart';

import 'package:first/services/payment_ingestion_workflow.dart';
import 'package:first/services/payment_push_notification_service.dart';

void main() {
  test(
    'showSavedPayment updates the service notification and posts a user-visible notification',
    () async {
      final updates = <({String title, String body})>[];
      final postedNotifications = <({String title, String body})>[];
      final service = PaymentPushNotificationService(
        foregroundNotificationUpdater:
            ({required String title, required String body}) async {
              updates.add((title: title, body: body));
            },
        userNotificationPresenter:
            ({required String title, required String body}) async {
              postedNotifications.add((title: title, body: body));
            },
      );

      await service.showSavedPayment(
        const PaymentIngestionResult(
          status: PaymentIngestionStatus.saved,
          rawText: '하나은행 알바비 320,000원 입금',
          parsed: {
            'normalized_transaction': {
              'transaction_type': 'income',
              'amount': 320000,
              'merchant_name': '알바비',
            },
          },
        ),
      );

      expect(updates, [
        (title: '결제 내역 저장 완료', body: '알바비 320,000원 입금이 저장됐어요.'),
      ]);
      expect(postedNotifications, [
        (title: '결제 내역 저장 완료', body: '알바비 320,000원 입금이 저장됐어요.'),
      ]);
    },
  );
}
