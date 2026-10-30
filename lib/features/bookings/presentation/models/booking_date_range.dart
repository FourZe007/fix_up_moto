import 'package:flutter/material.dart' show DateTimeRange, DateUtils;
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';

/// The shortcuts on the Bookings date filter ("Pilihan cepat").
///
/// All of them are date-only (midnight) ranges, inclusive on both ends, like
/// the page's own range. Three look ahead from tomorrow; [thisMonth] is the
/// whole calendar month, so it also shows what already happened this month.
enum BookingRangePreset {
  week('7 hari'),
  month('1 bulan'),
  thisMonth('Bulan ini'),
  threeMonths('3 bulan');

  final String label;
  const BookingRangePreset(this.label);

  /// The range this shortcut stands for when today is [now].
  DateTimeRange rangeOn(DateTime now) {
    final today = DateUtils.dateOnly(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    return switch (this) {
      BookingRangePreset.week => DateTimeRange(
        start: tomorrow,
        end: DateTime(tomorrow.year, tomorrow.month, tomorrow.day + 6),
      ),
      BookingRangePreset.month => DateTimeRange(
        start: tomorrow,
        end: _plusMonths(tomorrow, 1),
      ),
      BookingRangePreset.thisMonth => DateTimeRange(
        start: DateTime(today.year, today.month),
        end: DateTime(today.year, today.month + 1, 0),
      ),
      BookingRangePreset.threeMonths => DateTimeRange(
        start: tomorrow,
        end: _plusMonths(tomorrow, 3),
      ),
    };
  }

  /// What the page opens on, and what "Reset" goes back to: tomorrow to
  /// one month later.
  static DateTimeRange defaultRange(DateTime now) => month.rangeOn(now);

  /// The shortcut whose range is exactly [range] when today is [now], or null
  /// for a range somebody picked by hand.
  static BookingRangePreset? matching(DateTimeRange range, DateTime now) {
    for (final preset in values) {
      if (preset.rangeOn(now) == range) return preset;
    }
    return null;
  }

  /// [from] moved [months] months on. The day clamps to the target month's
  /// last day, so a 31st doesn't spill into the month after (Jan 31 + 1 month
  /// would otherwise become Mar 3).
  static DateTime _plusMonths(DateTime from, int months) {
    final lastDay = DateTime(from.year, from.month + months + 1, 0).day;
    return DateTime(
      from.year,
      from.month + months,
      from.day < lastDay ? from.day : lastDay,
    );
  }
}

/// How a date range reads on screen, in Bahasa Indonesia.
extension BookingDateRangeText on DateTimeRange {
  /// How many days the range covers, both ends included.
  int get dayCount {
    final first = DateTime.utc(start.year, start.month, start.day);
    final last = DateTime.utc(end.year, end.month, end.day);
    return last.difference(first).inDays + 1;
  }

  /// "31 hari · Sab, 31 Okt sampai Sen, 30 Nov", under the two date cards.
  String get summary {
    final from = _dayAndMonth(start);
    if (dayCount == 1) return '1 hari · $from';
    return '$dayCount hari · $from sampai ${_dayAndMonth(end)}';
  }

  /// "15 Nov – 20 Nov 2026", on the chip under the tabs. The year is written
  /// once, unless the range crosses a year end.
  String get chipLabel {
    final from = start.year == end.year
        ? '${start.day} ${DateTimeFormatter.shortMonthId(start)}'
        : DateTimeFormatter.toShortDateId(start);
    return '$from – ${DateTimeFormatter.toShortDateId(end)}';
  }

  static String _dayAndMonth(DateTime date) =>
      '${DateTimeFormatter.shortWeekdayId(date)}, ${date.day} '
      '${DateTimeFormatter.shortMonthId(date)}';
}
