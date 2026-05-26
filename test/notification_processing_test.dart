import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';

import 'package:first/services/notification_processing.dart';

void main() {
  group('NotificationProcessing', () {
    test('builds searchable text from title and content', () {
      final event = ServiceNotificationEvent(
        title: 'KB국민카드',
        content: '스타벅스 4,500원 승인',
      );

      expect(
        NotificationProcessing.textFromEvent(event),
        'KB국민카드 스타벅스 4,500원 승인',
      );
    });

    test('accepts payment notifications from other apps', () {
      final event = ServiceNotificationEvent(
        id: 10,
        packageName: 'com.card.app',
        title: 'KB국민카드',
        content: '스타벅스 4,500원 승인',
        onGoing: false,
        hasRemoved: false,
      );

      final candidate = NotificationProcessing.candidateFromEvent(event);

      expect(candidate, isNotNull);
      expect(candidate!.rawText, contains('승인'));
      expect(candidate.fingerprint, contains('com.card.app'));
    });

    test('ignores the app foreground-service notification', () {
      final event = ServiceNotificationEvent(
        id: 256,
        packageName: NotificationProcessing.ownPackageName,
        title: '가계부 키우기',
        content: '결제 내역을 자동으로 기록 중',
        onGoing: true,
        hasRemoved: false,
      );

      expect(NotificationProcessing.candidateFromEvent(event), isNull);
    });

    test('ignores removed notifications', () {
      final event = ServiceNotificationEvent(
        id: 11,
        packageName: 'com.card.app',
        title: 'KB국민카드',
        content: '스타벅스 4,500원 승인',
        hasRemoved: true,
      );

      expect(NotificationProcessing.candidateFromEvent(event), isNull);
    });
  });
}
