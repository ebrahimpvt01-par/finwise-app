import 'package:flutter/material.dart';

/// Shared colors and text styles for the whole app.
/// Everyone should use THESE constants instead of picking their own
/// colors/fonts per screen -- this is what keeps the app looking like
/// one cohesive product instead of several stitched-together screens.
class AppColors {
  static const Color primary = Color(0xFF1F3864);   // deep navy -- app bars, headers
  static const Color accent = Color(0xFF00A896);    // teal/mint -- buttons, highlights
  static const Color background = Color(0xFFF5F7FA); // light grey -- screen backgrounds
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF5C5C5C);
  static const Color profit = Color(0xFF1B8A5A);    // green -- gains
  static const Color loss = Color(0xFFC0392B);      // red -- losses
  static const Color warning = Color(0xFFD97706);   // orange -- risk/alert flags
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ) != null
          ? InputDecorationTheme(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            )
          : null,
    );
  }
}