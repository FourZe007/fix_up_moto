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
  /// Body varies by `Jenis`: `{Jenis, MemberID, MemberName, PlateNo, PhoneNo,
  /// Status}` for the dashboard/bike-list projections, or
  /// `{Jenis: "SERVICEBOOKINGHISTORYBYMEMBER", MemberID, BeginDate, EndDate}`
  /// for a member's booking history, or
  /// `{Jenis: "NOTIFICATION", MemberID, IsSent, IsRead}` for the member's
  /// inbox (`IsSent: "1"` = already sent, `IsRead: "1"` = read, `""` = no
  /// filter), or `{Jenis: "INVOICEBYMEMBER", MemberID, Kode, BeginDate,
  /// EndDate}` for a member's invoices (`Kode` is `"SERVICE"` or `"SPAREPART"`,
  /// the dates are `yyyy-MM-dd` and both included; each record carries its
  /// lines in `Detail`). Backs the home dashboard stats, My Bikes' list, My
  /// Bookings, the notification inbox and Riwayat Invoice; `Jenis` selects
  /// which projection is returned.
  static const String browseTrans = '/apiSAMP/BrowseTrans';

  /// GET — the receipt (struk) of one invoice, as a PDF.
  ///
  /// Query: `PT=FIXUP` and `Param`, a JSON object with `TransID` (`SNT` for
  /// Servis, `PNT` for Sparepart; see `InvoiceType.transId`), `Location: "0"`,
  /// `Idx: "0"` and `TransNo`, the invoice number. Answers `200` with
  /// `Content-Type: application/pdf` and the file as the body.
  ///
  /// It does not check the invoice number: an unknown one still answers `200`
  /// with a PDF (an empty receipt), so the app only asks for numbers it listed.
  ///
  /// An absolute URL, since the host's port (2449) differs from [baseUrl]'s:
  /// Dio uses it as is, ignoring its base URL. Its sibling `ViewPDF` (POST) only
  /// generates the file on the server and returns JSON, not the PDF.
  static const String receiptPdfUrl =
      'https://wsip.yamaha-jatim.co.id:2449/CetakanSIP/DownloadPDF';

  /// POST — body: `{PhoneNo, DecryptedPassword}` → envelope carrying
  /// `MemberID`, `MemberName`, `Memo`, `Flag`. `Flag` gates whether sign-in is
  /// allowed; `Memo` is the server's wording, shown when it is not.
  ///
  /// There is no dedicated "does this phone exist" endpoint — this call
  /// doubles as that check for the Google flow below, since a login attempt
  /// against an unregistered phone is the only way to find out.
  static const String login = '/apiSAMP/Master/LoginMembership';

  /// POST — creates, updates, or deletes a member, picked by [ModifyMode].
  /// Registering a new account sends:
  /// ```json
  /// {
  ///   "Mode": "1",
  ///   "TransID": "REGISTRATION",
  ///   "Data": {
  ///     "MemberName": "...",
  ///     "MemberPass": "...",
  ///     "PhoneNo": "...",       // bare subscriber number, e.g. 81234567890
  ///     "EmailAddress": "...",  // "" when there is none
  ///     "IsGoogle": "0"         // "1" for an account made through Google
  ///   }
  /// }
  /// ```
  /// It answers HTTP 200 whether or not it created the member, so the status
  /// code proves nothing. The envelope's `Msg` is "Berhasil" or "Gagal", and on
  /// success `Data[0].ResultMessage` is the new member's id (on a refusal, the
  /// reason). `AuthRemoteDataSourceImpl.register` requires both before it logs
  /// in. Edits to an existing member carry its `Data.MemberID` (and `OldPass`
  /// when the password is changed).
  ///
  /// The same call also carries other writes, picked by `TransID` (always
  /// `Mode: "1"`, answered with `{ResultMessage}`): `"REGISTERMOTOR"` adds a
  /// bike, `"RSV"` creates a booking, and `"REDEEMPOINT"` spends a member's
  /// points on a voucher, with `Data: {MemberID, PointID}`.
  ///
  /// A bike's own `Data` carries a `Line` — the record's row number, as the
  /// bike list returns it — which says which bike an edit or a delete means
  /// (`PlateNo` is an ordinary, editable field, not a key). Adding sends no
  /// `Line` at all, since a new bike has no record yet.
  ///
  /// Editing a registered bike is `Mode: "2"` with `TransID: "REGISTERMOTOR"`
  /// and the same `Data` as adding one, with that bike's `Line` filled in.
  /// **UNVERIFIED** — inferred from a member edit reusing `REGISTRATION` with
  /// Mode 2, not confirmed against the backend. See
  /// `BikesRemoteDataSourceImpl.updateBike`.
  ///
  /// Deleting a registered bike is `Mode: "3"` with `TransID: "REGISTERMOTOR"`
  /// and a `Data` of only `MemberID` and `Line`. The mode is sent as a
  /// literal: [ModifyMode]'s `"3"` is `changePassword`, and its delete is a
  /// member's. **UNVERIFIED** against the backend. See
  /// `BikesRemoteDataSourceImpl.deleteBike`.
  ///
  /// Marking an inbox message read is `Mode: "2"` with `TransID:
  /// "NOTIFICATION"` and a `Data` of `MemberID`, `NotificationID` (as the inbox
  /// returns it) and `IsRead: "1"`. **UNVERIFIED** — inferred from the other
  /// edits, not confirmed against the backend. See
  /// `NotificationRemoteDataSourceImpl.markAsRead`.
  ///
  /// The Google complete-profile flow creates its member through this same call
  /// (with `IsGoogle: "1"`), via `AuthRemoteDataSourceImpl.submitGoogleAccount`.
  static const String modify = '/apiSAMP/Modify';

  /// POST — the shared master-data lookup. One endpoint, many lists: the
  /// `Jenis` field in the body picks which one comes back, so every list reuses
  /// this single constant instead of getting a path constant of its own.
  ///
  /// `Jenis` values in use:
  /// - `"BRANCHSHOP"` → the workshop/branch locations. See
  ///   `WorkshopsRemoteDataSource`.
  /// - `"IMAGEFORAPPS"` → the home promo carousel banners, each record
  ///   `{Line, Base64Image}` where `Base64Image` is the raw image bytes
  ///   base64-encoded directly in the response (no image URL). See
  ///   `PromosRemoteDataSource`.
  /// - `"POINTID"` → the rewards a member can get for points, each record
  ///   `{PointID, PointName, PointQty}` (`PointQty` is the point cost). See
  ///   `RewardsRemoteDataSource`.
  static const String master = '/apiSAMP/Master';

  // ══════════════════════════════════════════════════════════════════════════
  // UNVERIFIED — the paths below follow the BrowseTrans naming convention but
  // have NOT been confirmed against the backend, and their request bodies are
  // best guesses at the real field names.
  //
  // Before shipping: check each against the real endpoint list and correct both
  // the path and the body keys in the owning data source. The response models
  // (`user_model.dart`, `service_model.dart`, `booking_model.dart`,
  // `bike_model.dart`) still carry scaffold field mappings and will need
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

  // No separate listing endpoint — confirmed to reuse [browseTrans] with
  // `Jenis: "SERVICEBOOKINGHISTORYBYMEMBER"`, the same way Home and Profile
  // each pick their own projection out of it. See
  // BookingsRemoteDataSourceImpl.getBookings.

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

  // Editing a member has no endpoint of its own: it is [modify] with
  // [ModifyMode.updateProfile]. See ProfileRemoteDataSourceImpl.updateProfile.

  /// POST — body: `{Brand, Model, Year, PlateNo}` → the created bike.
  ///
  /// Registering a unit is a write, so it does not share [browseTrans]; the
  /// previous code posted an insert-shaped body to the browse endpoint.
  static const String addBike = '/apiSAMP/InsertUnit';

  // NOTE: there is no separate dashboard endpoint. The home dashboard reads
  // membership stats from [browseTrans]; the former `/dashboard` constant was
  // scaffold left-over and never called.
}

/// The five actions [ApiConstants.modify] can perform, selected by its
/// `Mode` field. Confirmed directly against the backend — these are not a
/// guess the way most of the unverified block above is.
enum ModifyMode {
  create('1'),

  /// Mode '2' is "update" for any record, not only a member: an edited bike
  /// sends it too (see `BikesRemoteDataSourceImpl.updateBike`).
  updateProfile('2'),
  changePassword('3'),
  delete('4'),
  forgotPassword('5');

  /// The exact string [ApiConstants.modify] expects in its `Mode` field.
  /// A string, not an int — the confirmed request body sends `"Mode": "1"`.
  final String wireValue;

  const ModifyMode(this.wireValue);
}
