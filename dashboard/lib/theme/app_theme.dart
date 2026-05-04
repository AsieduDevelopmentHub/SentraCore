import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SentraCore design system — matches `design.md`.
class AppTheme {
  AppTheme._();

  // ── Core palette ──
  // Dark mode
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF161A20); // secondary background
  static const Color darkSurfaceLight = Color(0xFF1B2029);
  static const Color darkBorder = Color(0xFF232A36);

  // Light mode
  static const Color lightBackground = Color(0xFFF7F9FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFF2F5FA);
  static const Color lightBorder = Color(0xFFE6EAF2);

  // Text
  static const Color darkTextPrimary = Color(0xFFE6E8EB);
  static const Color darkTextSecondary = Color(0xFF9AA3AF);
  static const Color lightTextPrimary = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // Accent
  static const Color primary = Color(0xFF3AA0FF); // soft blue
  static const Color accent = Color(0xFF5FD1C2); // teal

  // State colors (shared)
  static const Color stable = Color(0xFF22C55E);
  static const Color warning = Color(0xFFEAB308);
  static const Color elevated = Color(0xFFF97316);
  static const Color critical = Color(0xFFEF4444);

  // Back-compat for existing widgets
  static const Color success = stable;
  static const Color error = critical;
  static const Color info = primary;
  static const Color stressLow = stable;
  static const Color stressModerate = warning;
  static const Color stressHigh = elevated;
  static const Color stressCritical = critical;

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
        return stable;
      case 'degraded':
        return warning;
      case 'critical':
        return critical;
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
        error: critical,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        // Slightly brighter than scaffold for clearer separation.
        color: darkSurfaceLight,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerColor: darkBorder,
      iconTheme: const IconThemeData(color: darkTextSecondary, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceLight,
        hintStyle: TextStyle(color: darkTextSecondary.withValues(alpha: 0.85)),
        prefixIconColor: darkTextSecondary.withValues(alpha: 0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
    );
  }

  // ── Light Theme Data ──
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Slightly darker than card surface for clear separation.
      scaffoldBackgroundColor: const Color(0xFFF3F6FB),
      colorScheme: const ColorScheme.light(
        surface: lightSurface,
        primary: primary,
        secondary: accent,
        error: critical,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerColor: lightBorder,
      iconTheme: const IconThemeData(color: lightTextSecondary, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceLight,
        hintStyle: TextStyle(color: lightTextSecondary.withValues(alpha: 0.85)),
        prefixIconColor: lightTextSecondary.withValues(alpha: 0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
    );
  }

  static Color surfaceLightFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceLight
          : lightSurfaceLight;

  static Color textPrimaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : lightTextPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : lightTextSecondary;

  static Color textMutedFor(BuildContext context) =>
      (Theme.of(context).brightness == Brightness.dark
              ? darkTextSecondary
              : lightTextSecondary)
          .withValues(alpha: 0.85);

  // No legacy theme accessors — keep all callsites context-aware.
}
