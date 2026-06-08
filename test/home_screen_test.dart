import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:first/app_colors.dart';
import 'package:first/screens/home_screen.dart';
import 'package:first/services/api_service.dart';

import 'api_service_test.dart' as api_test;

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _streams = {};
  int _nextPlayerId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final playerId = _nextPlayerId++;
    final stream = StreamController<VideoEvent>();
    _streams[playerId] = stream;
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 1),
        size: const Size(100, 100),
      ),
    );
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _streams[playerId]!.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Widget buildView(int playerId) {
    return const SizedBox.expand();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  tearDown(() {
    ApiService.resetHttpClientForTest();
  });

  testWidgets('HomeScreen waits for backend pet state before showing a level', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-token',
      'demo_mode_enabled': false,
      'xp_total': 150,
    });

    final petResponse = Completer<http.Response>();
    ApiService.setHttpClientForTest(
      MockClient((request) async {
        if (request.url.path == '/api/v1/pet') {
          return petResponse.future;
        }
        if (request.url.path == '/api/v1/ledger') {
          return api_test.jsonResponse({
            'success': true,
            'data': {'items': []},
          }, 200);
        }
        if (request.url.path == '/api/v1/budgets/monthly') {
          return api_test.jsonResponse({
            'success': true,
            'data': {'is_configured': false},
          }, 200);
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      }),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('LV : 1'), findsNothing);
    expect(find.text('LV : 2'), findsNothing);
    expect(find.text('LV : --'), findsOneWidget);

    petResponse.complete(
      api_test.jsonResponse({
        'success': true,
        'data': {
          'id': 'pet-1',
          'user_id': 'user-1',
          'name': '고래',
          'species': 'blue_whale',
          'level': 7,
          'exp': 650,
          'mood': 'normal',
        },
      }, 200),
    );

    await tester.pumpAndSettle();

    expect(find.text('LV : 7'), findsOneWidget);
    expect(find.text('고래'), findsOneWidget);
  });

  testWidgets('HomeScreen demo controls use backend pet interaction', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-token',
      'demo_mode_enabled': true,
    });

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        if (request.url.path == '/api/v1/pet') {
          return api_test.jsonResponse({
            'success': true,
            'data': {
              'id': 'pet-1',
              'user_id': 'user-1',
              'name': '고래',
              'species': 'blue_whale',
              'level': 7,
              'exp': 650,
              'mood': 'normal',
            },
          }, 200);
        }
        if (request.url.path == '/api/v1/pet/interact') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['action'], 'play');
          return api_test.jsonResponse({
            'success': true,
            'data': {
              'id': 'pet-1',
              'user_id': 'user-1',
              'name': '고래',
              'species': 'blue_whale',
              'level': 8,
              'exp': 750,
              'mood': 'normal',
            },
          }, 200);
        }
        if (request.url.path == '/api/v1/ledger') {
          return api_test.jsonResponse({
            'success': true,
            'data': {'items': []},
          }, 200);
        }
        if (request.url.path == '/api/v1/budgets/monthly') {
          return api_test.jsonResponse({
            'success': true,
            'data': {'is_configured': false},
          }, 200);
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      }),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LV : 7'), findsOneWidget);
    expect(find.text('놀아주기'), findsOneWidget);
    expect(find.text('EXP +100'), findsNothing);
    expect(find.text('EXP 초기화'), findsNothing);

    await tester.tap(find.text('놀아주기'));
    await tester.pumpAndSettle();

    expect(find.text('LV : 8'), findsOneWidget);
  });

  testWidgets('HomeScreen hides unknown backend pet species labels', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-token',
      'demo_mode_enabled': false,
    });

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        if (request.url.path == '/api/v1/pet') {
          return api_test.jsonResponse({
            'success': true,
            'data': {'id': 'pet-1', 'level': 1, 'exp': 0, 'species': 'cat'},
          }, 200);
        }
        if (request.url.path == '/api/v1/ledger') {
          return api_test.jsonResponse({
            'success': true,
            'data': {'items': []},
          }, 200);
        }
        if (request.url.path == '/api/v1/budgets/monthly') {
          return api_test.jsonResponse({
            'success': true,
            'data': {'is_configured': false},
          }, 200);
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      }),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('cat'), findsNothing);
    expect(find.text('돌고래 · cat'), findsNothing);
  });
}
