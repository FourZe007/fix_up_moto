import 'package:shared_preferences/shared_preferences.dart';

/// Whether this install has been through the app tour.
///
/// The tour is a one-time walk through the five tabs for a member who has just
/// signed in. It is marked seen when the member finishes it or skips it, never
/// when it merely opens, so a member who is interrupted (a call, a force-close)
/// gets it again next launch instead of losing it. It is also marked seen, with
/// no tour shown, for a member who turns out not to be new (they already have a
/// bike, see `AppTourAudience`), so it cannot turn up later by itself.
/// Profile's "Panduan Aplikasi" row plays it again whenever they want, whatever
/// this says.
///
/// Kept in [SharedPreferences] for the same reason as `WelcomeSeen`: on iPhone
/// the keychain can survive an uninstall, while preferences are wiped with the
/// app, so a reinstall starts the tour again. Reading is synchronous.
///
/// It belongs to the phone, not to the member: someone else signing in on the
/// same phone does not see it again.
abstract final class AppTourSeen {
  static const String key = 'app_tour_seen';

  /// `false` when nothing is stored — and for any stored value that is not
  /// `true`, so a corrupt entry shows the tour instead of throwing.
  static bool read(SharedPreferences prefs) => prefs.get(key) == true;

  static Future<void> mark(SharedPreferences prefs) async {
    await prefs.setBool(key, true);
  }
}
