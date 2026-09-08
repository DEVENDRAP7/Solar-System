import 'package:flutter/material.dart';

/// Colours and text styles for the app.
///
/// The palette stays dark throughout: anything bright competes with the scene,
/// which is mostly black with small bright bodies in it.
class AppTheme {
  const AppTheme._();

  static const Color background = Color(0xFF05060A);
  static const Color panel = Color(0xE6101522);
  static const Color panelBorder = Color(0x332F4B7A);
  static const Color accent = Color(0xFF6FA8FF);
  static const Color textPrimary = Color(0xFFEAF0FA);
  static const Color textSecondary = Color(0xFF93A2BC);

  static ThemeData get dark {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(surface: background);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      sliderTheme: const SliderThemeData(
        trackHeight: 2.0,
        activeTrackColor: accent,
        thumbColor: accent,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13, height: 1.45),
        labelSmall: TextStyle(
          color: textSecondary,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
