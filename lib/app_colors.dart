import 'package:flutter/material.dart';

enum AppThemeType { sky, pink }

class AppColors {
  AppColors._();

  static const skyTheme = ThemeColors(
    background: Color(0xFFFFFFFF),      // 전체 배경 (흰색)
    cardBackground: Color(0xFFE8F6F8),  // 카드 배경 (하늘색)
    primaryText: Color(0xFF1E105C),     // 주요 텍스트 (남색)
    subText: Color(0xFF888888),         // 보조 텍스트 (회색)
    accent: Color(0xFF87CEEB),          // 포인트 색상
  );

  static const pinkTheme = ThemeColors(
    background: Color(0xFFFFFFFF),      // 전체 배경 (흰색)
    cardBackground: Color(0xFFFFF0F5),  // 카드 배경 (핑크)
    primaryText: Color(0xFF8B0045),     // 주요 텍스트 (딥핑크)
    subText: Color(0xFF888888),         // 보조 텍스트 (회색)
    accent: Color(0xFFFFB6C1),          // 포인트 색상
  );

  static ThemeColors of(AppThemeType type) {
    switch (type) {
      case AppThemeType.sky:
        return skyTheme;
      case AppThemeType.pink:
        return pinkTheme;
    }
  }
}

class ThemeColors {
  final Color background;
  final Color cardBackground; // ✅ 추가
  final Color primaryText;
  final Color subText;        // ✅ 추가
  final Color accent;

  const ThemeColors({
    required this.background,
    required this.cardBackground, // ✅ 추가
    required this.primaryText,
    required this.subText,        // ✅ 추가
    required this.accent,
  });
}
