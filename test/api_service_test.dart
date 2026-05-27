import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('request refreshes an expired access token and retries once', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'old-access',
      'refresh_token': 'refresh-token',
    });

    final requests = <http.Request>[];

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        requests.add(request);

        if (request.url.path == '/api/v1/ledger' && requests.length == 1) {
          expect(request.headers['Authorization'], 'Bearer old-access');
          return http.Response('{"success":false}', 401);
        }

        if (request.url.path == '/api/v1/auth/refresh') {
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {'refresh_token': 'refresh-token'});
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'access_token': 'new-access',
                'refresh_token': 'new-refresh',
              },
            }),
            200,
          );
        }

        if (request.url.path == '/api/v1/ledger' && requests.length == 3) {
          expect(request.headers['Authorization'], 'Bearer new-access');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'items': []},
            }),
            200,
          );
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      }),
    );

    final response = await ApiService.request('GET', '/api/v1/ledger');
    final prefs = await SharedPreferences.getInstance();

    expect(response?['success'], true);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/ledger',
      '/api/v1/auth/refresh',
      '/api/v1/ledger',
    ]);
    expect(prefs.getString('access_token'), 'new-access');
    expect(prefs.getString('refresh_token'), 'new-refresh');
  });

  test('request clears stored tokens when refresh fails', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'expired-access',
      'refresh_token': 'expired-refresh',
    });

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        if (request.url.path == '/api/v1/ledger') {
          return http.Response('{"success":false}', 401);
        }

        if (request.url.path == '/api/v1/auth/refresh') {
          return http.Response('{"success":false}', 401);
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      }),
    );

    final response = await ApiService.request('GET', '/api/v1/ledger');
    final prefs = await SharedPreferences.getInstance();

    expect(response, isNull);
    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
  });

  test('login fails when the response does not include tokens', () async {
    SharedPreferences.setMockInitialValues({});

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        expect(request.headers['Authorization'], isNull);
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      }),
    );

    final response = await ApiService.login('user@example.com', 'password');
    final prefs = await SharedPreferences.getInstance();

    expect(response['success'], false);
    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
  });

  test(
    'hasValidToken refreshes when the stored access token is expired',
    () async {
      final now = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        'access_token': 'expired-access',
        'refresh_token': 'refresh-token',
        'access_token_expires_at': now
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
        'refresh_token_expires_at': now
            .add(const Duration(days: 1))
            .toIso8601String(),
      });

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/refresh');
          expect(jsonDecode(request.body), {'refresh_token': 'refresh-token'});
          return http.Response(
            jsonEncode({
              'data': {
                'access_token': 'new-access',
                'refresh_token': 'new-refresh',
                'access_token_expires_at': now
                    .add(const Duration(hours: 1))
                    .toIso8601String(),
                'refresh_token_expires_at': now
                    .add(const Duration(days: 7))
                    .toIso8601String(),
              },
            }),
            200,
          );
        }),
      );

      final hasToken = await ApiService.hasValidToken();
      final prefs = await SharedPreferences.getInstance();

      expect(hasToken, true);
      expect(prefs.getString('access_token'), 'new-access');
      expect(prefs.getString('refresh_token'), 'new-refresh');
    },
  );

  test('hasValidToken renews when the refresh token expires soon', () async {
    final now = DateTime.now().toUtc();
    SharedPreferences.setMockInitialValues({
      'access_token': 'valid-access',
      'refresh_token': 'soon-refresh',
      'access_token_expires_at': now
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'refresh_token_expires_at': now
          .add(const Duration(days: 2))
          .toIso8601String(),
    });

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/refresh');
        expect(jsonDecode(request.body), {'refresh_token': 'soon-refresh'});
        return http.Response(
          jsonEncode({
            'data': {
              'access_token': 'renewed-access',
              'refresh_token': 'renewed-refresh',
              'access_token_expires_at': now
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
              'refresh_token_expires_at': now
                  .add(const Duration(days: 14))
                  .toIso8601String(),
            },
          }),
          200,
        );
      }),
    );

    final hasToken = await ApiService.hasValidToken();
    final prefs = await SharedPreferences.getInstance();

    expect(hasToken, true);
    expect(prefs.getString('access_token'), 'renewed-access');
    expect(prefs.getString('refresh_token'), 'renewed-refresh');
  });

  test(
    'hasValidToken clears tokens when the refresh token is expired',
    () async {
      final now = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        'access_token': 'valid-access',
        'refresh_token': 'expired-refresh',
        'access_token_expires_at': now
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'refresh_token_expires_at': now
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      });

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          fail('Refresh token expiry should be handled before backend calls');
        }),
      );

      final hasToken = await ApiService.hasValidToken();
      final prefs = await SharedPreferences.getInstance();

      expect(hasToken, false);
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
    },
  );

  test(
    'request refreshes locally expired access token before backend call',
    () async {
      final now = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        'access_token': 'expired-access',
        'refresh_token': 'refresh-token',
        'access_token_expires_at': now
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
        'refresh_token_expires_at': now
            .add(const Duration(days: 14))
            .toIso8601String(),
      });

      final paths = <String>[];

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          paths.add(request.url.path);

          if (request.url.path == '/api/v1/auth/refresh') {
            return http.Response(
              jsonEncode({
                'data': {
                  'access_token': 'new-access',
                  'refresh_token': 'new-refresh',
                },
              }),
              200,
            );
          }

          if (request.url.path == '/api/v1/ledger') {
            expect(request.headers['Authorization'], 'Bearer new-access');
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'items': []},
              }),
              200,
            );
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );

      final response = await ApiService.request('GET', '/api/v1/ledger');

      expect(response?['success'], true);
      expect(paths, ['/api/v1/auth/refresh', '/api/v1/ledger']);
    },
  );

  test(
    'request renews a soon-expiring refresh token before backend call',
    () async {
      final now = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        'access_token': 'valid-access',
        'refresh_token': 'soon-refresh',
        'access_token_expires_at': now
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'refresh_token_expires_at': now
            .add(const Duration(days: 2))
            .toIso8601String(),
      });

      final paths = <String>[];

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          paths.add(request.url.path);

          if (request.url.path == '/api/v1/auth/refresh') {
            expect(jsonDecode(request.body), {'refresh_token': 'soon-refresh'});
            return http.Response(
              jsonEncode({
                'data': {
                  'access_token': 'renewed-access',
                  'refresh_token': 'renewed-refresh',
                  'access_token_expires_at': now
                      .add(const Duration(hours: 1))
                      .toIso8601String(),
                  'refresh_token_expires_at': now
                      .add(const Duration(days: 14))
                      .toIso8601String(),
                },
              }),
              200,
            );
          }

          if (request.url.path == '/api/v1/ledger') {
            expect(request.headers['Authorization'], 'Bearer renewed-access');
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'items': []},
              }),
              200,
            );
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );

      final response = await ApiService.request('GET', '/api/v1/ledger');

      expect(response?['success'], true);
      expect(paths, ['/api/v1/auth/refresh', '/api/v1/ledger']);
    },
  );

  test('logout revokes the refresh token and clears local tokens', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
    });

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/logout');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {'refresh_token': 'refresh-token'});
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'revoked': true},
          }),
          200,
        );
      }),
    );

    await ApiService.logout();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
  });

  test(
    'getLedgerEntries sends optional month filters through request',
    () async {
      SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/ledger');
          expect(request.url.queryParameters, {'year': '2026', 'month': '5'});
          return http.Response(
            jsonEncode({
              'data': {
                'items': [
                  {'id': 'ledger-1', 'amount': 12000},
                ],
              },
            }),
            200,
          );
        }),
      );

      final entries = await ApiService.getLedgerEntries(year: 2026, month: 5);

      expect(entries, [
        {'id': 'ledger-1', 'amount': 12000},
      ]);
    },
  );

  test(
    'getMonthlyCategoryChartStats sends the requested month range',
    () async {
      SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/api/v1/ledger/stats/categories/monthly/chart',
          );
          expect(request.url.queryParameters, {
            'start_year': '2026',
            'start_month': '1',
            'end_year': '2026',
            'end_month': '5',
          });
          return jsonResponse({
            'success': true,
            'data': {
              'start_year': 2026,
              'start_month': 1,
              'end_year': 2026,
              'end_month': 5,
              'months': [
                {
                  'year': 2026,
                  'month': 5,
                  'total_expense': 350000,
                  'categories': [
                    {'category': 'food', 'amount': 200000, 'percentage': 57.1},
                  ],
                },
              ],
            },
          }, 200);
        }),
      );

      final stats = await ApiService.getMonthlyCategoryChartStats(
        startYear: 2026,
        startMonth: 1,
        endYear: 2026,
        endMonth: 5,
      );

      expect(stats?['months'], isA<List>());
      expect((stats?['months'] as List).first['total_expense'], 350000);
    },
  );

  test('getCurrentUser returns the authenticated user profile', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/users/me');
        return jsonResponse({
          'success': true,
          'data': {
            'id': 'user-1',
            'email': 'user@example.com',
            'nickname': '펭귄',
            'created_at': '2026-05-01T00:00:00Z',
            'updated_at': '2026-05-27T00:00:00Z',
          },
        }, 200);
      }),
    );

    final user = await ApiService.getCurrentUser();

    expect(user, {
      'id': 'user-1',
      'email': 'user@example.com',
      'nickname': '펭귄',
      'created_at': '2026-05-01T00:00:00Z',
      'updated_at': '2026-05-27T00:00:00Z',
    });
  });

  test('getPetState returns the backend pet state', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/pet');
        return jsonResponse({
          'success': true,
          'data': {
            'id': 'pet-1',
            'user_id': 'user-1',
            'name': '고래',
            'species': 'blue_whale',
            'level': 7,
            'exp': 650,
            'mood': 80,
            'health': 90,
            'weight': 12.5,
            'cleanliness': 70,
            'coins': 30,
          },
        }, 200);
      }),
    );

    final pet = await ApiService.getPetState();

    expect(pet?['name'], '고래');
    expect(pet?['level'], 7);
    expect(pet?['exp'], 650);
    expect(pet?['mood'], 80);
  });

  test('updatePetInfo patches supported pet fields', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'access-token'});

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/pet');
        expect(jsonDecode(request.body), {
          'name': '새 이름',
          'species': 'dolphin',
        });
        return jsonResponse({
          'success': true,
          'data': {
            'id': 'pet-1',
            'user_id': 'user-1',
            'name': '새 이름',
            'species': 'dolphin',
            'level': 1,
            'exp': 0,
            'mood': 100,
            'health': 100,
            'weight': 10,
            'cleanliness': 100,
            'coins': 0,
          },
        }, 200);
      }),
    );

    final pet = await ApiService.updatePetInfo(
      name: '새 이름',
      species: 'dolphin',
    );

    expect(pet?['name'], '새 이름');
    expect(pet?['species'], 'dolphin');
  });

  test('createManualLedgerEntry posts the backend ledger contract', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'access-token'});
    final transactionAt = DateTime.utc(2026, 5, 27, 10);

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/ledger');
        expect(jsonDecode(request.body), {
          'amount': 12000,
          'type': 'expense',
          'category': 'food',
          'merchant_name': '교보문고',
          'transaction_at': '2026-05-27T10:00:00.000Z',
          'source': 'manual',
        });
        return http.Response(
          jsonEncode({
            'data': {'id': 'ledger-1'},
          }),
          200,
        );
      }),
    );

    final saved = await ApiService.createManualLedgerEntry(
      amount: 12000,
      type: 'expense',
      category: '식비',
      merchantName: '교보문고',
      transactionAt: transactionAt,
    );

    expect(saved, true);
  });

  test(
    'createManualLedgerEntry normalizes unknown expense categories to others',
    () async {
      SharedPreferences.setMockInitialValues({'access_token': 'access-token'});
      final transactionAt = DateTime.utc(2026, 5, 27, 10);

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/ledger');
          expect(jsonDecode(request.body)['category'], 'others');
          return http.Response(
            jsonEncode({
              'data': {'id': 'ledger-1'},
            }),
            200,
          );
        }),
      );

      final saved = await ApiService.createManualLedgerEntry(
        amount: 12000,
        type: 'expense',
        category: '문화생활',
        merchantName: '공연장',
        transactionAt: transactionAt,
      );

      expect(saved, true);
    },
  );
}
