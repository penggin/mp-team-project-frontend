import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first/services/sms_event_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SmsEventService.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SmsEventService.stopListeningForTest();
  });

  test('SmsEvent parses native payloads', () {
    final event = SmsEvent.fromMap({
      'id': 'sms-1',
      'sender': '01012345678',
      'body': 'KB국민카드 스타벅스 4500원 승인',
      'receivedAt': 1779520000000,
    });

    expect(event.id, 'sms-1');
    expect(event.sender, '01012345678');
    expect(event.body, 'KB국민카드 스타벅스 4500원 승인');
    expect(event.receivedAt, 1779520000000);
  });

  test('replays pending SMS events and acknowledges handled events', () async {
    final methodCalls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call);
          if (call.method == 'getPendingSmsEvents') {
            return [
              {
                'id': 'sms-1',
                'sender': '01012345678',
                'body': '신한카드 교보문고 12000원 승인',
                'receivedAt': 1779520000000,
              },
            ];
          }
          if (call.method == 'ackSmsEvent') {
            return null;
          }
          fail('Unexpected method call: ${call.method}');
        });

    final handled = <SmsEvent>[];

    await SmsEventService.startListening((event) async {
      handled.add(event);
    });

    expect(handled.map((event) => event.body), ['신한카드 교보문고 12000원 승인']);
    expect(methodCalls.map((call) => call.method), [
      'getPendingSmsEvents',
      'ackSmsEvent',
    ]);
    expect(methodCalls.last.arguments, {'id': 'sms-1'});
  });

  test('handles duplicate SMS event ids only once', () async {
    final methodCalls = <MethodCall>[];
    final eventPayload = {
      'id': 'sms-duplicate',
      'sender': '01012345678',
      'body': '신한카드 교보문고 12000원 승인',
      'receivedAt': 1779520000000,
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call);
          if (call.method == 'getPendingSmsEvents') {
            return [eventPayload, eventPayload];
          }
          if (call.method == 'ackSmsEvent') {
            return null;
          }
          fail('Unexpected method call: ${call.method}');
        });

    final handled = <SmsEvent>[];

    await SmsEventService.startListening((event) async {
      handled.add(event);
    });

    expect(handled, hasLength(1));
    expect(methodCalls.map((call) => call.method), [
      'getPendingSmsEvents',
      'ackSmsEvent',
    ]);
    expect(methodCalls.last.arguments, {'id': 'sms-duplicate'});
  });

  test(
    'does not acknowledge failed SMS events so they can be retried',
    () async {
      final methodCalls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methodCalls.add(call);
            if (call.method == 'getPendingSmsEvents') {
              return [
                {
                  'id': 'sms-retry',
                  'sender': '01012345678',
                  'body': '신한카드 교보문고 12000원 승인',
                  'receivedAt': 1779520000000,
                },
              ];
            }
            if (call.method == 'ackSmsEvent') {
              fail('Failed SMS events must not be acknowledged');
            }
            fail('Unexpected method call: ${call.method}');
          });

      await expectLater(
        SmsEventService.startListening((event) async {
          throw StateError('temporary backend failure');
        }),
        throwsA(isA<StateError>()),
      );

      expect(methodCalls.map((call) => call.method), ['getPendingSmsEvents']);
    },
  );
}
