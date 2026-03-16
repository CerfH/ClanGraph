import 'package:flutter/material.dart';

class AppTheme {
  // 深空蓝紫渐变背景 - 比纯黑更有层次，比深蓝更通透
  static const Color deepSpaceGrey = Color(0xFF1a1a2e);

  // 略带蓝紫色调的表面色，与背景形成微妙对比
  static const Color surfaceGrey = Color(0xFF162035);

  // Minimalist Blue (极简蓝) - Primary/Accent
  static const Color minimalistBlue = Color(0xFF0F3460);

  // Bright accent for interactive elements
  static const Color electricBlue = Color(0xFF4ECCA3);

  // 五代辈分颜色
  static const Color genAncestor2 = Color(0xFF9C27B0); // 曾祖辈 - 紫
  static const Color genAncestor1 = Color(0xFF2196F3); // 祖辈 - 蓝
  static const Color genSelf = Color(0xFF4CAF50); // 本辈 - 绿
  static const Color genChild1 = Color(0xFFFFC107); // 子辈 - 黄
  static const Color genChild2 = Color(0xFFFF5722); // 孙辈 - 橙

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deepSpaceGrey,
      primaryColor: minimalistBlue,
      colorScheme: const ColorScheme.dark(
        primary: minimalistBlue,
        secondary: electricBlue,
        surface: surfaceGrey,
        onSurface: Colors.white,
        onPrimary: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: surfaceGrey,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: minimalistBlue.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
      iconTheme: const IconThemeData(color: electricBlue),
    );
  }
}
