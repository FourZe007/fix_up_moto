/// Application-level constants that are not tied to any specific feature.
///
/// All members are static — this class is never instantiated.
/// Import this wherever you need app-wide config values.
class AppConstants {
  AppConstants._(); // private constructor prevents instantiation

  /// Display name shown in the app bar and OS task switcher.
  static const String appName = 'FixUp Moto';

  /// Maximum number of items returned per paginated API list request.
  /// Used by datasources when building query parameters.
  static const int pageSize = 20;

  /// Number of seconds before an API request is considered timed out.
  /// Referenced by [DioClient] base options.
  static const int requestTimeoutSeconds = 30;

  /// Minimum password length enforced on the registration form.
  static const int minPasswordLength = 8;

  /// Maximum characters allowed in a booking notes field.
  static const int maxBookingNotesLength = 500;

  /// The WhatsApp chat of the customer service line. A `wa.me` link opens the
  /// WhatsApp app when it is installed and the same chat in the browser when
  /// it is not.
  static const String whatsappServiceUrl = 'https://wa.me/6285179798961';

  /// FixUp Moto's public pages, shown as the Welcome screen's "Ikuti kami"
  /// icons. Empty until the real links are set (full https:// addresses): an
  /// empty one is hidden in a release build, and shown as a placeholder in
  /// debug and profile builds so the design can be judged — see
  /// WelcomeSocialLinks.
  static const String instagramUrl =
      'https://www.instagram.com/fixupmotoidn_official/';
  static const String tiktokUrl = 'https://www.tiktok.com/@fixupmotoidn';

  /// Whether members can choose light/dark mode.
  ///
  /// Off for now, so the app always uses the light theme even when the phone
  /// is set to dark, and the Settings button is hidden from Profile. The
  /// dark theme, ThemeCubit and Settings page are all still in the code —
  /// turn this on to bring the feature back.
  static const bool themeSwitchEnabled = false;
}
