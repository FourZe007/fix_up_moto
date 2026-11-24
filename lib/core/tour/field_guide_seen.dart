import 'package:shared_preferences/shared_preferences.dart';

/// Which form a field guide belongs to. One id per form, so each guide is
/// remembered on its own.
abstract final class FieldGuideId {
  /// The guide on Add Bike, about each of its text fields and its photo box.
  static const String addBike = 'add_bike';

  /// The guide on Create Booking, about each thing the member picks or types.
  static const String createBooking = 'create_booking';
}

/// Whether this phone has been through a form's field guide (see
/// `buildFieldGuide`).
///
/// The same rules as [AppTourSeen]: marked when the guide *ends* (Selesai or
/// Lewati), never when it merely opens, so a member who leaves the page halfway
/// gets it again next time; kept in [SharedPreferences] (wiped with the app,
/// unlike the iPhone keychain) and read synchronously; it belongs to the phone,
/// not the member. The replay button on the form plays the guide whatever this
/// says.
///
/// [AppTourSeen]: package:fix_up_moto/core/tour/app_tour_seen.dart
abstract final class FieldGuideSeen {
  /// The preferences key for the guide of [guideId].
  static String keyFor(String guideId) => 'field_guide_seen_$guideId';

  /// `false` when nothing is stored, and for any stored value that is not
  /// `true`, so a corrupt entry shows the guide instead of throwing.
  static bool read(SharedPreferences prefs, String guideId) =>
      prefs.get(keyFor(guideId)) == true;

  static Future<void> mark(SharedPreferences prefs, String guideId) async {
    await prefs.setBool(keyFor(guideId), true);
  }
}
