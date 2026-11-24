import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/tour/app_tour_audience.dart';

void main() {
  test('a member with no bike is new', () {
    expect(AppTourAudience.isNew(0), isTrue);
  });

  test('a negative count is read as none', () {
    expect(AppTourAudience.isNew(-1), isTrue);
  });

  test('a member with a bike is not new', () {
    expect(AppTourAudience.isNew(1), isFalse);
    expect(AppTourAudience.isNew(4), isFalse);
  });

  group('still to make their first booking', () {
    test('a member with a bike who has not booked is new', () {
      expect(AppTourAudience.isNew(1, bookingPending: true), isTrue);
      expect(AppTourAudience.isNew(4, bookingPending: true), isTrue);
    });

    test('a member with a bike who is not pending is not new', () {
      expect(AppTourAudience.isNew(1, bookingPending: false), isFalse);
    });

    test('a member with no bike is new either way', () {
      expect(AppTourAudience.isNew(0, bookingPending: true), isTrue);
      expect(AppTourAudience.isNew(0, bookingPending: false), isTrue);
    });

    test('not knowing counts as not pending', () {
      expect(AppTourAudience.isNew(2), isFalse);
    });
  });
}
