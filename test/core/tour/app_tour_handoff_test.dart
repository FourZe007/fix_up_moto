import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/tour/app_tour_handoff.dart';

void main() {
  group('addFirstBike', () {
    const handoff = AppTourHandoff.addFirstBike;

    test('goes to Add Bike', () {
      expect(handoff.route, RouteNames.addBike);
    });

    test("opens it as the guidance's bike step, to offer a booking after", () {
      expect(handoff.extra, FirstTaskStep.addBike);
    });

    test('says why in a sentence, and what the button does', () {
      expect(handoff.message, contains('motor'));
      expect(handoff.message, contains('booking'));
      expect(handoff.acceptLabel, 'Tambah motor sekarang');
    });
  });

  group('forBikeCount', () {
    test('a member with no bike is offered adding one', () {
      expect(AppTourHandoff.forBikeCount(0), AppTourHandoff.addFirstBike);
    });

    test('a negative count is treated as none', () {
      expect(AppTourHandoff.forBikeCount(-1), AppTourHandoff.addFirstBike);
    });

    test('a member with a bike is offered nothing', () {
      expect(AppTourHandoff.forBikeCount(1), isNull);
      expect(AppTourHandoff.forBikeCount(4), isNull);
    });

    test('an unknown count (stats not loaded) is offered nothing', () {
      expect(AppTourHandoff.forBikeCount(null), isNull);
    });
  });
}
