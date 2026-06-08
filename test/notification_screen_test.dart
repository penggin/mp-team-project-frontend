import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:first/screens/notification_screen.dart';
import 'package:first/services/api_service.dart';

http.Response jsonResponse(Map<String, dynamic> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const foregroundTaskChannel = MethodChannel(
    'flutter_foreground_task/methods',
  );
  const notificationListenerChannel = MethodChannel(
    'x-slayer/notifications_channel',
  );

  setUp(() {
    // 알림 스트림 직접 구독 없음 — 채널 호출이 오면 테스트 실패
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationListenerChannel, (call) async {
          fail(
            'NotificationScreen must not read notifications directly: ${call.method}',
          );
        });

    // Foreground task service 재시작 없음 — 채널 호출이 오면 테스트 실패
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foregroundTaskChannel, (call) async {
          // addTaskDataCallback / removeTaskDataCallback 은 in-memory 이므로 채널 호출 없음
          fail(
            'NotificationScreen must not manage the foreground service: ${call.method}',
          );
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foregroundTaskChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationListenerChannel, null);
    ApiService.resetHttpClientForTest();
  });

  testWidgets(
    'NotificationScreen loads entries from backend and displays them',
    (tester) async {
      SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/ledger');
          return jsonResponse({
            'success': true,
            'data': {
              'items': [
                {
                  'id': 'ledger-1',
                  'amount': 5600,
                  'type': 'expense',
                  'category': 'cafe',
                  'merchant_name': '스타벅스',
                },
              ],
            },
          }, 200);
        }),
      );

      await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('스타벅스에서 5,600원 결제'), findsOneWidget);
    },
  );

  testWidgets('clears only the local notification inbox', (tester) async {
    SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

    final requestMethods = <String>[];
    var requestCount = 0;

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        requestMethods.add(request.method);
        requestCount += 1;
        expect(request.url.path, '/api/v1/ledger');
        expect(request.method, 'GET');
        final items = [
          {
            'id': 'ledger-1',
            'amount': 5600,
            'category': 'cafe',
            'merchant_name': '스타벅스',
          },
          {
            'id': 'ledger-2',
            'amount': 12000,
            'category': 'food',
            'merchant_name': '교보문고',
          },
          if (requestCount > 1)
            {
              'id': 'ledger-3',
              'amount': 320000,
              'type': 'income',
              'category': 'salary',
              'merchant_name': '알바비',
            },
        ];
        return jsonResponse({
          'success': true,
          'data': {'items': items},
        }, 200);
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('스타벅스에서 5,600원 결제'), findsOneWidget);
    expect(find.text('교보문고에서 12,000원 결제'), findsOneWidget);

    await tester.tap(find.byTooltip('알림 비우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('비우기'));
    await tester.pumpAndSettle();

    expect(find.text('감지된 결제 내역이 없습니다'), findsOneWidget);
    expect(find.text('스타벅스에서 5,600원 결제'), findsNothing);
    expect(find.text('교보문고에서 12,000원 결제'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('스타벅스에서 5,600원 결제'), findsNothing);
    expect(find.text('교보문고에서 12,000원 결제'), findsNothing);
    expect(find.text('알바비 320,000원 입금'), findsOneWidget);
    expect(requestMethods.length, greaterThanOrEqualTo(2));
    expect(requestMethods.every((method) => method == 'GET'), isTrue);
  });

  testWidgets(
    'refreshes ledger notifications automatically without a refresh button',
    (tester) async {
      SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

      var requestCount = 0;
      ApiService.setHttpClientForTest(
        MockClient((request) async {
          requestCount += 1;
          expect(request.url.path, '/api/v1/ledger');
          if (requestCount == 1) {
            return jsonResponse({
              'success': true,
              'data': {'items': []},
            }, 200);
          }

          return jsonResponse({
            'success': true,
            'data': {
              'items': [
                {
                  'id': 'ledger-1',
                  'amount': 5600,
                  'type': 'expense',
                  'category': 'cafe',
                  'merchant_name': '스타벅스',
                },
              ],
            },
          }, 200);
        }),
      );

      await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
      await tester.pumpAndSettle();

      expect(find.byTooltip('새로고침'), findsNothing);
      expect(find.text('감지된 결제 내역이 없습니다'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('스타벅스에서 5,600원 결제'), findsOneWidget);
      expect(requestCount, 2);
    },
  );

  testWidgets('shows income ledger entries as income notifications', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/ledger');
        return jsonResponse({
          'success': true,
          'data': {
            'items': [
              {
                'id': 'income-1',
                'amount': 320000,
                'type': 'income',
                'category': 'salary',
                'merchant_name': '알바비',
              },
              {
                'id': 'expense-1',
                'amount': 5600,
                'type': 'expense',
                'category': 'cafe',
                'merchant_name': '스타벅스',
              },
            ],
          },
        }, 200);
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('알바비 320,000원 입금'), findsOneWidget);
    expect(find.text('알바비에서 320,000원 결제'), findsNothing);
    expect(find.text('스타벅스에서 5,600원 결제'), findsOneWidget);
  });
}
