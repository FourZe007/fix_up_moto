/// All REST API base URLs, endpoint paths, and header/storage key names.
///
/// Centralising these here means a base URL change only touches one file,
/// and typos in endpoint strings are caught at compile time.
///
/// ## Calling convention
///
/// Every `/apiSAMP/*` endpoint is a **POST** carrying a JSON body of
/// PascalCase keys, and answers with the envelope
/// `{ "Code": ..., "Msg": ..., "Data": [ ... ] }`.
/// Unwrap responses with `SampEnvelope` (`core/network/samp_envelope.dart`) —
/// never subscript `response.data` in a data source.
class ApiConstants {
  ApiConstants._(); // static-only class — never instantiated

  // ── Base URL ──────────────────────────────────────────────────────────────

  /// Root of the backend API. All endpoint paths are appended to this.
  static const String baseUrl = 'https://wsip.yamaha-jatim.co.id:2448';

  // ── Secure Storage Keys ───────────────────────────────────────────────────
  //
  // There are no token keys here. The SAMP backend issues no access or refresh
  // token — signing in returns a member record with an `Active` flag, and a
  // caller identifies itself afterwards with `MemberID` in the request body.
  // The session *is* the cached member record below.

  /// Key for the cached member JSON string — the whole persisted session.
  /// Present means signed in; absent means signed out.
  static const String cachedUserKey = 'cached_user';

  // ══════════════════════════════════════════════════════════════════════════
  // ENDPOINT PATHS
  //
  // VERIFIED — confirmed against the live backend.
  // ══════════════════════════════════════════════════════════════════════════

  /// POST — the membership/transaction browse endpoint.
  ///
  /// Body: `{Jenis, MemberID, MemberName, PlateNo, PhoneNo, Status}`.
  /// Backs both the home dashboard stats and the profile's motorcycle list;
  /// `Jenis` selects which projection is returned.
  static const String browseTrans = '/apiSAMP/BrowseTrans';

  // ══════════════════════════════════════════════════════════════════════════
  // UNVERIFIED — the paths below follow the BrowseTrans naming convention but
  // have NOT been confirmed against the backend, and their request bodies are
  // best guesses at the real field names.
  //
  // Before shipping: check each against the real endpoint list and correct both
  // the path and the body keys in the owning data source. The response models
  // (`user_model.dart`, `service_model.dart`, `booking_model.dart`,
  // `motorcycle_model.dart`) still carry scaffold field mappings and will need
  // the same treatment — only `dashboard_stats_model.dart` reflects the real
  // schema so far.
  // ══════════════════════════════════════════════════════════════════════════

  // ── Auth Endpoints ────────────────────────────────────────────────────────

  /// POST — body: `{EmailAddress, Password}` → envelope carrying the member
  /// record, whose `Active` flag decides whether the sign-in is allowed.
  static const String login = '/apiSAMP/Master/LoginMembership';

  /// POST — body: `{Name, Email, Password}` → envelope carrying the new member.
  static const String register = '/apiSAMP/Register';

  /// POST — invalidates the server-side session.
  static const String logout = '/apiSAMP/Logout';

  // ── Services Endpoints ────────────────────────────────────────────────────

  /// POST — body: `{CategoryID}` (empty string for "all") → list of services.
  static const String services = '/apiSAMP/BrowseService';

  /// POST — body: `{ServiceID}` → single service record.
  static const String serviceDetail = '/apiSAMP/BrowseServiceDetail';

  // ── Bookings Endpoints ────────────────────────────────────────────────────

  /// POST — list bookings for the authenticated member.
  static const String bookings = '/apiSAMP/BrowseBooking';

  /// POST — body: `{ServiceID, ScheduledAt, Notes}` → the created booking.
  static const String createBooking = '/apiSAMP/InsertBooking';

  /// POST — body: `{BookingID}` → cancels the booking.
  static const String cancelBooking = '/apiSAMP/CancelBooking';

  /// POST — body: `{ServiceID, Date}` → bookable time slots for that date.
  ///
  /// Not called yet; the create-booking screen will need it.
  static const String availableSlots = '/apiSAMP/BrowseSlot';

  // ── Profile Endpoints ─────────────────────────────────────────────────────

  /// POST — fetches the authenticated member's profile.
  static const String profile = '/apiSAMP/BrowseMember';

  /// POST — body: `{Name, PhoneNo}` → the updated member record.
  static const String updateProfile = '/apiSAMP/UpdateMember';

  /// POST — body: `{Brand, Model, Year, PlateNo}` → the created motorcycle.
  ///
  /// Registering a unit is a write, so it does not share [browseTrans]; the
  /// previous code posted an insert-shaped body to the browse endpoint.
  static const String addMotorcycle = '/apiSAMP/InsertUnit';

  // NOTE: there is no separate dashboard endpoint. The home dashboard reads
  // membership stats from [browseTrans]; the former `/dashboard` constant was
  // scaffold left-over and never called.
}
