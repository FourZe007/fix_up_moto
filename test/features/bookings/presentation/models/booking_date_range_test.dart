import 'package:flutter/material.dart' show DateTimeRange, DateUtils;
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/bookings/presentation/models/booking_date_range.dart';

DateTimeRange range(DateTime start, DateTime end) =>
    DateTimeRange(start: start, end: end);

void main() {
  // Friday 30 Oct 2026, so tomorrow is Saturday the 31st.
  final friday = DateTime(2026, 10, 30);

  group('BookingRangePreset.rangeOn', () {
    test('7 hari is seven days from tomorrow, both ends included', () {
      final r = BookingRangePreset.week.rangeOn(friday);

      expect(r, range(DateTime(2026, 10, 31), DateTime(2026, 11, 6)));
      expect(r.dayCount, 7);
    });

    test('1 bulan is tomorrow to the same day one month on', () {
      expect(
        BookingRangePreset.month.rangeOn(friday),
        range(DateTime(2026, 10, 31), DateTime(2026, 11, 30)),
      );
    });

    test('1 bulan clamps to the last day of a shorter month', () {
      // Tomorrow is Jan 31; Feb has no 31st (nor, in 2027, a 29th).
      expect(
        BookingRangePreset.month.rangeOn(DateTime(2027, 1, 30)),
        range(DateTime(2027, 1, 31), DateTime(2027, 2, 28)),
      );
      expect(
        BookingRangePreset.month.rangeOn(DateTime(2028, 1, 30)),
        range(DateTime(2028, 1, 31), DateTime(2028, 2, 29)),
      );
    });

    test('1 bulan rolls over a year end', () {
      expect(
        BookingRangePreset.month.rangeOn(DateTime(2026, 12, 31)),
        range(DateTime(2027, 1, 1), DateTime(2027, 2, 1)),
      );
    });

    test('Bulan ini is the whole calendar month, today included', () {
      expect(
        BookingRangePreset.thisMonth.rangeOn(friday),
        range(DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
      );
      expect(
        BookingRangePreset.thisMonth.rangeOn(DateTime(2028, 2, 10)),
        range(DateTime(2028, 2, 1), DateTime(2028, 2, 29)),
      );
    });

    test('3 bulan is tomorrow to three months on, clamped', () {
      expect(
        BookingRangePreset.threeMonths.rangeOn(friday),
        range(DateTime(2026, 10, 31), DateTime(2027, 1, 31)),
      );
      expect(
        BookingRangePreset.threeMonths.rangeOn(DateTime(2026, 11, 29)),
        range(DateTime(2026, 11, 30), DateTime(2027, 2, 28)),
      );
    });

    test('the time of day makes no difference', () {
      for (final preset in BookingRangePreset.values) {
        expect(
          preset.rangeOn(DateTime(2026, 10, 30, 23, 59)),
          preset.rangeOn(friday),
          reason: preset.label,
        );
      }
    });

    test('every range is date-only', () {
      for (final preset in BookingRangePreset.values) {
        final r = preset.rangeOn(DateTime(2026, 10, 30, 14, 30));
        expect(r.start, DateUtils.dateOnly(r.start), reason: preset.label);
        expect(r.end, DateUtils.dateOnly(r.end), reason: preset.label);
      }
    });
  });

  test('the default range is 1 bulan', () {
    expect(
      BookingRangePreset.defaultRange(friday),
      BookingRangePreset.month.rangeOn(friday),
    );
  });

  group('BookingRangePreset.matching', () {
    test('finds the shortcut a range came from', () {
      for (final preset in BookingRangePreset.values) {
        expect(
          BookingRangePreset.matching(preset.rangeOn(friday), friday),
          preset,
          reason: preset.label,
        );
      }
    });

    test('is null for a range picked by hand', () {
      expect(
        BookingRangePreset.matching(
          range(DateTime(2026, 11, 15), DateTime(2026, 11, 20)),
          friday,
        ),
        isNull,
      );
    });

    test('is null once a day has passed and the range has not moved', () {
      final yesterdaysWeek = BookingRangePreset.week.rangeOn(friday);

      expect(
        BookingRangePreset.matching(yesterdaysWeek, DateTime(2026, 10, 31)),
        isNull,
      );
    });
  });

  group('BookingDateRangeText', () {
    test('counts the days, both ends included', () {
      expect(
        range(DateTime(2026, 10, 31), DateTime(2026, 11, 30)).dayCount,
        31,
      );
      expect(range(DateTime(2026, 10, 31), DateTime(2026, 10, 31)).dayCount, 1);
      expect(range(DateTime(2026, 12, 30), DateTime(2027, 1, 2)).dayCount, 4);
    });

    test('the summary names the days and the weekdays', () {
      expect(
        range(DateTime(2026, 10, 31), DateTime(2026, 11, 30)).summary,
        '31 hari · Sab, 31 Okt sampai Sen, 30 Nov',
      );
      expect(
        range(DateTime(2026, 11, 15), DateTime(2026, 11, 20)).summary,
        '6 hari · Min, 15 Nov sampai Jum, 20 Nov',
      );
    });

    test('the summary of a single day has no "sampai"', () {
      expect(
        range(DateTime(2026, 10, 31), DateTime(2026, 10, 31)).summary,
        '1 hari · Sab, 31 Okt',
      );
    });

    test('the chip writes the year once', () {
      expect(
        range(DateTime(2026, 11, 15), DateTime(2026, 11, 20)).chipLabel,
        '15 Nov – 20 Nov 2026',
      );
    });

    test('the chip writes both years across a year end', () {
      expect(
        range(DateTime(2026, 12, 30), DateTime(2027, 1, 5)).chipLabel,
        '30 Des 2026 – 5 Jan 2027',
      );
    });
  });
}
