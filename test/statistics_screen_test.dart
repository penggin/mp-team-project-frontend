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

          if (request.url.path == '/api/v1/ledger/stats/monthly') {
            return jsonResponse({
              'success': true,
              'data': {
                'year': 2026,
                'month': 5,
                'entry_count': 3,
                'total_income': 1000000,
                'total_expense': 350000,
                'total_transfer': 0,
                'net_amount': 650000,
                'category_totals': [
                  {'category': 'food', 'amount': 200000},
                  {'category': 'cafe', 'amount': 150000},
                ],
                'budget_progress': [
                  {
                    'category': 'food',
                    'monthly_limit': 300000,
                    'spent': 200000,
                    'remaining': 100000,
                    'is_over_limit': false,
                  },
                  {
                    'category': 'cafe',
                    'monthly_limit': 200000,
                    'spent': 150000,
                    'remaining': 50000,
                    'is_over_limit': false,
                  },
                ],
              },
            }, 200);
          }

          if (request.url.path ==
              '/api/v1/ledger/stats/categories/monthly/chart') {
            return jsonResponse({
              'success': true,
              'data': {
                'start_year': 2025,
                'start_month': 12,
                'end_year': 2026,
                'end_month': 5,
                'months': [
                  {
                    'year': 2026,
                    'month': 4,
                    'total_expense': 420000,
                    'categories': [
                      {
                        'category': 'food',
                        'amount': 280000,
                        'percentage': 66.7,
                      },
                    ],
                  },
                  {
                    'year': 2026,
                    'month': 5,
                    'total_expense': 350000,
                    'categories': [
                      {
                        'category': 'food',
                        'amount': 200000,
                        'percentage': 57.1,
                      },
                      {
                        'category': 'cafe',
                        'amount': 150000,
                        'percentage': 42.9,
                      },
                    ],
                  },
                ],
              },
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

      expect(requestedPaths, contains('/api/v1/ledger/stats/monthly'));
      expect(
        requestedPaths,
        contains('/api/v1/ledger/stats/categories/monthly/chart'),
      );
      expect(find.text('1,000,000 원'), findsOneWidget);
      expect(find.text('350,000 원'), findsWidgets);
      expect(find.text('최근 6개월 지출 추이'), findsOneWidget);
      expect(find.text('예산 500,000 원'), findsOneWidget);
      expect(find.text('지출 350,000 원'), findsOneWidget);
    },
  );
}
