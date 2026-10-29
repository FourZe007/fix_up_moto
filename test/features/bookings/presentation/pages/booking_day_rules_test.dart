import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/bookings/presentation/pages/create_booking_page.dart';

void main() {
  // 30 Oct 2026 is a Friday, followed by the weekend of 31 Oct and 1 Nov.
  final friday = DateTime(2026, 10, 30);
  final saturday = DateTime(2026, 10, 31);
  final sunday = DateTime(2026, 11, 1);
  final monday = DateTime(2026, 11, 2);

  test('isBookableDay rejects Saturday and Sunday only', () {
    expect(isBookableDay(saturday), isFalse);
    expect(isBookableDay(sunday), isFalse);
    expect(isBookableDay(friday), isTrue);
    expect(isBookableDay(monday), isTrue);
  });

  test('firstBookableDay skips the weekend and keeps any weekday', () {
    expect(firstBookableDay(saturday), monday);
    expect(firstBookableDay(sunday), monday);
    expect(firstBookableDay(friday), friday);
    expect(firstBookableDay(monday), monday);
  });
}
