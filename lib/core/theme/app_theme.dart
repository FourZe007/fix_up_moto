import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/constants/asset_constants.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Provides the [ThemeData] for light and dark modes.
///
/// Both themes use [AppColors] and [AppTextStyles] so any colour or font
/// change propagates consistently. Pass [AppTheme.light] / [AppTheme.dark]
/// to [MaterialApp.theme] / [MaterialApp.darkTheme].
class AppTheme {
  AppTheme._(); // static-only class

  // ── Light Theme ───────────────────────────────────────────────────────────

  static final ThemeData light = ThemeData(
    useMaterial3: true,

    // ColorScheme drives Material 3 component colours automatically
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surfaceLight,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.backgroundLight,

    // ── Typography ──────────────────────────────────────────────────────────
    fontFamily: AssetConstants.fontPoppins,
    textTheme: _textTheme(AppColors.textPrimary),

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary, // icon + title colour
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.headingMedium.copyWith(
        color: AppColors.textOnPrimary,
      ),
    ),

    // ── Elevated Button ─────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        textStyle: AppTextStyles.labelLarge,
        // Pill shape with generous vertical padding for thumb-friendly tapping
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(double.infinity, 52), // full-width by default
      ),
    ),

    // ── Text Button ─────────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTextStyles.labelLarge,
      ),
    ),

    // ── Input / Text Field ──────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      hintStyle: AppTextStyles.bodyMedium,
      // Default border: grey outline
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.grey400),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.grey200),
      ),
      // Focused border uses brand colour
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // ── Card ────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.surfaceLight,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // ── Bottom Navigation Bar ────────────────────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.grey600,
      type: BottomNavigationBarType.fixed, // labels always visible
      elevation: 8,
    ),

    // ── Chip ────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.grey200,
      labelStyle: AppTextStyles.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // ── Divider ─────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.grey200,
      thickness: 1,
      space: 1,
    ),
  );

  // ── Dark Theme ────────────────────────────────────────────────────────────

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    fontFamily: AssetConstants.fontPoppins,
    textTheme: _textTheme(Colors.white),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.headingMedium.copyWith(
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
    ),
  );

  // ── Shared TextTheme factory ──────────────────────────────────────────────

  /// Builds a [TextTheme] that maps Material 3 text roles to [AppTextStyles].
  /// [baseColor] lets light/dark modes set appropriate default text colours.
  static TextTheme _textTheme(Color baseColor) {
    return TextTheme(
      displayLarge:  AppTextStyles.displayLarge.copyWith(color: baseColor),
      headlineLarge: AppTextStyles.headingLarge.copyWith(color: baseColor),
      headlineMedium: AppTextStyles.headingMedium.copyWith(color: baseColor),
      titleLarge:    AppTextStyles.headingSmall.copyWith(color: baseColor),
      bodyLarge:     AppTextStyles.bodyLarge.copyWith(color: baseColor),
      bodyMedium:    AppTextStyles.bodyMedium,
      labelLarge:    AppTextStyles.labelLarge,
      labelSmall:    AppTextStyles.caption,
    );
  }
}
