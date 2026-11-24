/// Who the app tour plays for by itself.
///
/// The tour exists for a member who does not yet know the app, and the app has
/// no "joined on" date to tell such a member from one who has used it for a year.
/// What it does know is two things the phone has seen: the bike count, and
/// whether the member still has their first booking to make (see
/// `FirstBookingGuide`). A member with no bike registered is in the same spot as a
/// brand-new one: nothing set up, nothing booked. So is a member the phone noted
/// as new who now has a bike but has not booked yet: one step further on, still
/// without the thing the app is for. Anyone else (a bike, and either booked or
/// never seen at the start) is not new, and is never shown the tour unasked.
/// (Profile's "Panduan Aplikasi" row still plays it for anyone.)
///
/// The same state the other first-task nudges use (Home's "Tambah motor pertama
/// Anda" and "Buat booking pertama Anda" cards, the tour's own hand-off), so all
/// of them agree on who is new.
abstract final class AppTourAudience {
  /// Whether a member with [bikeCount] bikes counts as new.
  ///
  /// [bookingPending] is whether the phone remembers them as still to make their
  /// first booking. It only matters for a member with a bike: one with none is
  /// new either way. It defaults to false, so a caller that does not know gets
  /// the plain "no bike" rule.
  static bool isNew(int bikeCount, {bool bookingPending = false}) =>
      bikeCount <= 0 || bookingPending;
}
