import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SentraCore design system — dark theme with cyan/teal accent palette.
class AppTheme {
  AppTheme._();

  // ── Color Palette ──
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);

  static const Color primary = Color(0xFF58A6FF);
  static const Color accent = Color(0xFF39D353);
  static const Color warning = Color(0xFFD29922);
  static const Color error = Color(0xFFF85149);
  static const Color info = Color(0xFF79C0FF);

  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  // ── Stress Level Colors ──
  static const Color stressLow = Color(0xFF39D353);
  static const Color stressModerate = Color(0xFFD29922);
  static const Color stressHigh = Color(0xFFF85149);
  static const Color stressCritical = Color(0xFFDA3633);

  static Color stressColor(String level) {
    switch (level) {
      case 'low':
        return stressLow;
      case 'moderate':
        return stressModerate;
      case 'high':
        return stressHigh;
      case 'critical':
        return stressCritical;
      default:
        return textMuted;
    }
  }

  // ── Theme Data ──
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: primary,
        secondary: accent,
        error: error,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
