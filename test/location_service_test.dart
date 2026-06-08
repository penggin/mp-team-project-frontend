import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:first/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeolocatorPlatform originalPlatform;
  late FakeGeolocatorPlatform fakeGeolocator;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalPlatform = GeolocatorPlatform.instance;
    fakeGeolocator = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fakeGeolocator;
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
  });

  test('currentCoordinates stores a fresh current position', () async {
    fakeGeolocator.currentPosition = testPosition(
      longitude: 126.978,
      latitude: 37.5665,
    );

    final coordinates = await LocationService.currentCoordinates();

    expect(coordinates.x, 126.978);
    expect(coordinates.y, 37.5665);

    fakeGeolocator.currentPosition = null;
    fakeGeolocator.currentPositionError = TimeoutException('background');

    final cachedCoordinates = await LocationService.currentCoordinates();

    expect(cachedCoordinates.x, 126.978);
    expect(cachedCoordinates.y, 37.5665);
  });

  test('ensurePermission requests permission and warms coordinates', () async {
    fakeGeolocator.permission = LocationPermission.denied;
    fakeGeolocator.permissionAfterRequest = LocationPermission.whileInUse;
    fakeGeolocator.currentPosition = testPosition(
      longitude: 127.0276,
      latitude: 37.4979,
    );

    final granted = await LocationService.ensurePermission();

    expect(granted, isTrue);
    expect(fakeGeolocator.requestPermissionCalls, 1);

    fakeGeolocator.currentPosition = null;
    fakeGeolocator.currentPositionError = TimeoutException('background');

    final cachedCoordinates = await LocationService.currentCoordinates();

    expect(cachedCoordinates.x, 127.0276);
    expect(cachedCoordinates.y, 37.4979);
  });

  test(
    'currentCoordinates does not use cache when permission is denied',
    () async {
      fakeGeolocator.currentPosition = testPosition(
        longitude: 126.978,
        latitude: 37.5665,
      );
      await LocationService.currentCoordinates();

      fakeGeolocator.permission = LocationPermission.denied;

      final coordinates = await LocationService.currentCoordinates();

      expect(coordinates.x, isNull);
      expect(coordinates.y, isNull);
    },
  );
}

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission permissionAfterRequest = LocationPermission.whileInUse;
  Position? lastKnownPosition;
  Position? currentPosition;
  Object? currentPositionError;
  int requestPermissionCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    return lastKnownPosition;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    final error = currentPositionError;
    if (error != null) throw error;

    final position = currentPosition;
    if (position == null) throw TimeoutException('missing position');
    return position;
  }
}

Position testPosition({required double longitude, required double latitude}) {
  return Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: DateTime(2026, 6, 8),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
