/// String constants for every named route path in the app.
///
/// Using constants here instead of raw strings in [AppRouter]:
/// - The IDE catches typos at compile time
/// - Refactoring a path only requires changing it here
/// - `context.go(RouteNames.login)` reads more clearly than `context.go('/login')`
class RouteNames {
  RouteNames._(); // static-only class — never instantiated

  // ── Auth routes ───────────────────────────────────────────────────────────

  /// Unauthenticated users land here; [AppRouter] redirects here on 401.
  static const String login = '/login';

  /// Registration screen — reachable from the login page.
  static const String register = '/register';

  // ── Main tab routes (inside ShellRoute) ───────────────────────────────────
  // These paths are wrapped by [MainShell] which provides the bottom nav bar.

  /// Dashboard: upcoming bookings, quick stats, quick-action buttons.
  static const String home = '/home';

  /// Browse all available repair services and categories.
  static const String services = '/services';

  /// View existing bookings and create new appointments.
  static const String bookings = '/bookings';

  /// User profile, account settings, and registered motorcycles.
  static const String profile = '/profile';

  // ── Detail / nested routes ────────────────────────────────────────────────

  /// Service detail screen — append the service ID when navigating:
  ///   `context.go('${RouteNames.serviceDetail}/abc123')`
  static const String serviceDetail = '/services/detail';

  /// Create a new booking — opened from the Services detail or Bookings tab.
  static const String createBooking = '/bookings/create';

  /// Add a motorcycle — opened from the Profile page.
  static const String addMotorcycle = '/profile/motorcycle/add';
}
