import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SentraCore design system — Modern high-density palette inspired by digital mockups.
class AppTheme {
  AppTheme._();

  // ── Dark Theme Colors (Mockup Style) ──
  static const Color darkBackground = Color(0xFF040911);
  static const Color darkSurface = Color(0xFF0C141F);
  static const Color darkSurfaceLight = Color(0xFF161F2C);
  static const Color darkBorder = Color(0xFF1E293B);

  static const Color primary = Color(0xFF00D1FF); // Neon Cyan
  static const Color accent = Color(0xFFA259FF); // Vibrant Purple
  static const Color success = Color(0xFF00FF94); // Neon Green
  static const Color warning = Color(0xFFFFB800); // Amber
  static const Color error = Color(0xFFFF4D4D); // Bright Red
  static const Color info = Color(0xFF0085FF); // Deep Blue

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF475569);

  // ── Light Theme Colors ──
  static const Color lightBackground = Color(0xFFF1F5F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // ── Stress Level Colors (Vibrant) ──
  static const Color stressLow = success;
  static const Color stressModerate = warning;
  static const Color stressHigh = Color(0xFFFF7A00);
  static const Color stressCritical = error;

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
        return Colors.grey;
    }
  }

  static Color stabilityColor(String state) {
    switch (state) {
      case 'stable':
        return stressLow;
      case 'degraded':
        return stressModerate;
      case 'critical':
        return stressCritical;
      default:
        return Colors.grey;
    }
  }

  // ── Dark Theme Data ──
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        surface: darkSurface,
        primary: primary,
        secondary: accent,
        error: error,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1.5),
        ),
      ),
      dividerColor: darkBorder,
      iconTheme: const IconThemeData(color: darkTextSecondary, size: 20),
    );
  }

  // ── Light Theme Data ──
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        surface: lightSurface,
        primary: primary,
        secondary: accent,
        error: error,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      dividerColor: lightBorder,
      iconTheme: const IconThemeData(color: lightTextSecondary, size: 20),
    );
  }

  // Helper for dynamic colors based on brightness
  static Color get background => darkBackground;
  static Color get surface => darkSurface;
  static Color get surfaceLight => darkSurfaceLight;
  static Color get border => darkBorder;
  static Color get textPrimary => darkTextPrimary;
  static Color get textSecondary => darkTextSecondary;
  static Color get textMuted => darkTextMuted;
}
