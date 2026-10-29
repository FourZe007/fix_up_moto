import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';

void main() {
  group('Bahasa Indonesia names', () {
    // 30 Oct 2026 is a Friday.
    final friday = DateTime(2026, 10, 30);

    test('toDisplayDateId writes weekday, day, month and year', () {
      expect(DateTimeFormatter.toDisplayDateId(friday), 'Jum, 30 Okt 2026');
      expect(DateTimeFormatter.toDisplayDateId(null), '');
    });

    test('short names are the first three letters of the full names', () {
      expect(DateTimeFormatter.shortWeekdayId(friday), 'Jum');
      expect(DateTimeFormatter.shortMonthId(friday), 'Okt');
    });

    test('toShortDateId writes day, month and year without the weekday', () {
      expect(DateTimeFormatter.toShortDateId(friday), '30 Okt 2026');
      expect(
        DateTimeFormatter.toShortDateId(DateTime(2024, 9, 5)),
        '5 Sep 2024',
      );
      expect(DateTimeFormatter.toShortDateId(null), '');
    });

    test('toSpokenDateId writes the full names', () {
      expect(DateTimeFormatter.toSpokenDateId(friday), 'Jumat, 30 Oktober');
    });

    test('every weekday and month has a name', () {
      final weekdays = [
        for (var d = 2; d <= 8; d++)
          DateTimeFormatter.shortWeekdayId(DateTime(2026, 11, d)),
      ];
      expect(weekdays, ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']);

      final months = [
        for (var m = 1; m <= 12; m++)
          DateTimeFormatter.shortMonthId(DateTime(2026, m, 1)),
      ];
      expect(months, [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ]);
    });
  });
}
