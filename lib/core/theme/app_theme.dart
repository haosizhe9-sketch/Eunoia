import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Dark Glass design tokens for Eunoia.
abstract final class AppTheme {
  /// App background gradient (top → bottom).
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFF1A103C),
      Color(0xFF0D071C),
    ],
  );

  static const Color primary = Color(0xFF7C3AED);
  static const Color accent = Color(0xFF2DD4BF);

  static Color get glassCard => Colors.white.withValues(alpha: 0.04);
  static Color get glassBorder => Colors.white.withValues(alpha: 0.08);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D071C),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: accent,
      surface: const Color(0xFF151028),
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: Colors.white.withValues(alpha: 0.92),
      displayColor: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      dividerTheme: DividerThemeData(color: glassBorder),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary.withValues(alpha: 0.92),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
