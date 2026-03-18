import 'package:flutter/material.dart';

/// Brand colour palette for Fix Up Moto.
///
/// All widget colours reference these constants rather than raw hex values.
/// Changing a brand colour here propagates everywhere automatically.
class AppColors {
  AppColors._(); // static-only class

  // ── Primary ───────────────────────────────────────────────────────────────
  // Deep orange — evokes energy, speed, and mechanical craftsmanship.

  /// Main brand colour — used for primary buttons, active tab indicators, FABs.
  static const Color primary = Color(0xFFE65100);

  /// Slightly lighter shade — hover/pressed states on primary surfaces.
  static const Color primaryLight = Color(0xFFFF8330);

  /// Dark variant — used for elevated primary surfaces (AppBar background).
  static const Color primaryDark = Color(0xFFAC1900);

  // ── Secondary ─────────────────────────────────────────────────────────────
  // Steel blue — used for secondary actions and information chips.

  static const Color secondary = Color(0xFF1565C0);
  static const Color secondaryLight = Color(0xFF5E92F3);
  static const Color secondaryDark = Color(0xFF003C8F);

  // ── Neutral / Greys ───────────────────────────────────────────────────────

  /// Page / scaffold background in light mode.
  static const Color backgroundLight = Color(0xFFF5F5F5);

  /// Page / scaffold background in dark mode.
  static const Color backgroundDark = Color(0xFF121212);

  /// Surface colour for cards and bottom sheets in light mode.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Surface colour for cards and bottom sheets in dark mode.
  static const Color surfaceDark = Color(0xFF1E1E1E);

  /// Dividers, borders, and disabled UI elements.
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey600 = Color(0xFF757575);

  // ── Text ──────────────────────────────────────────────────────────────────

  /// Primary body text on light backgrounds.
  static const Color textPrimary = Color(0xFF212121);

  /// Secondary / hint text — used for labels and captions.
  static const Color textSecondary = Color(0xFF757575);

  /// Text colour on dark/coloured backgrounds (e.g. inside primary buttons).
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Semantic ──────────────────────────────────────────────────────────────

  /// Success state — confirmed bookings, completed services.
  static const Color success = Color(0xFF2E7D32);
  static const Color successBackground = Color(0xFFE8F5E9);

  /// Warning state — bookings due soon, low stock.
  static const Color warning = Color(0xFFF57F17);
  static const Color warningBackground = Color(0xFFFFFDE7);

  /// Error state — failed requests, validation errors.
  static const Color error = Color(0xFFC62828);
  static const Color errorBackground = Color(0xFFFFEBEE);

  /// Informational messages.
  static const Color info = Color(0xFF0277BD);
  static const Color infoBackground = Color(0xFFE1F5FE);
}
