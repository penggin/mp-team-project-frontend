import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:first/app_colors.dart';
import 'package:first/screens/home_screen.dart';
import 'package:first/services/api_service.dart';
import 'package:first/services/experience_service.dart';

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

  testWidgets(
    'HomeScreen shows demo exp button only when demo mode is enabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'access-token',
        'demo_mode_enabled': true,
        'xp_total': 0,
      });

      ApiService.setHttpClientForTest(
        MockClient((request) async {
          if (request.url.path == '/api/v1/pet') {
            return api_test.jsonResponse({'success': false}, 200);
          }
          if (request.url.path == '/api/v1/ledger') {
            return api_test.jsonResponse({
              'success': true,
              'data': {'items': []},
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

      expect(find.text('EXP +100'), findsOneWidget);

      await tester.tap(find.text('EXP +100'));
      await tester.pumpAndSettle();

      expect(find.text('LV : 2'), findsOneWidget);
    },
  );

  testWidgets('HomeScreen resets local demo experience from demo controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-token',
      'demo_mode_enabled': true,
      'xp_total': 150,
    });

    ApiService.setHttpClientForTest(
      MockClient((request) async {
        if (request.url.path == '/api/v1/pet') {
          return api_test.jsonResponse({'success': false}, 200);
        }
        if (request.url.path == '/api/v1/ledger') {
          return api_test.jsonResponse({
            'success': true,
            'data': {'items': []},
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

    expect(find.text('LV : 2'), findsOneWidget);
    expect(find.text('EXP 초기화'), findsOneWidget);

    await tester.tap(find.text('EXP 초기화'));
    await tester.pumpAndSettle();

    expect(find.text('LV : 1'), findsOneWidget);
    expect(await ExperienceService.getTotalExp(), 0);
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
