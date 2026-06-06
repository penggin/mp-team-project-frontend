import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// GPS 좌표를 가져오는 서비스.
/// x = 경도(longitude), y = 위도(latitude)
/// 권한 없음 / GPS 비활성화 / 타임아웃 등 모든 실패 상황에서 null 반환.
class LocationService {
  /// 좌표 조회. 백그라운드 isolate에서도 안전하게 호출 가능 —
  /// 권한 요청은 절대 하지 않고, 이미 부여된 권한만 사용.
  /// 권한이 없으면 그냥 null 반환.
  static Future<({double? x, double? y})> currentCoordinates() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return (x: null, y: null);

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return (x: null, y: null);
      }

      // 마지막으로 알려진 위치 우선 사용 (빠름, 배터리 절약)
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        return (x: pos.longitude, y: pos.latitude);
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

      return (x: pos.longitude, y: pos.latitude);
    } catch (e) {
      debugPrint('GPS 좌표 조회 실패: $e');
      return (x: null, y: null);
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
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      debugPrint('위치 권한 상태: $permission (granted=$granted)');
      return granted;
    } catch (e) {
      debugPrint('위치 권한 요청 실패: $e');
      return false;
    }
  }
}
