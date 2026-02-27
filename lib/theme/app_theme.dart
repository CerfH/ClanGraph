import 'package:flutter/material.dart';

class AppTheme {
  // Deep Space Grey (深空灰) - Background
  static const Color deepSpaceGrey = Color.fromARGB(255, 26, 26, 46);
  
  // Lighter Grey for Surface/Cards
  static const Color surfaceGrey = Color(0xFF16213E);
  
  // Minimalist Blue (极简蓝) - Primary/Accent
  static const Color minimalistBlue = Color(0xFF0F3460);
  
  // Bright accent for interactive elements
  static const Color electricBlue = Color(0xFF4ECCA3);

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
          side: BorderSide(color: minimalistBlue.withValues(alpha: 0.3), width: 1),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        bodyMedium: TextStyle(
          color: Colors.white70,
        ),
      ),
      iconTheme: const IconThemeData(
        color: electricBlue,
      ),
    );
  }
}
