/// File paths for all static assets bundled with the app.
///
/// Using constants here means the IDE catches missing asset references at
/// compile time and avoids magic strings scattered across widget files.
/// All paths must match entries under `flutter: assets:` in pubspec.yaml.
class AssetConstants {
  AssetConstants._(); // static-only class — never instantiated

  // ── Images ────────────────────────────────────────────────────────────────

  /// App logo shown on the splash/login screens.
  static const String logo = 'assets/images/logo.png';

  /// Placeholder image displayed while a network image is loading.
  static const String imagePlaceholder = 'assets/images/placeholder.png';

  /// Full-screen illustration for the empty-state widget (no bookings yet).
  static const String emptyBookings = 'assets/images/empty_bookings.png';

  /// Full-screen illustration for the empty-state widget (no services found).
  static const String emptyServices = 'assets/images/empty_services.png';

  // ── Icons ─────────────────────────────────────────────────────────────────
  // Custom SVG/PNG icons — use these when Material Icons don't fit the design.

  /// Wrench icon used on the Services tab.
  static const String iconWrench = 'assets/icons/wrench.png';

  /// Motorcycle silhouette icon used on profile cards.
  static const String iconMotorcycle = 'assets/icons/motorcycle.png';

  /// Calendar icon used on the Bookings tab.
  static const String iconCalendar = 'assets/icons/calendar.png';

  // ── Animations ────────────────────────────────────────────────────────────
  // Lottie JSON animation files. Play with lottie package:
  //   Lottie.asset(AssetConstants.loadingAnimation)

  /// Spinning loader shown during async operations.
  static const String loadingAnimation = 'assets/animations/loading.json';

  /// Success checkmark animation shown after a booking is confirmed.
  static const String successAnimation = 'assets/animations/success.json';

  /// Error animation shown when an API call fails.
  static const String errorAnimation = 'assets/animations/error.json';

  // ── Fonts ─────────────────────────────────────────────────────────────────
  // Font family name — used in TextStyle(fontFamily: AssetConstants.fontPoppins)

  /// Primary typeface — referenced in [AppTextStyles] and [AppTheme].
  static const String fontPoppins = 'Poppins';
}
