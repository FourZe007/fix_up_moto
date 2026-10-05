import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/constants/app_constants.dart';
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

    // Without this, a TabBar placed in AppBar.bottom (e.g. the Bookings tab's
    // Browse/My Bookings segments) falls back to Material 3's default label
    // colour, which is ColorScheme.primary — the same deep orange as the
    // AppBar background behind it. Same colour on same colour: technically
    // rendered, invisible to the eye. This matches it to the AppBar's own
    // white foreground instead.
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.textOnPrimary,
      unselectedLabelColor: AppColors.textOnPrimary.withValues(alpha: 0.7),
      indicatorColor: AppColors.textOnPrimary,
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
      // Without this, a Card's child (e.g. ListTile, itself a Material) isn't
      // clipped to the Card's own rounded shape, and Impeller (Android's
      // default renderer) can show a hairline seam where the two Materials'
      // paint bounds meet — the "white line" cutting across ServiceCard.
      clipBehavior: Clip.antiAlias,
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
    scaffoldBackgroundColor: AppColors.backgroundBlack,
    fontFamily: AssetConstants.fontPoppins,
    textTheme: _textTheme(Colors.white),
    appBarTheme: AppBarTheme(
      // Same colour as the scaffold, so the bar and the page read as one
      // surface — the dark counterpart of light mode's orange-on-orange.
      backgroundColor: AppColors.backgroundBlack,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.headingMedium.copyWith(color: Colors.white),
    ),
    // Same reasoning as the light theme's tabBarTheme — without it, a TabBar
    // in AppBar.bottom would default to ColorScheme.primary rather than
    // matching this AppBar's own white foreground.
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: AppColors.backgroundBlack,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Same reasoning as the light theme's cardTheme — see its comment.
      clipBehavior: Clip.antiAlias,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      // Light grey bar, so the items need dark-on-light colours (the old
      // primaryLight / white54 pair was chosen for a dark bar).
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.grey600,
      type: BottomNavigationBarType.fixed,
    ),
  );

  // ── Light-grey surfaces inside dark mode ──────────────────────────────────

  /// The light theme re-skinned for content that sits on a light-grey
  /// surface in dark mode.
  ///
  /// Dark mode keeps a black page with white text, but cards, panels and
  /// inputs that are white in light mode are light grey here — and text on
  /// light grey must be dark, which the dark theme's own colours can't give
  /// without breaking text drawn straight on the black page. So that content
  /// is built from the light theme instead (see `LightSurfaceScope`), with
  /// only the white surfaces swapped to [AppColors.surfaceDark] and the two
  /// grey secondary text styles darkened to stay readable on it.
  static final ThemeData darkSurface = light.copyWith(
    colorScheme: light.colorScheme.copyWith(surface: AppColors.surfaceDark),
    cardTheme: light.cardTheme.copyWith(color: AppColors.surfaceDark),
    inputDecorationTheme: light.inputDecorationTheme.copyWith(
      fillColor: AppColors.surfaceDark,
    ),
    textTheme: light.textTheme.copyWith(
      bodyMedium: light.textTheme.bodyMedium?.copyWith(
        color: AppColors.grey700,
      ),
      labelSmall: light.textTheme.labelSmall?.copyWith(
        color: AppColors.grey700,
      ),
    ),
  );

  /// The mode `MaterialApp` should actually use. While the theme switch is
  /// off ([AppConstants.themeSwitchEnabled]) that is always light — whatever
  /// the member saved earlier and whatever the phone is set to — so dark mode
  /// can stay in the code without ever being shown.
  static ThemeMode resolveMode(
    ThemeMode chosen, {
    bool enabled = AppConstants.themeSwitchEnabled,
  }) => enabled ? chosen : ThemeMode.light;

  /// Backdrop for screens whose AppBar and rounded body share one coloured
  /// surface: the brand orange in light mode (exactly what those screens used
  /// to hard-code), black in dark mode.
  static Color brandBackdrop(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.backgroundBlack
      : AppColors.primary;

  // ── Shared TextTheme factory ──────────────────────────────────────────────

  /// Builds a [TextTheme] that maps Material 3 text roles to [AppTextStyles].
  /// [baseColor] lets light/dark modes set appropriate default text colours.
  static TextTheme _textTheme(Color baseColor) {
    return TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: baseColor),
      headlineLarge: AppTextStyles.headingLarge.copyWith(color: baseColor),
      headlineMedium: AppTextStyles.headingMedium.copyWith(color: baseColor),
      titleLarge: AppTextStyles.headingSmall.copyWith(color: baseColor),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: baseColor),
      bodyMedium: AppTextStyles.bodyMedium,
      // Recoloured like the styles above: AppTextStyles.labelLarge hard-codes
      // textPrimary (dark grey), which is near-invisible on dark surfaces.
      // Light mode is unchanged — baseColor there is that same textPrimary.
      labelLarge: AppTextStyles.labelLarge.copyWith(color: baseColor),
      labelSmall: AppTextStyles.caption,
    );
  }
}
