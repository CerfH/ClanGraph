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

  // 辈分颜色：在深色背景上高可读性
  static const Map<int, Color> _genPalette = {
    -4: Color(0xFF7E57C2), // 天祖 - 浅靛紫
    -3: Color(0xFF9575CD), // 高祖 - 淡紫
    -2: Color(0xFFAB47BC), // 曾祖 - 亮紫
    -1: Color(0xFF42A5F5), // 祖辈 - 亮蓝
    0:  Color(0xFF26A69A), // 本辈 - 青绿
    1:  Color(0xFFFFCA28), // 子辈 - 亮琥珀
    2:  Color(0xFFFF7043), // 孙辈 - 亮橙
    3:  Color(0xFFEF5350), // 曾孙 - 亮红
    4:  Color(0xFFEC407A), // 玄孙 - 亮粉
  };

  static Color generationColor(int generation) {
    if (_genPalette.containsKey(generation)) return _genPalette[generation]!;
    // 超出范围：在色环上取亮色
    final hue = (generation * 47 + 240) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.7, 0.6).toColor();
  }

  // 保留旧常量，向后兼容
  static const Color genAncestor2 = Color(0xFFAB47BC);
  static const Color genAncestor1 = Color(0xFF42A5F5);
  static const Color genSelf = Color(0xFF26A69A);
  static const Color genChild1 = Color(0xFFFFCA28);
  static const Color genChild2 = Color(0xFFFF7043);

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
