import 'package:shared_preferences/shared_preferences.dart';

/// What this phone remembers about which members still have their first booking
/// to make, so Home can nudge them (see `FirstBookingSlot`).
///
/// The app cannot ask the server whether a member has ever booked: bookings are
/// only fetched by date range, so "never" would mean searching all of history.
/// Instead it goes by what it has seen, the same way the app tour decides who is
/// new: a member the app finds with **no bike registered** is a new member, and
/// is noted as *pending*. A member the app never finds in that state (everyone
/// who already had a bike before this existed) is never pending, so existing
/// members do not get a "first booking" nudge. A booking made in the app
/// *settles* the member for good, so the nudge goes, and cannot come back if
/// they later delete their last bike.
///
/// Kept per member, in [SharedPreferences]: a phone is sometimes shared, and
/// preferences (unlike the iPhone keychain) are wiped with the app. The cost of
/// this approach is on the record: a member who booked before, then removed
/// every bike and added one again, is nudged once more.
abstract final class FirstBookingGuide {
  /// Members noted as new who have not booked yet.
  static const String pendingKey = 'first_booking_pending';

  /// Members who have booked (or were settled some other way): never pending
  /// again.
  static const String settledKey = 'first_booking_settled';

  /// Whether [memberId] is still to make their first booking.
  static bool isPending(SharedPreferences prefs, String memberId) =>
      _read(prefs, pendingKey).contains(memberId);

  /// Notes [memberId] as a new member, unless they are already noted or already
  /// settled. Safe to call over and over.
  static Future<void> notePending(SharedPreferences prefs, String memberId) {
    final pending = _read(prefs, pendingKey);
    if (pending.contains(memberId) ||
        _read(prefs, settledKey).contains(memberId)) {
      return Future<void>.value();
    }
    return prefs.setStringList(pendingKey, [...pending, memberId]);
  }

  /// Marks [memberId] as having booked: no longer pending, and not to be noted
  /// as pending again.
  static Future<void> settle(SharedPreferences prefs, String memberId) async {
    final settled = _read(prefs, settledKey);
    if (!settled.contains(memberId)) {
      await prefs.setStringList(settledKey, [...settled, memberId]);
    }
    final pending = _read(prefs, pendingKey);
    if (pending.contains(memberId)) {
      await prefs.setStringList(pendingKey, [
        for (final id in pending)
          if (id != memberId) id,
      ]);
    }
  }

  /// The stored list, or empty for nothing stored and for anything that is not a
  /// list of strings, so a corrupt entry reads as "nobody" instead of throwing.
  static List<String> _read(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    return value is List ? value.whereType<String>().toList() : const [];
  }
}
