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

  /// Key for a JSON map of `{googleEmail: phone}`, remembering which phone
  /// number each Google account was linked to on this device.
  ///
  /// Separate from [cachedUserKey] on purpose: that key holds only the
  /// *current* session and is wiped on logout, while this one must survive
  /// logout — the whole point is recognising the same Google account again
  /// later, including after signing out. Google never provides a phone
  /// number, and the backend has no way to look a member up by email, so this
  /// mapping is the only way to skip the complete-profile form for a
  /// returning Google sign-in.
  static const String googleAccountPhonesKey = 'google_account_phones';

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

  /// POST — body: `{PhoneNo, DecryptedPassword}` → envelope carrying
  /// `MemberID`, `MemberName`, `Memo`, `Flag`. `Flag` gates whether sign-in is
  /// allowed; `Memo` is the server's wording, shown when it is not.
  ///
  /// There is no dedicated "does this phone exist" endpoint — this call
  /// doubles as that check for the Google flow below, since a login attempt
  /// against an unregistered phone is the only way to find out.
  static const String login = '/apiSAMP/Master/LoginMembership';

  /// POST — creates, updates, or deletes a member, discriminated by [ModifyMode]
  /// and by whether `Data.MemberID` is blank (blank = new account). Body:
  /// ```json
  /// {
  ///   "Mode": "1",
  ///   "TransID": "REGISTRATION",
  ///   "Data": {
  ///     "MemberID": "",       // blank when registering a new account
  ///     "MemberName": "...",
  ///     "MemberPass": "...",
  ///     "PhoneNo": "...",
  ///     "EmailAddress": "...",
  ///     "OldPass": ""         // required when changing an existing password
  ///   }
  /// }
  /// ```
  /// Manual registration (name/email/password only, no phone collected yet —
  /// see `register_page.dart`) still targets the old placeholder [register]
  /// endpoint below and has not been migrated to this one. The Google
  /// complete-profile flow, which does collect a phone number, uses this
  /// endpoint directly via `AuthRemoteDataSourceImpl.submitGoogleAccount`.
  static const String modify = '/apiSAMP/Modify';

  /// POST `/apiSAMP/Master` — body: `{Jenis: "BRANCHSHOP"}` → the list of
  /// workshop/branch locations. See `WorkshopsRemoteDataSource`.
  ///
  /// Named for what this call actually does, not the shared endpoint path —
  /// `Master` is a discriminated multi-purpose lookup, and `Jenis` is what
  /// picks "workshops" out of it. A future `Jenis` value for a different kind
  /// of master data gets its own constant here, not a rename of this one.
  static const String workshops = '/apiSAMP/Master';

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
  //
  // No separate register endpoint. register_page.dart now collects a phone
  // number, so manual registration uses [modify] with [ModifyMode.create] —
  // the same call submitGoogleAccount already makes; both are the identical
  // "create a new member" action, just reached from different screens.

  // No logout endpoint. There is no server-side session to invalidate —
  // signing out is entirely a local-storage operation. See
  // AuthRepositoryImpl.logout().

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

/// The five actions [ApiConstants.modify] can perform, selected by its
/// `Mode` field. Confirmed directly against the backend — these are not a
/// guess the way most of the unverified block above is.
enum ModifyMode {
  create('1'),
  updateProfile('2'),
  changePassword('3'),
  delete('4'),
  forgotPassword('5');

  /// The exact string [ApiConstants.modify] expects in its `Mode` field.
  /// A string, not an int — the confirmed request body sends `"Mode": "1"`.
  final String wireValue;

  const ModifyMode(this.wireValue);
}
