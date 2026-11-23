/// Who the app tour plays for by itself.
///
/// The tour exists for a member who does not yet know the app, and the app has
/// no "joined on" date to tell such a member from one who has used it for a year.
/// What it does know is the bike count, and a member with no bike registered is
/// in the same spot as a brand-new one: nothing set up, nothing booked. So that
/// is the line: a member with at least one bike is not new, and is never shown
/// the tour unasked. (Profile's "Panduan Aplikasi" row still plays it for anyone.)
///
/// The same state the other first-task nudges use (Home's "Tambah motor pertama
/// Anda" card, the tour's own hand-off), so all of them agree on who is new.
abstract final class AppTourAudience {
  /// Whether a member with [bikeCount] bikes counts as new.
  static bool isNew(int bikeCount) => bikeCount <= 0;
}
