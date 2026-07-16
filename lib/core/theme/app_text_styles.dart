import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/constants/asset_constants.dart';
import 'app_colors.dart';

/// Centralised typography scale using the Poppins typeface.
///
/// Every [Text] widget in the app should reference one of these styles instead
/// of inline [TextStyle] definitions. This makes global font size or weight
/// changes a single-file edit.
///
/// Usage:
///   `Text('Hello', style: AppTextStyles.headingLarge)`
class AppTextStyles {
  AppTextStyles._(); // static-only class

  static const String _font = AssetConstants.fontPoppins;

  // ── Display / Headings ────────────────────────────────────────────────────

  /// Large screen titles — used sparingly (e.g. onboarding headlines).
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _font,
    fontSize: 32,
    fontWeight: FontWeight.w700, // Poppins-Bold
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// Section headings — page titles inside AppBar or card headers.
  static const TextStyle headingLarge = TextStyle(
    fontFamily: _font,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Sub-section headings — group labels, dialog titles.
  static const TextStyle headingMedium = TextStyle(
    fontFamily: _font,
    fontSize: 20,
    fontWeight: FontWeight.w600, // Poppins-SemiBold
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Card titles and list item primary text.
  static const TextStyle headingSmall = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ── Body ──────────────────────────────────────────────────────────────────

  /// Default reading text — paragraphs, descriptions.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w400, // Poppins-Regular
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Secondary body text — list subtitles, secondary info lines.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ── Labels ────────────────────────────────────────────────────────────────

  /// Button labels and form field input text.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w500, // Poppins-Medium
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  /// Chip labels, badge text, small action buttons.
  static const TextStyle labelMedium = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
  );

  // ── Captions ──────────────────────────────────────────────────────────────

  /// Timestamp, helper text, and fine-print labels.
  static const TextStyle caption = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Error messages shown below form fields.
  static const TextStyle errorText = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
    height: 1.4,
  );
}
