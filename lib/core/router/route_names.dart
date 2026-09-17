/// String constants for every named route path in the app.
///
/// Using constants here instead of raw strings in [AppRouter]:
/// - The IDE catches typos at compile time
/// - Refactoring a path only requires changing it here
/// - `context.go(RouteNames.login)` reads more clearly than `context.go('/login')`
class RouteNames {
  RouteNames._(); // static-only class — never instantiated

  // ── Auth routes ───────────────────────────────────────────────────────────

  /// Cold-start landing route. Shows a spinner while [AuthBloc] restores any
  /// cached session, then the router redirects to [home] or [login].
  /// Never navigated to manually.
  static const String splash = '/';

  /// Unauthenticated users land here; [AppRouter] redirects here on 401.
  static const String login = '/login';

  /// Registration screen — reachable from the login page.
  static const String register = '/register';

  /// Reached only after a successful Google identity pick, before any backend
  /// session exists — collects name/phone (email is prefilled from Google).
  /// Treated as an auth route by the redirect guard, the same as [login] and
  /// [register], since the user is not authenticated while filling it in.
  static const String completeGoogleProfile = '/complete-google-profile';

  // ── Main tab routes (inside ShellRoute) ───────────────────────────────────
  // These paths are wrapped by [MainShell] which provides the bottom nav bar.
  // Five tabs: Home, Bookings, Membership, Feeds, Profile. Services has no tab
  // of its own — its past-transaction history is a segment inside the
  // Bookings tab (see BookingsPage), alongside the member's current bookings.

  /// Dashboard: greeting, workshop picker, promos, quick-action buttons.
  static const String home = '/home';

  /// View service history and manage bookings — two segments, one tab.
  static const String bookings = '/bookings';

  /// Loyalty status: points, point history, vouchers. Reuses the same
  /// [DashboardStatsEntity] Home's greeting header reads — see MembershipPage.
  static const String membership = '/membership';

  /// Short-form video feed (Meta Business API). Placeholder until real
  /// credentials exist — see FeedsPage.
  static const String feeds = '/feeds';

  /// User profile, account settings, and registered motorcycles.
  static const String profile = '/profile';

  // ── Detail / nested routes ────────────────────────────────────────────────

  /// Service detail screen, nested under Bookings now that Services has no
  /// tab of its own — append the service ID when navigating:
  ///   `context.go('${RouteNames.serviceDetail}/abc123')`
  static const String serviceDetail = '/bookings/services/detail';

  /// Create a new booking — opened from the Services detail or Bookings tab.
  static const String createBooking = '/bookings/create';

  /// Add a motorcycle — opened from the Profile page.
  static const String addMotorcycle = '/profile/motorcycle/add';

  /// Lists nearby/partner workshops so the member can pick one — reached
  /// from both Home's picker and Create Booking's, so this is a top-level
  /// route rather than nested under either one specifically.
  static const String workshops = '/workshops';

  /// AI-powered virtual customer service chat — opened from Home's "Chat
  /// with Mika" button. Currently an empty placeholder page.
  static const String chatbot = '/chatbot';
}
