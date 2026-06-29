import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SkillForge design tokens, expressed as Flutter theme primitives.
/// Mirrors `docs/DESIGN_SYSTEM.md`. Dark-first; per-career accent is injected
/// at runtime via [AppTheme.dark] so each career feels distinct while sharing
/// one component library.
class AppColors {
  // Base (dark)
  static const canvas = Color(0xFF0B0E14);
  static const surface = Color(0xFF141925);
  static const elevated = Color(0xFF1C2230);
  static const borderSubtle = Color(0xFF252C3B);
  static const textPrimary = Color(0xFFF5F7FA);
  static const textSecondary = Color(0xFF9AA4B2);
  static const textDisabled = Color(0xFF5A6473);

  // Semantic
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const info = Color(0xFF60A5FA);
  static const xpGold = Color(0xFFFFC857);
  static const streakFlame = Color(0xFFFF6B35);

  /// Default accent when no career is active (Electrician amber).
  static const defaultAccent = Color(0xFFF5A623);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppRadius {
  static const card = 20.0;
  static const button = 14.0;
  static const pill = 999.0;
}

class AppTheme {
  /// Build the dark theme, themed by the active career [accent].
  static ThemeData dark({Color accent = AppColors.defaultAccent}) {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    ).copyWith(
      primary: accent,
      surface: AppColors.surface,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: scheme,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: AppColors.canvas,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      dividerColor: AppColors.borderSubtle,
    );
  }
}
