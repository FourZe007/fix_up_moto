/// All REST API base URLs, endpoint paths, and header/storage key names.
///
/// Centralising these here means a base URL change only touches one file,
/// and typos in endpoint strings are caught at compile time.
class ApiConstants {
  ApiConstants._(); // static-only class — never instantiated

  // ── Base URL ──────────────────────────────────────────────────────────────

  /// Root of the backend API. All endpoint paths are appended to this.
  static const String baseUrl = 'http://wsip.yamaha-jatim.co.id:2448';

  // ── Secure Storage Keys ───────────────────────────────────────────────────
  // Keys used with FlutterSecureStorage to persist auth tokens between sessions.

  /// Key for the short-lived JWT access token.
  static const String tokenKey = 'auth_token';

  /// Key for the long-lived refresh token used to obtain new access tokens.
  static const String refreshTokenKey = 'refresh_token';

  /// Key for the cached user JSON string (avoids an extra API call on launch).
  static const String cachedUserKey = 'cached_user';

  // ── Auth Endpoints ────────────────────────────────────────────────────────

  /// POST — body: {email, password} → response: {token, refresh_token, user}
  static const String login = '/auth/login';

  /// POST — body: {name, email, password} → response: {token, refresh_token, user}
  static const String register = '/auth/register';

  /// POST — refreshes the access token using the stored refresh token
  static const String refreshToken = '/auth/refresh';

  /// DELETE — invalidates the server-side session
  static const String logout = '/auth/logout';

  // ── Services Endpoints ────────────────────────────────────────────────────

  /// GET — list all available repair services (supports ?category= filter)
  static const String services = '/services';

  /// GET — single service detail; append /{id} when calling
  static const String serviceDetail = '/services';

  // ── Bookings Endpoints ────────────────────────────────────────────────────

  /// GET  — list bookings for the authenticated user
  /// POST — create a new booking; body: {service_id, date, time_slot_id, notes}
  static const String bookings = '/bookings';

  /// DELETE — cancel a booking; append /{id} when calling
  static const String cancelBooking = '/bookings';

  /// GET — available time slots for a given date; ?date=YYYY-MM-DD&service_id=
  static const String availableSlots = '/bookings/slots';

  // ── Profile Endpoints ─────────────────────────────────────────────────────

  /// GET  — fetch authenticated user's profile
  /// PATCH — update profile; body: {name, phone, avatarUrl}
  static const String profile = '/profile';

  /// GET  — list user's motorcycles
  /// POST — add a motorcycle; body: {brand, model, year, plateNumber}
  static const String motorcycles = '/profile/motorcycles';

  // ── Dashboard Endpoints ───────────────────────────────────────────────────

  /// GET — summary stats for the home dashboard (upcoming bookings, counts)
  static const String dashboard = '/dashboard';
}
