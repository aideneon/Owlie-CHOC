import 'package:flutter/material.dart';

class AppTheme {
  static const homeBackground = Color(0xFFCBC1B1);
  static const overlayTint = Color(0xCCF5E6D3);
  static const headerIconColor = Color(0xFFFFD54F);

  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C4DFF),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: homeBackground,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
