import 'package:intl/intl.dart';

/// Utility class for consistent date and time formatting throughout the app.
///
/// All methods are static — import and call directly:
///   `DateTimeFormatter.toDisplayDate(booking.date)` → "Mon, 10 Mar 2026"
///
/// Using a single class keeps formatting patterns consistent across the UI and
/// makes localisation changes (e.g. switching locale) a one-file edit.
class DateTimeFormatter {
  DateTimeFormatter._(); // static-only class

  // ── Formatters ────────────────────────────────────────────────────────────
  // DateFormat objects are created once and reused — instantiation is expensive.

  /// "Mon, 10 Mar 2026" — used on booking cards and appointment lists.
  static final DateFormat _displayDate = DateFormat('EEE, d MMM yyyy');

  /// "10 Mar 2026" — compact version for tight spaces (chips, table cells).
  static final DateFormat _shortDate = DateFormat('d MMM yyyy');

  /// "10:30 AM" — time-slot labels and booking confirmation screens.
  static final DateFormat _time = DateFormat('h:mm a');

  /// "Mon, 10 Mar 2026 • 10:30 AM" — full timestamp in confirmation dialogs.
  static final DateFormat _fullDateTime = DateFormat(
    "EEE, d MMM yyyy '•' h:mm",
  );

  /// "March 2026" — month header in calendar views.
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');

  /// "2026-08-31" — SAMP wire format for `BookDate`, not for display.
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');

  /// "10:00" (24-hour) — SAMP wire format for `BookTime`, not for display.
  static final DateFormat _apiTime = DateFormat('HH:mm');

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

  /// Formats [dateTime] as "Mon, 10 Mar 2026 • 10:30 AM".
  static String toFullDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _fullDateTime.format(dateTime);
  }

  /// Formats [date] as "March 2026".
  static String toMonthYear(DateTime? date) {
    if (date == null) return '';
    return _monthYear.format(date);
  }

  /// Formats [dateTime] as `"2026-08-31"` — the `BookDate` wire format a
  /// SAMP write request expects. Despite the name, [dateTime] is used as-is
  /// with no UTC conversion (local time in, local time out) — matching how
  /// the response side reads it back with none either (see `BookingModel`'s
  /// own `_combineDateAndTime`). Pair with [fromUtcToTime] for `BookTime`.
  static String fromUtcToDate(DateTime dateTime) => _apiDate.format(dateTime);

  /// Formats [dateTime] as `"10:00"` (24-hour) — the `BookTime` wire format
  /// a SAMP write request expects. Same no-UTC-conversion behavior as
  /// [fromUtcToDate] — see its doc comment.
  static String fromUtcToTime(DateTime dateTime) => _apiTime.format(dateTime);

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

  // ── Bahasa Indonesia ──────────────────────────────────────────────────────
  // Hand-written names rather than DateFormat('…', 'id_ID'), which would need
  // the locale data initialised at startup. The formatters above stay English;
  // use these where a screen is written in Bahasa Indonesia.

  static const List<String> _weekdaysId = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _monthsId = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// "Jum" — the first three letters of the weekday's Indonesian name.
  static String shortWeekdayId(DateTime date) =>
      _weekdaysId[date.weekday - 1].substring(0, 3);

  /// "Okt" — the first three letters of the month's Indonesian name.
  static String shortMonthId(DateTime date) =>
      _monthsId[date.month - 1].substring(0, 3);

  /// Formats [date] as "Jum, 30 Okt 2026".
  /// Returns an empty string if [date] is null.
  static String toDisplayDateId(DateTime? date) {
    if (date == null) return '';
    return '${shortWeekdayId(date)}, ${date.day} ${shortMonthId(date)} '
        '${date.year}';
  }

  /// Formats [date] as "16 Sep 2024".
  /// Returns an empty string if [date] is null.
  static String toShortDateId(DateTime? date) {
    if (date == null) return '';
    return '${date.day} ${shortMonthId(date)} ${date.year}';
  }

  /// Formats [date] as "Jumat, 30 Oktober" — the full names, for screen readers.
  static String toSpokenDateId(DateTime date) =>
      '${_weekdaysId[date.weekday - 1]}, ${date.day} '
      '${_monthsId[date.month - 1]}';
}
