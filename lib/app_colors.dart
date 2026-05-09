import 'package:flutter/material.dart';

enum AppThemeType { sky, pink }

class AppColors {
  AppColors._();

  static const skyTheme = ThemeColors(
    background: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFE8F6F8),
    primaryText: Color(0xFF1E105C),
    subText: Color(0xFF888888),
    accent: Color(0xFF87CEEB),
  );

  static const pinkTheme = ThemeColors(
    background: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFF0F5),
    primaryText: Color(0xFF8B0045),
    subText: Color(0xFF888888),
    accent: Color(0xFFFFB6C1),
  );

  // ✅ 전역 함수: AppThemeType → ThemeColors 반환
  static ThemeColors of(AppThemeType type) {
    switch (type) {
      case AppThemeType.sky:
        return skyTheme;
      case AppThemeType.pink:
        return pinkTheme;
    }
  }

  // ✅ 전역 함수: 인덱스 → AppThemeType 반환
  static AppThemeType typeFromIndex(int index) {
    switch (index) {
      case 0:
        return AppThemeType.sky;
      case 1:
        return AppThemeType.pink;
      default:
        return AppThemeType.sky;
    }
  }

  // ✅ 전역 함수: AppThemeType → 인덱스 반환
  static int indexFromType(AppThemeType type) {
    switch (type) {
      case AppThemeType.sky:
        return 0;
      case AppThemeType.pink:
        return 1;
    }
  }

  // ✅ 전역 함수: AppThemeType → 테마 이름(한글) 반환
  static String labelOf(AppThemeType type) {
    switch (type) {
      case AppThemeType.sky:
        return '하늘 테마';
      case AppThemeType.pink:
        return '핑크 테마';
    }
  }
}

class ThemeColors {
  final Color background;
  final Color cardBackground;
  final Color primaryText;
  final Color subText;
  final Color accent;

  const ThemeColors({
    required this.background,
    required this.cardBackground,
    required this.primaryText,
    required this.subText,
    required this.accent,
  });
}
// ✅ ThemeProvider 클래스 추가
class ThemeProvider extends ChangeNotifier {
  AppThemeType _currentTheme = AppThemeType.sky; // 기본 테마: sky

  // ✅ 현재 테마 타입 반환
  AppThemeType get currentTheme => _currentTheme;

  // ✅ 현재 테마 색상 반환
  ThemeColors get colors => AppColors.of(_currentTheme);

  // ✅ 테마 변경
  void setTheme(AppThemeType type) {
    _currentTheme = type;
    notifyListeners(); // 화면 다시 그리기
  }
}
