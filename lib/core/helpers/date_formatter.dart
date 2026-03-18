import 'package:intl/intl.dart';

/// Utility class for consistent date and time formatting throughout the app.
///
/// All methods are static — import and call directly:
///   `DateFormatter.toDisplayDate(booking.date)` → "Mon, 10 Mar 2026"
///
/// Using a single class keeps formatting patterns consistent across the UI and
/// makes localisation changes (e.g. switching locale) a one-file edit.
class DateFormatter {
  DateFormatter._(); // static-only class

  // ── Formatters ────────────────────────────────────────────────────────────
  // DateFormat objects are created once and reused — instantiation is expensive.

  /// "Mon, 10 Mar 2026" — used on booking cards and appointment lists.
  static final DateFormat _displayDate = DateFormat('EEE, d MMM yyyy');

  /// "10 Mar 2026" — compact version for tight spaces (chips, table cells).
  static final DateFormat _shortDate = DateFormat('d MMM yyyy');

  /// "10:30 AM" — time-slot labels and booking confirmation screens.
  static final DateFormat _time = DateFormat('h:mm a');

  /// "Mon, 10 Mar 2026 at 10:30 AM" — full timestamp in confirmation dialogs.
  static final DateFormat _fullDateTime = DateFormat("EEE, d MMM yyyy 'at' h:mm a");

  /// "March 2026" — month header in calendar views.
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');

  // ── Public API ────────────────────────────────────────────────────────────

  /// Formats [date] as "Mon, 10 Mar 2026".
  /// Returns an empty string if [date] is null.
  static String toDisplayDate(DateTime? date) {
    if (date == null) return '';
    return _displayDate.format(date);
  }

  /// Formats [date] as "10 Mar 2026".
  static String toShortDate(DateTime? date) {
    if (date == null) return '';
    return _shortDate.format(date);
  }

  /// Formats [dateTime] as "10:30 AM".
  static String toTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _time.format(dateTime);
  }

  /// Formats [dateTime] as "Mon, 10 Mar 2026 at 10:30 AM".
  static String toFullDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _fullDateTime.format(dateTime);
  }

  /// Formats [date] as "March 2026".
  static String toMonthYear(DateTime? date) {
    if (date == null) return '';
    return _monthYear.format(date);
  }

  /// Returns a human-friendly relative label for [date]:
  /// "Today", "Tomorrow", "Yesterday", or falls back to [toDisplayDate].
  static String toRelativeLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return toDisplayDate(date);
  }
}
