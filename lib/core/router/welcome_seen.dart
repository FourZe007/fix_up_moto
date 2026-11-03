import 'package:shared_preferences/shared_preferences.dart';

/// Whether this install has been through the welcome screen.
///
/// Welcome is a one-time introduction: the first logged-out launch lands there,
/// and once the member has tapped through it every later logged-out launch
/// (a restart, a logout, an expired session) goes straight to login.
///
/// Kept in [SharedPreferences], not secure storage: on iPhone the keychain can
/// survive an uninstall, so a reinstall would never show Welcome again, while
/// preferences are wiped along with the app. Reading is synchronous, so the
/// router's redirect can ask without waiting.
abstract final class WelcomeSeen {
  static const String key = 'welcome_seen';

  /// `false` when nothing is stored — and for any stored value that is not
  /// `true`, so a corrupt entry shows Welcome instead of throwing in a redirect.
  static bool read(SharedPreferences prefs) => prefs.get(key) == true;

  static Future<void> mark(SharedPreferences prefs) async {
    await prefs.setBool(key, true);
  }
}
