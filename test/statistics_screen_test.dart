import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:first/app_colors.dart';
import 'package:first/screens/statistics_screen.dart';
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

  tearDown(() {
    ApiService.resetHttpClientForTest();
  });

  testWidgets(
    'StatisticsScreen renders monthly summary and trend from backend',
    (tester) async {
      SharedPreferences.setMockInitialValues({'access_token': 'access-token'});
      final requestedPaths = <String>[];

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          requestedPaths.add(request.url.path);

          if (request.url.path == '/api/v1/ledger') {
            final items = request.url.queryParameters.containsKey('year')
                ? [
                    {
                      'id': 'income-1',
                      'amount': 1000000,
                      'type': 'income',
                      'category': 'salary',
                      'merchant_name': '월급',
                      'transaction_at': '2026-06-01T09:00:00+09:00',
                    },
                    {
                      'id': 'expense-1',
                      'amount': 200000,
                      'type': 'expense',
                      'category': 'food',
                      'merchant_name': '식비',
                      'transaction_at': '2026-06-02T09:00:00+09:00',
                    },
                    {
                      'id': 'expense-2',
                      'amount': 150000,
                      'type': 'expense',
                      'category': 'cafe',
                      'merchant_name': '카페',
                      'transaction_at': '2026-06-03T09:00:00+09:00',
                    },
                  ]
                : [
                    {
                      'id': 'income-1',
                      'amount': 1000000,
                      'type': 'income',
                      'category': 'salary',
                      'merchant_name': '월급',
                      'transaction_at': '2026-06-01T09:00:00+09:00',
                    },
                    {
                      'id': 'expense-1',
                      'amount': 200000,
                      'type': 'expense',
                      'category': 'food',
                      'merchant_name': '식비',
                      'transaction_at': '2026-06-02T09:00:00+09:00',
                    },
                    {
                      'id': 'expense-2',
                      'amount': 150000,
                      'type': 'expense',
                      'category': 'cafe',
                      'merchant_name': '카페',
                      'transaction_at': '2026-06-03T09:00:00+09:00',
                    },
                    {
                      'id': 'expense-3',
                      'amount': 420000,
                      'type': 'expense',
                      'category': 'food',
                      'merchant_name': '지난달 식비',
                      'transaction_at': '2026-05-02T09:00:00+09:00',
                    },
                  ];
            return jsonResponse({
              'success': true,
              'data': {'items': items},
            }, 200);
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: const MaterialApp(home: StatisticsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(requestedPaths.every((path) => path == '/api/v1/ledger'), isTrue);
      expect(find.text('1,000,000 원'), findsOneWidget);
      expect(find.text('350,000 원'), findsWidgets);
      expect(find.text('최근 6개월 지출 추이'), findsOneWidget);
      expect(find.text('지출 350,000 원'), findsOneWidget);
    },
  );
}
