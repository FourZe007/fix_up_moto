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
}
