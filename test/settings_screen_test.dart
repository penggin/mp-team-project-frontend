import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:first/app_colors.dart';
import 'package:first/screens/settings_screen.dart';
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

  testWidgets('SettingsScreen shows user profile from backend', (tester) async {
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

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('펭귄'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
  });

  testWidgets('SettingsScreen toggles demo mode', (tester) async {
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

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('데모 모드'), findsOneWidget);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('demo_mode_enabled'), true);
  });
}
