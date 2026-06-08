import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GPS 좌표를 가져오는 서비스.
/// x = 경도(longitude), y = 위도(latitude)
/// 권한 없음 / GPS 비활성화 / 타임아웃 등 모든 실패 상황에서 null 반환.
class LocationService {
  static const _cachedLongitudeKey = 'last_location_x';
  static const _cachedLatitudeKey = 'last_location_y';

  /// 좌표 조회. 백그라운드 isolate에서도 안전하게 호출 가능 —
  /// 권한 요청은 절대 하지 않고, 이미 부여된 권한만 사용.
  /// 권한이 없으면 null 반환. 위치 조회가 실패하면 마지막 좌표를 사용.
  static Future<({double? x, double? y})> currentCoordinates() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return (x: null, y: null);
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _cachedCoordinates();

      // 마지막으로 알려진 위치 우선 사용 (빠름, 배터리 절약)
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        return _cachePosition(pos);
      }

      // forceLocationManager: true → Google Play Services 우회.
      // 에뮬레이터 + Play Services 없는 기기에서도 동작.
      pos = await Geolocator.getCurrentPosition(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                accuracy: LocationAccuracy.medium,
                forceLocationManager: true,
                intervalDuration: const Duration(seconds: 1),
              )
            : const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 15));

      return _cachePosition(pos);
    } catch (e) {
      debugPrint('GPS 좌표 조회 실패: $e');
      return _cachedCoordinates();
    }
  }

  /// UI 레이어에서 호출. 사용자에게 위치 권한을 요청.
  /// Activity가 필요하므로 반드시 foreground(UI 코드) 에서만 호출할 것.
  /// 반환: 권한이 부여됐는지 여부.
  static Future<bool> ensurePermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('위치 서비스 비활성화됨');
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (granted) {
        final coordinates = await currentCoordinates();
        debugPrint(
          '위치 권한 상태: $permission '
          '(granted=$granted, hasCoordinates=${coordinates.x != null && coordinates.y != null})',
        );
      } else {
        debugPrint('위치 권한 상태: $permission (granted=$granted)');
      }
      return granted;
    } catch (e) {
      debugPrint('위치 권한 요청 실패: $e');
      return false;
    }
  }

  static Future<({double? x, double? y})> _cachePosition(Position pos) async {
    final coordinates = (x: pos.longitude, y: pos.latitude);
    if (!_isValidCoordinate(coordinates.x, coordinates.y)) return coordinates;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cachedLongitudeKey, coordinates.x);
    await prefs.setDouble(_cachedLatitudeKey, coordinates.y);
    return coordinates;
  }

  static Future<({double? x, double? y})> _cachedCoordinates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_cachedLongitudeKey);
      final y = prefs.getDouble(_cachedLatitudeKey);
      if (!_isValidCoordinate(x, y)) return (x: null, y: null);
      return (x: x, y: y);
    } catch (_) {
      return (x: null, y: null);
    }
  }

  static bool _isValidCoordinate(double? x, double? y) {
    if (x == null || y == null) return false;
    return x >= -180 && x <= 180 && y >= -90 && y <= 90;
  }
}
