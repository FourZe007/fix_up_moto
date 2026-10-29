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

  /// The front door for everyone who is logged out — a cold start with no
  /// session, a logout, an expired session: [AppRouter] sends them here first,
  /// and from here they continue to [register] or [login].
  static const String welcome = '/welcome';

  /// Reached from [welcome]. Also where [completeGoogleProfile] sends the user
  /// back to when it is restored without the Google identity it needs.
  static const String login = '/login';

  /// Registration screen — reachable from [welcome] and from the login page.
  static const String register = '/register';

  /// Reached only after a successful Google identity pick, before any backend
  /// session exists — collects name/phone (email is prefilled from Google).
  /// Treated as an auth route by the redirect guard, the same as [login] and
  /// [register], since the user is not authenticated while filling it in.
  static const String completeGoogleProfile = '/complete-google-profile';

  // ── Main tab routes (inside the StatefulShellRoute) ───────────────────────
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

  /// User profile and account settings. Registered bikes live on the
  /// dedicated [myBikes] page instead — see its own doc comment.
  static const String profile = '/profile';

  // ── Detail / nested routes ────────────────────────────────────────────────

  /// Service detail screen, nested under Bookings now that Services has no
  /// tab of its own — append the service ID when navigating:
  ///   `context.go('${RouteNames.serviceDetail}/abc123')`
  static const String serviceDetail = '/bookings/services/detail';

  /// Create a new booking — opened from the Services detail or Bookings tab.
  static const String createBooking = '/bookings/create';

  /// Lists the member's registered bikes — opened from Home's "Motor Saya"
  /// button. A dedicated top-level page, not the Profile tab's own (still
  /// unwired) placeholder section.
  static const String myBikes = '/my-bikes';

  /// App settings (appearance) — opened from the Profile tab's settings
  /// button. Top-level like [myBikes], so it renders full-screen with a back
  /// button rather than inside the bottom-nav shell.
  static const String settings = '/settings';

  /// The privacy policy text — opened from the Profile tab's Kebijakan Privasi
  /// row. Top-level like [settings], so it renders full-screen with a back
  /// button rather than inside the bottom-nav shell.
  static const String privacyPolicy = '/privacy-policy';

  /// Edit the member's name, phone and email — opened from the Profile tab's
  /// Edit Profile row. Top-level like [settings], so it renders full-screen
  /// with a back button rather than inside the bottom-nav shell.
  static const String editProfile = '/edit-profile';

  /// Add a bike — reached from [myBikes], so this is a top-level route too
  /// rather than nested under Profile specifically.
  static const String addBike = '/bikes/add';

  /// Edit a registered bike — opened from [myBikes]' more-actions sheet with
  /// the bike as the route's `extra`. Top-level for the same reason as
  /// [addBike]. Without a `BikeEntity` extra there is nothing to edit, so the
  /// route sends the member back to [myBikes].
  static const String editBike = '/bikes/edit';

  /// Lists nearby/partner workshops so the member can pick one — reached
  /// from both Home's picker and Create Booking's, so this is a top-level
  /// route rather than nested under either one specifically.
  static const String workshops = '/workshops';

  /// Chat with Fima, the virtual customer service — opened from Home's "Chat
  /// dengan Fima" button. Answers come from the chat service at
  /// [ChatConstants.askUrl].
  static const String chatbot = '/chatbot';

  /// The member's notifications. A focused full-screen page like [chatbot],
  /// so it is top-level too, without the bottom nav bar. Currently an empty
  /// placeholder page.
  static const String notification = '/notification';

  /// The member's Servis and Sparepart invoices — opened from the Profile
  /// tab's "Riwayat Invoice" row. A focused full-screen page like
  /// [notification], so it is top-level too, without the bottom nav bar.
  static const String invoices = '/invoices';
}
